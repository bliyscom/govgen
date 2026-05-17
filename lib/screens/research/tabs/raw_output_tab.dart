import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../../../state/chat_state.dart';
import '../../../theme.dart';
import '../../../models.dart';

class RawOutputTab extends StatefulWidget {
  const RawOutputTab({super.key});

  @override
  State<RawOutputTab> createState() => _RawOutputTabState();
}

class _RawOutputTabState extends State<RawOutputTab> {
  String _viewMode = 'EDITOR'; // EDITOR, MARKDOWN

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChatState>();
    final project = state.currentProject;
    
    if (project == null) {
      return const Center(child: Text("Select a project to view output."));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              const Text('MANUSCRIPT VIEW:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(width: 12),
              _buildModeButton('EDITOR', Icons.edit_note),
              _buildModeButton('MARKDOWN', Icons.auto_stories),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => state.exportManuscriptToPdf(),
                icon: const Icon(Icons.picture_as_pdf, size: 14),
                label: const Text('EXPORT PDF', style: TextStyle(fontSize: 10)),
                style: ElevatedButton.styleFrom(backgroundColor: OhadaTheme.accent, foregroundColor: OhadaTheme.primary),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _viewMode == 'EDITOR' 
              ? _buildJsonEditor(state, project)
              : _buildMarkdownPreview(project),
          ),
        ),
      ],
    );
  }

  Widget _buildModeButton(String mode, IconData icon) {
    final isSelected = _viewMode == mode;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? OhadaTheme.primary : Colors.grey),
            const SizedBox(width: 4),
            Text(mode, style: TextStyle(fontSize: 10, color: isSelected ? OhadaTheme.primary : Colors.grey)),
          ],
        ),
        selected: isSelected,
        onSelected: (val) {
          if (val) setState(() => _viewMode = mode);
        },
        selectedColor: OhadaTheme.accent,
        backgroundColor: Colors.transparent,
      ),
    );
  }

  Widget _buildJsonEditor(ChatState state, ResearchProject project) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('MODULAR JSON EDITOR', 
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13, color: OhadaTheme.accent)),
        const SizedBox(height: 16),
        _buildStageSection("1. Literature Review (Read-only)", project.litReview, isReadOnly: true),
        _buildStageSection("2. Methodology (Read-only)", project.methodology, isReadOnly: true),
        _buildStageSection("3. Data Analysis Result (Read-only)", project.analysis, isReadOnly: true),
        const Divider(color: Colors.white10, height: 48),
        const Text('EDITABLE SECTIONS', 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 16),
        ...project.manuscriptSections.entries.map((e) => _buildEditableSection(state, e.key, e.value)),
        if (project.manuscriptSections.isEmpty)
          const Center(child: Text('Generate manuscript to see editable JSON sections.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))),
      ],
    );
  }

  Widget _buildMarkdownPreview(ResearchProject project) {
    return Container(
      decoration: BoxDecoration(
        color: OhadaTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(32),
      child: MarkdownBody(
        data: project.finalManuscript,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          h1: const TextStyle(color: OhadaTheme.accent, fontWeight: FontWeight.bold),
          h2: const TextStyle(color: OhadaTheme.accent, fontWeight: FontWeight.bold),
          p: const TextStyle(height: 1.6, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildEditableSection(ChatState state, String key, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: OhadaTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: ExpansionTile(
        title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: TextEditingController(text: value),
              maxLines: null,
              style: const TextStyle(fontSize: 13, height: 1.5, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.black26,
              ),
              onChanged: (val) => state.updateManuscriptSection(key, val),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageSection(String title, String content, {bool isReadOnly = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: OhadaTheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: Colors.black26,
            child: content.isEmpty 
              ? const Text('Empty.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 11))
              : MarkdownBody(data: content, styleSheet: MarkdownStyleSheet(p: const TextStyle(fontSize: 11, color: Colors.grey))),
          ),
        ],
      ),
    );
  }
}
