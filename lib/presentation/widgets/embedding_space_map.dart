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
  final ValueChanged<InferenceResult>? onPointSelected;

  const EmbeddingSpaceMap({
    super.key,
    required this.history,
    required this.activeResult,
    this.kNeighbors = 3,
    this.onPointSelected,
  });

  @override
  State<EmbeddingSpaceMap> createState() => _EmbeddingSpaceMapState();
}

class _EmbeddingSpaceMapState extends State<EmbeddingSpaceMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  final TransformationController _transformController =
      TransformationController();
  int? _hoveredIndex;

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
    if (!identical(widget.activeResult, oldWidget.activeResult)) {
      _hoveredIndex = null;
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  double get _entryProgress =>
      Curves.easeOutCubic.transform(_entryController.value);

  Offset _toCanvasPosition(
    ProjectedPoint point,
    Size size,
    double entryProgress,
  ) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = min(size.width, size.height) * 0.38;
    return Offset(
      center.dx + point.x * scale * entryProgress,
      center.dy + point.y * scale * entryProgress,
    );
  }

  Offset _viewportToCanvas(Offset viewportPosition) {
    return MatrixUtils.transformPoint(
      Matrix4.inverted(_transformController.value),
      viewportPosition,
    );
  }

  int? _hitTestIndex(
    Offset canvasPosition,
    Size size,
    List<ProjectedPoint> points,
  ) {
    const hitRadius = 18.0;
    var bestIndex = -1;
    var bestDistance = double.infinity;

    for (var i = 0; i < points.length; i++) {
      final position = _toCanvasPosition(points[i], size, _entryProgress);
      final distance = (position - canvasPosition).distance;
      if (distance <= hitRadius && distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }

    return bestIndex >= 0 ? bestIndex : null;
  }

  void _handleTap(
    TapUpDetails details,
    Size size,
    List<ProjectedPoint> points,
  ) {
    final index = _hitTestIndex(
      _viewportToCanvas(details.localPosition),
      size,
      points,
    );
    if (index == null) return;
    setState(() => _hoveredIndex = index);
    widget.onPointSelected?.call(points[index].item);
  }

  void _handleHover(
    Offset localPosition,
    Size size,
    List<ProjectedPoint> points,
  ) {
    final index = _hitTestIndex(_viewportToCanvas(localPosition), size, points);
    if (index == _hoveredIndex) return;
    setState(() => _hoveredIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final validHistory = widget.history
        .where((h) => h.embedding.isNotEmpty)
        .toList();

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
          'Drag to pan · Scroll or pinch to zoom · Tap a point to inspect',
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final canvasSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );

                  return InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 0.5,
                    maxScale: 4.0,
                    boundaryMargin: const EdgeInsets.all(64),
                    panEnabled: true,
                    scaleEnabled: true,
                    child: SizedBox(
                      width: canvasSize.width,
                      height: canvasSize.height,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapUp: (details) =>
                            _handleTap(details, canvasSize, points),
                        child: MouseRegion(
                          onHover: (event) => _handleHover(
                            event.localPosition,
                            canvasSize,
                            points,
                          ),
                          onExit: (_) => setState(() => _hoveredIndex = null),
                          child: AnimatedBuilder(
                            animation: _entryController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: _SpaceMapPainter(
                                  points: points,
                                  activeIndex: activeIndex,
                                  hoveredIndex: _hoveredIndex,
                                  kNeighbors: widget.kNeighbors,
                                  entryProgress: _entryProgress,
                                ),
                                child: const SizedBox.expand(),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
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
  final int? hoveredIndex;
  final int kNeighbors;
  final double entryProgress;

  _SpaceMapPainter({
    required this.points,
    required this.activeIndex,
    required this.hoveredIndex,
    required this.kNeighbors,
    required this.entryProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final scale = min(size.width, size.height) * 0.38;

    Offset pos(ProjectedPoint p) {
      final x = center.dx + p.x * scale * entryProgress;
      final y = center.dy + p.y * scale * entryProgress;
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
      final isHovered = i == hoveredIndex;
      final position = pos(p);
      final radius = isActive
          ? 7.0
          : isHovered
          ? 6.0
          : 4.5;

      if (isActive || isHovered) {
        final glow = Paint()
          ..color = AppColors.primaryText.withValues(
            alpha: isActive ? 0.15 : 0.08,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(position, radius + 6, glow);
      }

      final dotPaint = Paint()
        ..color = isActive
            ? AppColors.primaryText
            : isHovered
            ? AppColors.highlight
            : AppColors.secondaryText;
      canvas.drawCircle(position, radius, dotPaint);

      if (isActive || isHovered) {
        final label = _shortLabel(p.item.text, p.index);
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: isActive ? AppColors.primaryText : AppColors.highlight,
              fontFamily: 'monospace',
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 120);

        tp.paint(canvas, Offset(position.dx - tp.width / 2, position.dy + 10));
      }
    }
  }

  List<ProjectedPoint> _topKNeighbors(ProjectedPoint active, int k) {
    final scored =
        points
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
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.entryProgress != entryProgress;
  }
}
