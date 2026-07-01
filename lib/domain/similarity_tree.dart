import 'dart:math';

import 'inference_result.dart';
import 'vector_math.dart';

/// A node in a hierarchical clustering dendrogram built from embedding similarity.
class SimilarityTreeNode {
  final int? leafIndex;
  final double mergeHeight;
  final SimilarityTreeNode? left;
  final SimilarityTreeNode? right;

  const SimilarityTreeNode({
    required this.leafIndex,
    required this.mergeHeight,
    this.left,
    this.right,
  });

  bool get isLeaf => leafIndex != null;

  int get leafCount {
    if (isLeaf) return 1;
    return left!.leafCount + right!.leafCount;
  }
}

class _Cluster {
  final List<int> indices;
  final SimilarityTreeNode node;

  _Cluster({required this.indices, required this.node});
}

/// Builds an agglomerative clustering tree using average-linkage on cosine similarity.
SimilarityTreeNode buildSimilarityTree(List<InferenceResult> items) {
  if (items.isEmpty) {
    throw ArgumentError('Cannot build similarity tree from empty history.');
  }

  final validIndices = <int>[];
  for (var i = 0; i < items.length; i++) {
    if (items[i].embedding.isNotEmpty) validIndices.add(i);
  }

  if (validIndices.isEmpty) {
    return const SimilarityTreeNode(leafIndex: 0, mergeHeight: 0);
  }

  if (validIndices.length == 1) {
    return SimilarityTreeNode(leafIndex: validIndices.first, mergeHeight: 0);
  }

  final clusters = validIndices
      .map(
        (index) => _Cluster(
          indices: [index],
          node: SimilarityTreeNode(leafIndex: index, mergeHeight: 0),
        ),
      )
      .toList();

  while (clusters.length > 1) {
    var bestI = 0;
    var bestJ = 1;
    var bestSim = -2.0;

    for (var i = 0; i < clusters.length; i++) {
      for (var j = i + 1; j < clusters.length; j++) {
        final sim = _averageLinkage(clusters[i], clusters[j], items);
        if (sim > bestSim) {
          bestSim = sim;
          bestI = i;
          bestJ = j;
        }
      }
    }

    final a = clusters[bestI];
    final b = clusters[bestJ];
    final mergedIndices = [...a.indices, ...b.indices];
    final mergeHeight = (1.0 - bestSim).clamp(0.0, 2.0);

    final merged = _Cluster(
      indices: mergedIndices,
      node: SimilarityTreeNode(
        leafIndex: null,
        mergeHeight: mergeHeight,
        left: a.node,
        right: b.node,
      ),
    );

    clusters.removeAt(bestJ);
    clusters.removeAt(bestI);
    clusters.add(merged);
  }

  return clusters.first.node;
}

double _averageLinkage(_Cluster a, _Cluster b, List<InferenceResult> items) {
  var sum = 0.0;
  var count = 0;

  for (final i in a.indices) {
    for (final j in b.indices) {
      sum += cosineSimilarity(items[i].embedding, items[j].embedding);
      count++;
    }
  }

  return count == 0 ? 0.0 : sum / count;
}

/// Layout coordinates for rendering a dendrogram.
class DendrogramLayout {
  final Map<SimilarityTreeNode, TreePoint> nodePositions;
  final List<(SimilarityTreeNode, SimilarityTreeNode)> edges;
  final TreeBounds bounds;
  final double maxHeight;

  const DendrogramLayout({
    required this.nodePositions,
    required this.edges,
    required this.bounds,
    required this.maxHeight,
  });
}

class TreePoint {
  final double x;
  final double y;

  const TreePoint(this.x, this.y);
}

class TreeBounds {
  final double width;
  final double height;

  const TreeBounds(this.width, this.height);
}

DendrogramLayout layoutDendrogram(
  SimilarityTreeNode root, {
  required double leafSpacing,
  required double levelHeight,
  required double padding,
}) {
  final positions = <SimilarityTreeNode, TreePoint>{};
  final edges = <(SimilarityTreeNode, SimilarityTreeNode)>[];
  var leafCounter = 0.0;
  var maxMergeHeight = 0.0;

  void visit(SimilarityTreeNode node) {
    if (node.isLeaf) {
      final x = padding + leafCounter * leafSpacing;
      leafCounter += 1;
      positions[node] = TreePoint(x, padding);
      return;
    }

    visit(node.left!);
    visit(node.right!);

    final leftPos = positions[node.left!]!;
    final rightPos = positions[node.right!]!;
    final x = (leftPos.x + rightPos.x) / 2;
    final y = padding + node.mergeHeight * levelHeight;

    if (node.mergeHeight > maxMergeHeight) {
      maxMergeHeight = node.mergeHeight;
    }

    positions[node] = TreePoint(x, y);
    edges.add((node, node.left!));
    edges.add((node, node.right!));
  }

  visit(root);

  final leafCount = root.leafCount;
  final width = max(
    padding * 2 + (leafCount - 1) * leafSpacing,
    padding * 2 + 120,
  );
  final height = padding * 2 + max(maxMergeHeight * levelHeight, levelHeight);

  return DendrogramLayout(
    nodePositions: positions,
    edges: edges,
    bounds: TreeBounds(width, height),
    maxHeight: maxMergeHeight,
  );
}
