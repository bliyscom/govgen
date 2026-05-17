import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:provider/provider.dart';

import '../state/chat_state.dart';
import '../theme.dart';

class DocumentEditor extends StatelessWidget {
  const DocumentEditor({super.key});

  @override
  Widget build(BuildContext context) {
    // Only rebuild if the project ID switches. 
    // This prevents the extremely heavy QuillEditor from entirely rebuilding when other ChatState properties change.
    final projectId = context.select<ChatState, String?>((s) => s.currentProject?.id);
    if (projectId == null) {
      return const Center(child: Text("Select a project to start editing."));
    }

    // Read the controller once. It handles its own internal state.
    final controller = context.read<ChatState>().getEditorController(projectId);

    return Column(
      children: [
        QuillSimpleToolbar(
          controller: controller,
          config: const QuillSimpleToolbarConfig(),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QuillEditor.basic(
              controller: controller,
              config: QuillEditorConfig(
                autoFocus: true,
                expands: false,
                padding: EdgeInsets.zero,
                embedBuilders: [
                  FormulaEmbedBuilder(),
                ],
              ),
            ),
          ),
        ),
        _EditorStatusBar(controller: controller),
      ],
    );
  }
}

class _EditorStatusBar extends StatelessWidget {
  final QuillController controller;
  const _EditorStatusBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    // Watch specific flags here, leaving Quill isolated
    final isLoading = context.select<ChatState, bool>((s) => s.isLoading);
    final state = context.read<ChatState>();

    // Need a ListenableBuilder to watch the Quill controller for word count updates independently
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final text = controller.document.toPlainText();
        final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        final chars = text.length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            children: [
              _Stat(label: 'WORDS', value: words.toString()),
              const SizedBox(width: 24),
              _Stat(label: 'CHARS', value: chars.toString()),
              const Spacer(),
              if (isLoading)
                 const Row(
                    children: [
                       SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: OhadaTheme.accent)),
                       SizedBox(width: 8),
                       Text('SYNCING...', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: OhadaTheme.accent)),
                    ],
                 )
              else
                 const Text('ALL CHANGES SAVED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(width: 16),
              _ActionButton(
                icon: Icons.picture_as_pdf,
                label: 'PDF',
                onPressed: () => state.exportManuscriptToPdf(),
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.code,
                label: 'MD',
                onPressed: () => state.exportManuscriptToMarkdown(),
              ),
            ],
          ),
        );
      }
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: OhadaTheme.accent)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _ActionButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      style: TextButton.styleFrom(
        backgroundColor: OhadaTheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}

class FormulaEmbedBuilder extends EmbedBuilder {
  @override
  String get key => 'formula';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final formulaText = embedContext.node.value.data;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF5F5FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
          ),
          child: Math.tex(
            formulaText,
            textStyle: TextStyle(
              fontSize: 18,
              color: isDark ? Colors.white : Colors.black87,
            ),
            mathStyle: MathStyle.display,
          ),
        ),
      ),
    );
  }
}
