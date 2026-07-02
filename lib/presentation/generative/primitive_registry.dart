import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../domain/generative_context.dart';
import '../../domain/inference_result.dart';
import '../../domain/ui_schema.dart';
import '../../domain/vector_math.dart';
import '../widgets/embedding_heatmap_barcode.dart';
import '../widgets/embedding_space_map.dart';
import '../widgets/pipeline_theater.dart';
import '../widgets/similarity_matrix.dart';

typedef PrimitiveBuilder = Widget Function(
  Map<String, dynamic> props,
  GenerativeContext context,
);

class PrimitiveRegistry {
  static final Map<String, PrimitiveBuilder> _builders = {
    'MetricCard': (props, ctx) => GenerativeMetricCard(
      label: props['label'] as String? ?? 'METRIC',
      value: _formatValue(props['value']),
      unit: props['unit'] as String?,
    ),
    'SimilarityBar': (props, ctx) => GenerativeSimilarityBar(
      score: _doubleProp(props['score'], ctx.bestNonSelfSimilarity ?? 0.0),
    ),
    'VectorHeatmap': (props, ctx) {
      final embedding = _resolveEmbedding(props, ctx);
      return embedding == null
          ? const _EmptyPrimitive(label: 'NO EMBEDDING')
          : EmbeddingHeatmapBarcode(
              embedding: embedding,
              compareEmbedding: ctx.compareEmbedding,
              height: (props['height'] as num?)?.toDouble() ?? 28,
            );
    },
    'EmbeddingMap': (props, ctx) => SizedBox(
      height: (props['height'] as num?)?.toDouble() ?? 160,
      child: EmbeddingSpaceMap(
        history: ctx.history,
        activeResult: ctx.activeResult,
        onPointSelected: ctx.onSelectResult,
      ),
    ),
    'SimilarityMatrix': (props, ctx) => SizedBox(
      height: (props['compact'] as bool? ?? true) ? 180 : 280,
      child: SimilarityMatrix(history: ctx.history),
    ),
    'PipelineTheater': (props, ctx) => PipelineTheater(
      isProcessing: ctx.isProcessing || ctx.pipelineStage != null,
      activeStage: ctx.pipelineStage,
      tokens: ctx.pipelineTokens,
      stageDetail: ctx.pipelineDetail,
      l2Norm: ctx.pipelineL2Norm,
    ),
    'HistoryList': (props, ctx) => GenerativeHistoryList(
      history: ctx.history,
      activeResult: ctx.activeResult,
      similarities: ctx.similarities,
      compact: props['compact'] as bool? ?? false,
      onSelect: ctx.onSelectResult,
    ),
    'ComparePicker': (props, ctx) => GenerativeComparePicker(
      history: ctx.history,
      activeResult: ctx.activeResult,
      similarities: ctx.similarities,
      onSelect: ctx.onSelectResult,
    ),
    'IntentSuggestions': (props, ctx) {
      final suggestions = props['suggestions'] as List<dynamic>? ?? [];
      return GenerativeIntentSuggestions(
        suggestions: suggestions
            .map((s) => s.toString())
            .where((s) => s.isNotEmpty)
            .toList(),
        onTap: props['onTap'] as void Function(String)?,
      );
    },
    'DendrogramMini': (props, ctx) => GenerativeDendrogramMini(
      label: props['label'] as String? ?? 'CLUSTER',
    ),
    'Stack': (props, ctx) => const SizedBox.shrink(),
    'SplitPane': (props, ctx) => const SizedBox.shrink(),
    'Accordion': (props, ctx) => const SizedBox.shrink(),
  };

  static Widget build(
    String type,
    Map<String, dynamic> props,
    GenerativeContext context,
  ) {
    final builder = _builders[type];
    if (builder == null) {
      return Text(
        'Unknown: $type',
        style: const TextStyle(color: AppColors.error, fontSize: 11),
      );
    }
    return builder(props, context);
  }

  static List<double>? _resolveEmbedding(
    Map<String, dynamic> props,
    GenerativeContext ctx,
  ) {
    final dataRef = props['dataRef'] as String?;
    if (dataRef == 'activeEmbedding') return ctx.activeEmbedding;
    return ctx.activeEmbedding;
  }

  static double _doubleProp(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static String _formatValue(dynamic value) {
    if (value == null) return '—';
    if (value is double) return value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
    return value.toString();
  }
}

class GenerativeMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;

  const GenerativeMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final display = unit != null && unit!.isNotEmpty ? '$value $unit' : value;
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
            display,
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

class GenerativeHistoryList extends StatelessWidget {
  final List<InferenceResult> history;
  final InferenceResult? activeResult;
  final Map<int, double> similarities;
  final bool compact;
  final void Function(InferenceResult)? onSelect;

  const GenerativeHistoryList({
    super.key,
    required this.history,
    required this.activeResult,
    required this.similarities,
    this.compact = false,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const _EmptyPrimitive(label: 'NO HISTORY');
    }

    final items = compact ? history.take(5) : history;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HISTORY',
          style: TextStyle(
            color: AppColors.mutedText,
            fontFamily: 'monospace',
            fontSize: 9,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ...items.map((item) {
          final isActive = identical(item, activeResult);
          final sim = similarityToActive(item, activeResult, similarities);
          final label = item.text.trim();
          final short = label.length > 24 ? '${label.substring(0, 24)}…' : label;

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Material(
              color: isActive ? AppColors.surface : AppColors.background,
              child: InkWell(
                onTap: onSelect == null ? null : () => onSelect!(item),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isActive
                          ? AppColors.primaryText
                          : AppColors.borderDark,
                    ),
                    borderRadius: BorderRadius.circular(AppBorders.radiusSm),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          short.isEmpty ? '—' : short,
                          style: TextStyle(
                            color: isActive
                                ? AppColors.primaryText
                                : AppColors.secondaryText,
                            fontFamily: 'monospace',
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (sim != null)
                        Text(
                          sim.toStringAsFixed(3),
                          style: const TextStyle(
                            color: AppColors.mutedText,
                            fontFamily: 'monospace',
                            fontSize: 9,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class GenerativeComparePicker extends StatelessWidget {
  final List<InferenceResult> history;
  final InferenceResult? activeResult;
  final Map<int, double> similarities;
  final void Function(InferenceResult)? onSelect;

  const GenerativeComparePicker({
    super.key,
    required this.history,
    required this.activeResult,
    required this.similarities,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final candidates = history
        .where((h) => !identical(h, activeResult) && h.embedding.isNotEmpty)
        .toList();

    if (candidates.isEmpty) {
      return const _EmptyPrimitive(label: 'ADD 2+ VECTORS TO COMPARE');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'COMPARE TARGET',
          style: TextStyle(
            color: AppColors.mutedText,
            fontFamily: 'monospace',
            fontSize: 9,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: candidates.map((item) {
            final sim = similarityToActive(item, activeResult, similarities);
            final label = item.text.trim();
            final short = label.length > 16 ? '${label.substring(0, 16)}…' : label;
            return ActionChip(
              label: Text(
                sim != null ? '$short (${sim.toStringAsFixed(2)})' : short,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                ),
              ),
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.borderLight),
              onPressed: onSelect == null ? null : () => onSelect!(item),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class GenerativeIntentSuggestions extends StatelessWidget {
  final List<String> suggestions;
  final void Function(String)? onTap;

  const GenerativeIntentSuggestions({
    super.key,
    required this.suggestions,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: suggestions.map((s) {
        return ActionChip(
          label: Text(
            s,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 9),
          ),
          backgroundColor: AppColors.background,
          side: const BorderSide(color: AppColors.borderDark),
          onPressed: onTap == null ? null : () => onTap!(s),
        );
      }).toList(),
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

class _EmptyPrimitive extends StatelessWidget {
  final String label;

  const _EmptyPrimitive({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderDark),
        borderRadius: BorderRadius.circular(AppBorders.radiusSm),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.mutedText,
          fontFamily: 'monospace',
          fontSize: 10,
        ),
      ),
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
