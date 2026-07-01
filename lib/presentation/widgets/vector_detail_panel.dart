import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../domain/inference_result.dart';
import '../../domain/vector_math.dart';
import 'embedding_heatmap_barcode.dart';

class VectorDetailPanel extends StatelessWidget {
  final InferenceResult result;
  final bool expanded;
  final VoidCallback onToggle;
  final double? similarityToActive;
  final String? headerLabel;
  final List<double>? compareEmbedding;

  const VectorDetailPanel({
    super.key,
    required this.result,
    required this.expanded,
    required this.onToggle,
    this.similarityToActive,
    this.headerLabel,
    this.compareEmbedding,
  });

  @override
  Widget build(BuildContext context) {
    if (result.hasError) {
      return _ErrorBody(message: result.error!, text: result.text);
    }

    final embedding = result.embedding;
    final stats = EmbeddingStats.fromEmbedding(embedding);
    final preview = _formatVectorPreview(embedding);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(AppBorders.radiusSm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            border: Border.all(
              color: expanded ? AppColors.primaryText : AppColors.borderDark,
              width: expanded ? 1.0 : 0.5,
            ),
            borderRadius: BorderRadius.circular(AppBorders.radiusSm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.mutedText,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      headerLabel ?? 'VECTOR DETAILS',
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontFamily: 'monospace',
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Text(
                    expanded ? 'COLLAPSE' : 'EXPAND',
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontFamily: 'monospace',
                      fontSize: 9,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _MetricRow(
                children: [
                  _MetricChip(label: 'DIM', value: '${embedding.length}'),
                  _MetricChip(
                    label: 'TIME',
                    value: '${result.inferenceTimeMs.toStringAsFixed(2)} ms',
                  ),
                  if (similarityToActive != null)
                    _MetricChip(
                      label: 'SIM',
                      value: similarityToActive!.toStringAsFixed(4),
                      highlight: true,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              EmbeddingHeatmapBarcode(
                embedding: embedding,
                compareEmbedding: compareEmbedding,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                result.text,
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 13,
                  height: 1.4,
                ),
                maxLines: expanded ? null : 2,
                overflow: expanded ? null : TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                preview,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: _ExpandedBody(embedding: embedding, stats: stats),
                ),
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
                sizeCurve: Curves.easeOutCubic,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatVectorPreview(List<double> embedding) {
    if (embedding.isEmpty) return '[]';
    const showCount = 8;
    if (embedding.length <= showCount * 2) {
      return '[${embedding.map((v) => v.toStringAsFixed(4)).join(', ')}]';
    }
    final start = embedding
        .take(showCount)
        .map((v) => v.toStringAsFixed(4))
        .join(', ');
    final end = embedding
        .skip(embedding.length - showCount)
        .map((v) => v.toStringAsFixed(4))
        .join(', ');
    return '[$start, ..., $end]';
  }
}

class _ExpandedBody extends StatelessWidget {
  final List<double> embedding;
  final EmbeddingStats stats;

  const _ExpandedBody({required this.embedding, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'EMBEDDING STATISTICS',
          style: TextStyle(
            color: AppColors.mutedText,
            fontFamily: 'monospace',
            fontSize: 9,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _MetricRow(
          children: [
            _MetricChip(
              label: 'L2 NORM',
              value: stats.l2Norm.toStringAsFixed(4),
            ),
            _MetricChip(label: 'MEAN', value: stats.mean.toStringAsFixed(4)),
            _MetricChip(label: 'STD', value: stats.stdDev.toStringAsFixed(4)),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        _MetricRow(
          children: [
            _MetricChip(label: 'MIN', value: stats.min.toStringAsFixed(4)),
            _MetricChip(label: 'MAX', value: stats.max.toStringAsFixed(4)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'FULL EMBEDDING VECTOR',
          style: TextStyle(
            color: AppColors.mutedText,
            fontFamily: 'monospace',
            fontSize: 9,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.borderDark),
            borderRadius: BorderRadius.circular(AppBorders.radiusSm),
          ),
          child: SingleChildScrollView(
            child: _VectorGrid(embedding: embedding),
          ),
        ),
      ],
    );
  }
}

class _VectorGrid extends StatelessWidget {
  final List<double> embedding;
  static const _columns = 4;

  const _VectorGrid({required this.embedding});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate((embedding.length / _columns).ceil(), (row) {
        final start = row * _columns;
        final end = min(start + _columns, embedding.length);
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(
            embedding
                .sublist(start, end)
                .asMap()
                .entries
                .map(
                  (entry) =>
                      '[${start + entry.key}] ${entry.value.toStringAsFixed(5)}',
                )
                .join('   '),
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontFamily: 'monospace',
              fontSize: 10,
              height: 1.6,
            ),
          ),
        );
      }),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final List<Widget> children;

  const _MetricRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: children,
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _MetricChip({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: highlight ? AppColors.surface : AppColors.background,
        border: Border.all(
          color: highlight ? AppColors.success : AppColors.borderDark,
        ),
        borderRadius: BorderRadius.circular(AppBorders.radiusSm / 2),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: highlight ? AppColors.success : AppColors.primaryText,
          fontFamily: 'monospace',
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final String text;

  const _ErrorBody({required this.message, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppBorders.radiusSm),
        border: Border.all(color: AppColors.error, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ERROR PIPELINE EXCEPTION',
            style: TextStyle(
              color: AppColors.error,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              text,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
