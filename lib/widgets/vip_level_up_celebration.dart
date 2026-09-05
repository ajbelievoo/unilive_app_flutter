/// VIP Level-Up Celebration overlay.
///
/// Full-screen confetti + "VIP X Activated!" banner that plays after a
/// successful VIP purchase. Bigo Live style — confetti rain, gold glow,
/// tier-colored burst, and the user's new VIP badge.
library vip_level_up_celebration;

import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../utils/media_utils.dart';
import 'svga_player_widget.dart' show SvgaPlayer;

/// Shows the celebration overlay on top of the current screen.
/// Call after a successful VIP tier purchase.
void showVipLevelUpCelebration(
  BuildContext context, {
  required int vipLevel,
  String? badgeUrl,
  String? tierName,
  String? frameUrl,
  String? userImage,
  Color? tierColor,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _VipCelebrationOverlay(
      vipLevel: vipLevel,
      badgeUrl: badgeUrl,
      tierName: tierName,
      frameUrl: frameUrl,
      userImage: userImage,
      tierColor: tierColor,
      onDismiss: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _VipCelebrationOverlay extends StatefulWidget {
  const _VipCelebrationOverlay({
    required this.vipLevel,
    this.badgeUrl,
    this.tierName,
    this.frameUrl,
    this.userImage,
    this.tierColor,
    this.onDismiss,
  });

  final int vipLevel;
  final String? badgeUrl;
  final String? tierName;
  final String? frameUrl;
  final String? userImage;
  final Color? tierColor;
  final VoidCallback? onDismiss;

  @override
  State<_VipCelebrationOverlay> createState() => _VipCelebrationOverlayState();
}

class _VipCelebrationOverlayState extends State<_VipCelebrationOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final AnimationController _confettiCtrl;
  late final AnimationController _scaleCtrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final List<_ConfettiPiece> _pieces;

  static const _tierColors = [
    Color(0xFFD4A24E),
    Color(0xFFD0D0D8),
    Color(0xFFC39BD3),
    Color(0xFF52BE80),
    Color(0xFFE74C3C),
    Color(0xFFF1C40F),
    Color(0xFFF5B041),
    Color(0xFF28B463),
    Color(0xFFFFD700),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut),
    );

    final rng = math.Random();
    final accent = _tierColors[(widget.vipLevel - 1).clamp(0, _tierColors.length - 1)];
    _pieces = List.generate(80, (i) {
      final colors = [accent, const Color(0xFFFFD700), Colors.white, const Color(0xFFFF6B9D), const Color(0xFF6A5AE0)];
      return _ConfettiPiece(
        x: rng.nextDouble(),
        startY: -0.2 - rng.nextDouble() * 0.3,
        endY: 1.0 + rng.nextDouble() * 0.3,
        color: colors[rng.nextInt(colors.length)],
        size: 4 + rng.nextDouble() * 8,
        rotation: rng.nextDouble() * math.pi * 2,
        rotationSpeed: (rng.nextDouble() - 0.5) * 4,
        drift: (rng.nextDouble() - 0.5) * 0.3,
        shape: rng.nextBool() ? _ConfettiShape.rect : _ConfettiShape.circle,
      );
    });

    _fadeCtrl.forward();
    _scaleCtrl.forward();
    _confettiCtrl.repeat();

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      _fadeCtrl.reverse().then((_) {
        if (mounted) widget.onDismiss?.call();
      });
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _confettiCtrl.dispose();
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    _fadeCtrl.reverse().then((_) {
      if (mounted) widget.onDismiss?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final fallback = _tierColors[(widget.vipLevel - 1).clamp(0, _tierColors.length - 1)];
    final accent = widget.tierColor ?? fallback;

    return Positioned.fill(
      child: FadeTransition(
        opacity: _fade,
        child: Material(
          color: Colors.black.withValues(alpha: 0.75),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Stack(
              alignment: Alignment.topLeft,
              children: [
                // Confetti layer
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _confettiCtrl,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _ConfettiPainter(_pieces, _confettiCtrl.value),
                      );
                    },
                  ),
                ),

                // Center content
                Center(
                  child: ScaleTransition(
                    scale: _scale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Badge with glow
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.6),
                                blurRadius: 60,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: _buildBadge(accent),
                        ),
                        const SizedBox(height: 24),
                        // "VIP X Activated!" text
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [accent, const Color(0xFFFFD700), accent],
                          ).createShader(bounds),
                          child: Text(
                            'VIP ${widget.vipLevel} Activated!',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (widget.tierName != null)
                          Text(
                            widget.tierName!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'Enjoy your exclusive privileges',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Continue button
                        GestureDetector(
                          onTap: _dismiss,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.8)]),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: const Text(
                              'Continue',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Sparkle particles around badge
                ..._buildSparkles(size, accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(Color accent) {
    if (widget.badgeUrl != null && widget.badgeUrl!.isNotEmpty) {
      if (SvgaHelper.isSvgaUrl(widget.badgeUrl!)) {
        return SvgaPlayer(
          url: widget.badgeUrl!,
          width: 120,
          height: 120,
          allowAnimation: true,
        );
      }
      return CachedNetworkImage(
        imageUrl: widget.badgeUrl!,
        width: 120,
        height: 120,
        fit: BoxFit.contain,
        errorWidget: (_, __, ___) => _defaultBadge(accent),
      );
    }
    return _defaultBadge(accent);
  }

  Widget _defaultBadge(Color accent) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.5)]),
      ),
      child: const Icon(Icons.workspace_premium, size: 60, color: Colors.white),
    );
  }

  List<Widget> _buildSparkles(Size size, Color accent) {
    return List.generate(12, (i) {
      final angle = (i / 12) * math.pi * 2;
      final radius = 120.0 + (i % 3) * 30;
      final dx = size.width / 2 + math.cos(angle) * radius;
      final dy = size.height / 2 + math.sin(angle) * radius;
      return Positioned(
        left: dx - 6,
        top: dy - 6,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 800 + (i % 4) * 200),
          builder: (context, val, _) {
            return Opacity(
              opacity: (1 - val).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: val,
                child: Icon(Icons.star, size: 12 + (i % 3) * 4, color: accent),
              ),
            );
          },
        ),
      );
    });
  }
}

enum _ConfettiShape { rect, circle }

class _ConfettiPiece {
  _ConfettiPiece({
    required this.x,
    required this.startY,
    required this.endY,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.drift,
    required this.shape,
  });
  final double x;
  final double startY;
  final double endY;
  final Color color;
  final double size;
  final double rotation;
  final double rotationSpeed;
  final double drift;
  final _ConfettiShape shape;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.progress);
  final List<_ConfettiPiece> pieces;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final t = progress;
      final y = (p.startY + (p.endY - p.startY) * t) * size.height;
      final x = (p.x + p.drift * t) * size.width;
      final rot = p.rotation + p.rotationSpeed * t * math.pi * 2;

      final paint = Paint()..color = p.color.withValues(alpha: (1 - t * 0.5).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      if (p.shape == _ConfettiShape.rect) {
        canvas.drawRect(Offset(-p.size / 2, -p.size / 4) & Size(p.size, p.size / 2), paint);
      } else {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.progress != progress;
}
