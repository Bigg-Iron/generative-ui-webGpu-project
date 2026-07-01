import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../domain/inference_result.dart';
import '../../domain/vector_math.dart';

class SimilarityMatrix extends StatelessWidget {
  final List<InferenceResult> history;
  final void Function(InferenceResult a, InferenceResult b)? onCellTap;

  const SimilarityMatrix({
    super.key,
    required this.history,
    this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    final valid =
        history.where((h) => h.embedding.isNotEmpty).toList();

    if (valid.length < 2) {
      return const Center(
        child: Text(
          'ADD 2+ VECTORS FOR SIMILARITY MATRIX',
          style: TextStyle(
            color: AppColors.mutedText,
            fontFamily: 'monospace',
            fontSize: 11,
          ),
        ),
      );
    }

    final n = valid.length;
    final matrix = List.generate(
      n,
      (i) => List.generate(
        n,
        (j) => i == j
            ? 1.0
            : cosineSimilarity(valid[i].embedding, valid[j].embedding),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PAIRWISE SIMILARITY MATRIX',
          style: TextStyle(
            color: AppColors.mutedText,
            fontFamily: 'monospace',
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: Table(
                defaultColumnWidth: const FixedColumnWidth(52),
                children: [
                  TableRow(
                    children: [
                      const SizedBox(width: 52, height: 24),
                      ...valid.map(
                        (h) => _HeaderCell(_short(h.text)),
                      ),
                    ],
                  ),
                  ...List.generate(n, (row) {
                    return TableRow(
                      children: [
                        _HeaderCell(_short(valid[row].text)),
                        ...List.generate(n, (col) {
                          final sim = matrix[row][col];
                          return _MatrixCell(
                            similarity: sim,
                            onTap: onCellTap == null
                                ? null
                                : () => onCellTap!(
                                      valid[row],
                                      valid[col],
                                    ),
                          );
                        }),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _short(String text) {
    final t = text.trim();
    if (t.length <= 6) return t.isEmpty ? '—' : t;
    return '${t.substring(0, 6)}…';
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;

  const _HeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.mutedText,
          fontFamily: 'monospace',
          fontSize: 8,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _MatrixCell extends StatelessWidget {
  final double similarity;
  final VoidCallback? onTap;

  const _MatrixCell({required this.similarity, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = similarity.clamp(0.0, 1.0);
    final color = Color.lerp(
      AppColors.background,
      AppColors.primaryText,
      t,
    )!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(1),
        height: 36,
        color: color,
        alignment: Alignment.center,
        child: Text(
          similarity.toStringAsFixed(2),
          style: TextStyle(
            color: t > 0.5 ? AppColors.background : AppColors.secondaryText,
            fontFamily: 'monospace',
            fontSize: 8,
          ),
        ),
      ),
    );
  }
}
