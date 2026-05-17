import 'dart:async';
import 'package:flutter/material.dart';
import '../state/pipeline_progress.dart';
import '../theme.dart';

class PipelineStepper extends StatelessWidget {
  final PipelineProgress progress;
  final VoidCallback? onCancel;

  const PipelineStepper({
    super.key, 
    required this.progress,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: OhadaTheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OhadaTheme.accent.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub, color: OhadaTheme.accent, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('AUTONOMOUS PIPELINE ACTIVE', 
                  style: TextStyle(fontWeight: FontWeight.w900, color: OhadaTheme.accent, letterSpacing: 2, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onCancel != null) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel, size: 16, color: Colors.redAccent),
                  label: const Text('Cancel', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          ...PipelineStage.values.map((stage) => _buildStep(context, stage)),
          const SizedBox(height: 16),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context, PipelineStage stage) {
    final status = progress.stages[stage] ?? StageStatus.pending;
    final isCurrent = progress.currentStage == stage && status == StageStatus.running;
    final isDone = status == StageStatus.done;
    final isError = status == StageStatus.error;
    
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIndicator(stage, status, isCurrent),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(stage.name, 
                        style: TextStyle(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent ? Colors.white : (isDone ? Colors.white70 : Colors.grey),
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isDone) 
                      Text('${progress.charCount[stage]} chars', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    if (isCurrent)
                      _LiveTimer(startedAt: progress.startedAt),
                  ],
                ),
                if (isError)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(progress.errorMsg[stage] ?? 'Unknown error', 
                      style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                  ),
                if (stage != PipelineStage.values.last)
                  const SizedBox(height: 24), // Spacing for the line
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(PipelineStage stage, StageStatus status, bool isCurrent) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getIndicatorColor(status),
            border: isCurrent ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: _getIndicatorContent(status, isCurrent),
        ),
        if (stage != PipelineStage.values.last)
          Expanded(
            child: Container(
              width: 2,
              color: status == StageStatus.done ? Colors.greenAccent.withValues(alpha: 0.5) : Colors.white12,
            ),
          ),
      ],
    );
  }

  Color _getIndicatorColor(StageStatus status) {
    switch (status) {
      case StageStatus.done: return Colors.greenAccent.withValues(alpha: 0.2);
      case StageStatus.running: return OhadaTheme.accent;
      case StageStatus.error: return Colors.redAccent;
      default: return Colors.white10;
    }
  }

  Widget _getIndicatorContent(StageStatus status, bool isCurrent) {
    if (isCurrent) return const _RotatingPulse();
    switch (status) {
      case StageStatus.done: return const Icon(Icons.check, size: 14, color: Colors.greenAccent);
      case StageStatus.error: return const Icon(Icons.close, size: 14, color: Colors.redAccent);
      default: return const SizedBox();
    }
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text('Tokens: ${progress.estimatedTokensUsed}', 
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text('Progress: ${(progress.totalProgress * 100).toInt()}%', 
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: OhadaTheme.accent)),
        ],
      ),
    );
  }
}

class _RotatingPulse extends StatefulWidget {
  const _RotatingPulse();
  @override
  State<_RotatingPulse> createState() => _RotatingPulseState();
}

class _RotatingPulseState extends State<_RotatingPulse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: const Icon(Icons.sync, size: 14, color: Colors.white),
    );
  }
}

class _LiveTimer extends StatefulWidget {
  final DateTime startedAt;
  const _LiveTimer({required this.startedAt});
  @override
  State<_LiveTimer> createState() => _LiveTimerState();
}

class _LiveTimerState extends State<_LiveTimer> {
  late Timer _timer;
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.startedAt);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(widget.startedAt);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${_elapsed.inMinutes}:${(_elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
      style: const TextStyle(fontSize: 10, color: OhadaTheme.accent, fontWeight: FontWeight.bold),
    );
  }
}
