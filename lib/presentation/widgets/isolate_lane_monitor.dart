import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../state/ml_state.dart';

class IsolateLaneMonitor extends StatefulWidget {
  final LaneTimeline timeline;
  final bool isProcessing;

  const IsolateLaneMonitor({
    super.key,
    required this.timeline,
    required this.isProcessing,
  });

  @override
  State<IsolateLaneMonitor> createState() => _IsolateLaneMonitorState();
}

class _IsolateLaneMonitorState extends State<IsolateLaneMonitor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _packetController;

  @override
  void initState() {
    super.initState();
    _packetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void didUpdateWidget(covariant IsolateLaneMonitor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.timeline.events.length > oldWidget.timeline.events.length) {
      _packetController
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _packetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final events = widget.timeline.events;
  final durationMs = widget.timeline.totalDurationMs.clamp(100, 5000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ISOLATE DUAL-LANE MONITOR',
          style: TextStyle(
            color: AppColors.mutedText,
            fontFamily: 'monospace',
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'UI thread stays responsive while ML isolate computes.',
          style: TextStyle(
            color: AppColors.secondaryText.withValues(alpha: 0.85),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 72,
          child: AnimatedBuilder(
            animation: _packetController,
            builder: (context, child) {
              return CustomPaint(
                painter: _LanePainter(
                  events: events,
                  durationMs: durationMs.toDouble(),
                  isProcessing: widget.isProcessing,
                  packetProgress: _packetController.value,
                  uiFramePulses: widget.timeline.uiFramePulses,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LanePainter extends CustomPainter {
  final List<LaneEvent> events;
  final double durationMs;
  final bool isProcessing;
  final double packetProgress;
  final int uiFramePulses;

  _LanePainter({
    required this.events,
    required this.durationMs,
    required this.isProcessing,
    required this.packetProgress,
    required this.uiFramePulses,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const laneH = 22.0;
    const gap = 12.0;
    const labelW = 28.0;

    _drawLane(
      canvas,
      size,
      y: 4,
      label: 'UI',
      laneH: laneH,
      labelW: labelW,
      fillColor: AppColors.borderLight.withValues(alpha: 0.25),
      activityBlocks: _uiBlocks(),
    );

    _drawLane(
      canvas,
      size,
      y: 4 + laneH + gap,
      label: 'ML',
      laneH: laneH,
      labelW: labelW,
      fillColor: AppColors.primaryText.withValues(alpha: 0.35),
      activityBlocks: _mlBlocks(),
    );

  if (events.isNotEmpty && packetProgress > 0) {
      final packetY = 4 + laneH / 2;
      final startX = labelW;
      final endX = size.width - 8;
      final x = startX + (endX - startX) * packetProgress;
      final last = events.last;

      final paint = Paint()..color = AppColors.highlight;
      canvas.drawCircle(Offset(x, packetY), 4, paint);

      final tp = TextPainter(
        text: TextSpan(
          text: last.label,
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontFamily: 'monospace',
            fontSize: 8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + 6, packetY - 6));
    }

    final axisPaint = Paint()
      ..color = AppColors.borderDark
      ..strokeWidth = 0.5;
    canvas.drawLine(
      Offset(labelW, size.height - 4),
      Offset(size.width, size.height - 4),
      axisPaint,
    );
  }

  List<(double start, double end)> _uiBlocks() {
    if (!isProcessing && events.isEmpty) return [];
    return [(0.0, 0.15), (0.85, 1.0)];
  }

  List<(double start, double end)> _mlBlocks() {
    final infer = events.where((e) => e.type == LaneEventType.inferenceStart).toList();
    final done = events.where((e) => e.type == LaneEventType.inferenceComplete).toList();
    if (infer.isEmpty) return isProcessing ? [(0.2, 0.9)] : [];
    final start = infer.last.offsetMs / durationMs;
    final end = done.isNotEmpty
        ? done.last.offsetMs / durationMs
        : min(start + 0.7, 1.0);
    return [(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0))];
  }

  void _drawLane(
    Canvas canvas,
    Size size, {
    required double y,
    required String label,
    required double laneH,
    required double labelW,
    required Color fillColor,
    required List<(double start, double end)> activityBlocks,
  }) {
    final laneRect = Rect.fromLTWH(labelW, y, size.width - labelW - 4, laneH);

    canvas.drawRect(
      laneRect,
      Paint()..color = AppColors.background,
    );
    canvas.drawRect(
      laneRect,
      Paint()
        ..color = AppColors.borderDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );

    for (final block in activityBlocks) {
      final left = laneRect.left + laneRect.width * block.$1;
      final right = laneRect.left + laneRect.width * block.$2;
      canvas.drawRect(
        Rect.fromLTRB(left, y + 2, right, y + laneH - 2),
        Paint()..color = fillColor,
      );
    }

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: AppColors.mutedText,
          fontFamily: 'monospace',
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(0, y + (laneH - tp.height) / 2));
  }

  @override
  bool shouldRepaint(covariant _LanePainter oldDelegate) {
    return oldDelegate.events != events ||
        oldDelegate.isProcessing != isProcessing ||
        oldDelegate.packetProgress != packetProgress;
  }
}
