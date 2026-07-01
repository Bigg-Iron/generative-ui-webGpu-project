import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// Horizontal strip of micro-cells representing embedding dimensions.
/// Cool gray → hot white by magnitude; negative values use darker tones.
class EmbeddingHeatmapBarcode extends StatefulWidget {
  final List<double> embedding;
  final List<double>? compareEmbedding;
  final double height;

  const EmbeddingHeatmapBarcode({
    super.key,
    required this.embedding,
    this.compareEmbedding,
    this.height = 28,
  });

  @override
  State<EmbeddingHeatmapBarcode> createState() =>
      _EmbeddingHeatmapBarcodeState();
}

class _EmbeddingHeatmapBarcodeState extends State<EmbeddingHeatmapBarcode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant EmbeddingHeatmapBarcode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.embedding != widget.embedding) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedding.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'EMBEDDING FINGERPRINT',
          style: TextStyle(
            color: AppColors.mutedText,
            fontFamily: 'monospace',
            fontSize: 9,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return MouseRegion(
              onExit: (_) => setState(() => _hoveredIndex = null),
              child: GestureDetector(
                onTapUp: (details) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final local = box.globalToLocal(details.globalPosition);
                  final index = _indexAt(local.dx, box.size.width);
                  if (index != null) setState(() => _hoveredIndex = index);
                },
                child: SizedBox(
                  width: double.infinity,
                  height: widget.height,
                  child: CustomPaint(
                    painter: _BarcodePainter(
                      embedding: widget.embedding,
                      compareEmbedding: widget.compareEmbedding,
                      fillProgress: _controller.value,
                      hoveredIndex: _hoveredIndex,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (_hoveredIndex != null && _hoveredIndex! < widget.embedding.length)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              '[$_hoveredIndex] ${widget.embedding[_hoveredIndex!].toStringAsFixed(5)}',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontFamily: 'monospace',
                fontSize: 10,
              ),
            ),
          ),
      ],
    );
  }

  int? _indexAt(double x, double width) {
    if (widget.embedding.isEmpty || width <= 0) return null;
    final cellW = width / widget.embedding.length;
    final index = (x / cellW).floor().clamp(0, widget.embedding.length - 1);
    return index;
  }
}

class _BarcodePainter extends CustomPainter {
  final List<double> embedding;
  final List<double>? compareEmbedding;
  final double fillProgress;
  final int? hoveredIndex;

  _BarcodePainter({
    required this.embedding,
    this.compareEmbedding,
    required this.fillProgress,
    this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dim = embedding.length;
    if (dim == 0) return;

    final cellW = size.width / dim;
    final visibleCells = (dim * fillProgress).ceil().clamp(0, dim);
    final maxAbs = embedding
        .map((v) => v.abs())
        .fold(0.0, max)
        .clamp(0.001, 1.0);

    final bg = Paint()..color = AppColors.background;
    canvas.drawRect(Offset.zero & size, bg);

    for (var i = 0; i < visibleCells; i++) {
      final value = embedding[i];
      final t = (value.abs() / maxAbs).clamp(0.0, 1.0);
      final luminance = value >= 0 ? 0.15 + t * 0.85 : 0.05 + t * 0.35;
      final color = Color.lerp(
        AppColors.borderDark,
        AppColors.primaryText,
        luminance,
      )!;

      final rect = Rect.fromLTWH(
        i * cellW,
        0,
        max(cellW - 0.5, 0.5),
        size.height,
      );
      canvas.drawRect(rect, Paint()..color = color);

      if (compareEmbedding != null &&
          i < compareEmbedding!.length &&
          (embedding[i] - compareEmbedding![i]).abs() > 0.05) {
        canvas.drawRect(
          rect,
          Paint()
            ..color = AppColors.highlight.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }

      if (hoveredIndex == i) {
        canvas.drawRect(
          rect.inflate(1),
          Paint()
            ..color = AppColors.primaryText
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodePainter oldDelegate) {
    return oldDelegate.embedding != embedding ||
        oldDelegate.compareEmbedding != compareEmbedding ||
        oldDelegate.fillProgress != fillProgress ||
        oldDelegate.hoveredIndex != hoveredIndex;
  }
}
