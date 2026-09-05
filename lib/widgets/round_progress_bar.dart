import 'package:flutter/material.dart';

class RoundProgressBar extends StatefulWidget {
  const RoundProgressBar({
    super.key,
    required this.progress,
    this.size = 48,
    this.strokeWidth = 4,
    this.backgroundColor,
    this.progressColor = const Color(0xFF7E3FF2),
    this.child,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Color? backgroundColor;
  final Color progressColor;
  final Widget? child;

  @override
  State<RoundProgressBar> createState() => _RoundProgressBarState();
}

class _RoundProgressBarState extends State<RoundProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(RoundProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _controller.animateTo(widget.progress, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _RoundProgressPainter(
              progress: widget.progress.clamp(0.0, 1.0),
              strokeWidth: widget.strokeWidth,
              backgroundColor: widget.backgroundColor ?? Colors.grey.shade300,
              progressColor: widget.progressColor,
            ),
          ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _RoundProgressPainter extends CustomPainter {
  _RoundProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.progressColor,
  });

  final double progress;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    final sweepAngle = progress * 2 * 3.14159265;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159265 / 2,
      sweepAngle,
      false,
      Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RoundProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class LikeButton extends StatefulWidget {
  const LikeButton({
    super.key,
    required this.isLiked,
    required this.onTap,
    this.size = 30,
    this.activeColor = Colors.red,
    this.inactiveColor = Colors.white,
  });

  final bool isLiked;
  final VoidCallback onTap;
  final double size;
  final Color activeColor;
  final Color inactiveColor;

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Icon(
          widget.isLiked ? Icons.favorite : Icons.favorite_border,
          color: widget.isLiked ? widget.activeColor : widget.inactiveColor,
          size: widget.size,
        ),
      ),
    );
  }
}
