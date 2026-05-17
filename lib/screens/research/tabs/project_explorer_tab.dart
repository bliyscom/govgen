import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/chat_state.dart';
import '../../../theme.dart';
import '../../../models.dart';
// import '../../../widgets/pipeline_stepper.dart';

class ProjectExplorerTab extends StatefulWidget {
  const ProjectExplorerTab({super.key});

  @override
  State<ProjectExplorerTab> createState() => _ProjectExplorerTabState();
}

class _ProjectExplorerTabState extends State<ProjectExplorerTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = context.watch<ChatState>();
    final projects = state.allProjects;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RESEARCH HUB', 
                    style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 20, color: OhadaTheme.accent)),
                  Text('Manage your project portfolio', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showNewProjectDialog(context, state),
                icon: const Icon(Icons.add_chart, size: 20),
                label: const Text('NEW PROJECT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OhadaTheme.primary,
                  foregroundColor: OhadaTheme.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (projects.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_open, size: 64, color: Colors.white10),
                    SizedBox(height: 16),
                    Text('No research projects found.', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  mainAxisExtent: 220,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                ),
                itemCount: projects.length,
                itemBuilder: (context, index) {
                  final project = projects[index];
                  return _ProjectCard(project: project);
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showNewProjectDialog(BuildContext context, ChatState state) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: OhadaTheme.surface,
        title: const Text('Initialize Research Project', style: TextStyle(color: OhadaTheme.accent, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'e.g. Impact of AI on Public Policy',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                state.createNewProject(controller.text);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: OhadaTheme.accent, foregroundColor: OhadaTheme.primary),
            child: const Text('CREATE'),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final ResearchProject project;
  const _ProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChatState>();
    final isSelected = state.currentProject?.id == project.id;
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => state.selectProject(project),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected ? OhadaTheme.accent.withValues(alpha: 0.05) : OhadaTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? OhadaTheme.accent : Colors.white12,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected ? [
              BoxShadow(color: OhadaTheme.accent.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: -5)
            ] : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CompletionRing(project: project),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.title, 
                          maxLines: 2, 
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.2),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'ID: ${project.id}', 
                              style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace'),
                            ),
                            if (project.lastCompletedStage.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  project.lastCompletedStage,
                                  style: const TextStyle(fontSize: 8, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  _InfoChip(icon: Icons.description, label: '${project.files.length} Files'),
                  const SizedBox(width: 8),
                  _InfoChip(icon: Icons.style, label: project.citationStyle),
                  const SizedBox(width: 8),
                  _InfoChip(icon: Icons.toll, label: _formatTokens(project.totalTokensUsed)),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white10, height: 1),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getRelativeTime(project.id),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.play_circle_outline, size: 20, color: state.isSearchingLiterature ? Colors.grey : Colors.greenAccent),
                            onPressed: state.isSearchingLiterature ? null : () {
                              state.selectProject(project);
                              state.runAutonomousResearch(forceRestart: false);
                            },
                            tooltip: 'Resume Research',
                          ),
                          IconButton(
                            icon: Icon(Icons.restart_alt, size: 20, color: state.isSearchingLiterature ? Colors.grey : OhadaTheme.accent),
                            onPressed: state.isSearchingLiterature ? null : () {
                              state.selectProject(project);
                              state.runAutonomousResearch(forceRestart: true);
                            },
                            tooltip: 'Restart Full Pipeline',
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_all, size: 18, color: Colors.grey),
                            onPressed: () => state.duplicateProject(project),
                            tooltip: 'Duplicate',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            onPressed: () => _confirmDelete(context, state, project),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTokens(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  String _getRelativeTime(String id) {
    final timestamp = int.tryParse(id) ?? 0;
    if (timestamp == 0) return "Unknown";
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  void _confirmDelete(BuildContext context, ChatState state, ResearchProject project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: OhadaTheme.surface,
        title: const Text('Delete Project?', style: TextStyle(color: Colors.redAccent)),
        content: Text('This will permanently delete "${project.title}" and all its data.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              state.deleteProject(project.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
}

class _CompletionRing extends StatelessWidget {
  final ResearchProject project;
  const _CompletionRing({required this.project});

  @override
  Widget build(BuildContext context) {
    String s = project.lastCompletedStage;
    if (s.isEmpty) {
      if (project.finalManuscript.isNotEmpty) s = 'WRITER';
      else if (project.analysis.isNotEmpty) s = 'DATA_ANALYSIS';
      else if (project.methodology.isNotEmpty) s = 'METHODOLOGY';
      else if (project.litReview.isNotEmpty) s = 'LITERATURE';
    }

    final status = [
      s == 'LITERATURE' || s == 'METHODOLOGY' || s == 'DATA_ANALYSIS' || s == 'WRITER',
      s == 'METHODOLOGY' || s == 'DATA_ANALYSIS' || s == 'WRITER',
      s == 'DATA_ANALYSIS' || s == 'WRITER',
      s == 'WRITER',
    ];
    
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 50,
          height: 50,
          child: CustomPaint(
            painter: _RingPainter(status: status),
          ),
        ),
        Text(
          '${status.where((s) => s).length}/4',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: OhadaTheme.accent),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final List<bool> status;
  _RingPainter({required this.status});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const spacing = 0.2; // Small gap between arcs

    for (int i = 0; i < 4; i++) {
       paint.color = status[i] ? Colors.greenAccent : Colors.white10;
       canvas.drawArc(
         Rect.fromCircle(center: center, radius: radius),
         (i * 1.5708) + spacing, 
         1.5708 - (spacing * 2),
         false,
         paint
       );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: OhadaTheme.accent),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}
