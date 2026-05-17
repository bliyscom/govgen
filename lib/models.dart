enum FileCategory { literature, results, data }

class ResearchFile {
  final String name;
  final String content;
  final String type;
  final int charCount;
  String summary;
  FileCategory category;

  // Structured citation metadata — populated by the extraction pre-step
  String extractedAuthors;
  String extractedYear;
  String extractedTitle;
  String extractedDoi;
  String extractedJournal;

  ResearchFile({
    required this.name,
    required this.content,
    required this.type,
    required this.charCount,
    this.summary = "",
    this.category = FileCategory.literature,
    this.extractedAuthors = "",
    this.extractedYear = "",
    this.extractedTitle = "",
    this.extractedDoi = "",
    this.extractedJournal = "",
  });

  /// Whether structured metadata has been extracted for this file.
  bool get hasExtractedMetadata => extractedAuthors.isNotEmpty && extractedYear.isNotEmpty && extractedTitle.isNotEmpty;

  /// Build a short APA-style in-text key like "(Masoumi et al., 2021)"
  String get citationKey {
    if (!hasExtractedMetadata) return '(Unknown, n.d.)';
    final firstAuthor = extractedAuthors.split(',').first.split(' ').last.trim();
    final etAl = extractedAuthors.contains(',') ? ' et al.' : '';
    return '($firstAuthor$etAl, $extractedYear)';
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'content': content,
    'type': type,
    'charCount': charCount,
    'summary': summary,
    'category': category.name,
    'extractedAuthors': extractedAuthors,
    'extractedYear': extractedYear,
    'extractedTitle': extractedTitle,
    'extractedDoi': extractedDoi,
    'extractedJournal': extractedJournal,
  };

  factory ResearchFile.fromJson(Map<String, dynamic> json) => ResearchFile(
    name: json['name'] as String,
    content: json['content'] as String,
    type: json['type'] as String,
    charCount: json['charCount'] as int,
    summary: json['summary'] as String? ?? "",
    category: FileCategory.values.firstWhere((e) => e.name == (json['category'] ?? 'literature'), orElse: () => FileCategory.literature),
    extractedAuthors: json['extractedAuthors'] as String? ?? "",
    extractedYear: json['extractedYear'] as String? ?? "",
    extractedTitle: json['extractedTitle'] as String? ?? "",
    extractedDoi: json['extractedDoi'] as String? ?? "",
    extractedJournal: json['extractedJournal'] as String? ?? "",
  );
}

class ChatMessage {
  final String id;
  final String role;
  final String content;
  final List<String>? images;
  final DateTime timestamp;

  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    this.images,
    DateTime? timestamp,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'images': images,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Serialization for Ollama API — only includes fields the API understands.
  Map<String, dynamic> toOllamaJson() {
    final json = <String, dynamic>{
      'role': role,
      'content': content,
    };
    if (images != null && images!.isNotEmpty) {
      json['images'] = images;
    }
    return json;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String?,
      role: json['role'] as String,
      content: json['content'] as String,
      images: (json['images'] as List?)?.map((e) => e as String).toList(),
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp'] as String) : null,
    );
  }
}

class TokenUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  TokenUsage({
    this.promptTokens = 0,
    this.completionTokens = 0,
    int? totalTokens,
  }) : totalTokens = totalTokens ?? (promptTokens + completionTokens);

  /// Heuristically estimate tokens from string length (approx 4 chars per token)
  static TokenUsage fromTextEstimation(String prompt, String response) {
    final pt = (prompt.length / 4).ceil();
    final ct = (response.length / 4).ceil();
    return TokenUsage(promptTokens: pt, completionTokens: ct);
  }

  Map<String, dynamic> toJson() => {
    'promptTokens': promptTokens,
    'completionTokens': completionTokens,
    'totalTokens': totalTokens,
  };
}

class AiResponse {
  final ChatMessage message;
  final TokenUsage usage;

  AiResponse({required this.message, required this.usage});
}

class ChatSession {
  final String id;
  String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  String? contextText;  // Extracted text from PDF, DOCX, etc.
  String? contextName; // Original file name
  String? contextType; // 'pdf', 'docx', etc.
  String? contextSummary; // Cached summary of the context

  ChatSession({
    String? id,
    required this.title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    this.contextText,
    this.contextName,
    this.contextType,
    this.contextSummary,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now();

  int get contextCharCount => contextText?.length ?? 0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'messages': messages.map((m) => m.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'contextText': contextText,
      'contextName': contextName,
      'contextType': contextType,
      'contextSummary': contextSummary,
    };
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String?,
      title: json['title'] as String,
      messages: (json['messages'] as List?)
          ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
      contextText: json['contextText'] as String?,
      contextName: json['contextName'] as String?,
      contextType: json['contextType'] as String?,
    );
  }
}

class ManuscriptSection {
  String id;
  String title;
  String content;
  int order;
  String customPrompt;
  List<ChatMessage> chatHistory;

  ManuscriptSection({
    String? id,
    required this.title,
    this.content = "",
    required this.order,
    this.customPrompt = "",
    List<ChatMessage>? chatHistory,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString() + title.hashCode.toString(),
       chatHistory = chatHistory ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'order': order,
    'customPrompt': customPrompt,
    'chatHistory': chatHistory.map((m) => m.toJson()).toList(),
  };

  factory ManuscriptSection.fromJson(Map<String, dynamic> json) => ManuscriptSection(
    id: json['id'] as String?,
    title: json['title'] as String,
    content: json['content'] as String? ?? "",
    order: json['order'] as int? ?? 0,
    customPrompt: json['customPrompt'] as String? ?? "",
    chatHistory: (json['chatHistory'] as List?)?.map((m) => ChatMessage.fromJson(m)).toList() ?? [],
  );
}

class ResearchProject {
  final String id;
  String title;
  DateTime createdAt;
  DateTime lastModified;
  
  // Persistence for each stage
  String litReview = "";
  String methodology = "";
  String analysis = "";
  String finalManuscript = ""; // Legacy/Reconstructed
  List<ManuscriptSection> sections = [];
  Map<String, String> manuscriptSections = {}; // Legacy
  String reviewerFeedback = ""; // Feedback from the reviewer agent
  String lastCompletedStage = ""; // e.g. "LITERATURE"
  
  // File Repository
  List<ResearchFile> files = [];
  
  // Agent Chats (1-5)
  Map<int, List<ChatMessage>> agentChats = {
    1: [], 2: [], 3: [], 4: [], 5: []
  };

  // Settings
  String citationStyle = "APA";
  String? dataAnalysisModel; // Stage-specific override
  bool isAutonomousProactive = true;
  bool isDraftRefinementMode = false;
  String extraInstructions = "";
  String initialDraft = "";
  String reviewerInstructions = ""; 
  int totalTokensUsed = 0;

  ResearchProject({
    String? id,
    required this.title,
    DateTime? createdAt,
    DateTime? lastModified,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now(),
       lastModified = lastModified ?? DateTime.now() {
    // Initialize default sections if empty
    if (sections.isEmpty) {
      final defaultTitles = [
        "Title", "Abstract", "Keywords", "Authors", "Introduction", 
        "Literature Review", "Methodology", "Results", "Discussion", 
        "Conclusion", "References", "Appendices", "Reviewer comments",
        "AI Detection", "Similarity"
      ];
      final defaultInstructions = {
        "Title": "Generate a concise, impactful academic title reflecting the core scientific focus and findings of the analysis. Avoid generic filler words. Maximum 15 words.",
        "Abstract": "Summarize the research problem, the methodology deployed, the key quantitative findings, and broader implications in a single cohesive paragraph (under 250 words). Do NOT use citations in the abstract.",
        "Keywords": "Provide 5 to 7 highly specific, comma-separated keywords optimized for academic search indexing.",
        "Authors": "Format the author names and affiliations accurately.",
        "Introduction": "Write a comprehensive introduction. You MUST include in-text citations from the CITATION SOURCE MATERIAL using the chosen citation style. For EVERY claim or background statement, cite the relevant author(s) by surname and year, e.g. (Kirui et al., 2021) or (Landskron & Böhm, 2017). Do NOT write generic phrases like 'as discussed in general literature'. Cite the ACTUAL authors from the provided documents. The Introduction MUST contain multiple in-text citations from the source material.",
        "Literature Review": "Synthesize ALL provided source documents. You MUST cite EVERY SINGLE document from the CITATION SOURCE MATERIAL by author surname and year using the chosen citation style. Each document MUST appear at least once as an in-text citation. Compare and contrast findings across documents.",
        "Methodology": "Detail the specific algorithms, datasets, tools, and procedures used. Reference methodological approaches from the CITATION SOURCE MATERIAL where applicable, citing by author and year.",
        "Results": "Present findings objectively using quantitative statistical data extracted from the context. Cite source documents when comparing results.",
        "Discussion": "Interpret the results by explicitly referencing findings from the CITATION SOURCE MATERIAL. You MUST cite specific authors when comparing or contextualizing your findings. Discuss limitations and unexpected findings.",
        "Conclusion": "Provide a definitive concluding synthesis of the impact of the findings. Do NOT introduce new references or claims.",
        "References": "List EVERY document from the CITATION SOURCE MATERIAL as a formatted reference entry. Use the exact author names, year, title, and URL/DOI from the source documents. Every single entry MUST be present. If the year or source is not explicitly listed, extract it from the text yourself. Do NOT output '(Year)' or 'Source information missing'. Do NOT fabricate references that are not in the source material.",
      };

      for (int i = 0; i < defaultTitles.length; i++) {
        final title = defaultTitles[i];
        final instruction = defaultInstructions[title] ?? "";
        final initialContent = (title == 'Title') ? this.title : "";
        sections.add(ManuscriptSection(title: title, content: initialContent, order: i, customPrompt: instruction));
      }
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
      'litReview': litReview,
      'methodology': methodology,
      'analysis': analysis,
      'finalManuscript': finalManuscript,
      'sections': sections.map((s) => s.toJson()).toList(),
      'manuscriptSections': manuscriptSections,
      'reviewerFeedback': reviewerFeedback,
      'lastCompletedStage': lastCompletedStage,
      'files': files.map((f) => f.toJson()).toList(),
      'agentChats': agentChats.map((k, v) => MapEntry(k.toString(), v.map((m) => m.toJson()).toList())),
      'citationStyle': citationStyle,
      'dataAnalysisModel': dataAnalysisModel,
      'isAutonomousProactive': isAutonomousProactive,
      'isDraftRefinementMode': isDraftRefinementMode,
      'extraInstructions': extraInstructions,
      'initialDraft': initialDraft,
      'reviewerInstructions': reviewerInstructions,
      'totalTokensUsed': totalTokensUsed,
    };
  }

  factory ResearchProject.fromJson(Map<String, dynamic> json) {
    final project = ResearchProject(
      id: json['id'] as String?,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastModified: DateTime.parse(json['lastModified'] as String),
    );
    project.litReview = json['litReview'] ?? "";
    project.methodology = json['methodology'] ?? "";
    project.analysis = json['analysis'] ?? "";
    project.finalManuscript = json['finalManuscript'] ?? "";
    
    if (json['sections'] != null) {
      project.sections = (json['sections'] as List).map((s) => ManuscriptSection.fromJson(s as Map<String, dynamic>)).toList();
    } else if (json['manuscriptSections'] != null) {
      // Legacy migration
      project.manuscriptSections = Map<String, String>.from(json['manuscriptSections']);
      int order = 0;
      project.manuscriptSections.forEach((key, value) {
        // Try to update existing default sections if they match, or append
        final existingIdx = project.sections.indexWhere((s) => s.title.toLowerCase() == key.toLowerCase());
        if (existingIdx != -1) {
          project.sections[existingIdx].content = value;
        } else {
          project.sections.add(ManuscriptSection(title: key, content: value, order: 100 + order));
          order++;
        }
      });
    }

    project.reviewerFeedback = json['reviewerFeedback'] ?? "";
    project.lastCompletedStage = json['lastCompletedStage'] ?? "";
    project.files = (json['files'] as List?)?.map((f) => ResearchFile.fromJson(f)).toList() ?? [];
    
    if (json['agentChats'] != null) {
      final chatsMap = json['agentChats'] as Map<String, dynamic>;
      project.agentChats = chatsMap.map((k, v) => MapEntry(
        int.parse(k),
        (v as List).map((m) => ChatMessage.fromJson(m)).toList(),
      ));
    }
    
    project.citationStyle = json['citationStyle'] ?? "APA";
    project.dataAnalysisModel = json['dataAnalysisModel'] as String?;
    project.isAutonomousProactive = json['isAutonomousProactive'] ?? json['isProactive'] ?? true;
    project.isDraftRefinementMode = json['isDraftRefinementMode'] ?? json['isRefinement'] ?? false;
    project.extraInstructions = json['extraInstructions'] ?? "";
    project.initialDraft = json['initialDraft'] ?? json['userDraft'] ?? "";
    project.reviewerInstructions = json['reviewerInstructions'] ?? json['reviewerComments'] ?? "";
    project.totalTokensUsed = json['totalTokensUsed'] ?? 0;
    
    return project;
  }
}
