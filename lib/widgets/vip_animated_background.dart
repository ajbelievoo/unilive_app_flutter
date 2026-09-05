/// Animated, colorful, glassmorphic VIP background.
///
/// Renders (bottom -> top):
///   1. Optional API background image (per-tier) with crossfade
///   2. A slowly rotating, tier-tinted multi-hue gradient wash
///   3. Floating, blurred "neon orbs" tinted with the tier stroke color
///   4. A frosted-glass darkening overlay (BackdropFilter blur)
///
/// Used by [VipScreen].
library vip_animated_background;

import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../utils/media_utils.dart';

class VipAnimatedBackground extends StatefulWidget {
  const VipAnimatedBackground({
    super.key,
    required this.gradientColors,
    required this.strokeColor,
    this.backgroundImageUrl,
    this.blurSigma = 18,
    this.overlayOpacity = 0.55,
  });

  /// Two-tier gradient colors (e.g. gold/dark) used as the base wash.
  final List<Color> gradientColors;

  /// Tier accent color used for the floating orbs + glow.
  final Color strokeColor;

  /// Optional per-tier background image URL from the API.
  final String? backgroundImageUrl;

  final double blurSigma;
  final double overlayOpacity;

  @override
  State<VipAnimatedBackground> createState() => _VipAnimatedBackgroundState();
}

class _VipAnimatedBackgroundState extends State<VipAnimatedBackground>
    with TickerProviderStateMixin {
  late final AnimationController _hueCtrl;
  late final AnimationController _orbCtrl;
  late final Animation<double> _hue;

  @override
  void initState() {
    super.initState();
    _hueCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
    _hue = Tween<double>(begin: 0, end: 360).animate(_hueCtrl);

    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
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
    final base = widget.gradientColors;
    final stroke = widget.strokeColor;

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.topLeft,
        children: [
          // 1. Base tier gradient.
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  base.isNotEmpty ? base[0] : const Color(0xFF1A0B2E),
                  base.length > 1 ? base[1] : const Color(0xFF0D0420),
                  const Color(0xFF0A0A0A),
                  const Color(0xFF000000),
                ],
              ),
            ),
          ),

          // 2. Optional API background image (crossfade).
          if (_hasBgImage())
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                child: _buildBgImage(),
              ),
            ),

          // 3. Rotating tier-tinted colorful wash.
          AnimatedBuilder(
            animation: _hue,
            builder: (context, _) {
              final h = _hue.value;
              // Blend the tier stroke color's hue with rotating hues so the
              // wash stays on-theme but feels alive.
              final strokeHsl = HSLColor.fromColor(stroke);
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      HSLColor.fromAHSL(0.45, (strokeHsl.hue + h * 0.2) % 360, 0.7, 0.30).toColor(),
                      HSLColor.fromAHSL(0.30, (h + 90) % 360, 0.6, 0.18).toColor(),
                      HSLColor.fromAHSL(0.45, (strokeHsl.hue + h * 0.2 + 180) % 360, 0.7, 0.30).toColor(),
                      HSLColor.fromAHSL(0.30, (h + 270) % 360, 0.6, 0.18).toColor(),
                    ],
                    stops: const [0.0, 0.35, 0.7, 1.0],
                  ),
                ),
              );
            },
          ),

          // 4. Floating neon orbs — NO per-frame ImageFilter.blur.
          // The RadialGradient (fade to transparent) already creates a soft
          // glow effect. Removing ImageFilter.blur saves 4 heavy GPU blur
          // operations per frame (sigma 60-80 was killing scroll performance).
          AnimatedBuilder(
            animation: _orbCtrl,
            builder: (context, _) {
              final t = _orbCtrl.value * math.pi * 2;
              return Stack(
                alignment: Alignment.topLeft,
                children: [
                  _orb(
                    color: stroke,
                    size: size.width * 0.6,
                    top: size.height * 0.08 + math.sin(t) * 26,
                    left: -size.width * 0.2 + math.cos(t * 0.8) * 22,
                  ),
                  _orb(
                    color: base.isNotEmpty ? base[0] : stroke,
                    size: size.width * 0.55,
                    top: size.height * 0.5 + math.cos(t * 1.1) * 30,
                    right: -size.width * 0.18 + math.sin(t * 0.9) * 24,
                  ),
                  _orb(
                    color: stroke,
                    size: size.width * 0.4,
                    top: size.height * 0.75 + math.sin(t * 1.3) * 20,
                    left: size.width * 0.2 + math.cos(t * 1.2) * 18,
                  ),
                  _orb(
                    color: base.isNotEmpty ? base[0] : stroke,
                    size: size.width * 0.3,
                    top: size.height * 0.28 + math.cos(t * 0.7) * 28,
                    right: size.width * 0.24 + math.sin(t * 1.05) * 20,
                  ),
                ],
              );
            },
          ),

          // 5. Darkening overlay — solid color, no BackdropFilter.
          // BackdropFilter with sigma 18 was a full-screen GPU blur running
          // every frame. Replaced with a simple gradient overlay for performance.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: widget.overlayOpacity * 0.7),
                  Colors.black.withValues(alpha: widget.overlayOpacity * 1.1),
                  Colors.black.withValues(alpha: widget.overlayOpacity * 1.3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasBgImage() {
    final url = widget.backgroundImageUrl;
    return url != null && url.trim().isNotEmpty && url.startsWith('http') && !SvgaHelper.isSvgaUrl(url);
  }

  Widget _buildBgImage() {
    final url = widget.backgroundImageUrl!;
    return CachedNetworkImage(
      key: ValueKey('vip_bg_$url'),
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => const SizedBox.shrink(),
      errorWidget: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  Widget _orb({
    required Color color,
    required double size,
    required double top,
    double? left,
    double? right,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: 0.5),
                color.withValues(alpha: 0.15),
                color.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
