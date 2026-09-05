/// Gift trail overlay — Bigo-style particle trail that follows a gift as it
/// flies from the sender's avatar to the receiver's avatar/seat.
///
/// Ports the native sparkle/heart trail that accompanies gift animations.
/// Embed [GiftTrailOverlay] in a Stack and call
/// [GiftTrailController.spawnTrail] with start + end offsets.
library gift_trail_overlay;

import 'dart:math';

import 'package:flutter/material.dart';

/// Controller that spawns gift trails.
class GiftTrailController {
  void Function(Offset start, Offset end, Color color)? _callback;

  void attach(void Function(Offset start, Offset end, Color color) callback) =>
      _callback = callback;
  void detach() => _callback = null;

  /// Spawn a particle trail from [start] to [end].
  void spawnTrail({
    required Offset start,
    required Offset end,
    Color color = const Color(0xFFFFD700),
  }) =>
      _callback?.call(start, end, color);
}

/// Gift trail particle overlay.
class GiftTrailOverlay extends StatefulWidget {
  const GiftTrailOverlay({super.key, required this.controller});

  final GiftTrailController controller;

  @override
  State<GiftTrailOverlay> createState() => GiftTrailOverlayState();
}

class GiftTrailOverlayState extends State<GiftTrailOverlay>
    with TickerProviderStateMixin {
  final _activeTrails = <_Trail>[];

  @override
  void initState() {
    super.initState();
    widget.controller.attach(_spawn);
  }

  @override
  void dispose() {
    for (final t in _activeTrails) {
      t.controller.dispose();
    }
    widget.controller.detach();
    super.dispose();
  }

  void _spawn(Offset start, Offset end, Color color) {
    if (!mounted) return;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    final trail = _Trail(
      start: start,
      end: end,
      color: color,
      controller: controller,
      rng: Random(),
    );
    _activeTrails.add(trail);
    controller.forward().then((_) {
      if (mounted) {
        controller.dispose();
        setState(() => _activeTrails.remove(trail));
      }
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_activeTrails.isEmpty) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          alignment: Alignment.topLeft,
          children: _activeTrails.map((t) {
            return AnimatedBuilder(
              animation: t.controller,
              builder: (_, __) {
                return CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: _TrailPainter(trail: t, progress: t.controller.value),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _Trail {
  final Offset start;
  final Offset end;
  final Color color;
  final AnimationController controller;
  final Random rng;
  final List<_TrailParticle> particles;

  _Trail({
    required this.start,
    required this.end,
    required this.color,
    required this.controller,
    required this.rng,
  }) : particles = List.generate(18, (i) {
          return _TrailParticle(
            delay: i / 18,
            size: 3 + rng.nextDouble() * 5,
            offset: Offset(
              (rng.nextDouble() - 0.5) * 20,
              (rng.nextDouble() - 0.5) * 20,
            ),
          );
        });
}

class _TrailParticle {
  final double delay; // 0..1, when this particle starts
  final double size;
  final Offset offset;
  _TrailParticle({
    required this.delay,
    required this.size,
    required this.offset,
  });
}

class _TrailPainter extends CustomPainter {
  final _Trail trail;
  final double progress;
  _TrailPainter({required this.trail, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Quadratic bezier for a gentle arc.
    final mid = Offset(
      (trail.start.dx + trail.end.dx) / 2,
      (trail.start.dy + trail.end.dy) / 2 - 80,
    );
    for (final p in trail.particles) {
      final t = (progress - p.delay).clamp(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;
      // Bezier interpolation.
      final omt = 1 - t;
      final x = omt * omt * trail.start.dx +
          2 * omt * t * mid.dx +
          t * t * trail.end.dx;
      final y = omt * omt * trail.start.dy +
          2 * omt * t * mid.dy +
          t * t * trail.end.dy;
      final pos = Offset(x, y) + p.offset * (1 - t);
      final opacity = sin(t * pi); // fade in then out
      final paint = Paint()
        ..color = trail.color.withValues(alpha: opacity * 0.9)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, p.size * (1 - t * 0.3), paint);
      // Glow.
      paint
        ..color = trail.color.withValues(alpha: opacity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(pos, p.size * 1.8, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrailPainter old) =>
      old.progress != progress;
}
