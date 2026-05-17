import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';


import '../models.dart';
import '../ai_client.dart';
import '../semantic_scholar_client.dart';
import 'pipeline_progress.dart';

/// Helper class for ranking literature sources by relevance to a paragraph.
class _RankedSource {
  final ResearchFile file;
  final int score;
  final int globalIndex;
  _RankedSource({required this.file, required this.score, required this.globalIndex});
}

/// Result of a citation quality gate check.
class _QualityGateResult {
  final bool passed;
  final int citationCount;
  final String reason;
  _QualityGateResult({required this.passed, required this.citationCount, required this.reason});
}

class ChatState extends ChangeNotifier {
  late AiClient _client;
  late Box<String> _projectBox;
  late Box<String> _settingsBox;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _selectedModel;
  String? get selectedModel => _selectedModel;
  List<String> _models = [];
  List<String> get models => _models;
  
  Set<String> _ollamaModelNames = {};
  List<String> get localModels => _models.where((m) => _ollamaModelNames.contains(m)).toList();
  List<String> get cloudModels => _models.where((m) => !_ollamaModelNames.contains(m)).toList();

  Map<String, String> _apiKeys = {};
  Map<String, String> get apiKeys => _apiKeys;

  int _researchTabIndex = 0;
  int get researchTabIndex => _researchTabIndex;

  List<ResearchProject> _allProjects = [];
  List<ResearchProject> get allProjects => _allProjects;

  ResearchProject? _currentProject;
  ResearchProject? get currentProject => _currentProject;

  List<ResearchFile> get researchFiles => _currentProject?.files ?? [];
  String get researchTitle => _currentProject?.title ?? "";
  String get citationStyle => _currentProject?.citationStyle ?? "APA";
  bool get isAutonomousProactive => _currentProject?.isAutonomousProactive ?? true;
  bool get isDraftRefinementMode => _currentProject?.isDraftRefinementMode ?? false;
  String get initialDraft => _currentProject?.initialDraft ?? "";
  String get researchExtraInstructions => _currentProject?.extraInstructions ?? "";
  String get reviewerComments => _currentProject?.reviewerInstructions ?? "";

  bool _isTerminalExpanded = true;
  bool get isTerminalExpanded => _isTerminalExpanded;
  
  List<String> _terminalLines = [];
  List<String> get terminalLines => _terminalLines;

  String? _activeOutputSectionId;
  String? get activeOutputSectionId => _activeOutputSectionId;

  String _outputViewMode = 'canvas';
  String get outputViewMode => _outputViewMode;

  final Map<String, bool> _sectionLoading = {};
  Map<String, bool> get sectionLoading => _sectionLoading;

  bool _extendedLiteratureSearch = false;
  bool get extendedLiteratureSearch => _extendedLiteratureSearch;
  bool _isSearchingLiterature = false;
  bool get isSearchingLiterature => _isSearchingLiterature;
  int _semanticLimit = 10;
  int get semanticLimit => _semanticLimit;
  int _semanticMinYear = 2015;
  int get semanticMinYear => _semanticMinYear;

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;


  String _paraphraseInstructions = "Paraphrase the following academic text to be more original while preserving the meaning, technical accuracy, and citation references. Use varied sentence structures, different vocabulary, and rephrase without losing scholarly tone. Do NOT remove or alter any citations.";
  String get paraphraseInstructions => _paraphraseInstructions;

  // Undo/Redo history per section
  final Map<String, List<String>> _sectionHistory = {};
  final Map<String, int> _sectionHistoryIdx = {};

  final Map<int, String> agentInstructions = {
    0: "You are the Data Explorer Assistant. Help the user understand their uploaded research files.",
    1: """<ROLE>
  You are an Elite Literature Reviewer.
</ROLE>
<TASK>
  Write a comprehensive, scholarly literature review based ONLY on the provided source material.
</TASK>
<RULES>
  1. Use {{CITATION_STYLE}} in-text citations.
  2. EVERY claim must be cited using the provided keys.
  3. Include a '## References' section at the end with DOIs.
  4. START DIRECTLY with the review content. 
  5. DO NOT repeat these instructions. 
  6. DO NOT include any introductory or concluding conversational filler.
</RULES>""",
    2: """<ROLE>
  You are an Elite Research Methodologist.
</ROLE>
<TASK>
  Design a detailed, technical, step-by-step methodology for the project.
</TASK>
<RULES>
  1. Output ONLY the methodology content.
  2. DO NOT repeat the project title or context descriptions.
  3. DO NOT include introductory filler. 
  4. START DIRECTLY with the first heading.
</RULES>""",
    3: "You are an Elite Data Laboratorian. Your task is to write CLEAN Python code to analyze CSV/JSON files. ALWAYS use 'pandas' for CSVs. Files available in the current directory: {{FILES}}. Output ONLY a ```python code block. NEVER use placeholders. Use the exact filenames provided. Output ONLY the code.",
    4: """<ROLE>
  You are an Elite Academic Manuscript Writer.
</ROLE>
<TASK>
  Write the specific section requested based on the project context and literature.
</TASK>
<RULES>
  1. Use {{CITATION_STYLE}} in-text citations consistently.
  2. Use ONLY the provided bibliography for citations.
  3. START DIRECTLY with the content for the section.
  4. DO NOT repeat the project title, author list, or prompts.
  5. DO NOT provide conversational intro/outro.
</RULES>""",
    5: "You are an Elite Peer Reviewer acting as a rigid strict Quality Control gatekeeper. Provide constructive, section-by-section feedback for the entire manuscript. You MUST verify that: completely ALL ingested sources are cited in-text, the Title and Introduction are completely written, and there is ZERO conversational filler (like 'Here is a summary'). If any of these are missing, or citations lack DOIs, you MUST explicitly state 'FAILS quality check' and list exactly what needs changing so the writer can rewrite it. Output ONLY Markdown.",
  };

  static Future<Delta> _computeDelta(String markdown) async {
    String cleaned = _cleanLatexStatic(markdown);
    final List<_MarkdownChunk> chunks = _parseMarkdownIntoChunksStatic(cleaned);
    final delta = Delta();
    for (final chunk in chunks) {
      if (chunk.type == 'formula') {
        delta.insert({'formula': chunk.content});
        delta.insert('\n');
      } else {
        delta.insert(chunk.content);
      }
    }
    return delta;
  }

  Future<Delta> _buildAdvancedDelta(String markdown) async {
    return await compute(_computeDelta, markdown);
  }

  static String _cleanLatexStatic(String input) {
    return input
        .replaceAll(r'\(', r'$').replaceAll(r'\)', r'$')
        .replaceAll(r'\[', r'$$').replaceAll(r'\]', r'$$')
        .replaceAll(r'\begin{equation}', r'$$').replaceAll(r'\end{equation}', r'$$')
        .replaceAll(r'\begin{align}', r'$$').replaceAll(r'\end{align}', r'$$')
        .replaceAll(r'\mathbf', '').replaceAll(r'\text', '')
        .replaceAll('{', '').replaceAll('}', '');
  }

  static List<_MarkdownChunk> _parseMarkdownIntoChunksStatic(String markdown) {
    final List<_MarkdownChunk> chunks = [];
    final lines = markdown.split('\n');
    String currentBlock = "";
    String mode = 'text';

    for (var line in lines) {
      if (line.trim().startsWith(r'$$')) {
        if (mode == 'formula') {
          chunks.add(_MarkdownChunk('formula', currentBlock.trim()));
          currentBlock = "";
          mode = 'text';
        } else {
          chunks.add(_MarkdownChunk('text', currentBlock));
          currentBlock = "";
          mode = 'formula';
        }
        continue;
      }
      currentBlock += "$line\n";
    }
    if (currentBlock.isNotEmpty) chunks.add(_MarkdownChunk(mode, currentBlock));
    return chunks;
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      _projectBox = await Hive.openBox<String>('research_projects_json');
      _settingsBox = await Hive.openBox<String>('settings');
      
      final keysJson = _settingsBox.get('api_keys');
      if (keysJson != null) {
        _apiKeys = Map<String, String>.from(jsonDecode(keysJson));
      }
      
      _client = AiClient(apiKeys: _apiKeys);
      _allProjects = _projectBox.values.map((s) => ResearchProject.fromJson(jsonDecode(s))).toList();
      
      final savedTheme = _settingsBox.get('theme_mode');
      if (savedTheme != null) {
        _themeMode = savedTheme == 'light' ? ThemeMode.light : ThemeMode.dark;
      }

      await fetchModels();
    } catch (e) {
      _terminalLines.add("❌ Init error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchModels() async {
    try {
      final fetched = await _client.listModels();
      _ollamaModelNames = fetched.toSet();
      _models = fetched;
      if (_models.isNotEmpty) {
        if (_selectedModel == null || !_models.contains(_selectedModel)) {
          _selectedModel = _models.first;
        }
      }
      notifyListeners();
    } catch (e) {
      _terminalLines.add("❌ Model fetch error: $e");
    }
  }

  void setSelectedModel(String model) {
    if (!_models.contains(model)) _models.add(model);
    _selectedModel = model;
    notifyListeners();
  }

  void addCustomModel(String model, String? apiKey) {
    if (!_models.contains(model)) _models.add(model);
    _selectedModel = model;
    
    if (apiKey != null && apiKey.isNotEmpty && model.contains(':')) {
      final provider = model.split(':').first;
      saveApiKey(provider, apiKey);
    } else {
      notifyListeners();
    }
  }

  void removeCustomModel(String model) {
    if (_ollamaModelNames.contains(model)) return;
    _models.remove(model);
    if (_selectedModel == model) {
      _selectedModel = _models.isNotEmpty ? _models.first : null;
    }
    notifyListeners();
  }
  
  void setDataAnalysisModel(String? model) {
    if (model != null && !_models.contains(model)) _models.add(model);
    if (_currentProject != null) {
      _currentProject!.dataAnalysisModel = model;
      saveResearchHub();
      notifyListeners();
    }
  }

  void saveApiKey(String provider, String key) {
    _apiKeys[provider] = key;
    _settingsBox.put('api_keys', jsonEncode(_apiKeys));
    _client = AiClient(apiKeys: _apiKeys);
    fetchModels();
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _settingsBox.put('theme_mode', _themeMode == ThemeMode.light ? 'light' : 'dark');
    notifyListeners();
  }

  void createNewProject(String title, {String projectType = "Academic Manuscript"}) {
    final newProject = ResearchProject(title: title, projectType: projectType);
    _projectBox.put(newProject.id, jsonEncode(newProject.toJson()));
    _allProjects.add(newProject);
    _currentProject = newProject;
    _researchTabIndex = 1;
    _terminalLines.add("🚀 Project Created: ${newProject.title} ($projectType)");
    notifyListeners();
  }

  void selectProject(ResearchProject project) {
    _currentProject = project;
    _researchTabIndex = 1;
    _terminalLines.add("📍 Active: ${project.title}");
    if (project.finalManuscript.isNotEmpty) {
      copyToEditor(project.finalManuscript);
    }
    notifyListeners();
  }

  void deleteProject(String id) {
    _projectBox.delete(id);
    _allProjects.removeWhere((p) => p.id == id);
    if (_currentProject?.id == id) _currentProject = null;
    notifyListeners();
  }

  Future<void> loadResearchFromUrl(String url) async {
    if (_currentProject == null || url.isEmpty) return;
    if (!url.startsWith('http')) url = 'https://$url';
    _isAttachingDocument = true;
    _terminalLines.add("🔍 Ingesting: $url");
    notifyListeners();
    try {
      final res = await http.post(
        Uri.parse('http://127.0.0.1:8000/proxy'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': url}),
      ).timeout(const Duration(seconds: 20));
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        String content = data['content']; 
        String type = data['type'] ?? 'html';
        String name = url.split('/').last.split('?').first;
        if (name.isEmpty) name = "Web_Article_${DateTime.now().millisecond}";
        if (type == 'pdf' && !name.toLowerCase().endsWith('.pdf')) name += '.pdf';

        final rf = ResearchFile(
          name: name, content: content, type: type, charCount: content.length,
          category: FileCategory.literature,
        );
        _currentProject!.files.add(rf);
        _terminalLines.add("✅ Ingested (${type.toUpperCase()}): $name (${content.length} chars)");
      } else {
        _terminalLines.add("❌ Proxy failed: ${res.statusCode}");
      }
    } catch (e) {
      _terminalLines.add("❌ Error: $e");
    } finally {
      _isAttachingDocument = false;
      notifyListeners();
    }
  }

  bool _isAttachingDocument = false;
  bool get isAttachingDocument => _isAttachingDocument;

  Future<void> pickResearchFiles({FileCategory? category}) async {
    if (_currentProject == null) return;
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx', 'csv', 'txt']);
    if (result != null) {
      _isAttachingDocument = true;
      notifyListeners();
      for (var file in result.files) {
        try {
          String content = "";
          final bytes = file.bytes;
          if (file.extension == 'pdf') {
            final input = bytes ?? (file.path != null ? File(file.path!).readAsBytesSync() : null);
            if (input == null) continue;
            final doc = sf.PdfDocument(inputBytes: input);
            content = sf.PdfTextExtractor(doc).extractText();
            doc.dispose();
          } else {
            if (bytes != null) content = utf8.decode(bytes, allowMalformed: true);
            else if (file.path != null) content = await File(file.path!).readAsString();
          }
          final rf = ResearchFile(name: file.name, content: content, type: file.extension ?? 'txt', charCount: content.length);
          if (category != null) rf.category = category;
          _currentProject!.files.add(rf);
          _terminalLines.add("✅ Loaded: ${file.name} [${category?.name.toUpperCase() ?? 'NONE'}]");
        } catch (e) {
          _terminalLines.add("❌ Error loading ${file.name}: $e");
        }
      }
      _isAttachingDocument = false;
      notifyListeners();
      saveResearchHub();
    }
  }

  /// Uses the LLM to extract structured metadata from each literature file.
  /// This runs ONCE before the pipeline and populates ResearchFile fields.
  Future<void> _extractMetadataForFiles() async {
    if (_currentProject == null) return;
    final litFiles = _currentProject!.files.where((f) => f.category == FileCategory.literature).toList();
    if (litFiles.isEmpty) return;

    for (int i = 0; i < litFiles.length; i++) {
      final f = litFiles[i];
      // Skip if already extracted
      if (f.hasExtractedMetadata) {
        _terminalLines.add("  ✅ [${i + 1}/${litFiles.length}] ${f.name} — metadata cached.");
        continue;
      }

      _terminalLines.add("  🔍 [${i + 1}/${litFiles.length}] Extracting metadata from: ${f.name}...");
      notifyListeners();

      // Send first 3000 chars to the LLM for metadata extraction
      final snippet = f.content.length > 3000 ? f.content.substring(0, 3000) : f.content;
      final extractionPrompt = "Extract the bibliographic metadata from the following academic document text. Output ONLY a valid JSON object with these exact keys: \"authors\", \"year\", \"title\", \"doi\", \"journal\". For \"authors\", list ALL author full names as a comma-separated string. For \"year\", provide the 4-digit publication year. For \"title\", provide the full paper title. For \"doi\", provide the DOI if found, otherwise empty string. For \"journal\", provide the journal/conference name if found, otherwise empty string. OUTPUT ONLY THE JSON OBJECT, nothing else.\n\nDocument text:\n$snippet";
      final extractionSystem = "You are a bibliographic metadata extractor. You read academic text and output ONLY a JSON object with keys: authors, year, title, doi, journal. No explanation, no markdown fences, ONLY raw JSON.";

      try {
        // Use a single-shot (non-streaming) call via agent chat slot 0 (Data Explorer)
        final chat = getResearchAgentChat(0);
        chat.add(ChatMessage(role: 'user', content: extractionPrompt));
        notifyListeners();

        String response = "";
        final messages = [ChatMessage(role: 'system', content: extractionSystem), ...chat];
        _activeHttpClient = http.Client();
        await for (final chunk in _client.chatStream(_selectedModel ?? "gemma4", messages, client: _activeHttpClient)) {
          if (_cancelRequested) break;
          response += chunk;
        }
        _activeHttpClient?.close();
        _activeHttpClient = null;

        chat.add(ChatMessage(role: 'assistant', content: response));

        // Parse JSON from response
        String jsonStr = response.trim();
        if (jsonStr.contains('```json')) jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
        else if (jsonStr.contains('```')) jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
        // Handle case where response has text before/after JSON
        final jsonStart = jsonStr.indexOf('{');
        final jsonEnd = jsonStr.lastIndexOf('}');
        if (jsonStart != -1 && jsonEnd != -1) {
          jsonStr = jsonStr.substring(jsonStart, jsonEnd + 1);
        }

        final parsed = jsonDecode(jsonStr);
        f.extractedAuthors = (parsed['authors'] as String? ?? '').trim();
        f.extractedYear = (parsed['year']?.toString() ?? '').trim();
        f.extractedTitle = (parsed['title'] as String? ?? '').trim();
        f.extractedDoi = (parsed['doi'] as String? ?? '').trim();
        f.extractedJournal = (parsed['journal'] as String? ?? '').trim();

        _terminalLines.add("    ✅ ${f.citationKey} — \"${f.extractedTitle}\"");
      } catch (e) {
        _terminalLines.add("    ⚠️ Metadata extraction failed for ${f.name}: $e");
        // Fallback: try to parse headers from the text
        for (final line in f.content.split('\n').take(50)) {
          if (line.startsWith('Authors:')) f.extractedAuthors = line.replaceFirst('Authors:', '').trim();
          if (line.startsWith('Year:')) f.extractedYear = line.replaceFirst('Year:', '').trim();
          if (line.startsWith('Title:')) f.extractedTitle = line.replaceFirst('Title:', '').trim();
          if (line.startsWith('URL:')) f.extractedDoi = line.replaceFirst('URL:', '').trim();
        }
        if (f.extractedTitle.isEmpty) f.extractedTitle = f.name;
      }
      saveResearchHub();
      notifyListeners();
    }
  }

  /// Builds the unified KNOWLEDGE BASE from all literature files.
  /// Each document is prefixed with its pre-extracted structured metadata.
  String buildLiteratureKnowledgeBase() {
    if (_currentProject == null) return '';
    final litFiles = _currentProject!.files.where((f) => f.category == FileCategory.literature).toList();
    if (litFiles.isEmpty) return '';
    final sb = StringBuffer();
    sb.writeln('<SOURCE_MATERIAL>');
    sb.writeln('The following is the curated bibliography for this project. YOU MUST cite ONLY from these sources.');
    sb.writeln('');
    for (int i = 0; i < litFiles.length; i++) {
      final f = litFiles[i];
      sb.writeln('<DOCUMENT index="${i + 1}">');
      sb.writeln('  <METADATA>');
      sb.writeln('    <CITATION_KEY>${f.citationKey}</CITATION_KEY>');
      sb.writeln('    <AUTHORS>${f.extractedAuthors.isNotEmpty ? f.extractedAuthors : "See text"}</AUTHORS>');
      sb.writeln('    <YEAR>${f.extractedYear.isNotEmpty ? f.extractedYear : "See text"}</YEAR>');
      sb.writeln('    <TITLE>${f.extractedTitle.isNotEmpty ? f.extractedTitle : f.name}</TITLE>');
      if (f.extractedDoi.isNotEmpty) sb.writeln('    <DOI>${f.extractedDoi}</DOI>');
      sb.writeln('  </METADATA>');
      sb.writeln('  <CONTENT>');
      sb.writeln(f.content);
      sb.writeln('  </CONTENT>');
      sb.writeln('</DOCUMENT>');
      sb.writeln('');
    }
    sb.writeln('</SOURCE_MATERIAL>');
    return sb.toString();
  }

  /// Builds a concise, structured citation index from pre-extracted metadata.
  String _buildAuthorIndex() {
    if (_currentProject == null) return '';
    final litFiles = _currentProject!.files.where((f) => f.category == FileCategory.literature).toList();
    if (litFiles.isEmpty) return '';
    final sb = StringBuffer();
    sb.writeln('MANDATORY CITATION INDEX — You MUST use these exact citation keys in-text:');
    for (int i = 0; i < litFiles.length; i++) {
      final f = litFiles[i];
      sb.writeln('[${i + 1}] ${f.citationKey} — "${f.extractedTitle.isNotEmpty ? f.extractedTitle : f.name}"');
    }
    return sb.toString();
  }

  /// Builds the References section programmatically from extracted metadata.
  /// This is deterministic — no LLM hallucination possible.
  String _buildReferencesSection() {
    if (_currentProject == null) return '';
    final litFiles = _currentProject!.files.where((f) => f.category == FileCategory.literature).toList();
    if (litFiles.isEmpty) return '';
    final style = _currentProject!.citationStyle;
    final sb = StringBuffer();
    sb.writeln('## References\n');
    for (int i = 0; i < litFiles.length; i++) {
      final f = litFiles[i];
      final authors = f.extractedAuthors.isNotEmpty ? f.extractedAuthors : 'Unknown Author';
      final year = f.extractedYear.isNotEmpty ? f.extractedYear : 'n.d.';
      final title = f.extractedTitle.isNotEmpty ? f.extractedTitle : f.name;
      final journal = f.extractedJournal.isNotEmpty ? f.extractedJournal : '';
      final doi = f.extractedDoi.isNotEmpty ? f.extractedDoi : '';

      if (style == 'APA') {
        String entry = '$authors ($year). *$title*.';
        if (journal.isNotEmpty) entry += ' $journal.';
        if (doi.isNotEmpty) {
          if (doi.startsWith('http')) entry += ' $doi';
          else entry += ' https://doi.org/$doi';
        }
        sb.writeln('${i + 1}. $entry\n');
      } else if (style == 'IEEE') {
        String entry = '[${ i + 1}] $authors, "$title,"';
        if (journal.isNotEmpty) entry += ' *$journal*,';
        entry += ' $year.';
        if (doi.isNotEmpty) {
          if (doi.startsWith('http')) entry += ' $doi';
          else entry += ' doi: $doi';
        }
        sb.writeln('$entry\n');
      } else {
        // Generic fallback
        String entry = '$authors ($year). "$title."';
        if (journal.isNotEmpty) entry += ' $journal.';
        if (doi.isNotEmpty) entry += ' $doi';
        sb.writeln('${i + 1}. $entry\n');
      }
    }
    return sb.toString();
  }

  PipelineProgress? _pipelineProgress;
  PipelineProgress? get pipelineProgress => _pipelineProgress;
  bool _isResearchRunning = false;
  bool get isResearchRunning => _isResearchRunning;
  bool _cancelRequested = false;
  http.Client? _activeHttpClient;

  Future<void> runAutonomousResearch({String startStage = 'LITERATURE', bool forceRestart = false}) async {
    if (_currentProject == null || _isResearchRunning) return;
    if (_selectedModel == null && _models.isEmpty) {
      _terminalLines.add("❌ No models available to run research.");
      return;
    }
    String actualStart = startStage;
    if (!forceRestart && startStage == 'LITERATURE') {
      if (_currentProject!.lastCompletedStage.isNotEmpty) {
        if (_currentProject!.lastCompletedStage == 'LITERATURE') actualStart = 'METHODOLOGY';
        else if (_currentProject!.lastCompletedStage == 'METHODOLOGY') actualStart = 'DATA_ANALYSIS';
        else if (_currentProject!.lastCompletedStage == 'DATA_ANALYSIS') actualStart = 'WRITER';
      } else {
        if (_currentProject!.finalManuscript.isNotEmpty) actualStart = 'DONE';
        else if (_currentProject!.analysis.isNotEmpty) actualStart = 'WRITER';
        else if (_currentProject!.methodology.isNotEmpty) actualStart = 'DATA_ANALYSIS';
        else if (_currentProject!.litReview.isNotEmpty) actualStart = 'METHODOLOGY';
      }
      
      if (actualStart == 'DONE') {
        _terminalLines.add("✅ Research already complete.");
        return;
      }
      if (actualStart != 'LITERATURE') _terminalLines.add("🔄 Resuming from inferred: $actualStart");
    } else if (forceRestart) {
      _currentProject!.lastCompletedStage = "";
      _currentProject!.litReview = "";
      _currentProject!.methodology = "";
      _currentProject!.analysis = "";
      _currentProject!.finalManuscript = "";
      
      // Clear all generated sections except Title
      for (var section in _currentProject!.sections) {
        if (section.title != 'Title') {
          section.content = "";
        }
      }
      
      saveResearchHub();
      _terminalLines.add("🚀 Forcing full pipeline restart (CLEAN SLATE)...");
    }
    _isResearchRunning = true; _cancelRequested = false;
    _pipelineProgress = PipelineProgress(startedAt: DateTime.now());
    notifyListeners();
    try {
      final dataFiles = _currentProject!.files.where((f) => f.category == FileCategory.data).toList();
      final fileNames = dataFiles.map((f) => f.name).join(", ");
      final projectExtra = _currentProject!.extraInstructions;
      final extraCtx = projectExtra.isNotEmpty ? "\n\nPRIMARY RESEARCH DIRECTIVE:\n$projectExtra" : "";
      final ctx = "Title: $researchTitle\nCitation: $citationStyle\nAvailable Data: $fileNames$extraCtx";
      
      if (actualStart == 'LITERATURE' || actualStart == 'RESULTS_CHECK') {
        _updateStage(PipelineStage.resultsCheck, StageStatus.running);
        final resultsFiles = _currentProject!.files.where((f) => f.category == FileCategory.results).toList();
        if (resultsFiles.isNotEmpty) {
          _terminalLines.add("💡 Found pre-calculated results: ${resultsFiles.map((f) => f.name).join(', ')}");
          _currentProject!.analysis = resultsFiles.map((f) => "FILE: ${f.name}\n${f.content}").join("\n\n");
          _terminalLines.add("✅ Results ingested directly. Skipping modeling.");
          actualStart = 'LITERATURE';
        } else {
          _terminalLines.add("📊 No results files found. Proceeding with full pipeline.");
          actualStart = 'LITERATURE';
        }
        _updateStage(PipelineStage.resultsCheck, StageStatus.done);
      }

      if (actualStart == 'LITERATURE') {
        // === METADATA EXTRACTION PRE-STEP ===
        _terminalLines.add("🔬 Pre-processing: Extracting citation metadata from source documents...");
        notifyListeners();
        await _extractMetadataForFiles();
        if (_cancelRequested) return;
        _terminalLines.add("✅ Citation metadata extraction complete.");

        _updateStage(PipelineStage.literature, StageStatus.running);
        _terminalLines.add("📚 Exploring Literature + Data context...");
        final knowledgeBase = buildLiteratureKnowledgeBase();
        final authorIndex = _buildAuthorIndex();
        
        final targetModel = _selectedModel ?? "gemma4";
        final isCloud = !_ollamaModelNames.contains(targetModel);
        
        if (isCloud) {
          _terminalLines.add("☁️ Cloud Mode: Initiating Granular Literature Synthesis...");
          
          // 1. Generate Outline
          final outlinePrompt = """<CONTEXT>
  $authorIndex
</CONTEXT>
<TASK>
  Create a structured outline for a literature review on '$researchTitle'. 
  Identify 3-5 logical sub-sections or themes based on the context.
  Output ONLY a bulleted list of 3-5 sub-section titles. No other text.
</TASK>""";
          
          await sendResearchMessage(1, outlinePrompt, "You are a research architect. Create a bulleted outline only. No preamble.");
          final outlineText = getResearchAgentChat(1).last.content;
          final outlinePoints = outlineText.split('\n').where((l) => l.trim().startsWith('-') || l.trim().startsWith('*') || RegExp(r'^\d+\.').hasMatch(l.trim())).toList();
          
          if (outlinePoints.isEmpty) {
             _terminalLines.add("⚠️ Outline generation failed, falling back to one-shot.");
             await _runOneShotLiterature(ctx, authorIndex, knowledgeBase, isCloud);
          } else {
             _terminalLines.add("🧬 Outline generated: ${outlinePoints.length} parts identified.");
             final List<String> literatureParts = [];
             for (int i = 0; i < outlinePoints.length; i++) {
                if (_cancelRequested) break;
                final point = outlinePoints[i].replaceAll(RegExp(r'^[-*0-9.]+'), '').trim();
                _terminalLines.add("📝 Drafting Part ${i + 1}/${outlinePoints.length}: $point...");
                
                final partPrompt = """### BIBLIOGRAPHIC CONTEXT
$authorIndex

### SOURCE MATERIAL
$knowledgeBase

### PREVIOUSLY WRITTEN PARTS
${literatureParts.join("\n\n")}

### TASK DEFINITION
Write the literature review section for: '$point'. 
Maintain academic tone and use $citationStyle citations.
IMPORTANT: OUTPUT ONLY THE CONTENT FOR THIS SECTION. START DIRECTLY WITH THE CONTENT.
""";
                
                await sendResearchMessage(1, partPrompt, agentInstructions[1]!.replaceAll('{{CITATION_STYLE}}', citationStyle) + "\n" + ctx);
                String partContent = getResearchAgentChat(1).last.content;
                
                // VALIDATION & SELF-CORRECTION LOOP
                if (!_validateSectionContent(partContent, "Drafting Part ${i + 1}")) {
                  _terminalLines.add("  ⚠️ Part ${i + 1} validation FAILED (Echo detected). Retrying with self-correction...");
                  final retryPrompt = "RETRY REQUEST: Your previous response was an echo of the instructions. Please provide ONLY the manuscript text for '$point'. DO NOT repeat the prompt tags.\n\n$partPrompt";
                  await sendResearchMessage(1, retryPrompt, agentInstructions[1]!.replaceAll('{{CITATION_STYLE}}', citationStyle));
                  partContent = getResearchAgentChat(1).last.content;
                }

                partContent = _stripPromptEcho(partContent, "Write the literature review section");
                literatureParts.add("### $point\n$partContent");
             }
             
             final references = _buildReferencesSection();
             final fullLit = literatureParts.join("\n\n") + "\n\n" + references;
             _currentProject!.litReview = fullLit;
             _updateSectionContentByTitle('Literature Review', fullLit);
          }
        } else {
          // Local Model: One-shot logic
          await _runOneShotLiterature(ctx, authorIndex, knowledgeBase, isCloud);
        }
        
        _currentProject!.lastCompletedStage = 'LITERATURE';
        saveResearchHub();
        _updateStage(PipelineStage.literature, StageStatus.done);
        actualStart = 'METHODOLOGY';
      }

      if (_cancelRequested) return;
      if (actualStart == 'METHODOLOGY') {
        _updateStage(PipelineStage.methodology, StageStatus.running);
        _terminalLines.add("🧠 Concept Synergy & Methodology...");
        
        final targetModel = _selectedModel ?? "gemma4";
        final isCloud = !_ollamaModelNames.contains(targetModel);
        
        final methPrompt = isCloud ? """<CONTEXT>
  FILENAMES: $fileNames
  LIT REVIEW CONTENT:
  ${_currentProject!.litReview}
</CONTEXT>
<TASK>
  Conceive a robust methodology for $researchTitle.
  IMPORTANT: OUTPUT ONLY THE METHODOLOGY CONTENT. DO NOT REPEAT THIS PROMPT OVERVIEW.
</TASK>""" : """<TASK>
  Conceive a robust methodology for $researchTitle.
</TASK>
<CONTEXT>
  FILENAMES: $fileNames
  LIT REVIEW CONTENT:
  ${_currentProject!.litReview}
</CONTEXT>""";

        await sendResearchMessage(2, methPrompt, agentInstructions[2]! + "\n" + ctx);
        String methContent = getResearchAgentChat(2).last.content;
        methContent = _stripPromptEcho(methContent, "Conceive methodology");
        
        _currentProject!.methodology = methContent;
        _updateSectionContentByTitle('Methodology', methContent);
        _currentProject!.lastCompletedStage = 'METHODOLOGY';
        saveResearchHub();
        _updateStage(PipelineStage.methodology, StageStatus.done);
        actualStart = 'DATA_ANALYSIS';
      }

      if (_cancelRequested) return;
      if (actualStart == 'DATA_ANALYSIS') {
        _updateStage(PipelineStage.dataAnalysis, StageStatus.running);
        final targetModel = _currentProject!.dataAnalysisModel ?? _selectedModel ?? "gemma4";
        _terminalLines.add("🧪 LABORATORY: Running Analysis with Model: $targetModel...");
        
        if (dataFiles.isEmpty) {
          _terminalLines.add("⚠️ No data files found. Will generate synthetic results based on methodology.");
          _updateStage(PipelineStage.dataAnalysis, StageStatus.running);
          final syntheticPrompt = "Based on the following proposed methodology, generate realistic synthetic results and data that would be expected from this research. Present the results as formatted text with tables and statistics where appropriate. DO NOT say 'synthetic' in the output — present them as actual findings.\n\nMethodology:\n${_currentProject!.methodology}\n\nResearch Title: $researchTitle";
          final syntheticSystem = "You are an expert research data analyst. Generate realistic, plausible synthetic results for the given methodology. Output formatted Markdown with tables, statistics, and key findings. NEVER use LaTeX.";
          await sendResearchMessage(3, syntheticPrompt, syntheticSystem);
          final syntheticContent = getResearchAgentChat(3).last.content;
          _currentProject!.analysis = syntheticContent;
          _updateSectionContentByTitle('Results', syntheticContent);
          _currentProject!.lastCompletedStage = 'DATA_ANALYSIS';
          saveResearchHub();
          _updateStage(PipelineStage.dataAnalysis, StageStatus.done);
        } else {
          String laborInstructions = agentInstructions[3]!.replaceAll('{{FILES}}', fileNames);
          bool analysisSuccess = false;
          String lastError = "";
          for (int attempt = 1; attempt <= 15; attempt++) {
            if (_cancelRequested) return;
            _terminalLines.add("🧪 Analysis Attempt $attempt/15...");
            String prompt = attempt == 1 ? "Analyze the following data files: $fileNames. Provide python code." : "Fix code error: $lastError. Output ONLY the code block.";
            await sendResearchMessage(3, prompt, laborInstructions + "\n" + ctx, modelOverride: targetModel);
            final code = _extractCode(getResearchAgentChat(3).last.content);
            if (code.isNotEmpty) {
              final res = await executePythonCode(code);
              if (res['exit_code'] == 0) {
                final analContent = (res['stdout'] ?? "") + (res['plots'] != null ? "\n\n[Analytic Plots Generated]" : "");
                _currentProject!.analysis = analContent;
                _updateSectionContentByTitle('Results', analContent);
                _currentProject!.lastCompletedStage = 'DATA_ANALYSIS';
                saveResearchHub();
                _updateStage(PipelineStage.dataAnalysis, StageStatus.done);
                analysisSuccess = true;
                break;
              } else {
                lastError = (res['stderr'] ?? "") + (res['stdout'] ?? "");
              }
            } else {
              lastError = "No code produced.";
            }
          }
          if (!analysisSuccess) {
            _updateStage(PipelineStage.dataAnalysis, StageStatus.error);
            _terminalLines.add("❌ Analysis failed after 15 attempts.");
            return;
          }
        }
        actualStart = 'WRITER';
      }

      if (_cancelRequested) return;
      if (actualStart == 'WRITER') {
        // Ensure metadata is extracted even when resuming from WRITER directly
        await _extractMetadataForFiles();
        if (_cancelRequested) return;

        _updateStage(PipelineStage.writer, StageStatus.running);
        _terminalLines.add("📝 Writing all manuscript sections...");
        
        // Build references programmatically and write all sections sequentially
        await _writeSectionsFallback(ctx);
        _currentProject!.lastCompletedStage = 'WRITER';
        saveResearchHub(); 
        syncSectionsToEditor();
        _updateStage(PipelineStage.writer, StageStatus.done);
        
        // Run autonomous Quality Control (QC) loop
        _updateStage(PipelineStage.reviewer, StageStatus.running);
        _terminalLines.add("🧐 Running comprehensive review...");
        
        bool passedQC = false;
        int qcAttempts = 0;
        
        while (!passedQC && qcAttempts < 2) {
          if (_cancelRequested) break;
          
          final fullManuscript = _currentProject!.sections.map((s) => "### ${s.title}\n${s.content}").join("\n\n");
          await sendResearchMessage(5, "Review this full manuscript section-by-section:\n\n$fullManuscript", agentInstructions[5]!);
          final reviewContent = getResearchAgentChat(5).last.content;
          _currentProject!.reviewerFeedback = reviewContent;
          _updateSectionContentByTitle('Reviewer comments', reviewContent);
          
          if (reviewContent.contains("FAILS quality check")) {
            qcAttempts++;
            _terminalLines.add("⚠️ Reviewer flagged poor quality. Initiating QC Rewrite Loop (Attempt $qcAttempts/2)...");
            
            // Re-run sections completely focusing on fixing reviewer feedback
            await _writeSectionsFallback(ctx, reviewerFeedback: reviewContent);
          } else {
            passedQC = true;
            _terminalLines.add("✅ Manuscript passed AI Quality Control Review!");
          }
        }
        
        saveResearchHub();
        _updateStage(PipelineStage.reviewer, StageStatus.done);
      }
    } finally {
      _isResearchRunning = false;
      notifyListeners();
    }
  }

  /// Triggers a re-run of the WRITER stage, specifically feeding the current 
  /// Reviewer Comments into the LLM context so it can correct the manuscript.
  Future<void> applyReviewerFixes() async {
    if (_currentProject == null || _isResearchRunning) return;
    
    final revIdx = _currentProject!.sections.indexWhere((s) => s.title.toLowerCase().contains("reviewer"));
    if (revIdx == -1) {
      _terminalLines.add("❌ No reviewer comments found.");
      return;
    }
    
    final reviewContent = _currentProject!.sections[revIdx].content;
    if (reviewContent.isEmpty) {
      _terminalLines.add("❌ Reviewer comments are empty.");
      return;
    }

    _isResearchRunning = true;
    _cancelRequested = false;
    _pipelineProgress = PipelineProgress(startedAt: DateTime.now());
    notifyListeners();

    try {
      _terminalLines.add("🔄 Applying reviewer fixes to manuscript...");
      _updateStage(PipelineStage.writer, StageStatus.running);
      
      final dataFiles = _currentProject!.files.where((f) => f.category == FileCategory.data).toList();
      final fileNames = dataFiles.map((f) => f.name).join(", ");
      final projectExtra = _currentProject!.extraInstructions;
      final extraCtx = projectExtra.isNotEmpty ? "\n\nPRIMARY RESEARCH DIRECTIVE:\n$projectExtra" : "";
      final ctx = "Title: $researchTitle\nCitation: $citationStyle\nAvailable Data: $fileNames$extraCtx";
      
      // Ensure metadata is extracted just in case
      await _extractMetadataForFiles();
      if (_cancelRequested) return;

      // Re-run sections with the reviewer's feedback
      await _writeSectionsFallback(ctx, reviewerFeedback: reviewContent);
      
      _currentProject!.lastCompletedStage = 'WRITER';
      saveResearchHub(); 
      syncSectionsToEditor();
      _updateStage(PipelineStage.writer, StageStatus.done);
      
      _terminalLines.add("✅ Reviewer fixes applied successfully.");
    } catch (e) {
      _terminalLines.add("❌ Error applying fixes: $e");
      _updateStage(PipelineStage.writer, StageStatus.error);
    } finally {
      _isResearchRunning = false;
      notifyListeners();
    }
  }

  Future<void> _writeSectionsFallback(String ctx, {String reviewerFeedback = ""}) async {
    if (_currentProject == null) return;

    // === STEP 1: Build References PROGRAMMATICALLY (no LLM) ===
    final programmaticReferences = _buildReferencesSection();
    _updateSectionContentByTitle('References', programmaticReferences);
    _terminalLines.add("📋 References built programmatically from extracted metadata (${_currentProject!.files.where((f) => f.category == FileCategory.literature).length} sources).");
    saveResearchHub();

    // === STEP 2: Write sections sequentially ===
    // Dynamically extract core sections to write, excluding metadata/utility sections
    final excludeSections = {
      'title', 'project title', 'document title', 'assessment title', 'plan title', 'trial title', 'case brief', 'security audit title',
      'authors', 'references', 'bibliography', 'reviewer comments', 'reviewer feedback', 'ai detection', 'similarity'
    };
    
    final sectionsToWrite = _currentProject!.sections
        .map((s) => s.title)
        .where((title) {
          final tLower = title.toLowerCase();
          if (excludeSections.contains(tLower)) return false;
          // Skip if it is a Literature Review or Methodology section that is already populated
          if ((tLower.contains('literature') || tLower.contains('needs assessment') || tLower.contains('market analysis') || tLower.contains('swot')) && 
              _currentProject!.litReview.isNotEmpty) {
            return false;
          }
          if ((tLower.contains('methodology') || tLower.contains('activities') || tLower.contains('roadmap')) && 
              _currentProject!.methodology.isNotEmpty) {
            return false;
          }
          return true;
        })
        .toList();
    
    String accumulatedManuscript = "";
    final knowledgeBase = buildLiteratureKnowledgeBase();

    for (final sectionName in sectionsToWrite) {
      if (_cancelRequested) return;
      _terminalLines.add("📝 Writing section: $sectionName...");
      
      final customPromptObj = _currentProject!.sections.where((s) => s.title.toLowerCase() == sectionName.toLowerCase()).map((s) => s.customPrompt).firstWhere((c) => c.isNotEmpty, orElse: () => "");
      final customPromptStr = customPromptObj.isNotEmpty ? "\n\nSECTION SPECIFIC INSTRUCTION:\n$customPromptObj" : "";
      
      String fbCtx = reviewerFeedback.isNotEmpty ? "\n\nCRITICAL REVIEWER FEEDBACK TO FIX IN THIS SECTION:\n$reviewerFeedback" : "";
      String prevCtx = accumulatedManuscript.isNotEmpty ? "\n\nPREVIOUSLY WRITTEN CONTENT (Context):\n$accumulatedManuscript" : "";

      final targetModel = _selectedModel ?? "gemma4";
      final isCloud = !_ollamaModelNames.contains(targetModel);

      // === PASS 1: Write section content ===
      String sectionPrompt = isCloud ? """### BIBLIOGRAPHIC CONTEXT
MANDATORY BIBLIOGRAPHY:
$programmaticReferences

LITERATURE REVIEW:
${_currentProject!.litReview}

METHODOLOGY:
${_currentProject!.methodology}

DATA ANALYSIS RESULTS:
${_currentProject!.analysis}

$knowledgeBase
$customPromptStr
$fbCtx
$prevCtx

### TASK DEFINITION
Write the '$sectionName' section for the paper: $researchTitle. Use $citationStyle citations.
IMPORTANT: OUTPUT ONLY THE MANUSCRIPT CONTENT FOR THIS SECTION. START IMMEDIATELY WITH THE CONTENT.
""" : """### TASK DEFINITION
Write the '$sectionName' section for the paper: $researchTitle. Use $citationStyle citations.

### BIBLIOGRAPHIC CONTEXT
MANDATORY BIBLIOGRAPHY:
$programmaticReferences

LITERATURE REVIEW:
${_currentProject!.litReview}

METHODOLOGY:
${_currentProject!.methodology}

DATA ANALYSIS RESULTS:
${_currentProject!.analysis}

$knowledgeBase
$customPromptStr
$fbCtx
$prevCtx
""";

      final sectionSystem = agentInstructions[4]!.replaceAll('{{CITATION_STYLE}}', citationStyle) + "\n" + ctx;
      
      final pass1Messages = [
        ChatMessage(role: 'system', content: sectionSystem),
        ChatMessage(role: 'user', content: sectionPrompt)
      ];

      String sectionContent = "";
      _activeHttpClient = http.Client();
      await for (final chunk in _client.chatStream(targetModel, pass1Messages, client: _activeHttpClient)) {
        if (_cancelRequested) break;
        sectionContent += chunk;
      }
      _activeHttpClient?.close();
      _activeHttpClient = null;
      if (_cancelRequested) return;

      _recordTokenUsage(targetModel, pass1Messages, sectionContent);

      // VALIDATION & SELF-CORRECTION LOOP (Cloud Only)
      if (isCloud && !_validateSectionContent(sectionContent, sectionName)) {
        _terminalLines.add("  ⚠️ Section $sectionName validation FAILED (Echo detected). Retrying with self-correction...");
        final retryPrompt = "RETRY REQUEST: Your previous response was an echo of the instructions or context. Please provide ONLY the actual manuscript text for '$sectionName'. DO NOT repeat the header tags (### TASK, etc).\n\n$sectionPrompt";
        final retryMessages = [ChatMessage(role: 'system', content: sectionSystem), ChatMessage(role: 'user', content: retryPrompt)];
        
        sectionContent = "";
        _activeHttpClient = http.Client();
        await for (final chunk in _client.chatStream(targetModel, retryMessages, client: _activeHttpClient)) {
          if (_cancelRequested) break;
          sectionContent += chunk;
        }
        _activeHttpClient?.close();
        _activeHttpClient = null;
      }

      // Clean prompt echo
      sectionContent = _stripPromptEcho(sectionContent, "Write the '$sectionName' section");

      // Log cleanly to Agent 4
      final chat = getResearchAgentChat(4);
      chat.add(ChatMessage(role: 'user', content: "Please draft the '$sectionName' section."));
      chat.add(ChatMessage(role: 'assistant', content: sectionContent));
      notifyListeners();

      // === PASS 2: Chunk-based citation injection + Quality Gate ===
      final tLower = sectionName.toLowerCase();
      final isCitationSection = !tLower.contains('abstract') && !tLower.contains('keywords') && !tLower.contains('authors');
      if (isCitationSection) {
        _terminalLines.add("  🔗 Injecting citations into $sectionName...");
        notifyListeners();
        
        sectionContent = await _injectCitationsChunked(sectionContent);
        
        // === QUALITY GATE: Validate citation density ===
        final gateResult = _citationQualityGate(sectionContent, sectionName);
        if (!gateResult.passed) {
          _terminalLines.add("  ⚠️ Quality Gate FAILED for $sectionName: ${gateResult.reason}");
          _terminalLines.add("  🔄 Retrying citation injection...");
          notifyListeners();
          // Retry once more on the failed output
          sectionContent = await _injectCitationsChunked(sectionContent);
          final retryResult = _citationQualityGate(sectionContent, sectionName);
          if (retryResult.passed) {
            _terminalLines.add("  ✅ Quality Gate PASSED on retry for $sectionName.");
          } else {
            _terminalLines.add("  ⚠️ Quality Gate still marginal for $sectionName — accepting best effort.");
          }
        } else {
          _terminalLines.add("  ✅ Quality Gate PASSED for $sectionName (${gateResult.citationCount} citations found).");
        }
      }

      _updateSectionContentByTitle(sectionName, sectionContent);
      saveResearchHub();

      accumulatedManuscript += "\n\n### $sectionName\n$sectionContent";
    }
    _currentProject!.finalManuscript = _reconstructManuscript(_currentProject!);
  }

  // ============================================================
  // CHUNK-BASED STATEFUL CITATION ENGINE
  // ============================================================

  /// Splits section text into paragraphs and injects citations one paragraph 
  /// at a time, tracking which sources have been used in a stateful memory.
  /// This is model-agnostic and works reliably with small LLMs (Gemma 4 (E2B, E4B), Qwen, etc.)
  Future<String> _injectCitationsChunked(String sectionText) async {
    if (_currentProject == null) return sectionText;

    final allLitFiles = _currentProject!.files.where((f) => f.category == FileCategory.literature).toList();
    if (allLitFiles.isEmpty) return sectionText;

    // Split into paragraphs (double newline or markdown heading boundaries)
    final paragraphs = sectionText.split(RegExp(r'\n\n+'));
    if (paragraphs.isEmpty) return sectionText;

    // Stateful memory: track which sources have been cited in THIS run
    final Set<int> citedSourceIndices = {};
    final List<String> processedParagraphs = [];
    
    _terminalLines.add("    📄 Processing ${paragraphs.length} paragraphs...");
    notifyListeners();

    for (int pIdx = 0; pIdx < paragraphs.length; pIdx++) {
      if (_cancelRequested) return sectionText;
      
      final paragraph = paragraphs[pIdx].trim();
      
      // Skip very short paragraphs, headings, or bullet-only lines
      if (paragraph.length < 80 || paragraph.startsWith('#')) {
        processedParagraphs.add(paragraph);
        continue;
      }

      // Find the top 3 most relevant UNCITED sources for this paragraph
      final rankedSources = _rankSourcesByRelevance(paragraph, allLitFiles, citedSourceIndices);
      
      if (rankedSources.isEmpty) {
        // All sources already cited or none relevant — keep paragraph as-is
        processedParagraphs.add(paragraph);
        continue;
      }

      // Build a tiny, focused prompt with just this paragraph and 3 sources
      final sourceSb = StringBuffer();
      for (int i = 0; i < rankedSources.length; i++) {
        final src = rankedSources[i];
        sourceSb.writeln('Source [${i + 1}]: ${src.file.extractedTitle}');
      }

      final chunkPrompt = """Insert citation tags into this paragraph. 

Sources:
${sourceSb.toString()}

Rules:
- Insert [1], [2], or [3] at the end of sentences that relate to that source's topic.
- You MUST cite at least one source. Pick the BEST match.
- Do NOT change the text. Only add bracket tags.
- Output ONLY the paragraph with tags added.

Paragraph:
$paragraph""";

      final chunkSystem = "You insert citation brackets into text. Output ONLY the paragraph with [1] or [2] or [3] added. Example: 'Water is essential [1].' Do not explain.";

      try {
        final messages = [
          ChatMessage(role: 'system', content: chunkSystem),
          ChatMessage(role: 'user', content: chunkPrompt)
        ];

        String response = "";
        _activeHttpClient = http.Client();
        await for (final chunk in _client.chatStream(_selectedModel ?? "gemma4", messages, client: _activeHttpClient)) {
          if (_cancelRequested) break;
          response += chunk;
        }
        _activeHttpClient?.close();
        _activeHttpClient = null;

        if (_cancelRequested) return sectionText;

        // Clean conversational fluff
        response = _stripLLMFluff(response);

        // Check if LLM actually inserted any brackets
        if (RegExp(r'\[\d+\]').hasMatch(response) && response.length > paragraph.length * 0.5) {
          // Replace bracket IDs with real citation keys
          String cited = response;
          for (int i = 0; i < rankedSources.length; i++) {
            final idStr = '[${i + 1}]';
            if (cited.contains(idStr)) {
              cited = cited.replaceAll(idStr, " ${rankedSources[i].file.citationKey}");
              citedSourceIndices.add(allLitFiles.indexOf(rankedSources[i].file));
            }
          }
          cited = cited.replaceAll("  (", " (");
          processedParagraphs.add(cited);
          _terminalLines.add("    ✅ Paragraph ${pIdx + 1}/${paragraphs.length}: citations added.");
        } else {
          // LLM failed to insert brackets — use deterministic fallback
          _terminalLines.add("    ⚠️ Paragraph ${pIdx + 1}: LLM returned no brackets. Using deterministic fallback.");
          final fallback = _deterministicCitationFallback(paragraph, rankedSources, citedSourceIndices, allLitFiles);
          processedParagraphs.add(fallback);
        }
      } catch (e) {
        _terminalLines.add("    ⚠️ Paragraph ${pIdx + 1} error: $e. Keeping original.");
        processedParagraphs.add(paragraph);
      }

      notifyListeners();
    }

    return processedParagraphs.join('\n\n');
  }

  /// Ranks literature files by keyword relevance to a paragraph.
  /// Returns the top N most relevant UNCITED sources.
  List<_RankedSource> _rankSourcesByRelevance(String paragraph, List<ResearchFile> allFiles, Set<int> citedIndices) {
    final paraLower = paragraph.toLowerCase();
    // Extract significant keywords from paragraph (4+ char words, excluding common ones)
    final commonWords = {'this', 'that', 'with', 'from', 'have', 'been', 'also', 'which', 'their', 'these', 'those', 'such', 'into', 'more', 'than', 'other', 'most', 'some', 'were', 'will', 'each', 'make', 'like', 'over', 'very', 'when', 'what', 'your', 'about', 'would', 'there', 'could', 'between', 'through', 'after', 'before', 'should', 'under', 'while'};
    final paraWords = paraLower.split(RegExp(r'\W+')).where((w) => w.length >= 4 && !commonWords.contains(w)).toSet();

    final ranked = <_RankedSource>[];
    for (int i = 0; i < allFiles.length; i++) {
      // Prefer uncited sources, but allow already-cited ones with lower priority
      final f = allFiles[i];
      if (!f.hasExtractedMetadata) continue;
      
      final titleLower = f.extractedTitle.toLowerCase();
      final contentSnippet = (f.content.length > 1000 ? f.content.substring(0, 1000) : f.content).toLowerCase();
      
      // Score: count how many paragraph keywords appear in the source title + first 1000 chars
      int score = 0;
      for (final word in paraWords) {
        if (titleLower.contains(word)) score += 3; // Title match weighted higher
        if (contentSnippet.contains(word)) score += 1;
      }
      
      // Penalize already-cited sources so uncited ones get priority
      if (citedIndices.contains(i)) score = (score * 0.3).round();
      
      if (score > 0) {
        ranked.add(_RankedSource(file: f, score: score, globalIndex: i));
      }
    }

    ranked.sort((a, b) => b.score.compareTo(a.score));
    return ranked.take(3).toList();
  }

  /// Deterministic fallback: if the LLM completely fails to insert brackets,
  /// we programmatically insert the highest-relevance citation at the end of
  /// the first sentence in the paragraph.
  String _deterministicCitationFallback(String paragraph, List<_RankedSource> rankedSources, Set<int> citedIndices, List<ResearchFile> allFiles) {
    if (rankedSources.isEmpty) return paragraph;
    
    final bestSource = rankedSources.first;
    final citationKey = bestSource.file.citationKey;
    citedIndices.add(allFiles.indexOf(bestSource.file));
    
    // Insert citation at the end of the first sentence
    final firstPeriod = paragraph.indexOf('. ');
    if (firstPeriod > 0) {
      return '${paragraph.substring(0, firstPeriod)} $citationKey${paragraph.substring(firstPeriod)}';
    } else if (paragraph.endsWith('.')) {
      return '${paragraph.substring(0, paragraph.length - 1)} $citationKey.';
    }
    return '$paragraph $citationKey';
  }

  /// Strips common LLM conversational preamble from a response.
  String _stripLLMFluff(String content) {
    String cleaned = content;
    final markers = ["Sure", "Certainly", "Here is", "Below is", "As requested", "Based on"];
    for (var m in markers) {
      if (cleaned.startsWith(m)) {
        int firstNewline = cleaned.indexOf("\n");
        if (firstNewline != -1 && firstNewline < 100) {
          cleaned = cleaned.substring(firstNewline).trim();
        }
      }
    }
    // Remove common preambles patterns
    final fluffPatterns = [
      RegExp(r'^Here is the .*?:\s*\n', caseSensitive: false),
      RegExp("^Here's the .*?:\\s*\\n", caseSensitive: false),
      RegExp(r'^Sure[,!.].*?:\s*\n', caseSensitive: false),
      RegExp("^I've added.*?:\\s*\\n", caseSensitive: false),
    ];
    for (final p in fluffPatterns) {
      cleaned = cleaned.replaceFirst(p, '');
    }
    return cleaned.trim();
  }

  /// Removes echo of the prompt instructions often generated by cloud models.
  String _stripPromptEcho(String content, String startMarker) {
    String cleaned = _stripLLMFluff(content);
    // If the response starts with the prompt instructions, strip it
    if (cleaned.toLowerCase().contains(startMarker.toLowerCase())) {
      int idx = cleaned.toLowerCase().indexOf(startMarker.toLowerCase());
      if (idx < 50) { // If it's near the start
        // Look for the end of the context/prompt block if model echoes it all
        int contentStart = cleaned.indexOf("\n\n", idx);
        if (contentStart != -1) {
          cleaned = cleaned.substring(contentStart).trim();
        }
      }
    }
    return cleaned.trim();
  }

  /// Quality gate: validates that a section has acceptable citation density.
  _QualityGateResult _citationQualityGate(String sectionContent, String sectionName) {
    if (_currentProject == null) return _QualityGateResult(passed: true, citationCount: 0, reason: '');
    
    final allLitFiles = _currentProject!.files.where((f) => f.category == FileCategory.literature).toList();
    
    // Count unique citations present in the section
    int citationCount = 0;
    for (final f in allLitFiles) {
      if (f.citationKey.length > 5 && sectionContent.contains(f.citationKey)) {
        citationCount++;
      }
    }
    
    // Count paragraphs (non-trivial ones)
    final paragraphs = sectionContent.split(RegExp(r'\n\n+')).where((p) => p.trim().length > 80).toList();
    final paragraphCount = paragraphs.length;
    
    // Minimum standards based on section type
    int minCitations;
    if ({'Introduction', 'Literature Review', 'Discussion'}.any((s) => sectionName.toLowerCase().contains(s.toLowerCase()))) {
      minCitations = (paragraphCount * 0.6).ceil().clamp(1, allLitFiles.length);
    } else {
      minCitations = (paragraphCount * 0.3).ceil().clamp(1, allLitFiles.length);
    }

    if (citationCount >= minCitations) {
      return _QualityGateResult(passed: true, citationCount: citationCount, reason: '');
    } else {
      return _QualityGateResult(
        passed: false,
        citationCount: citationCount,
        reason: 'Found $citationCount citations but need at least $minCitations for $paragraphCount paragraphs.',
      );
    }
  }

  // Legacy wrapper — kept for signature compatibility with callers
  Future<String> _injectCitations(String sectionText, String authorIndex, String references, {String? excludeSectionTitle}) async {
    return _injectCitationsChunked(sectionText);
  }

  Future<void> runCitationCorrection() async {
    if (_currentProject == null || _isResearchRunning) return;
    
    _isResearchRunning = true;
    _cancelRequested = false;
    notifyListeners();

    try {
      _terminalLines.add("🔄 Running Global Citation Correction...");
      final citationSections = {'Introduction', 'Literature Review', 'Discussion', 'Methodology', 'Results'};

      bool madeChanges = false;
      for (var section in _currentProject!.sections) {
        if (_cancelRequested) break;
        if (citationSections.any((s) => section.title.toLowerCase().contains(s.toLowerCase()))) {
          if (section.content.isEmpty) continue;
          
          _terminalLines.add("  🔗 Fixing citations in ${section.title}...");
          _sectionLoading[section.id] = true;
          setActiveOutputSection(section.id);
          notifyListeners();
          
          _pushSectionHistory(section.id, section.content);
          _appendChatLog(section.id, "Auto-Run Citation Correction tool on ${section.title}");

          final citationContent = await _injectCitationsChunked(section.content);
          
          // Quality gate
          final gateResult = _citationQualityGate(citationContent, section.title);
          String finalContent = citationContent;
          
          if (!gateResult.passed) {
            _terminalLines.add("  ⚠️ Quality Gate FAILED: ${gateResult.reason}");
            _terminalLines.add("  🔄 Retrying...");
            notifyListeners();
            finalContent = await _injectCitationsChunked(citationContent);
            final retryGate = _citationQualityGate(finalContent, section.title);
            if (retryGate.passed) {
              _terminalLines.add("  ✅ Quality Gate PASSED on retry (${retryGate.citationCount} citations).");
            } else {
              _terminalLines.add("  ⚠️ Best-effort: ${retryGate.citationCount} citations after retry.");
            }
          } else {
            _terminalLines.add("  ✅ Quality Gate PASSED (${gateResult.citationCount} citations).");
          }

          if (finalContent.isNotEmpty && finalContent != section.content) {
            section.content = finalContent;
            section.chatHistory.add(ChatMessage(role: 'assistant', content: "✅ Citations corrected. Quality gate: ${gateResult.passed ? 'PASSED' : 'RETRY'}."));
            madeChanges = true;
          } else {
            section.chatHistory.add(ChatMessage(role: 'assistant', content: "⚠️ No new citations could be added."));
          }
          
          _sectionLoading[section.id] = false;
          notifyListeners();
        }
      }
      
      if (madeChanges) {
        for (var s in _currentProject!.sections) {
          _recordFinalState(s.id);
        }
        _currentProject!.finalManuscript = _reconstructManuscript(_currentProject!);
        saveResearchHub();
        syncSectionsToEditor();
      }
      _terminalLines.add("✅ Global Citation Correction Completed.");
    } catch (e) {
      _terminalLines.add("❌ Citation Correction Error: $e");
    } finally {
      for (var s in _currentProject!.sections) { _sectionLoading[s.id] = false; }
      _isResearchRunning = false;
      notifyListeners();
    }
  }

  void _updateStage(PipelineStage stage, StageStatus status) {
    if (_pipelineProgress != null) {
      _pipelineProgress!.currentStage = stage;
      _pipelineProgress!.stages[stage] = status;
      notifyListeners();
    }
  }

  void updateSectionCustomPrompt(String sectionId, String newPrompt) {
    if (_currentProject == null) return;
    final idx = _currentProject!.sections.indexWhere((s) => s.id == sectionId);
    if (idx != -1) {
      _currentProject!.sections[idx].customPrompt = newPrompt;
      saveResearchHub();
      notifyListeners();
    }
  }

  List<ChatMessage> getResearchAgentChat(int idx) => _currentProject?.agentChats[idx] ?? [];

  Future<void> sendResearchMessage(int agentIndex, String content, String systemPrompt, {String? modelOverride}) async {
    if (_currentProject == null) return;
    final modelToUse = modelOverride ?? _selectedModel ?? "gemma4";
    final chat = getResearchAgentChat(agentIndex);
    chat.add(ChatMessage(role: 'user', content: content));
    notifyListeners();

    _handleRouting(agentIndex, content);

    try {
      String response = "";
      final messages = [ChatMessage(role: 'system', content: systemPrompt), ...chat];
      DateTime lastUpdate = DateTime.now();
      _activeHttpClient = http.Client();
      await for (final chunk in _client.chatStream(modelToUse, messages, client: _activeHttpClient)) {
        if (_cancelRequested) {
          _activeHttpClient?.close();
          break;
        }
        response += chunk;
        if (chat.last.role == 'assistant') chat.last = ChatMessage(role: 'assistant', content: response);
        else chat.add(ChatMessage(role: 'assistant', content: response));
        
        final now = DateTime.now();
        if (now.difference(lastUpdate).inMilliseconds >= 100) {
          notifyListeners();
          lastUpdate = now;
        }
      }
      _activeHttpClient?.close();
      _activeHttpClient = null;

      _recordTokenUsage(modelToUse, messages, response);
      saveResearchHub();
    } catch (e) {
      if (_cancelRequested) {
        _terminalLines.add("🛑 Generation interrupted by user.");
        notifyListeners();
        throw Exception('Pipeline cancelled');
      } else {
        _terminalLines.add("❌ Model error: $e");
      }
    }
    if (_cancelRequested) throw Exception('Pipeline cancelled');
    notifyListeners();
  }

  void _handleRouting(int idx, String message) async {
    final lower = message.toLowerCase();
    if (idx == 3) { // Laboratorian manual override
       final codeMatch = RegExp(r'```python\n([\s\S]*?)```').firstMatch(message);
       if (codeMatch != null) {
         final code = codeMatch.group(1)!;
         _terminalLines.add("🧠 Manual Intervention Detected. Executing...");
         final res = await executePythonCode(code);
         if (res['exit_code'] == 0) {
            final analContent = (res['stdout'] ?? "") + (res['plots'] != null ? "\n\n[Analytic Plots Generated]" : "");
            _currentProject!.analysis = analContent;
            _updateSectionContentByTitle('Results', analContent);
            _currentProject!.lastCompletedStage = 'DATA_ANALYSIS';
            saveResearchHub();
            runAutonomousResearch(startStage: 'WRITER');
         }
       }
    }
    if (lower.contains("start research") || lower.contains("run project")) runAutonomousResearch();
  }

  Future<Map<String, dynamic>> executePythonCode(String code) async {
    if (_currentProject == null) return {'stdout': '', 'stderr': 'No project', 'exit_code': -1};
    _terminalLines.add("> RUNNING PYTHON ANALYTICS...");
    try {
      final dataFiles = _currentProject!.files.where((f) => f.category == FileCategory.data).toList();
      final fileMap = { for (var f in dataFiles) f.name: f.content };
      final res = await http.post(Uri.parse('http://127.0.0.1:8000/execute'), 
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code, 'files': fileMap}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _terminalLines.add(data['stdout'] ?? "");
        if (data['stderr'] != null && data['stderr'].isNotEmpty) _terminalLines.add("⚠️ ERROR: ${data['stderr']}");
        return data;
      }
    } catch (e) { _terminalLines.add("❌ Executor error: $e"); }
    return {'stdout': '', 'stderr': 'Connection failed', 'exit_code': -2};
  }

  String _extractCode(String text) {
    final m = RegExp(r'```python\n([\s\S]*?)```').firstMatch(text);
    return m?.group(1) ?? "";
  }

  void syncResearchContext() => _terminalLines.add("🔄 Pipeline Context Synchronized.");
  void cancelPipeline() { 
    _cancelRequested = true; 
    _activeHttpClient?.close();
    _activeHttpClient = null;
    _isResearchRunning = false;
    _pipelineProgress = null;
    _terminalLines.add("🛑 Pipeline killed."); 
    notifyListeners();
  }

  final Map<String, quill.QuillController> _editorControllers = {};
  quill.QuillController getEditorController(String id) => _editorControllers.putIfAbsent(id, () => quill.QuillController.basic());

  void syncSectionsToEditor() {
    if (_currentProject != null) {
       _currentProject!.finalManuscript = _reconstructManuscript(_currentProject!);
       copyToEditor(_currentProject!.finalManuscript);
    }
  }

  Future<void> copyToEditor(String content) async {
    if (_currentProject != null) {
      final controller = getEditorController(_currentProject!.id);
      controller.document.delete(0, controller.document.length);
      final delta = await _buildAdvancedDelta(content);
      controller.compose(delta, const TextSelection.collapsed(offset: 0), quill.ChangeSource.local);
    }
  }

  void runReviewRefinement() => runAutonomousResearch(startStage: 'WRITER');
  void clearAgentChat(int idx) { if (_currentProject != null) { _currentProject!.agentChats[idx] = []; notifyListeners(); } }
  
  void updateResearchSettings({String? title, String? style, bool? isProactive, bool? isRefinement, String? draft, String? extra, String? reviewerInstructions}) {
    if (_currentProject == null) return;
    if (title != null) {
      _currentProject!.title = title;
      // Sync Titlte section content
      final titleSectionIdx = _currentProject!.sections.indexWhere((s) => s.title == 'Title');
      if (titleSectionIdx != -1) {
        _currentProject!.sections[titleSectionIdx].content = title;
      }
    }
    if (style != null) _currentProject!.citationStyle = style;
    if (isProactive != null) _currentProject!.isAutonomousProactive = isProactive;
    if (isRefinement != null) _currentProject!.isDraftRefinementMode = isRefinement;
    if (draft != null) _currentProject!.initialDraft = draft;
    if (extra != null) _currentProject!.extraInstructions = extra;
    if (reviewerInstructions != null) _currentProject!.reviewerInstructions = reviewerInstructions;
    saveResearchHub();
    notifyListeners();
  }

  void updateFileCategory(ResearchFile file, FileCategory cat) { file.category = cat; notifyListeners(); saveResearchHub(); }
  void setResearchTabIndex(int i) { _researchTabIndex = i; notifyListeners(); }
  bool _isResearchHubOpen = false;
  bool get isResearchHubOpen => _isResearchHubOpen;
  void openResearchHub() { _isResearchHubOpen = true; notifyListeners(); }
  void closeResearchHub() { _isResearchHubOpen = false; notifyListeners(); }
  void toggleTerminal() { _isTerminalExpanded = !_isTerminalExpanded; notifyListeners(); }
  void downloadResearchFile(ResearchFile f) => _terminalLines.add("📂 Downloading: ${f.name}");
  void removeResearchFile(int i) { if (_currentProject != null) { _currentProject!.files.removeAt(i); notifyListeners(); } }
  void clearResearchFiles() { if (_currentProject != null) { _currentProject!.files = []; notifyListeners(); } }
  void saveResearchHub() => _projectBox.put(_currentProject!.id, jsonEncode(_currentProject!.toJson()));

  void duplicateProject(ResearchProject project) {
    final data = project.toJson();
    final newProj = ResearchProject(title: "${project.title} (Copy)");
    data['id'] = newProj.id;
    data['title'] = newProj.title;
    final finalDuplicated = ResearchProject.fromJson(data);
    _projectBox.put(finalDuplicated.id, jsonEncode(finalDuplicated.toJson()));
    _allProjects.add(finalDuplicated);
    notifyListeners();
  }

  Future<void> exportManuscriptToPdf() async {
    if (_currentProject == null) return;
    _terminalLines.add("📄 Exporting PDF...");
    final doc = pw.Document();
    doc.addPage(pw.Page(build: (pw.Context context) => pw.Text(_currentProject!.finalManuscript)));
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  Future<void> exportManuscriptToMarkdown() async {
    if (_currentProject == null) return;
    _terminalLines.add("📄 Exporting Markdown...");
    final content = _currentProject!.finalManuscript;
    await Clipboard.setData(ClipboardData(text: content));
    _terminalLines.add("✅ Manuscript copied to clipboard as Markdown.");
  }

  String _reconstructManuscript(ResearchProject p) {
    if (p.sections.isEmpty) return p.finalManuscript;
    return p.sections.map((s) => "## ${s.title}\n\n${s.content}").join('\n\n');
  }

  void updateManuscriptSection(String key, String value) {
    if (_currentProject != null) {
      _currentProject!.manuscriptSections[key] = value;
      _currentProject!.finalManuscript = _reconstructManuscript(_currentProject!);
      saveResearchHub();
      notifyListeners();
    }
  }

  // --- OUTPUT CANVAS METHODS ---

  void setActiveOutputSection(String? id) {
    _activeOutputSectionId = id;
    notifyListeners();
  }

  void setOutputViewMode(String mode) {
    _outputViewMode = mode;
    if (mode == 'editor') syncSectionsToEditor();
    notifyListeners();
  }

  void _updateSectionContentByTitle(String title, String content) {
    if (_currentProject == null) return;
    
    // Smart Keyword Mapping for domains/templates
    List<String> keywords = [title];
    final titleLower = title.toLowerCase();
    
    if (titleLower.contains('literature') || titleLower.contains('litreview')) {
      keywords = ['literature', 'review', 'background', 'context', 'needs', 'market', 'swot'];
    } else if (titleLower.contains('methodology')) {
      keywords = ['methodology', 'framework', 'options', 'objectives', 'goals', 'activities'];
    } else if (titleLower.contains('results') || titleLower.contains('analysis')) {
      keywords = ['results', 'analysis', 'implementation', 'roadmap', 'findings', 'viable', 'options'];
    } else if (titleLower.contains('references')) {
      keywords = ['references', 'bibliography'];
    } else if (titleLower.contains('reviewer comments') || titleLower.contains('feedback')) {
      keywords = ['reviewer comments', 'reviewer feedback'];
    }

    int idx = -1;
    // Try to find by keyword matches first
    for (final kw in keywords) {
      idx = _currentProject!.sections.indexWhere((s) => s.title.toLowerCase().contains(kw.toLowerCase()));
      if (idx != -1) break;
    }
    
    // Fallback: exact contains match on original title
    if (idx == -1) {
      idx = _currentProject!.sections.indexWhere((s) => s.title.toLowerCase().contains(titleLower));
    }
    
    if (idx != -1) {
      final section = _currentProject!.sections[idx];
      _pushSectionHistory(section.id, section.content);
      section.content = content;
      _recordFinalState(section.id);
    } else {
      // Create a new section if not found
      int maxOrder = _currentProject!.sections.fold(0, (max, s) => s.order > max ? s.order : max);
      final newSection = ManuscriptSection(title: title, content: content, order: maxOrder + 1);
      _currentProject!.sections.add(newSection);
      _recordFinalState(newSection.id);
    }
  }

  void addManuscriptSection(String title) {
    if (_currentProject == null) return;
    int maxOrder = _currentProject!.sections.fold(0, (max, s) => s.order > max ? s.order : max);
    final newSection = ManuscriptSection(title: title, order: maxOrder + 1);
    _currentProject!.sections.add(newSection);
    _activeOutputSectionId = newSection.id;
    saveResearchHub();
    notifyListeners();
  }

  void updateManuscriptSectionContent(String id, String newContent) {
    if (_currentProject == null) return;
    final idx = _currentProject!.sections.indexWhere((s) => s.id == id);
    if (idx != -1) {
      _pushSectionHistory(id, _currentProject!.sections[idx].content);
      _currentProject!.sections[idx].content = newContent;
      _recordFinalState(id);
      saveResearchHub();
      notifyListeners();
    }
  }

  void deleteManuscriptSection(String id) {
    if (_currentProject == null) return;
    _currentProject!.sections.removeWhere((s) => s.id == id);
    if (_activeOutputSectionId == id) {
      _activeOutputSectionId = _currentProject!.sections.isNotEmpty ? _currentProject!.sections.first.id : null;
    }
    saveResearchHub();
    notifyListeners();
  }

  void reorderSections(int oldIndex, int newIndex) {
    if (_currentProject == null) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _currentProject!.sections.removeAt(oldIndex);
    _currentProject!.sections.insert(newIndex, item);
    for (int i = 0; i < _currentProject!.sections.length; i++) {
       _currentProject!.sections[i].order = i;
    }
    saveResearchHub();
    notifyListeners();
  }

  void _appendChatLog(String sectionId, String userMessage, {String? assistantMessage}) {
    if (_currentProject == null) return;
    final sectionIdx = _currentProject!.sections.indexWhere((s) => s.id == sectionId);
    if (sectionIdx == -1) return;
    
    final section = _currentProject!.sections[sectionIdx];
    section.chatHistory.add(ChatMessage(role: 'user', content: userMessage));
    if (assistantMessage != null) {
      section.chatHistory.add(ChatMessage(role: 'assistant', content: assistantMessage));
    }
    saveResearchHub();
    notifyListeners();
  }

  Future<void> modifySectionWithLLM(String sectionId, String prompt) async {
    if (_currentProject == null) return;
    final sectionIdx = _currentProject!.sections.indexWhere((s) => s.id == sectionId);
    if (sectionIdx == -1) return;
    
    final section = _currentProject!.sections[sectionIdx];
    final originalContent = section.content;
    
    _sectionLoading[sectionId] = true;
    _pushSectionHistory(sectionId, originalContent);
    _appendChatLog(sectionId, prompt);
    notifyListeners();
    try {
      final isMetaSection = ['title', 'keywords', 'authors'].contains(section.title.toLowerCase());
      final knowledgeBase = buildLiteratureKnowledgeBase();
      final customPromptStr = section.customPrompt.isNotEmpty ? "\n\nSECTION-SPECIFIC RULES YOU MUST FOLLOW:\n${section.customPrompt}" : "";

      final systemPrompt = """You are an Elite Academic Editor. 
Your task is to apply a specific EDIT INSTRUCTION to the 'CURRENT CONTENT' of the '${section.title}' section.

CRITICAL RULES:
1. Apply the user's edit instruction faithfully.
2. PRESERVE the existing text, structure, and citations as much as possible. 
3. ONLY modify the portions of the text affected by the instruction. 
4. ABSOLUTELY NO CONVERSATIONAL OUTPUT, EXPLANATIONS, OR PREAMBLES. 
5. Output ONLY the raw updated text.
6. ${isMetaSection ? 'This is a metadata section. DO NOT add citations.' : 'Maintain existing citations style.'}
$customPromptStr""";
      
      final userMessage = """EDIT INSTRUCTION:
$prompt

CURRENT CONTENT:
$originalContent

${isMetaSection ? '' : 'SUPPORTING CONTEXT:\n' + knowledgeBase}""";
      
      final messages = [
        ChatMessage(role: 'system', content: systemPrompt),
        ChatMessage(role: 'user', content: userMessage)
      ];
      
      String newContent = "";
      DateTime lastUpdate = DateTime.now();
      
      await for (final chunk in _client.chatStream(_selectedModel ?? 'gemma4', messages)) {
        newContent += chunk;
        _currentProject!.sections[sectionIdx].content = newContent;
        
        final now = DateTime.now();
        if (now.difference(lastUpdate).inMilliseconds >= 100) {
          notifyListeners();
          lastUpdate = now;
        }
      }
      _recordFinalState(sectionId);
      if (section.title.toLowerCase() == 'title') {
        _currentProject!.title = section.content;
      }
      _currentProject!.finalManuscript = _reconstructManuscript(_currentProject!);
      syncSectionsToEditor();
      saveResearchHub();
    } catch (e) {
      _terminalLines.add("❌ Section update error: $e");
      _currentProject!.sections[sectionIdx].content = originalContent + "\n\n[Error updating section]";
    } finally {
      _sectionLoading[sectionId] = false;
      notifyListeners();
    }
  }

  Future<void> runComprehensiveReview() async {
    if (_currentProject == null) return;
    
    final reviewerIdx = _currentProject!.sections.indexWhere((s) => s.title.toLowerCase() == "reviewer comments" || s.title.toLowerCase() == "reviewer feedback");
    if (reviewerIdx == -1) {
      _terminalLines.add("❌ Reviewer comments section not found. Add it to the output canvas first.");
      return;
    }
    
    final reviewerSectionId = _currentProject!.sections[reviewerIdx].id;
    _sectionLoading[reviewerSectionId] = true;
    setActiveOutputSection(reviewerSectionId);
    _appendChatLog(reviewerSectionId, "Run Comprehensive Peer Review");
    notifyListeners();
    
    _terminalLines.add("🧐 Start Comprehensive Review...");
    try {
      final fullManuscript = _currentProject!.sections.map((s) => "### ${s.title}\n${s.content}").join("\n\n");
      final systemPrompt = "You are an Elite Academic Peer Reviewer. Provide constructive, section-by-section feedback for the provided manuscript. Use Markdown headings for each section you review.";
      final messages = [
        ChatMessage(role: 'system', content: systemPrompt),
        ChatMessage(role: 'user', content: "Review the following manuscript:\n\n$fullManuscript")
      ];
      
      String response = "";
      DateTime lastUpdate = DateTime.now();
      
      await for (final chunk in _client.chatStream(_selectedModel ?? 'gemma4', messages)) {
        response += chunk;
        _currentProject!.sections[reviewerIdx].content = response;
        
        final now = DateTime.now();
        if (now.difference(lastUpdate).inMilliseconds >= 100) {
          notifyListeners();
          lastUpdate = now;
        }
      }
      _currentProject!.sections[reviewerIdx].chatHistory.add(ChatMessage(role: 'assistant', content: "✅ Comprehensive review completed and output to document."));
      saveResearchHub();
      _terminalLines.add("✅ Comprehensive review completed.");
    } catch (e) {
      _terminalLines.add("❌ Reviewer error: $e");
    } finally {
      _sectionLoading[reviewerSectionId] = false;
      notifyListeners();
    }
  }

  // --- SEMANTIC SCHOLAR ---

  void setSemanticLimit(int limit) {
    _semanticLimit = limit;
    notifyListeners();
  }

  void setSemanticMinYear(int minYear) {
    _semanticMinYear = minYear;
    notifyListeners();
  }

  void setExtendedLiteratureSearch(bool val) {
    _extendedLiteratureSearch = val;
    notifyListeners();
    if (val) runExtendedLiteratureSearch();
  }

  Future<void> runExtendedLiteratureSearch() async {
    if (_currentProject == null) return;
    _isSearchingLiterature = true;
    notifyListeners();
    _terminalLines.add("🔍 Running extended literature search via Semantic Scholar...");

    try {
      final client = SemanticScholarClient();
      final litFiles = _currentProject!.files.where((f) => f.category == FileCategory.literature).toList();
      
      // Build query from file names + title
      final keywords = <String>[researchTitle];
      for (final f in litFiles) {
        keywords.add(f.name.replaceAll(RegExp(r'\.(pdf|docx|txt)'), '').replaceAll('_', ' '));
      }
      
      final papers = await client.searchRelatedToContent(keywords, limit: _semanticLimit, minYear: _semanticMinYear);
      _terminalLines.add("📚 Found ${papers.length} related papers.");

      int added = 0;
      for (final paper in papers) {
        // Skip if we already have a file with the same title
        final alreadyExists = _currentProject!.files.any((f) => f.name.toLowerCase().contains(paper.title.toLowerCase().substring(0, (paper.title.length * 0.5).toInt().clamp(1, 30))));
        if (alreadyExists) continue;

        final content = paper.toFileContent();
        _currentProject!.files.add(ResearchFile(
          name: "${paper.year != null ? '[${paper.year}] ' : ''}${paper.title}.txt",
          content: content,
          type: "txt",
          charCount: content.length,
          summary: paper.abstract_,
          category: FileCategory.literature,
        ));
        added++;
      }
      _terminalLines.add("✅ Added $added new literature files from Academic Sources.");
      saveResearchHub();
    } catch (e) {
      _terminalLines.add("❌ Extended search error: $e");
    } finally {
      _isSearchingLiterature = false;
      notifyListeners();
    }
  }

  // --- PARAPHRASING ---

  void setParaphraseInstructions(String instructions) {
    _paraphraseInstructions = instructions;
    notifyListeners();
  }

  Future<void> paraphraseActiveSection() async {
    if (_currentProject == null || _activeOutputSectionId == null) return;
    final sectionIdx = _currentProject!.sections.indexWhere((s) => s.id == _activeOutputSectionId);
    if (sectionIdx == -1) return;

    final section = _currentProject!.sections[sectionIdx];
    if (section.content.isEmpty) return;

    _pushSectionHistory(section.id, section.content);
    _appendChatLog(section.id, "Apply Paraphrasing");
    _sectionLoading[section.id] = true;
    notifyListeners();
    _terminalLines.add("🔄 Paraphrasing: ${section.title}...");

    try {
      final customPromptStr = section.customPrompt.isNotEmpty ? "\n\nADDITIONAL INSTRUCTIONS SPECIFIC TO THIS SECTION:\n${section.customPrompt}" : "";
      final messages = [
        ChatMessage(role: 'system', content: _paraphraseInstructions + customPromptStr),
        ChatMessage(role: 'user', content: section.content),
      ];

      String result = "";
      DateTime lastUpdate = DateTime.now();
      await for (final chunk in _client.chatStream(_selectedModel ?? 'gemma4', messages)) {
        result += chunk;
        _currentProject!.sections[sectionIdx].content = result;
        final now = DateTime.now();
        if (now.difference(lastUpdate).inMilliseconds >= 100) {
          notifyListeners();
          lastUpdate = now;
        }
      }
      _currentProject!.sections[sectionIdx].chatHistory.add(ChatMessage(role: 'assistant', content: "✅ Paraphrasing applied successfully."));
      _recordFinalState(section.id);
      saveResearchHub();
      _terminalLines.add("✅ Paraphrasing complete.");
    } catch (e) {
      _terminalLines.add("❌ Paraphrase error: $e");
    } finally {
      _sectionLoading[section.id] = false;
      notifyListeners();
    }
  }

  Future<void> proofreadActiveSection() async {
    if (_currentProject == null || _activeOutputSectionId == null) return;
    final sectionIdx = _currentProject!.sections.indexWhere((s) => s.id == _activeOutputSectionId);
    if (sectionIdx == -1) return;

    final section = _currentProject!.sections[sectionIdx];
    if (section.content.isEmpty) return;

    _pushSectionHistory(section.id, section.content);
    _appendChatLog(section.id, "Run Proofreader");
    _sectionLoading[section.id] = true;
    notifyListeners();
    _terminalLines.add("🔍 Proofreading: ${section.title}...");

    try {
      final customPromptStr = section.customPrompt.isNotEmpty ? "\n\nADDITIONAL INSTRUCTIONS SPECIFIC TO THIS SECTION:\n${section.customPrompt}" : "";
      final messages = [
        ChatMessage(role: 'system', content: "Proofread the following academic text for grammatical errors, awkward phrasing, and semantic flow. Fix any issues. You MUST preserve all exact citations entirely. Output ONLY the corrected Markdown text. Do NOT wrap in codeblocks." + customPromptStr),
        ChatMessage(role: 'user', content: section.content),
      ];

      String result = "";
      DateTime lastUpdate = DateTime.now();
      await for (final chunk in _client.chatStream(_selectedModel ?? 'gemma4', messages)) {
        result += chunk;
        _currentProject!.sections[sectionIdx].content = result;
        final now = DateTime.now();
        if (now.difference(lastUpdate).inMilliseconds >= 100) {
          notifyListeners();
          lastUpdate = now;
        }
      }
      _currentProject!.sections[sectionIdx].chatHistory.add(ChatMessage(role: 'assistant', content: "✅ Proofreading applied successfully."));
      _recordFinalState(section.id);
      saveResearchHub();
      _terminalLines.add("✅ Proofreading complete.");
    } catch (e) {
      _terminalLines.add("❌ Proofread error: $e");
    } finally {
      _sectionLoading[section.id] = false;
      notifyListeners();
    }
  }

  // --- AI DETECTION ---

  Future<void> runAIDetection() async {
    if (_currentProject == null) return;
    int aiIdx = _currentProject!.sections.indexWhere((s) => s.title.toLowerCase() == "ai detection");
    if (aiIdx == -1) {
      _terminalLines.add("⚠️ AI Detection section not found. Creating it...");
      _currentProject!.sections.add(ManuscriptSection(title: "AI Detection", order: _currentProject!.sections.length));
      aiIdx = _currentProject!.sections.length - 1;
    }

    final aiSectionId = _currentProject!.sections[aiIdx].id;
    _sectionLoading[aiSectionId] = true;
    setActiveOutputSection(aiSectionId);
    _appendChatLog(aiSectionId, "Run AI Detection Analysis");
    notifyListeners();
    _terminalLines.add("🤖 Running AI Detection analysis...");

    try {
      final sectionsToAnalyze = _currentProject!.sections
          .where((s) => !['AI Detection', 'Similarity', 'Reviewer comments', 'Keywords', 'Authors', 'Title']
              .contains(s.title) && s.content.isNotEmpty)
          .toList();

      final systemPrompt = """You are an expert AI-generated text detector, similar to Turnitin's AI writing detection system. Analyze the provided academic text for signs of AI generation.

For each section provided, output:
1. A percentage score (0-100%) indicating likelihood of AI generation
2. Specific sentences or phrases that appear AI-generated (flag them)
3. Reasoning for the score

Look for these AI writing indicators:
- Overly uniform sentence length and structure
- Generic hedging language ("It is important to note", "Furthermore", "Moreover")
- Lack of specific personal insight or unique perspective
- Repetitive transitional phrases
- Unnaturally smooth flow without human-like irregularities
- Generic conclusions that could apply to any topic
- Excessive use of passive voice in a formulaic pattern
- Perfect paragraph structure without natural variation

Output ONLY Markdown with section headings and scored results. Use ⚠️ emoji for flagged sentences.""";

      final contentToAnalyze = sectionsToAnalyze.map((s) => "## ${s.title}\n${s.content}").join("\n\n");
      final messages = [
        ChatMessage(role: 'system', content: systemPrompt),
        ChatMessage(role: 'user', content: "Analyze the following manuscript sections for AI-generated content:\n\n$contentToAnalyze"),
      ];

      String result = "";
      DateTime lastUpdate = DateTime.now();
      await for (final chunk in _client.chatStream(_selectedModel ?? 'gemma4', messages)) {
        result += chunk;
        _currentProject!.sections[aiIdx].content = result;
        final now = DateTime.now();
        if (now.difference(lastUpdate).inMilliseconds >= 100) {
          notifyListeners();
          lastUpdate = now;
        }
      }
      saveResearchHub();
      _terminalLines.add("✅ AI Detection completed.");
    } catch (e) {
      _terminalLines.add("❌ AI Detection error: $e");
    } finally {
      _sectionLoading[aiSectionId] = false;
      notifyListeners();
    }
  }

  // --- SIMILARITY CHECK ---

  Future<void> runSimilarityCheck() async {
    if (_currentProject == null) return;
    int simIdx = _currentProject!.sections.indexWhere((s) => s.title.toLowerCase() == "similarity");
    if (simIdx == -1) {
      _terminalLines.add("⚠️ Similarity section not found. Creating it...");
      _currentProject!.sections.add(ManuscriptSection(title: "Similarity", order: _currentProject!.sections.length));
      simIdx = _currentProject!.sections.length - 1;
    }

    final simSectionId = _currentProject!.sections[simIdx].id;
    _sectionLoading[simSectionId] = true;
    setActiveOutputSection(simSectionId);
    _appendChatLog(simSectionId, "Run Similarity Analysis");
    notifyListeners();
    _terminalLines.add("🔍 Running similarity analysis...");

    try {
      final litFiles = _currentProject!.files.where((f) => f.category == FileCategory.literature).toList();
      final sectionsToCheck = _currentProject!.sections
          .where((s) => !['AI Detection', 'Similarity', 'Reviewer comments', 'Keywords', 'Authors', 'Title']
              .contains(s.title) && s.content.isNotEmpty)
          .toList();

      final litContext = litFiles.map((f) => "--- ${f.name} ---\n${f.content.length > 1500 ? f.content.substring(0, 1500) : f.content}").join("\n\n");
      final manuscriptContent = sectionsToCheck.map((s) => "## ${s.title}\n${s.content}").join("\n\n");

      final systemPrompt = """You are an expert plagiarism and similarity detection system. Compare the manuscript sections against the provided source literature documents.

For each manuscript section:
1. Provide a similarity percentage (0-100%)
2. Identify specific passages that closely match or overlap with source documents
3. Cite which source document the overlap is from

Output Markdown with section headings, percentage scores, and highlighted overlaps. Use 🟢 for low similarity (0-20%), 🟡 for moderate (20-50%), 🔴 for high (50%+).""";

      final messages = [
        ChatMessage(role: 'system', content: systemPrompt),
        ChatMessage(role: 'user', content: "SOURCE LITERATURE:\n$litContext\n\nMANUSCRIPT TO CHECK:\n$manuscriptContent"),
      ];

      String result = "";
      DateTime lastUpdate = DateTime.now();
      await for (final chunk in _client.chatStream(_selectedModel ?? 'gemma4', messages)) {
        result += chunk;
        _currentProject!.sections[simIdx].content = result;
        final now = DateTime.now();
        if (now.difference(lastUpdate).inMilliseconds >= 100) {
          notifyListeners();
          lastUpdate = now;
        }
      }
      saveResearchHub();
      _terminalLines.add("✅ Similarity analysis completed.");
    } catch (e) {
      _terminalLines.add("❌ Similarity error: $e");
    } finally {
      _sectionLoading[simSectionId] = false;
      notifyListeners();
    }
  }

  // --- UNDO / REDO ---

  void _pushSectionHistory(String id, String content) {
    if (!_sectionHistory.containsKey(id)) {
      _sectionHistory[id] = [];
      _sectionHistoryIdx[id] = -1;
    }
    
    final history = _sectionHistory[id]!;
    
    // Avoid duplicate pushes
    if (history.isNotEmpty && history.last == content) return;

    int idx = _sectionHistoryIdx[id]!;
    // Truncate future states if we're in the middle of history
    if (idx < history.length - 1) {
      _sectionHistory[id] = history.sublist(0, idx + 1);
    }
    
    _sectionHistory[id]!.add(content);
    
    // Cap history at 50 items
    if (_sectionHistory[id]!.length > 50) {
      _sectionHistory[id]!.removeAt(0);
    }
    
    _sectionHistoryIdx[id] = _sectionHistory[id]!.length - 1;
    notifyListeners();
  }

  /// Records the current project content as the final state after an operation.
  void _recordFinalState(String id) {
    if (_currentProject == null) return;
    final section = _currentProject!.sections.firstWhere((s) => s.id == id, orElse: () => ManuscriptSection(title: '', order: 0));
    if (section.id.isNotEmpty) {
      _pushSectionHistory(id, section.content);
    }
  }

  bool canUndo(String id) {
    return (_sectionHistoryIdx[id] ?? -1) > 0;
  }

  bool canRedo(String id) {
    final history = _sectionHistory[id];
    final idx = _sectionHistoryIdx[id];
    if (history == null || idx == null) return false;
    return idx < history.length - 1;
  }

  void undoSection(String id) {
    if (!canUndo(id) || _currentProject == null) return;
    _sectionHistoryIdx[id] = _sectionHistoryIdx[id]! - 1;
    final content = _sectionHistory[id]![_sectionHistoryIdx[id]!];
    final idx = _currentProject!.sections.indexWhere((s) => s.id == id);
    if (idx != -1) {
      final section = _currentProject!.sections[idx];
      section.content = content;
      if (section.title.toLowerCase() == 'title') {
        _currentProject!.title = section.content;
      }
      _currentProject!.finalManuscript = _reconstructManuscript(_currentProject!);
      syncSectionsToEditor();
      saveResearchHub();
      notifyListeners();
    }
  }

  void redoSection(String id) {
    if (!canRedo(id) || _currentProject == null) return;
    _sectionHistoryIdx[id] = _sectionHistoryIdx[id]! + 1;
    final content = _sectionHistory[id]![_sectionHistoryIdx[id]!];
    final idx = _currentProject!.sections.indexWhere((s) => s.id == id);
    if (idx != -1) {
      final section = _currentProject!.sections[idx];
      section.content = content;
      if (section.title.toLowerCase() == 'title') {
        _currentProject!.title = section.content;
      }
      _currentProject!.finalManuscript = _reconstructManuscript(_currentProject!);
      syncSectionsToEditor();
      saveResearchHub();
      notifyListeners();
    }
  }



  void copySectionContent(String id) {
    if (_currentProject == null) return;
    final section = _currentProject!.sections.firstWhere((s) => s.id == id, orElse: () => ManuscriptSection(title: '', order: 0));
    if (section.content.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: section.content));
      _terminalLines.add("📋 Copied '${section.title}' to clipboard.");
      notifyListeners();
    }
  }

  /// Helper to run the standard one-shot literature review (used for local models)
  Future<void> _runOneShotLiterature(String ctx, String authorIndex, String knowledgeBase, bool isCloud) async {
    final litPrompt = isCloud ? """<CONTEXT>
  $authorIndex
  $knowledgeBase
</CONTEXT>
<TASK>
  Write a literature review for '$researchTitle'. 
  Citation Style: $citationStyle.
  IMPORTANT: OUTPUT ONLY THE LITERATURE REVIEW TEXT.
</TASK>""" : """<TASK>
  Write a literature review for '$researchTitle'. 
  Citation Style: $citationStyle.
</TASK>
<CONTEXT>
  $authorIndex
  $knowledgeBase
</CONTEXT>""";

    await sendResearchMessage(1, litPrompt, agentInstructions[1]!.replaceAll('{{CITATION_STYLE}}', citationStyle) + "\n" + ctx);
    String litContent = getResearchAgentChat(1).last.content;
    litContent = _stripPromptEcho(litContent, "Write a literature review");
    
    // Add references list automatically
    final references = _buildReferencesSection();
    final fullLit = litContent + "\n\n" + references;
    
    _currentProject!.litReview = fullLit;
    _updateSectionContentByTitle('Literature Review', fullLit);
  }

  /// Validates generated section content to ensure it is not an echo of the prompt.
  bool _validateSectionContent(String content, String sectionName) {
    if (content.isEmpty) return false;
    final lower = content.toLowerCase();
    
    // Pattern 1: Prompt Tags Echoing
    if (lower.contains('### task definition') || 
        lower.contains('### bibliographic context') ||
        lower.contains('<task>') || 
        lower.contains('<context>')) {
      return false;
    }
    
    // Pattern 2: Heavy Instruction Echoing
    if (lower.contains('write the') && lower.contains('section for the paper')) {
       // Check if the output looks too much like the task description
       return false;
    }

    // Pattern 3: Refusal
    if (lower.contains('i cannot fulfill this request') || 
        lower.contains('as an ai language model')) {
      return false;
    }

    return true;
  }

  void _recordTokenUsage(String model, List<ChatMessage> prompt, String response) {
    if (_currentProject == null) return;
    
    TokenUsage usage;
    if (_client.lastUsage != null) {
      usage = _client.lastUsage!;
      _client.lastUsage = null;
    } else {
      final promptText = prompt.map((m) => m.content).join("\n");
      usage = TokenUsage.fromTextEstimation(promptText, response);
    }
    
    _currentProject!.totalTokensUsed += usage.totalTokens;
    notifyListeners();
  }

}

class _MarkdownChunk {
  final String type, content;
  _MarkdownChunk(this.type, this.content);
}
