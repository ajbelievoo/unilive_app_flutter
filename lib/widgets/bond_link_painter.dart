import 'dart:math';
import 'package:flutter/material.dart';

/// A painter that draws an animated, glowing link (heart beam) between two points.
class BondLinkPainter extends CustomPainter {
  BondLinkPainter({
    required this.start,
    required this.end,
    required this.progress,
    this.color = const Color(0xFFE91E63),
  });

  final Offset start;
  final Offset end;
  final double progress; // 0.0 to 1.0 for animation
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    final path = Path();
    path.moveTo(start.dx, start.dy);

    // Control point for a slight curve
    final midX = (start.dx + end.dx) / 2;
    final midY = (start.dy + end.dy) / 2 - 20; // Offset up for curve
    path.quadraticBezierTo(midX, midY, end.dx, end.dy);

    // Draw background glow
    canvas.drawPath(path, glowPaint);
    // Draw main beam
    canvas.drawPath(path, paint);

    // Draw traveling heart particles along the path
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      final length = metric.length;
      // Spawn 3 hearts moving along the path based on progress
      for (int i = 0; i < 3; i++) {
        final heartPos = (progress + (i / 3)) % 1.0;
        final tangent = metric.getTangentForOffset(length * heartPos);
        if (tangent != null) {
          _drawHeart(canvas, tangent.position, 8.0 * (1.0 - (heartPos - 0.5).abs() * 2));
        }
      }
    }
  }

  void _drawHeart(Canvas canvas, Offset center, double size) {
    if (size <= 0) return;
    final paint = Paint()..color = color;
    final path = Path();
    
    final width = size;
    final height = size;
    
    path.moveTo(center.dx, center.dy + height / 4);
    path.cubicTo(center.dx + width / 2, center.dy - height / 2, 
                 center.dx + width * 1.2, center.dy + height / 3, 
                 center.dx, center.dy + height);
    path.cubicTo(center.dx - width * 1.2, center.dy + height / 3, 
                 center.dx - width / 2, center.dy - height / 2, 
                 center.dx, center.dy + height / 4);
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(BondLinkPainter oldDelegate) => 
      oldDelegate.start != start || oldDelegate.end != end || oldDelegate.progress != progress;
}

/// Widget wrapper for BondLinkPainter with animation.
class BondLinkWidget extends StatefulWidget {
  const BondLinkWidget({
    super.key,
    required this.start,
    required this.end,
    this.color = const Color(0xFFE91E63),
  });

  final Offset start;
  final Offset end;
  final Color color;

  @override
  State<BondLinkWidget> createState() => _BondLinkWidgetState();
}

class _BondLinkWidgetState extends State<BondLinkWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: BondLinkPainter(
            start: widget.start,
            end: widget.end,
            progress: _controller.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}
