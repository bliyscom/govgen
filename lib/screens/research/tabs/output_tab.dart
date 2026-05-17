import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../models.dart';
import '../../../state/chat_state.dart';
import '../../../theme.dart';
import '../../document_editor.dart';
import 'code_laboratory_tab.dart';

class OutputTab extends StatefulWidget {
  const OutputTab({super.key});

  @override
  State<OutputTab> createState() => _OutputTabState();
}

class _OutputTabState extends State<OutputTab> with AutomaticKeepAliveClientMixin {
  bool _isChatPaneOpen = true;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = context.watch<ChatState>();
    final project = state.currentProject;

    if (project == null) {
      return const Center(child: Text("No active project"));
    }

    return Column(
      children: [
        _buildToolbar(context, state),
        Expanded(
          child: Row(
            children: [
              Expanded(flex: 2, child: _buildLeftMenu(context, state, project)),
              const VerticalDivider(width: 1, color: Colors.white10),
              Expanded(flex: _isChatPaneOpen ? 5 : 8, child: _buildMiddlePane(context, state, project)),
              
              if (_isChatPaneOpen) const VerticalDivider(width: 1, color: Colors.white10),
              if (_isChatPaneOpen) Expanded(flex: 3, child: _buildRightChatPane(context, state, project)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context, ChatState state) {
    final sectionId = state.activeOutputSectionId;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: OhadaTheme.surface,
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // View mode toggles
            _toolbarModeButton(state, 'Canvas', 'canvas', Icons.web_asset),
            const SizedBox(width: 6),
            _toolbarModeButton(state, 'Data Analysis', 'laboratorian', Icons.code),
            const SizedBox(width: 6),
            _toolbarModeButton(state, 'Editor', 'editor', Icons.edit_document),
            
            const SizedBox(width: 16),
            Container(width: 1, height: 24, color: Colors.white10),
            const SizedBox(width: 16),

            // Model Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: (state.selectedModel != null && state.models.contains(state.selectedModel)) ? state.selectedModel : null,
                  dropdownColor: OhadaTheme.surface,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                  hint: const Text("Model", style: TextStyle(fontSize: 11, color: Colors.grey)),
                  items: state.models.map((m) => DropdownMenuItem<String?>(
                    value: m, 
                    child: Text(m, style: const TextStyle(fontSize: 11))
                  )).toList(),
                  onChanged: (val) => val != null ? state.setSelectedModel(val) : null,
                ),
              ),
            ),

            const SizedBox(width: 16),
            Container(width: 1, height: 24, color: Colors.white10),
            const SizedBox(width: 16),

            // Action tools
            _toolbarActionButton('Paraphrase', Icons.autorenew, OhadaTheme.accent,
              onPressed: state.sectionLoading.values.any((v) => v) ? null : () => state.paraphraseActiveSection()),
            const SizedBox(width: 6),
            _toolbarActionButton('AI Detect', Icons.smart_toy, Colors.orangeAccent,
              onPressed: state.sectionLoading.values.any((v) => v) ? null : () => state.runAIDetection()),
            const SizedBox(width: 6),
            _toolbarActionButton('Similarity', Icons.compare_arrows, Colors.cyanAccent,
              onPressed: state.sectionLoading.values.any((v) => v) ? null : () => state.runSimilarityCheck()),
            const SizedBox(width: 6),
            _toolbarActionButton('Reviewers', Icons.rate_review, Colors.purpleAccent,
              onPressed: state.isResearchRunning ? null : () => state.runComprehensiveReview()),

            const SizedBox(width: 16),
            Container(width: 1, height: 24, color: Colors.white10),
            const SizedBox(width: 16),

            // Undo/Redo
            IconButton(
              icon: const Icon(Icons.undo, size: 18),
              onPressed: sectionId != null && state.canUndo(sectionId) ? () => state.undoSection(sectionId) : null,
              tooltip: 'Undo',
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              icon: const Icon(Icons.redo, size: 18),
              onPressed: sectionId != null && state.canRedo(sectionId) ? () => state.redoSection(sectionId) : null,
              tooltip: 'Redo',
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),

            const SizedBox(width: 16),
            Container(width: 1, height: 24, color: Colors.white10),
            const SizedBox(width: 16),

            // Literature Knowledge Base Preview
            _toolbarActionButton('Sources', Icons.library_books, Colors.blueAccent,
              onPressed: () {
                final kb = state.buildLiteratureKnowledgeBase();
                final litCount = state.currentProject?.files.where((f) => f.category == FileCategory.literature).length ?? 0;
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: OhadaTheme.surface,
                    title: Row(children: [
                      const Icon(Icons.library_books, color: Colors.blueAccent, size: 18),
                      const SizedBox(width: 8),
                      Text('Citation Knowledge Base ($litCount docs)', style: const TextStyle(fontSize: 14, color: Colors.white)),
                    ]),
                    content: SizedBox(
                      width: 650, height: 500,
                      child: kb.isEmpty
                        ? const Center(child: Text('No literature files ingested.', style: TextStyle(color: Colors.grey)))
                        : SingleChildScrollView(child: SelectableText(kb, style: const TextStyle(fontSize: 11, color: Colors.white70, fontFamily: 'monospace'))),
                    ),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
                  ),
                );
              }),
            const SizedBox(width: 6),
            
            // Citation Fix Tool
            _toolbarActionButton('Fix Citations', Icons.format_quote, Colors.orangeAccent,
              onPressed: () {
                if (!state.isResearchRunning) {
                  state.runCitationCorrection();
                }
              }),
            const SizedBox(width: 6),

            // Export
            ElevatedButton.icon(
              onPressed: () => state.exportManuscriptToPdf(),
              icon: const Icon(Icons.picture_as_pdf, size: 14, color: OhadaTheme.primary),
              label: const Text("PDF", style: TextStyle(fontSize: 11, color: OhadaTheme.primary)),
              style: ElevatedButton.styleFrom(backgroundColor: OhadaTheme.accent, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
            ),
            const SizedBox(width: 6),
            ElevatedButton.icon(
              onPressed: () => state.exportManuscriptToMarkdown(),
              icon: const Icon(Icons.content_copy, size: 14, color: OhadaTheme.primary),
              label: const Text("MD", style: TextStyle(fontSize: 11, color: OhadaTheme.primary)),
              style: ElevatedButton.styleFrom(backgroundColor: OhadaTheme.accent, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
            ),
            
            const SizedBox(width: 16),
            Container(width: 1, height: 24, color: Colors.white10),
            const SizedBox(width: 16),
            
            IconButton(
              icon: Icon(_isChatPaneOpen ? Icons.keyboard_double_arrow_right : Icons.keyboard_double_arrow_left, size: 18, color: Colors.grey),
              onPressed: () => setState(() => _isChatPaneOpen = !_isChatPaneOpen),
              tooltip: _isChatPaneOpen ? 'Close Chat Pane' : 'Open Chat Pane',
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbarModeButton(ChatState state, String label, String mode, IconData icon) {
    final isActive = state.outputViewMode == mode;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isActive,
      onSelected: (val) {
        if (val) state.setOutputViewMode(mode);
      },
      avatar: Icon(icon, size: 14, color: isActive ? OhadaTheme.primary : Colors.grey),
      selectedColor: OhadaTheme.accent,
      backgroundColor: Colors.transparent,
      labelStyle: TextStyle(color: isActive ? OhadaTheme.primary : Colors.grey),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isActive ? OhadaTheme.accent : Colors.white10),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _toolbarActionButton(String label, IconData icon, Color color, {VoidCallback? onPressed}) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14, color: color),
      label: Text(label, style: TextStyle(fontSize: 11, color: color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 30),
      ),
    );
  }

  Widget _buildLeftMenu(BuildContext context, ChatState state, ResearchProject project) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  "SECTIONS", 
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton( 
                icon: const Icon(Icons.add, size: 16, color: OhadaTheme.accent),
                onPressed: () => _showAddSectionDialog(context, state),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                tooltip: 'Add Section',
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: project.sections.length,
            onReorder: (oldIndex, newIndex) => state.reorderSections(oldIndex, newIndex),
            itemBuilder: (context, index) {
              final section = project.sections[index];
              final isActive = state.activeOutputSectionId == section.id;
              final isLoading = state.sectionLoading[section.id] ?? false;
              final hasContent = section.content.isNotEmpty;

              return ReorderableDragStartListener(
                key: ValueKey(section.id),
                index: index,
                child: Container(
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
                    border: isActive ? const Border(left: BorderSide(color: OhadaTheme.accent, width: 3)) : null,
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    visualDensity: VisualDensity.compact,
                    mouseCursor: SystemMouseCursors.click,
                    leading: isLoading 
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: OhadaTheme.accent))
                      : Icon(hasContent ? Icons.check_circle : Icons.radio_button_unchecked, size: 14, color: hasContent ? Colors.green : Colors.grey),
                    title: Text(section.title, style: TextStyle(fontSize: 11, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? OhadaTheme.accent : Colors.white)),
                    onTap: () => state.setActiveOutputSection(section.id),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.settings, size: 12, color: Colors.blueAccent),
                          onPressed: () => _showSectionPromptSettings(context, state, section),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          tooltip: 'Prompt Settings',
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 12, color: Colors.grey),
                          onPressed: hasContent ? () => state.copySectionContent(section.id) : null,
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          tooltip: 'Copy',
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 12, color: Colors.redAccent),
                          onPressed: () => state.deleteManuscriptSection(section.id),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showSectionPromptSettings(BuildContext context, ChatState state, ManuscriptSection section) {
    final TextEditingController promptController = TextEditingController(text: section.customPrompt);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: OhadaTheme.surface,
          title: Text("Prompt Instructions: ${section.title}", style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Define custom AI instructions for this section. The model will strictly adhere to these when regenerating.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 12),
                TextField(
                  controller: promptController,
                  maxLines: 6,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: "E.g. Focus on statistical significance, omit background theory...",
                    hintStyle: TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.black12,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                state.updateSectionCustomPrompt(section.id, promptController.text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Section instructions updated.'), duration: Duration(seconds: 1)));
              },
              style: ElevatedButton.styleFrom(backgroundColor: OhadaTheme.accent),
              child: const Text("Save", style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMiddlePane(BuildContext context, ChatState state, ResearchProject project) {
    int modeIndex = 0;
    if (state.outputViewMode == 'laboratorian') modeIndex = 1;
    else if (state.outputViewMode == 'editor') modeIndex = 2;

    return IndexedStack(
      index: modeIndex,
      children: [
        _buildCanvasMode(context, state, project),
        const CodeLaboratoryTab(),
        const RepaintBoundary(child: DocumentEditor()),
      ],
    );
  }

  Widget _buildCanvasMode(BuildContext context, ChatState state, ResearchProject project) {
    final sectionId = state.activeOutputSectionId;
    if (sectionId == null || project.sections.isEmpty) {
      return const Center(child: Text("Select a section to view.", style: TextStyle(color: Colors.grey)));
    }

    final section = project.sections.firstWhere((s) => s.id == sectionId, orElse: () => project.sections.first);
    final isLoading = state.sectionLoading[sectionId] ?? false;

    return _DeferredRender(
      key: ValueKey(section.id),
      child: Stack(
        children: [
          Container(
            color: OhadaTheme.background,
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(section.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                    if (isLoading)
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: OhadaTheme.accent)),
                  ],
                ),
                const Divider(height: 24, color: Colors.white10),
                Expanded(
                  child: SingleChildScrollView(
                    child: _RichContentRenderer(content: section.content.isEmpty ? "*Empty content. Use the chat to generate.*" : section.content),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildMiniFab(context, tooltip: 'Proofreader', icon: Icons.spellcheck, color: Colors.blueAccent, onPressed: state.sectionLoading.values.any((v) => v) ? null : () => state.proofreadActiveSection()),
                const SizedBox(height: 12),
                _buildMiniFab(context, tooltip: 'Paraphraser', icon: Icons.autorenew, color: OhadaTheme.accent, onPressed: state.sectionLoading.values.any((v) => v) ? null : () => state.paraphraseActiveSection()),
                const SizedBox(height: 12),
                _buildMiniFab(context, tooltip: 'Similarity', icon: Icons.compare_arrows, color: Colors.cyanAccent, onPressed: state.sectionLoading.values.any((v) => v) ? null : () => state.runSimilarityCheck()),
                const SizedBox(height: 12),
                _buildMiniFab(context, tooltip: 'AI-Detector', icon: Icons.smart_toy, color: Colors.orangeAccent, onPressed: state.sectionLoading.values.any((v) => v) ? null : () => state.runAIDetection()),
                const SizedBox(height: 12),
                _buildMiniFab(context, tooltip: 'Review', icon: Icons.rate_review, color: Colors.purpleAccent, onPressed: state.isResearchRunning ? null : () => state.runComprehensiveReview()),
                const SizedBox(height: 16),
                
                if (section.title.toLowerCase().contains("reviewer")) ...[
                  FloatingActionButton.extended(
                    heroTag: 'apply_fixes_fab',
                    onPressed: state.isResearchRunning ? null : () => state.applyReviewerFixes(),
                    backgroundColor: Colors.purpleAccent,
                    icon: const Icon(Icons.auto_fix_high, color: Colors.white, size: 18),
                    label: const Text("Apply Fixes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(height: 16),
                ],

                FloatingActionButton(
                  heroTag: 'copy_content_fab',
                  onPressed: section.content.isEmpty ? null : () {
                    Clipboard.setData(ClipboardData(text: section.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Content copied to clipboard'), duration: Duration(seconds: 1)),
                    );
                  },
                  backgroundColor: OhadaTheme.accent,
                  child: const Icon(Icons.copy, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniFab(BuildContext context, {required String tooltip, required IconData icon, required Color color, VoidCallback? onPressed}) {
    return Tooltip(
      message: tooltip,
      child: FloatingActionButton.small(
        heroTag: 'fab_${tooltip.toLowerCase().replaceAll(' ', '_')}',
        onPressed: onPressed,
        backgroundColor: OhadaTheme.surface,
        elevation: 2,
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildRightChatPane(BuildContext context, ChatState state, ResearchProject project) {
    final sectionId = state.activeOutputSectionId;
    if (sectionId == null || project.sections.isEmpty) {
      return const Center(child: Text("Select a section to chat.", style: TextStyle(color: Colors.grey)));
    }

    final section = project.sections.firstWhere((s) => s.id == sectionId, orElse: () => project.sections.first);
    final isLoading = state.sectionLoading[sectionId] ?? false;

    return Container(
      color: OhadaTheme.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: OhadaTheme.accent),
                const SizedBox(width: 6),
                Expanded(child: Text("Edit: ${section.title}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                // Section Prompt settings
                IconButton(
                  icon: const Icon(Icons.settings, size: 14, color: Colors.blueAccent),
                  onPressed: () => _showSectionPromptSettings(context, state, section),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  tooltip: 'Section Prompt Settings',
                ),
              ],
            ),
          ),
          Expanded(
            child: section.chatHistory.isEmpty 
              ? ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(8)),
                      child: const Text(
                        "Ask the LLM to rewrite, extend, summarize, add citations, or fix specific parts of the selected section.",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: section.chatHistory.length,
                  reverse: true, // we might want it reversed, wait no we add to end.
                  itemBuilder: (context, index) {
                    final idx = section.chatHistory.length - 1 - index;
                    final msg = section.chatHistory[idx];
                    final isUser = msg.role == 'user';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 300),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isUser ? OhadaTheme.accent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: isUser ? Border.all(color: OhadaTheme.accent.withValues(alpha: 0.5)) : null,
                        ),
                        child: MarkdownBody(
                          data: msg.content,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(fontSize: 11, color: isUser ? Colors.white : Colors.grey[300]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ),
          _ChatInputBox(sectionId: section.id, isLoading: isLoading),
        ],
      ),
    );
  }

  void _showAddSectionDialog(BuildContext context, ChatState state) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OhadaTheme.surface,
        title: const Text("Add New Section", style: TextStyle(fontSize: 16, color: OhadaTheme.accent)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: "e.g. Funding Acknowledgements"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty) {
                state.addManuscriptSection(ctrl.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

}

/// Rich content renderer that handles Markdown, math formulas, and citation highlighting
class _RichContentRenderer extends StatelessWidget {
  final String content;
  const _RichContentRenderer({required this.content});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: content,
      selectable: true,
      extensionSet: md.ExtensionSet(
        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        [
          md.EmojiSyntax(),
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
          _BlockMathSyntax(),
          _InlineMathSyntax(),
          _CitationSyntax(),
          _HighlightSyntax(),
        ],
      ),
      builders: {
        'inlinemath': _MathBuilder(isBlock: false),
        'blockmath': _MathBuilder(isBlock: true),
        'cite': _CitationBuilder(),
        'highlight': _HighlightBuilder(),
      },
      styleSheetTheme: MarkdownStyleSheetBaseTheme.material,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(fontSize: 13, height: 1.7),
        h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: OhadaTheme.accent),
        h2: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: OhadaTheme.accent),
        h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        tableHead: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        tableBody: const TextStyle(fontSize: 12),
        code: TextStyle(fontSize: 12, backgroundColor: Colors.white.withValues(alpha: 0.05)),
      ),
    );
  }
}

class _BlockMathSyntax extends md.InlineSyntax {
  _BlockMathSyntax() : super(r'\$\$([^\$]+)\$\$');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('blockmath', match[1]!));
    return true;
  }
}

class _InlineMathSyntax extends md.InlineSyntax {
  _InlineMathSyntax() : super(r'\$([^\$]+)\$');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('inlinemath', match[1]!));
    return true;
  }
}

class _MathBuilder extends MarkdownElementBuilder {
  final bool isBlock;
  _MathBuilder({required this.isBlock});

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final mathWidget = Math.tex(
      element.textContent.trim(),
      textStyle: preferredStyle?.copyWith(fontSize: isBlock ? 16 : 14),
      mathStyle: isBlock ? MathStyle.display : MathStyle.text,
    );

    if (isBlock) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: mathWidget,
          ),
        ),
      );
    }
    return mathWidget;
  }
}

class _CitationSyntax extends md.InlineSyntax {
  _CitationSyntax() : super(
    r'(\([A-Z][A-Za-z\s\,\.\&\-]+\s\d{4}[a-z]?\))'
    r'|(\[\d+(?:[-–,]\s*\d+)*\])'
    r'|([A-Z][A-Za-z\s\,\.\&\-]+\s*\(\d{4}[a-z]?\))'
    r'|([A-Z][A-Za-z\s\,\.\&\-]+\s*\[\d+(?:[-–,]\s*\d+)*\])'
  );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('cite', match[0]!));
    return true;
  }
}

class _CitationBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        element.textContent,
        style: preferredStyle?.copyWith(color: Colors.green, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _HighlightSyntax extends md.InlineSyntax {
  _HighlightSyntax() : super(r'==(.*?)==');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('highlight', match[1]!));
    return true;
  }
}

class _HighlightBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
      ),
      child: Text(
        element.textContent,
        style: preferredStyle?.copyWith(color: Colors.redAccent, backgroundColor: Colors.transparent),
      ),
    );
  }
}



class _ChatInputBox extends StatefulWidget {
  final String sectionId;
  final bool isLoading;
  const _ChatInputBox({required this.sectionId, required this.isLoading});

  @override
  State<_ChatInputBox> createState() => _ChatInputBoxState();
}

class _ChatInputBoxState extends State<_ChatInputBox> {
  final _ctrl = TextEditingController();

  void _submit() {
    if (_ctrl.text.trim().isEmpty || widget.isLoading) return;
    context.read<ChatState>().modifySectionWithLLM(widget.sectionId, _ctrl.text.trim());
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: OhadaTheme.surface,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              enabled: !widget.isLoading,
              onSubmitted: (_) => _submit(),
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: "E.g. Add citation for Smith et al...",
                hintStyle: const TextStyle(fontSize: 11),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: widget.isLoading ? null : _submit,
            icon: widget.isLoading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send, size: 18, color: OhadaTheme.accent),
          ),
        ],
      ),
    );
  }
}

class _DeferredRender extends StatefulWidget {
  final Widget child;
  const _DeferredRender({super.key, required this.child});

  @override
  State<_DeferredRender> createState() => _DeferredRenderState();
}

class _DeferredRenderState extends State<_DeferredRender> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // Allow the transition and tap ripples to fully paint first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // A short 150ms delay guarantees the UI is completely responsive
        // and the spinner is visible before the main thread gets blocked
        // doing the heavy synchronous Markdown regex parsing.
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) setState(() => _ready = true);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(child: CircularProgressIndicator(color: OhadaTheme.accent, strokeWidth: 2));
    }
    return widget.child;
  }
}
