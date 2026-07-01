import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../domain/isolate_message.dart';

class PipelineTheater extends StatelessWidget {
  final bool isProcessing;
  final PipelineStage? activeStage;
  final List<String>? tokens;
  final String? stageDetail;
  final double? l2Norm;

  const PipelineTheater({
    super.key,
    required this.isProcessing,
    this.activeStage,
    this.tokens,
    this.stageDetail,
    this.l2Norm,
  });

  static const _stages = [
    (PipelineStage.tokenize, 'TOKENIZE'),
    (PipelineStage.tensor, 'TENSOR'),
    (PipelineStage.infer, 'INFER'),
    (PipelineStage.pool, 'POOL'),
    (PipelineStage.normalize, 'NORMALIZE'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'INFERENCE PIPELINE',
          style: TextStyle(
            color: AppColors.mutedText,
            fontFamily: 'monospace',
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            if (compact) {
              return Column(
                children: _stages
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _StagePanel(
                            label: s.$2,
                            active: activeStage == s.$1,
                            done: _isDone(s.$1),
                            idle: !isProcessing && activeStage == null,
                            detail: activeStage == s.$1 ? stageDetail : null,
                            expanded: activeStage == s.$1,
                          ),
                        ))
                    .toList(),
              );
            }
            return Row(
              children: _stages
                  .map(
                    (s) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: _StagePanel(
                          label: s.$2,
                          active: activeStage == s.$1,
                          done: _isDone(s.$1),
                          idle: !isProcessing && activeStage == null,
                          detail: activeStage == s.$1 ? stageDetail : null,
                          expanded: activeStage == s.$1,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        if (tokens != null && tokens!.isNotEmpty && isProcessing) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: tokens!
                .take(16)
                .map(
                  (t) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.borderLight),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      t,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontFamily: 'monospace',
                        fontSize: 9,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        if (l2Norm != null && activeStage == PipelineStage.normalize) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'L2 NORM → ${l2Norm!.toStringAsFixed(4)}',
            style: const TextStyle(
              color: AppColors.success,
              fontFamily: 'monospace',
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }

  bool _isDone(PipelineStage stage) {
    if (activeStage == null) return false;
    final order = PipelineStage.values;
    return order.indexOf(stage) < order.indexOf(activeStage!);
  }
}

class _StagePanel extends StatelessWidget {
  final String label;
  final bool active;
  final bool done;
  final bool idle;
  final String? detail;
  final bool expanded;

  const _StagePanel({
    required this.label,
    required this.active,
    required this.done,
    required this.idle,
    this.detail,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = active
        ? AppColors.primaryText
        : done
            ? AppColors.borderLight
            : AppColors.borderDark;
    final bg = active
        ? AppColors.surface
        : done
            ? AppColors.cardBackground
            : AppColors.background;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(
          color: borderColor,
          width: active ? 1.2 : 0.5,
        ),
        borderRadius: BorderRadius.circular(AppBorders.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primaryText
                      : done
                          ? AppColors.secondaryText
                          : AppColors.mutedText,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: active
                        ? AppColors.primaryText
                        : idle
                            ? AppColors.mutedText
                            : AppColors.secondaryText,
                    fontFamily: 'monospace',
                    fontSize: 9,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          if (detail != null && expanded) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              detail!,
              style: const TextStyle(
                color: AppColors.mutedText,
                fontFamily: 'monospace',
                fontSize: 8,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
