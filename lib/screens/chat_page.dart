import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../state/chat_state.dart';
import '../theme.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChatState>();
    // Simple placeholder for main chat (since the focus is Research Hub)
    return Column(
      children: [
        const Expanded(child: WelcomeView()),
        _buildChatInput(state),
      ],
    );
  }

  Widget _buildChatInput(ChatState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: "Message GovGen...",
          suffixIcon: IconButton(icon: const Icon(Icons.send), onPressed: () {}),
        ),
      ),
    );
  }
}

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const GovGenLogo(size: 120),
          const SizedBox(height: 24),
          const Text('Welcome to GovGen', 
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 32, color: OhadaTheme.accent)),
          const Text('Your autonomous academic research partner.', 
            style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 48),
          Wrap(
            spacing: 16,
            children: [
              _buildFeatureCard(Icons.science, "Data Analysis"),
              _buildFeatureCard(Icons.menu_book, "Lit Review"),
              _buildFeatureCard(Icons.history_edu, "Manuscript Gen"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icon, color: OhadaTheme.accent, size: 28),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final String content;
  final bool isUser;
  const ChatBubble({super.key, required this.content, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        decoration: BoxDecoration(
          color: isUser ? OhadaTheme.primary : Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: MarkdownBody(data: content),
      ),
    );
  }
}
