import 'dart:math';

import 'inference_result.dart';

/// 2D point projected from a high-dimensional embedding.
class ProjectedPoint {
  final int index;
  final double x;
  final double y;
  final InferenceResult item;

  const ProjectedPoint({
    required this.index,
    required this.x,
    required this.y,
    required this.item,
  });
}

/// Projects embedding vectors to 2D using PCA (power iteration on covariance).
List<ProjectedPoint> projectEmbeddingsTo2D(List<InferenceResult> items) {
  final valid = <int, List<double>>{};
  for (var i = 0; i < items.length; i++) {
    if (items[i].embedding.isNotEmpty) valid[i] = items[i].embedding;
  }
  if (valid.isEmpty) return [];
  if (valid.length == 1) {
    final entry = valid.entries.first;
    return [
      ProjectedPoint(
        index: entry.key,
        x: 0,
        y: 0,
        item: items[entry.key],
      ),
    ];
  }

  final dim = valid.values.first.length;
  final indices = valid.keys.toList();
  final matrix = indices.map((i) => valid[i]!).toList();

  final mean = List<double>.filled(dim, 0);
  for (final row in matrix) {
    for (var d = 0; d < dim; d++) {
      mean[d] += row[d];
    }
  }
  for (var d = 0; d < dim; d++) {
    mean[d] /= matrix.length;
  }

  final centered = matrix
      .map((row) => List<double>.generate(dim, (d) => row[d] - mean[d]))
      .toList();

  final pc1 = _powerIterationComponent(centered, dim);
  final pc2 = _powerIterationComponent(
    _deflate(centered, pc1),
    dim,
    exclude: pc1,
  );

  final points = <ProjectedPoint>[];
  for (var r = 0; r < centered.length; r++) {
    final row = centered[r];
    var x = 0.0;
    var y = 0.0;
    for (var d = 0; d < dim; d++) {
      x += row[d] * pc1[d];
      y += row[d] * pc2[d];
    }
    points.add(
      ProjectedPoint(
        index: indices[r],
        x: x,
        y: y,
        item: items[indices[r]],
      ),
    );
  }

  return _normalizeSpread(points);
}

List<double> _powerIterationComponent(
  List<List<double>> data,
  int dim, {
  List<double>? exclude,
  int iterations = 40,
}) {
  final rand = Random(42);
  var v = List<double>.generate(dim, (_) => rand.nextDouble() - 0.5);
  if (exclude != null) {
    for (var d = 0; d < dim; d++) {
      v[d] -= exclude[d] * _dot(v, exclude);
    }
  }
  _normalize(v);

  for (var iter = 0; iter < iterations; iter++) {
    final next = List<double>.filled(dim, 0);
    for (final row in data) {
      final proj = _dot(row, v);
      for (var d = 0; d < dim; d++) {
        next[d] += proj * row[d];
      }
    }
    if (exclude != null) {
      for (var d = 0; d < dim; d++) {
        next[d] -= exclude[d] * _dot(next, exclude);
      }
    }
    _normalize(next);
    v = next;
  }
  return v;
}

List<List<double>> _deflate(List<List<double>> data, List<double> component) {
  return data
      .map((row) {
        final proj = _dot(row, component);
        return List<double>.generate(
          row.length,
          (d) => row[d] - proj * component[d],
        );
      })
      .toList();
}

double _dot(List<double> a, List<double> b) {
  var sum = 0.0;
  final len = min(a.length, b.length);
  for (var i = 0; i < len; i++) {
    sum += a[i] * b[i];
  }
  return sum;
}

void _normalize(List<double> v) {
  var norm = 0.0;
  for (final x in v) {
    norm += x * x;
  }
  norm = sqrt(norm);
  if (norm > 0) {
    for (var i = 0; i < v.length; i++) {
      v[i] /= norm;
    }
  }
}

List<ProjectedPoint> _normalizeSpread(List<ProjectedPoint> points) {
  if (points.length < 2) return points;

  var minX = points.first.x;
  var maxX = points.first.x;
  var minY = points.first.y;
  var maxY = points.first.y;
  for (final p in points) {
    if (p.x < minX) minX = p.x;
    if (p.x > maxX) maxX = p.x;
    if (p.y < minY) minY = p.y;
    if (p.y > maxY) maxY = p.y;
  }

  final rangeX = (maxX - minX).abs().clamp(0.001, double.infinity);
  final rangeY = (maxY - minY).abs().clamp(0.001, double.infinity);

  return points
      .map(
        (p) => ProjectedPoint(
          index: p.index,
          x: (p.x - minX) / rangeX * 2 - 1,
          y: (p.y - minY) / rangeY * 2 - 1,
          item: p.item,
        ),
      )
      .toList();
}
