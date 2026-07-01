import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../domain/inference_result.dart';
import '../../domain/pca_projection.dart';
import '../../domain/vector_math.dart';

class EmbeddingSpaceMap extends StatefulWidget {
  final List<InferenceResult> history;
  final InferenceResult? activeResult;
  final int kNeighbors;

  const EmbeddingSpaceMap({
    super.key,
    required this.history,
    required this.activeResult,
    this.kNeighbors = 3,
  });

  @override
  State<EmbeddingSpaceMap> createState() => _EmbeddingSpaceMapState();
}

class _EmbeddingSpaceMapState extends State<EmbeddingSpaceMap>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  final Map<int, AnimationController> _springControllers = {};

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant EmbeddingSpaceMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.history.length != oldWidget.history.length) {
      _entryController
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    for (final c in _springControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final validHistory =
        widget.history.where((h) => h.embedding.isNotEmpty).toList();

    if (validHistory.isEmpty) {
      return const Center(
        child: Text(
          'ADD VECTORS TO RENDER SEMANTIC SPACE',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.mutedText,
            fontFamily: 'monospace',
            fontSize: 11,
            letterSpacing: 1.0,
          ),
        ),
      );
    }

    final points = projectEmbeddingsTo2D(validHistory);
    final activeIndex = widget.activeResult == null
        ? -1
        : validHistory.indexWhere((h) => identical(h, widget.activeResult));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SEMANTIC SPACE MAP (PCA)',
          style: TextStyle(
            color: AppColors.mutedText,
            fontFamily: 'monospace',
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Nearby points share meaning. Edge thickness = cosine similarity.',
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
              child: AnimatedBuilder(
                animation: _entryController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _SpaceMapPainter(
                      points: points,
                      activeIndex: activeIndex,
                      kNeighbors: widget.kNeighbors,
                      entryProgress: Curves.easeOutCubic
                          .transform(_entryController.value),
                    ),
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpaceMapPainter extends CustomPainter {
  final List<ProjectedPoint> points;
  final int activeIndex;
  final int kNeighbors;
  final double entryProgress;

  _SpaceMapPainter({
    required this.points,
    required this.activeIndex,
    required this.kNeighbors,
    required this.entryProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final scale = min(size.width, size.height) * 0.38;

    Offset pos(ProjectedPoint p) {
      final animT = entryProgress;
      final x = center.dx + p.x * scale * animT;
      final y = center.dy + p.y * scale * animT;
      return Offset(x, y);
    }

    if (activeIndex >= 0 && activeIndex < points.length) {
      final active = points[activeIndex];
      final neighbors = _topKNeighbors(active, kNeighbors);

      for (final neighbor in neighbors) {
        final sim = cosineSimilarity(
          active.item.embedding,
          neighbor.item.embedding,
        );
        final paint = Paint()
          ..color = AppColors.borderLight.withValues(alpha: 0.3 + sim * 0.5)
          ..strokeWidth = 0.5 + sim * 2.5;
        canvas.drawLine(pos(active), pos(neighbor), paint);
      }
    }

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final isActive = i == activeIndex;
      final position = pos(p);
      final radius = isActive ? 7.0 : 4.5;

      if (isActive) {
        final glow = Paint()
          ..color = AppColors.primaryText.withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(position, radius + 6, glow);
      }

      final dotPaint = Paint()
        ..color = isActive ? AppColors.primaryText : AppColors.secondaryText;
      canvas.drawCircle(position, radius, dotPaint);

      final label = _shortLabel(p.item.text, p.index);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: isActive ? AppColors.primaryText : AppColors.mutedText,
            fontFamily: 'monospace',
            fontSize: 9,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 72);

      tp.paint(canvas, Offset(position.dx - tp.width / 2, position.dy + 10));
    }
  }

  List<ProjectedPoint> _topKNeighbors(ProjectedPoint active, int k) {
    final scored = points
        .where((p) => p.index != active.index)
        .map(
          (p) => (
            p,
            cosineSimilarity(active.item.embedding, p.item.embedding),
          ),
        )
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(k).map((e) => e.$1).toList();
  }

  String _shortLabel(String text, int index) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '#$index';
    if (trimmed.length <= 12) return trimmed;
    return '${trimmed.substring(0, 12)}…';
  }

  @override
  bool shouldRepaint(covariant _SpaceMapPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.entryProgress != entryProgress;
  }
}
