import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../domain/inference_result.dart';
import '../../domain/similarity_tree.dart';

class SimilarityTreeGraph extends StatelessWidget {
  final List<InferenceResult> history;
  final InferenceResult? activeResult;

  const SimilarityTreeGraph({
    super.key,
    required this.history,
    required this.activeResult,
  });

  @override
  Widget build(BuildContext context) {
    final validHistory = history
        .where((item) => item.embedding.isNotEmpty)
        .toList();

    if (validHistory.length < 2) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Text(
            'ADD 2+ VECTORS TO RENDER RELATIONSHIP TREE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.mutedText,
              fontFamily: 'monospace',
              fontSize: 11,
              letterSpacing: 1.0,
              height: 1.5,
            ),
          ),
        ),
      );
    }

    final tree = buildSimilarityTree(validHistory);
    final layout = layoutDendrogram(
      tree,
      leafSpacing: 96,
      levelHeight: 72,
      padding: 28,
    );

    final activeIndex = activeResult == null
        ? -1
        : validHistory.indexWhere((item) => identical(item, activeResult));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HIERARCHICAL SIMILARITY DENDROGRAM',
          style: TextStyle(
            color: AppColors.mutedText,
            fontFamily: 'monospace',
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Branch height = dissimilarity (1 − cosine similarity). Closer leaves share more meaning.',
          style: TextStyle(
            color: AppColors.secondaryText.withValues(alpha: 0.85),
            fontSize: 11,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border.all(color: AppColors.borderDark),
              borderRadius: BorderRadius.circular(AppBorders.radiusSm),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppBorders.radiusSm),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                boundaryMargin: const EdgeInsets.all(80),
                child: CustomPaint(
                  size: Size(layout.bounds.width, layout.bounds.height),
                  painter: _DendrogramPainter(
                    layout: layout,
                    items: validHistory,
                    activeLeafIndex: activeIndex,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _Legend(activeLabel: activeResult?.text),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final String? activeLabel;

  const _Legend({this.activeLabel});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        _LegendItem(color: AppColors.primaryText, label: 'ACTIVE VECTOR'),
        _LegendItem(color: AppColors.secondaryText, label: 'HISTORICAL VECTOR'),
        _LegendItem(
          color: AppColors.borderLight,
          label: 'MERGE BRANCH',
          isLine: true,
        ),
        if (activeLabel != null && activeLabel!.isNotEmpty)
          Text(
            'ACTIVE: ${activeLabel!.length > 42 ? '${activeLabel!.substring(0, 42)}…' : activeLabel}',
            style: const TextStyle(
              color: AppColors.mutedText,
              fontFamily: 'monospace',
              fontSize: 10,
            ),
          ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isLine;

  const _LegendItem({
    required this.color,
    required this.label,
    this.isLine = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLine)
          Container(width: 16, height: 2, color: color)
        else
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.mutedText,
            fontFamily: 'monospace',
            fontSize: 9,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _DendrogramPainter extends CustomPainter {
  final DendrogramLayout layout;
  final List<InferenceResult> items;
  final int activeLeafIndex;

  _DendrogramPainter({
    required this.layout,
    required this.items,
    required this.activeLeafIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = AppColors.borderLight
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (final (parent, child) in layout.edges) {
      final parentPos = layout.nodePositions[parent]!;
      final childPos = layout.nodePositions[child]!;

      canvas.drawLine(
        Offset(parentPos.x, parentPos.y),
        Offset(childPos.x, parentPos.y),
        edgePaint,
      );
      canvas.drawLine(
        Offset(childPos.x, parentPos.y),
        Offset(childPos.x, childPos.y),
        edgePaint,
      );
    }

    for (final entry in layout.nodePositions.entries) {
      final node = entry.key;
      final pos = entry.value;
      if (!node.isLeaf) continue;

      final index = node.leafIndex!;
      final isActive = index == activeLeafIndex;
      final label = _shortLabel(items[index].text, index);

      final dotPaint = Paint()
        ..color = isActive ? AppColors.primaryText : AppColors.secondaryText;
      canvas.drawCircle(Offset(pos.x, pos.y), isActive ? 5 : 3.5, dotPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: isActive ? AppColors.primaryText : AppColors.secondaryText,
            fontFamily: 'monospace',
            fontSize: 9,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 88);

      textPainter.paint(
        canvas,
        Offset(pos.x - textPainter.width / 2, pos.y + 8),
      );
    }
  }

  String _shortLabel(String text, int index) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '#$index';
    if (trimmed.length <= 14) return trimmed;
    return '${trimmed.substring(0, 14)}…';
  }

  @override
  bool shouldRepaint(covariant _DendrogramPainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.items != items ||
        oldDelegate.activeLeafIndex != activeLeafIndex;
  }
}
