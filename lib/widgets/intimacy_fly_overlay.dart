import 'dart:math';
import 'package:flutter/material.dart';

/// Data for a single intimacy fly-up animation.
class IntimacyFlyData {
  final Key key = UniqueKey();
  final String text;
  final Offset position;
  final Color color;

  IntimacyFlyData({
    required this.text,
    required this.position,
    this.color = const Color(0xFFE91E63),
  });
}

/// Overlay that manages and displays floating intimacy rewards.
class IntimacyFlyOverlay extends StatefulWidget {
  const IntimacyFlyOverlay({super.key});

  @override
  State<IntimacyFlyOverlay> createState() => IntimacyFlyOverlayState();
}

class IntimacyFlyOverlayState extends State<IntimacyFlyOverlay> {
  final List<IntimacyFlyData> _items = [];

  void spawn({required String text, required Offset position, Color? color}) {
    if (!mounted) return;
    setState(() {
      _items.add(IntimacyFlyData(text: text, position: position, color: color ?? const Color(0xFFE91E63)));
    });
    // Auto-remove after animation
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _items.removeWhere((item) => item.text == text && item.position == position);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topLeft,
      children: _items.map((data) => _FloatingItem(data: data)).toList(),
    );
  }
}

class _FloatingItem extends StatefulWidget {
  const _FloatingItem({required this.data});
  final IntimacyFlyData data;

  @override
  State<_FloatingItem> createState() => _FloatingItemState();
}

class _FloatingItemState extends State<_FloatingItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _translateY;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);

    _translateY = Tween<double>(begin: 0.0, end: -100.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.2), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 70),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.data.position.dx - 50,
      top: widget.data.position.dy,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacity.value,
            child: Transform.translate(
              offset: Offset(0, _translateY.value),
              child: Transform.scale(
                scale: _scale.value,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite, color: widget.data.color, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      widget.data.text,
                      style: TextStyle(
                        color: widget.data.color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        shadows: const [
                          Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
