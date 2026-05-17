import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/chat_state.dart';
import '../theme.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChatState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: isDark ? OhadaTheme.surface : OhadaTheme.lightSurface,
        border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: GovGenLogo(size: 80),
          ),
          const Text('GOVGEN', 
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 4, fontSize: 20, color: OhadaTheme.accent)),
          const Text('AUTONOMOUS RESEARCH', 
            style: TextStyle(fontSize: 9, letterSpacing: 1.5, color: Colors.grey)),
          const SizedBox(height: 32),
          
          ListTile(
            leading: const Icon(Icons.hub, color: OhadaTheme.accent),
            title: const Text('Research Hub', style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () => state.openResearchHub(),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.history, size: 14, color: Colors.grey),
                SizedBox(width: 8),
                Text('SESSIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 0, // Placeholder for chat sessions if implemented
              itemBuilder: (context, index) => const ListTile(title: Text("Coming Soon...")),
            ),
          ),
          const Divider(),
          _buildModelSelector(state),
        ],
      ),
    );
  }

  Widget _buildModelSelector(ChatState state) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('OLLAMA MODEL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: (state.selectedModel != null && state.models.contains(state.selectedModel)) ? state.selectedModel : null,
                isExpanded: true,
                dropdownColor: OhadaTheme.background,
                hint: const Text("Select Model", style: TextStyle(fontSize: 12, color: Colors.grey)),
                items: state.models.isEmpty 
                  ? [const DropdownMenuItem<String?>(value: null, child: Text("No models found", style: TextStyle(fontSize: 12, color: Colors.grey)))]
                  : state.models.map((m) => DropdownMenuItem<String?>(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (val) => val != null ? state.setSelectedModel(val) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
