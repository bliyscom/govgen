import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../state/chat_state.dart';
import '../theme.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const WelcomeView();
  }
}

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChatState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const GovGenLogo(size: 140),
            const SizedBox(height: 28),
            const Text(
              'Welcome to GovGen', 
              style: TextStyle(
                fontWeight: FontWeight.w900, 
                fontSize: 36, 
                letterSpacing: 0.5,
                color: OhadaTheme.accent,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your multi-domain autonomous intelligence and research orchestrator.', 
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 48),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: [
                _buildFeatureCard(
                  context,
                  icon: Icons.hub_outlined,
                  title: "Research Hub",
                  description: "Complete academic manuscripts, policy drafts, whitepapers, and NGO reports with context-chained sequential writing agents.",
                  badge: "ACTIVE SUITE",
                  badgeColor: OhadaTheme.accent,
                  onTap: () => state.openResearchHub(),
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.shield_outlined,
                  title: "Cybersecurity Probing",
                  description: "Autonomous penetration testing agent. Simulates defensive assessments, scanning, and system profiling inside safe boundaries.",
                  badge: "GRAND FEATURE • COMING SOON",
                  badgeColor: Colors.blueAccent,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.shield_outlined, color: OhadaTheme.accent),
                            SizedBox(width: 12),
                            Text("Cybersecurity Probing suite is currently undergoing validation checks."),
                          ],
                        ),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: isDark ? OhadaTheme.surface : OhadaTheme.lightSurface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 340,
      height: 200,
      decoration: BoxDecoration(
        color: isDark 
            ? OhadaTheme.surface.withValues(alpha: 0.7) 
            : OhadaTheme.lightSurface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: OhadaTheme.accent.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          hoverColor: OhadaTheme.accent.withValues(alpha: 0.05),
          splashColor: OhadaTheme.accent.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: OhadaTheme.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: OhadaTheme.accent, size: 24),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 1),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
