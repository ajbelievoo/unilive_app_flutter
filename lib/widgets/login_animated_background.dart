/// Animated, colorful, glassmorphic login background.
///
/// Renders (bottom -> top):
///   1. Optional looping [videoController] (falls back to a deep-purple gradient)
///   2. A slowly rotating, multi-hue conic/linear gradient wash
///   3. Floating, blurred "neon orbs" that drift around (parallax 3D feel)
///   4. A frosted-glass darkening overlay (BackdropFilter blur) so foreground
///      text stays readable while keeping the colorful motion visible behind.
///
/// Used by [LoginScreen] and [MobileLoginScreen].
library login_animated_background;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AnimatedLoginBackground extends StatefulWidget {
  const AnimatedLoginBackground({
    super.key,
    this.videoController,
    this.videoReady = false,
    this.blurSigma = 14,
    this.overlayOpacity = 0.45,
  });

  /// Optional looping video that plays underneath the colorful wash.
  final VideoPlayerController? videoController;
  final bool videoReady;

  /// Blur amount for the frosted overlay.
  final double blurSigma;

  /// How dark the frosted overlay is (0..1).
  final double overlayOpacity;

  @override
  State<AnimatedLoginBackground> createState() => _AnimatedLoginBackgroundState();
}

class _AnimatedLoginBackgroundState extends State<AnimatedLoginBackground>
    with TickerProviderStateMixin {
  late final AnimationController _hueCtrl;
  late final AnimationController _orbCtrl;
  late final Animation<double> _hue;

  static const _orbColors = [
    Color(0xFFE84393), // pink
    Color(0xFF6C5CE7), // purple
    Color(0xFF00CEC9), // teal
    Color(0xFFFDCB6E), // amber
    Color(0xFF74B9FF), // sky
  ];

  @override
  void initState() {
    super.initState();
    _hueCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    _hue = Tween<double>(begin: 0, end: 360).animate(_hueCtrl);

    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _hueCtrl.dispose();
    _orbCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.topLeft,
      children: [
        // 1. Base layer: video or gradient fallback.
        if (widget.videoReady && widget.videoController != null)
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: widget.videoController!.value.size.width,
                height: widget.videoController!.value.size.height,
                child: VideoPlayer(widget.videoController!),
              ),
            ),
          )
        else
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A0B2E), Color(0xFF0D0420)],
              ),
            ),
          ),

        // 2. Rotating colorful wash.
        AnimatedBuilder(
          animation: _hue,
          builder: (context, _) {
            final h = _hue.value;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    HSLColor.fromAHSL(0.55, h, 0.85, 0.45).toColor(),
                    HSLColor.fromAHSL(0.35, (h + 90) % 360, 0.8, 0.30).toColor(),
                    HSLColor.fromAHSL(0.55, (h + 180) % 360, 0.85, 0.45).toColor(),
                    HSLColor.fromAHSL(0.35, (h + 270) % 360, 0.8, 0.30).toColor(),
                  ],
                  stops: const [0.0, 0.35, 0.7, 1.0],
                ),
              ),
            );
          },
        ),

        // 3. Floating neon orbs (blurred for a soft 3D glow).
        AnimatedBuilder(
          animation: _orbCtrl,
          builder: (context, _) {
            final t = _orbCtrl.value * math.pi * 2;
            return Stack(
              alignment: Alignment.topLeft,
              children: [
                _orb(
                  color: _orbColors[0],
                  size: size.width * 0.55,
                  top: size.height * 0.12 + math.sin(t) * 24,
                  left: -size.width * 0.18 + math.cos(t * 0.8) * 20,
                  sigma: 60,
                ),
                _orb(
                  color: _orbColors[1],
                  size: size.width * 0.5,
                  top: size.height * 0.55 + math.cos(t * 1.1) * 30,
                  right: -size.width * 0.16 + math.sin(t * 0.9) * 22,
                  sigma: 70,
                ),
                _orb(
                  color: _orbColors[2],
                  size: size.width * 0.35,
                  top: size.height * 0.78 + math.sin(t * 1.3) * 18,
                  left: size.width * 0.18 + math.cos(t * 1.2) * 16,
                  sigma: 50,
                ),
                _orb(
                  color: _orbColors[3],
                  size: size.width * 0.28,
                  top: size.height * 0.30 + math.cos(t * 0.7) * 26,
                  right: size.width * 0.22 + math.sin(t * 1.05) * 18,
                  sigma: 55,
                ),
                _orb(
                  color: _orbColors[4],
                  size: size.width * 0.22,
                  top: size.height * 0.05 + math.sin(t * 1.5) * 14,
                  left: size.width * 0.40 + math.cos(t * 1.4) * 14,
                  sigma: 45,
                ),
              ],
            );
          },
        ),

        // 4. Frosted darkening overlay (keeps text readable).
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: widget.blurSigma, sigmaY: widget.blurSigma),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: widget.overlayOpacity * 0.7),
                  Colors.black.withValues(alpha: widget.overlayOpacity),
                  Colors.black.withValues(alpha: widget.overlayOpacity * 1.1),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _orb({
    required Color color,
    required double size,
    required double top,
    double? left,
    double? right,
    required double sigma,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.85),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
