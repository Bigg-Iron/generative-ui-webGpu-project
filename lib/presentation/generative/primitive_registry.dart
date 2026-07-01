import 'dart:convert';

import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../domain/ui_schema.dart';

typedef PrimitiveBuilder = Widget Function(Map<String, dynamic> props);

class PrimitiveRegistry {
  static final Map<String, PrimitiveBuilder> _builders = {
    'MetricCard': (props) => GenerativeMetricCard(
      label: props['label'] as String? ?? 'METRIC',
      value: props['value']?.toString() ?? '—',
    ),
    'SimilarityBar': (props) => GenerativeSimilarityBar(
      score: (props['score'] as num?)?.toDouble() ?? 0.0,
    ),
    'VectorHeatmap': (props) => GenerativeVectorHeatmapPlaceholder(
      dim: (props['dim'] as num?)?.toInt() ?? 384,
    ),
    'DendrogramMini': (props) =>
        GenerativeDendrogramMini(label: props['label'] as String? ?? 'CLUSTER'),
  };

  static Widget build(String type, Map<String, dynamic> props) {
    final builder = _builders[type];
    if (builder == null) {
      return Text(
        'Unknown: $type',
        style: const TextStyle(color: AppColors.error, fontSize: 11),
      );
    }
    return builder(props);
  }
}

class GenerativeMetricCard extends StatelessWidget {
  final String label;
  final String value;

  const GenerativeMetricCard({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(AppBorders.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontFamily: 'monospace',
              fontSize: 9,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontFamily: 'monospace',
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class GenerativeSimilarityBar extends StatelessWidget {
  final double score;

  const GenerativeSimilarityBar({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final clamped = score.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SIMILARITY ${clamped.toStringAsFixed(4)}',
          style: const TextStyle(
            color: AppColors.mutedText,
            fontFamily: 'monospace',
            fontSize: 9,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: 8,
            backgroundColor: AppColors.borderDark,
            color: AppColors.primaryText,
          ),
        ),
      ],
    );
  }
}

class GenerativeVectorHeatmapPlaceholder extends StatelessWidget {
  final int dim;

  const GenerativeVectorHeatmapPlaceholder({super.key, required this.dim});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderDark),
        borderRadius: BorderRadius.circular(AppBorders.radiusSm),
      ),
      child: Row(
        children: List.generate(
          min(dim, 48),
          (i) => Expanded(
            child: Container(
              color: Color.lerp(
                AppColors.borderDark,
                AppColors.primaryText,
                (i % 7) / 7,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GenerativeDendrogramMini extends StatelessWidget {
  final String label;

  const GenerativeDendrogramMini({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: CustomPaint(painter: _MiniDendrogramPainter(label: label)),
    );
  }
}

class _MiniDendrogramPainter extends CustomPainter {
  final String label;

  _MiniDendrogramPainter({required this.label});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.borderLight
      ..strokeWidth = 1;

    final y = size.height * 0.6;
    canvas.drawLine(
      Offset(size.width * 0.2, y),
      Offset(size.width * 0.5, y * 0.4),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.8, y),
      Offset(size.width * 0.5, y * 0.4),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.5, y * 0.4),
      Offset(size.width * 0.5, y * 0.15),
      paint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.2, y),
      3,
      Paint()..color = AppColors.secondaryText,
    );
    canvas.drawCircle(
      Offset(size.width * 0.8, y),
      3,
      Paint()..color = AppColors.secondaryText,
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, y * 0.15),
      4,
      Paint()..color = AppColors.primaryText,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String formatSchemaJson(UiLayoutSchema schema) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(schema.toJson());
}
