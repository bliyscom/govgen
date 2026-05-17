import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/chat_state.dart';
import '../../theme.dart';
import '../document_editor.dart';
import 'tabs/data_explorer_tab.dart';
import 'tabs/project_explorer_tab.dart';
import 'tabs/output_tab.dart';

class ResearchTool extends StatefulWidget {
  const ResearchTool({super.key});

  @override
  State<ResearchTool> createState() => _ResearchToolState();
}

class _ResearchToolState extends State<ResearchTool> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final state = context.read<ChatState>();
    _tabController = TabController(length: 3, vsync: this, initialIndex: state.researchTabIndex);
    
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (state.researchTabIndex != _tabController.index) {
           state.setResearchTabIndex(_tabController.index); 
        }
      }
    });

    // IMPORTANT: Listen to state changes to handle programmatic tab switches (e.g. project selection)
    state.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    final state = context.read<ChatState>();
    if (mounted && !_tabController.indexIsChanging && _tabController.index != state.researchTabIndex) {
      // ONLY sync if the tab is stable and the model has a truly different index
      _tabController.animateTo(state.researchTabIndex);
    }
  }

  @override
  void dispose() {
    context.read<ChatState>().removeListener(_onStateChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<ChatState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? OhadaTheme.surface : OhadaTheme.lightSurface,
      appBar: AppBar(
        title: const Text('RESEARCH SUITE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: OhadaTheme.accent,
            labelColor: OhadaTheme.accent,
            unselectedLabelColor: Colors.grey,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: [
              _buildTab(0, 'Explorer', Icons.explore),
              _buildTab(1, 'Repository', Icons.inventory_2),
              _buildTab(2, 'Output', Icons.workspaces_filled),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => state.closeResearchHub(),
            tooltip: 'Close Research Hub',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // Prevent accidental swipes
        children: [
          const ProjectExplorerTab(),
          const DataExplorerTab(),
          const OutputTab(),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label, IconData icon, {bool isAgent = false}) {
    return Selector<ChatState, bool>(
      selector: (_, s) => s.isResearchRunning && s.researchTabIndex == index && isAgent,
      builder: (context, isProcessing, _) {
        return Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label),
              if (isProcessing) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: OhadaTheme.accent),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
