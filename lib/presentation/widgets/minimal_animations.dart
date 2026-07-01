import 'package:flutter/material.dart';
import '../../core/constants.dart';

/// A sleek, pulsing indicator dot that fades in and out smoothly.
class PulsingStatusIndicator extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingStatusIndicator({
    super.key,
    required this.color,
    this.size = 8.0,
  });

  @override
  State<PulsingStatusIndicator> createState() => _PulsingStatusIndicatorState();
}

class _PulsingStatusIndicatorState extends State<PulsingStatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// A horizontal running line loading bar that loops continuously in a minimal style.
class MinimalLoadingIndicator extends StatefulWidget {
  const MinimalLoadingIndicator({super.key});

  @override
  State<MinimalLoadingIndicator> createState() => _MinimalLoadingIndicatorState();
}

class _MinimalLoadingIndicatorState extends State<MinimalLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Container(
          height: 2.0,
          width: width,
          color: AppColors.borderDark,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final val = _animation.value;
              // A simple custom painting of a moving line segment
              return CustomPaint(
                painter: _MovingLinePainter(progress: val),
                child: const SizedBox.expand(),
              );
            },
          ),
        );
      },
    );
  }
}

class _MovingLinePainter extends CustomPainter {
  final double progress;

  _MovingLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryText
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.square;

    final segmentWidth = size.width * 0.3;
    final startX = (size.width + segmentWidth) * progress - segmentWidth;
    final endX = startX + segmentWidth;

    canvas.drawLine(
      Offset(startX.clamp(0.0, size.width), size.height / 2),
      Offset(endX.clamp(0.0, size.width), size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _MovingLinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
