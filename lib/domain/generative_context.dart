import 'dart:math';

import 'inference_result.dart';
import 'isolate_message.dart';

/// Immutable snapshot of ML state passed into generative primitive builders.
class GenerativeContext {
  final InferenceResult? activeResult;
  final List<InferenceResult> history;
  final Map<int, double> similarities;
  final double? inferenceTimeMs;
  final PipelineStage? pipelineStage;
  final int? compareTargetIndex;
  final void Function(InferenceResult)? onSelectResult;
  final String? pipelineDetail;
  final List<String>? pipelineTokens;
  final double? pipelineL2Norm;
  final bool isProcessing;

  const GenerativeContext({
    this.activeResult,
    this.history = const [],
    this.similarities = const {},
    this.inferenceTimeMs,
    this.pipelineStage,
    this.compareTargetIndex,
    this.onSelectResult,
    this.pipelineDetail,
    this.pipelineTokens,
    this.pipelineL2Norm,
    this.isProcessing = false,
  });

  /// Best cosine similarity to a history item other than [activeResult].
  double? get bestNonSelfSimilarity {
    final active = activeResult;
    if (active == null || history.length < 2) return null;

    double? best;
    for (final item in history) {
      if (identical(item, active) || item.embedding.isEmpty) continue;
      final sim = similarities[identityHashCode(item)];
      if (sim == null) continue;
      if (best == null || sim > best) best = sim;
    }
    return best;
  }

  InferenceResult? get compareTarget {
    if (compareTargetIndex == null ||
        compareTargetIndex! < 0 ||
        compareTargetIndex! >= history.length) {
      return null;
    }
    return history[compareTargetIndex!];
  }

  List<double>? get activeEmbedding =>
      activeResult?.embedding.isNotEmpty == true ? activeResult!.embedding : null;

  List<double>? get compareEmbedding {
    final target = compareTarget;
    if (target != null && target.embedding.isNotEmpty) {
      return target.embedding;
    }
    final active = activeResult;
    if (active == null || history.length < 2) return null;
    final other = history.firstWhere(
      (h) => !identical(h, active) && h.embedding.isNotEmpty,
      orElse: () => active,
    );
    return identical(other, active) ? null : other.embedding;
  }

  double? get activeL2Norm {
    final emb = activeEmbedding;
    if (emb == null || emb.isEmpty) return null;
    var sumSq = 0.0;
    for (final v in emb) {
      sumSq += v * v;
    }
    return sumSq > 0 ? sqrt(sumSq) : 0.0;
  }

  int? get activeDim => activeEmbedding?.length;
}
