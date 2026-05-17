import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models.dart';
import '../../../state/chat_state.dart';
import '../../../theme.dart';

class AgentChatTab extends StatefulWidget {
  final int agentIndex;
  final String instruction;
  final bool isWriter;

  const AgentChatTab({
    super.key, 
    required this.agentIndex, 
    required this.instruction,
    this.isWriter = false,
  });

  @override
  State<AgentChatTab> createState() => _AgentChatTabState();
}

class _AgentChatTabState extends State<AgentChatTab> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _reviewerSettingsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = context.read<ChatState>();
    if (widget.agentIndex == 5 && state.currentProject != null) {
      _reviewerSettingsController.text = state.currentProject!.reviewerInstructions;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _reviewerSettingsController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = context.read<ChatState>();

    return Column(
      children: [
        if (widget.agentIndex == 5)
          _buildReviewerSettings(state, isDark),
        Expanded(
          child: Selector<ChatState, List<ChatMessage>>(
            selector: (_, s) => s.getResearchAgentChat(widget.agentIndex),
            builder: (context, messages, _) {
              if (messages.isEmpty) {
                return Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('AGENT READY', style: TextStyle(fontWeight: FontWeight.w900, color: OhadaTheme.accent, letterSpacing: 2)),
                          const SizedBox(height: 8),
                          Text(widget.instruction, 
                            textAlign: TextAlign.center, 
                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return RepaintBoundary(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isUser = msg.role == 'user';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          if (!isUser) ...[
                            const CircleAvatar(radius: 14, backgroundColor: OhadaTheme.primary, child: Icon(Icons.smart_toy, size: 14, color: OhadaTheme.accent)),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isUser ? OhadaTheme.primary : Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isUser ? Colors.transparent : Colors.white10),
                                boxShadow: [
                                  BoxShadow(color: OhadaTheme.accent.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MarkdownBody(
                                    data: msg.content,
                                    selectable: true,
                                    builders: {
                                      'code': CodeElementBuilder(),
                                    },
                                    sizedImageBuilder: (config) {
                                      final uri = config.uri;
                                      if (uri.toString().startsWith('(')) {
                                        final b64 = uri.toString().substring(1, uri.toString().length - 1);
                                        return _buildBase64Image(b64);
                                      }
                                      if (uri.toString().length > 100) {
                                        return _buildBase64Image(uri.toString());
                                      }
                                      return Image.network(uri.toString());
                                    },
                                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                      p: TextStyle(color: isUser ? Colors.white : null, fontSize: 13, height: 1.5),
                                      code: const TextStyle(backgroundColor: Colors.transparent),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isUser) ...[
                                        _ActionButton(
                                          icon: Icons.copy,
                                          label: 'Copy',
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: msg.content));
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        if (widget.isWriter || widget.agentIndex == 4)
                                          _ActionButton(
                                            icon: Icons.sync,
                                            label: 'Sync Editor',
                                            onPressed: () => state.copyToEditor(msg.content),
                                          ),
                                        if (widget.agentIndex == 5)
                                          _ActionButton(
                                            icon: Icons.auto_fix_high,
                                            label: 'Refine Manuscript',
                                            onPressed: () => state.runReviewRefinement(),
                                          ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isUser) ...[
                            const SizedBox(width: 8),
                            const CircleAvatar(radius: 14, backgroundColor: OhadaTheme.accent, child: Icon(Icons.person, size: 14, color: OhadaTheme.primary)),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        Selector<ChatState, (bool, int)>(
          selector: (_, s) => (s.isLoading, s.researchTabIndex),
          builder: (context, data, _) {
            final (isLoading, researchTabIndex) = data;
            if (isLoading && researchTabIndex == widget.agentIndex) {
              return const LinearProgressIndicator(color: OhadaTheme.accent, minHeight: 2);
            }
            return const SizedBox(height: 2);
          },
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            children: [
              IconButton(onPressed: () => state.clearAgentChat(widget.agentIndex), icon: const Icon(Icons.refresh, color: Colors.grey)),
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Ask the agent...',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (val) {
                    if (val.isNotEmpty) {
                      state.sendResearchMessage(widget.agentIndex, val, widget.instruction);
                      _controller.clear();
                      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
                    }
                  },
                ),
              ),
              IconButton(
                onPressed: () {
                  if (_controller.text.isNotEmpty) {
                    state.sendResearchMessage(widget.agentIndex, _controller.text, widget.instruction);
                    _controller.clear();
                    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
                  }
                },
                icon: const Icon(Icons.send, color: OhadaTheme.accent),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBase64Image(String base64String) {
    try {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            base64Decode(base64String),
            fit: BoxFit.contain,
          ),
        ),
      );
    } catch (e) {
      return const Text('[Invalid Image Data]', style: TextStyle(color: Colors.redAccent));
    }
  }

  Widget _buildReviewerSettings(ChatState state, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? OhadaTheme.surface.withValues(alpha: 0.5) : Colors.white,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.rule, size: 16, color: OhadaTheme.accent),
              SizedBox(width: 8),
              Text('REVIEWER DIRECTIVES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reviewerSettingsController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'e.g. Ensure manuscript has Title, Abstract... check for APA citations.',
              hintStyle: const TextStyle(fontSize: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: const TextStyle(fontSize: 12),
            onChanged: (val) => state.updateResearchSettings(reviewerInstructions: val),
          ),
        ],
      ),
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
      icon: Icon(icon, size: 14, color: OhadaTheme.accent),
      label: Text(label, style: const TextStyle(color: OhadaTheme.accent, fontSize: 11, fontWeight: FontWeight.bold)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: OhadaTheme.accent.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    var language = '';

    if (element.attributes['class'] != null) {
      String lg = element.attributes['class'] as String;
      if (lg.startsWith('language-')) {
        language = lg.substring(9);
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xff282c34),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: HighlightView(
        element.textContent,
        language: language.isEmpty ? 'python' : language,
        theme: atomOneDarkTheme,
        padding: const EdgeInsets.all(12),
        textStyle: GoogleFonts.firaCode(fontSize: 12),
      ),
    );
  }
}
