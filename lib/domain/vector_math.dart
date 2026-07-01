import 'dart:math';

import 'inference_result.dart';

/// Cosine similarity between two L2-normalized embedding vectors (dot product).
double cosineSimilarity(List<double> a, List<double> b) {
  final len = min(a.length, b.length);
  if (len == 0) return 0.0;

  var dot = 0.0;
  for (var i = 0; i < len; i++) {
    dot += a[i] * b[i];
  }
  return dot;
}

class EmbeddingStats {
  final double l2Norm;
  final double mean;
  final double min;
  final double max;
  final double stdDev;

  const EmbeddingStats({
    required this.l2Norm,
    required this.mean,
    required this.min,
    required this.max,
    required this.stdDev,
  });

  factory EmbeddingStats.fromEmbedding(List<double> embedding) {
    if (embedding.isEmpty) {
      return const EmbeddingStats(
        l2Norm: 0,
        mean: 0,
        min: 0,
        max: 0,
        stdDev: 0,
      );
    }

    var sum = 0.0;
    var sumSq = 0.0;
    var minVal = embedding.first;
    var maxVal = embedding.first;

    for (final value in embedding) {
      sum += value;
      sumSq += value * value;
      if (value < minVal) minVal = value;
      if (value > maxVal) maxVal = value;
    }

    final mean = sum / embedding.length;
    var variance = 0.0;
    for (final value in embedding) {
      final delta = value - mean;
      variance += delta * delta;
    }
    variance /= embedding.length;

    return EmbeddingStats(
      l2Norm: sqrt(sumSq),
      mean: mean,
      min: minVal,
      max: maxVal,
      stdDev: sqrt(variance),
    );
  }
}

double? similarityToActive(
  InferenceResult item,
  InferenceResult? active,
  Map<int, double> similarities,
) {
  if (active == null || item.embedding.isEmpty) return null;
  if (item == active) return 1.0;
  return similarities[identityHashCode(item)];
}
