enum PipelineStage { 
  resultsCheck, 
  literature, 
  methodology, 
  dataAnalysis, 
  writer, 
  reviewer 
}

enum StageStatus { 
  pending, 
  running, 
  done, 
  error, 
  skipped 
}

extension PipelineStageExtension on PipelineStage {
  String get name {
    switch (this) {
      case PipelineStage.resultsCheck: return 'Results Check';
      case PipelineStage.literature: return 'Literature Review';
      case PipelineStage.methodology: return 'Methodology';
      case PipelineStage.dataAnalysis: return 'Data Analysis';
      case PipelineStage.writer: return 'Manuscript Drafting';
      case PipelineStage.reviewer: return 'Final Review';
    }
  }
}

class PipelineProgress {
  PipelineStage currentStage;
  final Map<PipelineStage, StageStatus> stages;
  final Map<PipelineStage, Duration> elapsed;
  final Map<PipelineStage, int> charCount;
  final Map<PipelineStage, String?> errorMsg;
  final DateTime startedAt;
  int currentRetry;
  final int maxRetries;
  int estimatedTokensUsed;

  PipelineProgress({
    this.currentStage = PipelineStage.resultsCheck,
    required this.startedAt,
    this.currentRetry = 0,
    this.maxRetries = 3,
    this.estimatedTokensUsed = 0,
  }) : stages = { for (var s in PipelineStage.values) s: StageStatus.pending },
       elapsed = { for (var s in PipelineStage.values) s: Duration.zero },
       charCount = { for (var s in PipelineStage.values) s: 0 },
       errorMsg = { for (var s in PipelineStage.values) s: null };

  double get totalProgress {
    int done = stages.values.where((s) => s == StageStatus.done).length;
    return done / PipelineStage.values.length;
  }
}
