/// Combo milestone burst overlay — Bigo-style full-screen celebration when a
/// gift combo crosses a milestone (x10, x50, x99, x520, x1314, etc).
///
/// Ports the native "combo burst" from Bigo Live / Chamet:
/// - Full-screen radial particle burst (gold/purple sparks)
/// - Big glowing "xNN" number with fire gradient + scale punch
/// - "COMBO!" / milestone label (e.g. "AMAZING!", "INSANE!", "LEGENDARY!")
/// - Screen flash + screen shake (wired via [onShake] callback)
/// - Confetti rain from top
///
/// Embed [GiftComboBurstOverlay] in a Stack. Feed it combo counts via
/// [GiftComboBurstController.trigger]. The overlay auto-dismisses.
library gift_combo_burst_overlay;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../utils/log.dart';

/// Milestone thresholds and their labels (ports Bigo's tiered combo callouts).
class ComboMilestone {
  final int count;
  final String label;
  final String emoji;
  final Color primaryColor;
  final Color secondaryColor;

  const ComboMilestone(
    this.count,
    this.label,
    this.emoji,
    this.primaryColor,
    this.secondaryColor,
  );

  static const List<ComboMilestone> all = [
    ComboMilestone(10, 'NICE!', '🎉', Color(0xFFFFD54F), Color(0xFFFF8F00)),
    ComboMilestone(30, 'COOL!', '✨', Color(0xFF42A5F5), Color(0xFF1565C0)),
    ComboMilestone(50, 'GREAT!', '🔥', Color(0xFFFF7043), Color(0xFFD84315)),
    ComboMilestone(66, 'LUCKY 66!', '🍀', Color(0xFF66BB6A), Color(0xFF2E7D32)),
    ComboMilestone(88, 'FORTUNE 88!', '💰', Color(0xFFFFCA28), Color(0xFFF57F17)),
    ComboMilestone(99, 'AMAZING!', '💥', Color(0xFFEF5350), Color(0xFFB71C1C)),
    ComboMilestone(188, 'CRAZY!', '🚀', Color(0xFFAB47BC), Color(0xFF6A1B9A)),
    ComboMilestone(520, 'LOVE 520!', '❤️', Color(0xFFEC407A), Color(0xFFAD1457)),
    ComboMilestone(999, 'INSANE!', '⚡', Color(0xFF7C4DFF), Color(0xFF311B92)),
    ComboMilestone(1314, 'FOREVER 1314!', '💎', Color(0xFF26C6DA), Color(0xFF006064)),
    ComboMilestone(3344, 'LEGENDARY!', '👑', Color(0xFFFFD700), Color(0xFFFF6F00)),
  ];

  /// Find the highest milestone reached for a given combo count.
  static ComboMilestone? forCount(int count) {
    ComboMilestone? match;
    for (final m in all) {
      if (count >= m.count) match = m;
    }
    return match;
  }

  /// Returns true if [count] is exactly a milestone (burst should fire).
  static bool isMilestone(int count) {
    return all.any((m) => m.count == count);
  }
}

/// Controller that triggers the combo burst overlay.
class GiftComboBurstController {
  void Function(int count, ComboMilestone milestone)? _callback;
  void Function(double intensity)? onShake;

  void attach(
    void Function(int count, ComboMilestone milestone) callback,
  ) =>
      _callback = callback;

  void detach() => _callback = null;

  /// Trigger a burst if [count] is a milestone. Returns true if it fired.
  bool trigger(int count) {
    final milestone = ComboMilestone.forCount(count);
    if (milestone == null) return false;
    // Only fire on exact milestone crossings to avoid repeat bursts.
    if (!ComboMilestone.isMilestone(count)) return false;
    Log.d('ComboBurst', 'Milestone reached: x$count ${milestone.label}');
    _callback?.call(count, milestone);
    // Screen shake intensity scales with milestone.
    final intensity = (count / 50).clamp(4.0, 18.0).toDouble();
    onShake?.call(intensity);
    return true;
  }
}

/// Full-screen combo milestone burst overlay.
///
/// Place inside a Stack above all other overlays. Invisible when idle.
class GiftComboBurstOverlay extends StatefulWidget {
  const GiftComboBurstOverlay({
    super.key,
    required this.controller,
    this.onShake,
  });

  final GiftComboBurstController controller;
  /// Optional callback fired when a milestone triggers a screen shake.
  final void Function(double intensity)? onShake;

  @override
  State<GiftComboBurstOverlay> createState() => GiftComboBurstOverlayState();
}

class GiftComboBurstOverlayState extends State<GiftComboBurstOverlay>
    with TickerProviderStateMixin {
  ComboMilestone? _milestone;
  int _count = 0;
  bool _visible = false;

  late AnimationController _flashController; // white flash
  late AnimationController _numberController; // number scale punch
  late AnimationController _particleController; // radial particles
  late AnimationController _confettiController; // confetti fall
  Timer? _hideTimer;

  final _particles = <_Particle>[];
  final _confetti = <_ConfettiPiece>[];
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _numberController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    widget.controller.attach(_onMilestone);
    widget.controller.onShake = widget.onShake;
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _flashController.dispose();
    _numberController.dispose();
    _particleController.dispose();
    _confettiController.dispose();
    widget.controller.detach();
    super.dispose();
  }

  void _onMilestone(int count, ComboMilestone milestone) {
    if (!mounted) return;
    _hideTimer?.cancel();
    _generateParticles(milestone);
    _generateConfetti(milestone);
    setState(() {
      _count = count;
      _milestone = milestone;
      _visible = true;
    });
    _flashController.forward(from: 0);
    _numberController.forward(from: 0);
    _particleController.forward(from: 0);
    _confettiController.forward(from: 0);
    _hideTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _generateParticles(ComboMilestone m) {
    _particles.clear();
    const count = 36;
    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * pi;
      _particles.add(_Particle(
        angle: angle,
        speed: 120 + _rng.nextDouble() * 180,
        size: 4 + _rng.nextDouble() * 8,
        color: i % 2 == 0 ? m.primaryColor : m.secondaryColor,
      ));
    }
  }

  void _generateConfetti(ComboMilestone m) {
    _confetti.clear();
    const count = 60;
    for (int i = 0; i < count; i++) {
      _confetti.add(_ConfettiPiece(
        x: _rng.nextDouble(),
        color: [
          m.primaryColor,
          m.secondaryColor,
          Colors.white,
          const Color(0xFFFFD700),
        ][_rng.nextInt(4)],
        size: 6 + _rng.nextDouble() * 10,
        rotationSpeed: (_rng.nextDouble() - 0.5) * 8,
        fallDelay: _rng.nextDouble() * 0.3,
        drift: (_rng.nextDouble() - 0.5) * 0.3,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || _milestone == null) return const SizedBox.shrink();
    final m = _milestone!;
    final size = MediaQuery.of(context).size;

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          alignment: Alignment.topLeft,
          children: [
            // White flash.
            AnimatedBuilder(
              animation: _flashController,
              builder: (_, __) {
                final v = _flashController.value;
                // Flash fades out quickly.
                final opacity = (1 - v) * 0.5;
                return Container(color: Colors.white.withValues(alpha: opacity));
              },
            ),
            // Radial particle burst.
            AnimatedBuilder(
              animation: _particleController,
              builder: (_, __) {
                return CustomPaint(
                  size: size,
                  painter: _ParticlePainter(
                    particles: _particles,
                    progress: _particleController.value,
                  ),
                );
              },
            ),
            // Confetti rain.
            AnimatedBuilder(
              animation: _confettiController,
              builder: (_, __) {
                return CustomPaint(
                  size: size,
                  painter: _ConfettiPainter(
                    pieces: _confetti,
                    progress: _confettiController.value,
                  ),
                );
              },
            ),
            // Center number + label.
            Center(
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.3, end: 1.0).animate(
                  CurvedAnimation(
                    parent: _numberController,
                    curve: Curves.elasticOut,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Big "xNN" with fire gradient.
                    ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            m.primaryColor,
                            m.secondaryColor,
                            Colors.white,
                            m.primaryColor,
                          ],
                          stops: const [0.0, 0.4, 0.6, 1.0],
                        ).createShader(bounds);
                      },
                      child: Text(
                        'x$_count',
                        style: const TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Label chip.
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [m.primaryColor, m.secondaryColor],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: m.primaryColor.withValues(alpha: 0.6),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(m.emoji,
                              style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 8),
                          Text(
                            m.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (final p in particles) {
      // Particles fly outward and fade.
      final dist = p.speed * progress;
      final dx = center.dx + cos(p.angle) * dist;
      final dy = center.dy + sin(p.angle) * dist;
      final opacity = (1 - progress).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      // Spark as a small elongated streak.
      final tail = Offset(
        dx - cos(p.angle) * p.size * 2,
        dy - sin(p.angle) * p.size * 2,
      );
      paint.strokeWidth = p.size;
      paint.strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(dx, dy), tail, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) =>
      old.progress != progress;
}

class _ConfettiPiece {
  final double x; // 0..1 horizontal start
  final Color color;
  final double size;
  final double rotationSpeed;
  final double fallDelay; // 0..0.3
  final double drift;
  _ConfettiPiece({
    required this.x,
    required this.color,
    required this.size,
    required this.rotationSpeed,
    required this.fallDelay,
    required this.drift,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double progress;
  _ConfettiPainter({required this.pieces, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in pieces) {
      final p = (progress - c.fallDelay).clamp(0.0, 1.0);
      if (p <= 0) continue;
      final y = p * (size.height + 40);
      final x = size.width * c.x + c.drift * size.width * p;
      final rotation = p * c.rotationSpeed * pi;
      final opacity = p < 0.85 ? 1.0 : (1 - (p - 0.85) / 0.15);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      final paint = Paint()..color = c.color.withValues(alpha: opacity);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: c.size, height: c.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress;
}
