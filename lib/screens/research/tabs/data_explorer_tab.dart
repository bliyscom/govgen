import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models.dart';
import '../../../state/chat_state.dart';
import '../../../theme.dart';
import '../../../widgets/pipeline_stepper.dart';

class DataExplorerTab extends StatefulWidget {
  const DataExplorerTab({super.key});

  @override
  State<DataExplorerTab> createState() => _DataExplorerTabState();
}

class _DataExplorerTabState extends State<DataExplorerTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = context.watch<ChatState>();
    final project = state.currentProject;

    if (project == null) {
      return const Center(child: Text("No project selected. Please select one from the Explorer."));
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, state),
            const SizedBox(height: 24),
            
            _buildMainDirective(state),
            const SizedBox(height: 24),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BuildResearchButton(state: state),
                      const SizedBox(height: 24),
                      if (state.isResearchRunning && state.pipelineProgress != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: PipelineStepper(
                            progress: state.pipelineProgress!,
                            onCancel: () => state.cancelPipeline(),
                          ),
                        ),
                      _buildRepositorySection(state),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: _buildProjectConfig(context, state),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainDirective(ChatState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: OhadaTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OhadaTheme.accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: OhadaTheme.accent, size: 18),
              SizedBox(width: 8),
              Text('RESEARCH DIRECTIVE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12, color: OhadaTheme.accent)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              labelText: 'Research Title',
              labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              hintText: 'Enter the main research objective...',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.03),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            controller: TextEditingController(text: state.researchTitle)..selection = TextSelection.fromPosition(TextPosition(offset: state.researchTitle.length)),
            onChanged: (val) => state.updateResearchSettings(title: val),
          ),
          const SizedBox(height: 16),
          TextField(
            maxLines: 4,
            minLines: 2,
            decoration: InputDecoration(
              labelText: 'Primary Research Instruction (The "First Prompt")',
              labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              hintText: 'e.g. Focus on deep learning applications in healthcare, prioritize 2024 sources...',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.03),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              alignLabelWithHint: true,
            ),
            style: const TextStyle(fontSize: 13, height: 1.5),
            controller: TextEditingController(text: state.initialDraft)..selection = TextSelection.fromPosition(TextPosition(offset: state.initialDraft.length)),
            onChanged: (val) => state.updateResearchSettings(draft: val),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectConfig(BuildContext context, ChatState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: OhadaTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings, color: Colors.grey, size: 16),
              SizedBox(width: 8),
              Text('CONFIGURATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.grey, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 20),
          
          _buildConfigItem(
            label: 'CITATION STYLE',
            child: DropdownButtonFormField<String>(
              initialValue: state.citationStyle,
              items: ['APA', 'MLA', 'IEEE', 'Harvard', 'Chicago'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (val) => state.updateResearchSettings(style: val),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.03),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          SwitchListTile(
            title: const Text('PROACTIVE AUTONOMY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            subtitle: const Text('Agent makes decisions without asking', style: TextStyle(fontSize: 9, color: Colors.grey)),
            value: state.isAutonomousProactive,
            onChanged: (val) => state.updateResearchSettings(isProactive: val),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: OhadaTheme.accent,
          ),
          
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'ACTIVE PIPELINE MODEL',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: OhadaTheme.accent, letterSpacing: 1),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _showManageModelsDialog(context, state),
                icon: const Icon(Icons.settings_suggest, size: 14),
                label: const Text('MANAGE MODELS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  foregroundColor: OhadaTheme.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          _buildUnifiedModelSelector(state),
        ],
      ),
    );
  }

  Widget _buildConfigItem({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildRepositorySection(ChatState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DOCUMENT REPOSITORY (${state.currentProject?.files.length ?? 0})', 
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 11, color: OhadaTheme.accent)),
        const SizedBox(height: 16),
        DefaultTabController(
          length: 3,
          child: Container(
            height: 500,
            decoration: BoxDecoration(
              color: OhadaTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                TabBar(
                  indicatorColor: OhadaTheme.accent,
                  labelColor: OhadaTheme.accent,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                  tabs: const [
                    Tab(text: 'LITERATURE'),
                    Tab(text: 'RESULTS'),
                    Tab(text: 'DATA'),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TabBarView(
                      children: [
                        _buildFileList(state, FileCategory.literature),
                        _buildFileList(state, FileCategory.results),
                        _buildFileList(state, FileCategory.data),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileList(ChatState state, FileCategory category) {
    final files = state.currentProject?.files.where((f) => f.category == category).toList() ?? [];
    
    return Column(
      children: [
        if (category == FileCategory.literature)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withValues(alpha: 0.03),
            ),
            child: Row(
              children: [
                const Icon(Icons.travel_explore, size: 16, color: OhadaTheme.accent),
                const SizedBox(width: 8),
                const Expanded(child: Text("Extended Literature Search", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                _buildSmallDropdown<int>(
                  initialValue: state.semanticLimit,
                  items: [3, 5, 10, 20, 50],
                  label: (v) => "Top $v",
                  onChanged: (v) => v != null ? state.setSemanticLimit(v) : null,
                ),
                const SizedBox(width: 8),
                _buildSmallDropdown<int>(
                  initialValue: state.semanticMinYear,
                  items: List.generate(DateTime.now().year - 1990 + 1, (i) => DateTime.now().year - i),
                  label: (v) => "Since $v",
                  onChanged: (v) => v != null ? state.setSemanticMinYear(v) : null,
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: state.isSearchingLiterature ? null : () => state.runExtendedLiteratureSearch(),
                  icon: state.isSearchingLiterature 
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome, size: 14),
                  label: Text(state.isSearchingLiterature ? 'SEARCHING...' : 'DISCOVER PAPERS', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OhadaTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => state.pickResearchFiles(category: category),
            icon: const Icon(Icons.add_circle_outline, size: 14),
            label: Text('ATTACH ${category.name.toUpperCase()}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: OhadaTheme.accent.withValues(alpha: 0.3)),
              foregroundColor: OhadaTheme.accent,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: state.isAttachingDocument 
            ? const Center(child: CircularProgressIndicator(color: OhadaTheme.accent))
            : files.isEmpty
                ? const Center(child: Text('No files attached', style: TextStyle(color: Colors.grey, fontSize: 11)))
                : ListView.builder(
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final file = files[index];
                      return Card(
                        color: Colors.white.withValues(alpha: 0.02),
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        child: ListTile(
                          dense: true,
                          title: Text(file.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          subtitle: Text('${file.charCount} chars', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.visibility_outlined, size: 14), onPressed: () => _showFilePreviewDialog(context, file)),
                              IconButton(icon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent), onPressed: () => state.removeResearchFile(state.currentProject!.files.indexOf(file))),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildSmallDropdown<T>({required T initialValue, required List<T> items, required String Function(T) label, required ValueChanged<T?> onChanged}) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: initialValue,
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(label(i), style: const TextStyle(fontSize: 10)))).toList(),
        onChanged: onChanged,
        style: const TextStyle(fontSize: 10, color: OhadaTheme.accent),
        dropdownColor: OhadaTheme.background,
        iconSize: 16,
      ),
    );
  }

  void _showFilePreviewDialog(BuildContext context, ResearchFile file) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: OhadaTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 600, height: 500, padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(file.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: OhadaTheme.accent), overflow: TextOverflow.ellipsis)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(color: Colors.white10),
              Expanded(child: SingleChildScrollView(child: Text(file.content, style: const TextStyle(fontSize: 12, height: 1.5)))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ChatState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.currentProject?.title ?? 'NO PROJECT',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1),
                overflow: TextOverflow.ellipsis,
              ),
              const Text('RESEARCH REPOSITORY & PIPELINE CONTROL', style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1.5)),
            ],
          ),
        ),
        if (state.researchFiles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: TextButton.icon(
              onPressed: () => state.clearResearchFiles(),
              icon: const Icon(Icons.delete_sweep, size: 16, color: Colors.redAccent),
              label: const Text('CLEAR ALL FILES', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  void _showManageModelsDialog(BuildContext context, ChatState state) {
    final modelController = TextEditingController();
    final keyController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: OhadaTheme.surface,
          title: const Text("Manage Cloud Models", style: TextStyle(color: OhadaTheme.accent, fontSize: 16)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.cloudModels.isNotEmpty) ...[
                  const Text("CURRENT CLOUD MODELS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(border: Border.all(color: Colors.white10), borderRadius: BorderRadius.circular(8)),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: state.cloudModels.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
                      itemBuilder: (context, index) {
                        final m = state.cloudModels[index];
                        return ListTile(
                          dense: true,
                          title: Text(m, style: const TextStyle(fontSize: 12)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                            onPressed: () {
                              state.removeCustomModel(m);
                              setDialogState(() {}); // Refresh dialog list
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                const Text("ADD NEW CLOUD MODEL", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                const SizedBox(height: 12),
                TextField(
                  controller: modelController,
                  decoration: const InputDecoration(
                    labelText: "Model String",
                    hintText: "provider:model/name",
                    labelStyle: TextStyle(fontSize: 11),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "API Key (Optional)",
                    hintText: "Enter key for this provider",
                    labelStyle: TextStyle(fontSize: 11),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Done")),
            ElevatedButton(
              onPressed: () {
                if (modelController.text.isNotEmpty) {
                  state.addCustomModel(modelController.text, keyController.text);
                  setDialogState(() {});
                  modelController.clear();
                  keyController.clear();
                }
              },
              child: const Text("Add & Select"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedModelSelector(ChatState state) {
    return DropdownButtonFormField<String?>(
      initialValue: state.selectedModel,
      isExpanded: true,
      onChanged: (val) => val != null ? state.setSelectedModel(val) : null,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.03),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
      hint: const Text("Select Research Model", style: TextStyle(fontSize: 11, color: Colors.grey)),
      items: [
        if (state.models.isEmpty)
          const DropdownMenuItem<String?>(value: null, child: Text("No models available", style: TextStyle(fontSize: 11, color: Colors.grey)))
        else
          ...state.models.map((m) {
            final isLocal = state.localModels.contains(m);
            return DropdownMenuItem<String?>(
              value: m,
              child: Row(
                children: [
                  Icon(isLocal ? Icons.computer : Icons.cloud_outlined, size: 12, color: isLocal ? Colors.blueGrey : OhadaTheme.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      m.contains(':') ? m.replaceFirst(':', ' → ') : m,
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isLocal) 
                    const Icon(Icons.api_outlined, size: 10, color: Colors.grey),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _BuildResearchButton extends StatelessWidget {
  final ChatState state;
  const _BuildResearchButton({required this.state});

  @override
  Widget build(BuildContext context) {
    final project = state.currentProject;
    if (project == null) return const SizedBox.shrink();

    final isDone = project.lastCompletedStage == 'WRITER' || project.finalManuscript.isNotEmpty;
    final isRunning = state.isResearchRunning;
    
    // Determine if this is a fresh project (no work started yet)
    final isFresh = project.lastCompletedStage.isEmpty && 
                    project.litReview.isEmpty && 
                    project.methodology.isEmpty && 
                    project.analysis.isEmpty;

    if (isFresh) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: (isRunning || state.isSearchingLiterature) ? null : () => state.runAutonomousResearch(forceRestart: false),
          icon: const Icon(Icons.auto_awesome, size: 20),
          label: const Text('START RESEARCH PIPELINE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          style: ElevatedButton.styleFrom(
            backgroundColor: OhadaTheme.accent, foregroundColor: OhadaTheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: (isRunning || isDone || state.isSearchingLiterature) ? null : () => state.runAutonomousResearch(forceRestart: false),
            icon: const Icon(Icons.play_arrow, size: 20),
            label: const Text('RESUME PIPELINE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            style: ElevatedButton.styleFrom(
              backgroundColor: OhadaTheme.accent, foregroundColor: OhadaTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 22),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: (isRunning || state.isSearchingLiterature) ? null : () => state.runAutonomousResearch(forceRestart: true),
            icon: Icon(isDone ? Icons.check_circle : Icons.restart_alt, size: 18),
            label: Text(isDone ? 'RE-RUN' : 'RESTART', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDone ? Colors.greenAccent : OhadaTheme.accent,
              side: BorderSide(color: isDone ? Colors.greenAccent : OhadaTheme.accent.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 22),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}
