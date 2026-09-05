/// 3D perspective tilt wrapper for the VIP hero badge.
///
/// Gently wobbles the child on X/Y axes with a perspective transform and
/// a colored glow ring behind it. Used by [VipTierPage] for the level badge.
library vip_tilt_badge;

import 'dart:math' as math;

import 'package:flutter/material.dart';

class VipTiltBadge extends StatefulWidget {
  const VipTiltBadge({
    super.key,
    required this.child,
    required this.glowColor,
    this.size = 170,
    this.glowSize = 170,
  });

  final Widget child;
  final Color glowColor;
  final double size;
  final double glowSize;

  @override
  State<VipTiltBadge> createState() => _VipTiltBadgeState();
}

class _VipTiltBadgeState extends State<VipTiltBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tilt;

  @override
  void initState() {
    super.initState();
    _tilt = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _tilt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.size,
      width: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow ring.
          Container(
            width: widget.glowSize,
            height: widget.glowSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.glowColor.withValues(alpha: 0.3),
                  blurRadius: 60,
                  spreadRadius: 15,
                ),
              ],
            ),
          ),
          // 3D tilt child.
          AnimatedBuilder(
            animation: _tilt,
            builder: (context, _) {
              final v = _tilt.value;
              final rx = (v - 0.5) * 0.30; // ~ +/- 8.5deg
              final ry = math.sin(v * math.pi * 2) * 0.20;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0014) // perspective
                  ..rotateX(rx)
                  ..rotateY(ry),
                child: widget.child,
              );
            },
          ),
        ],
      ),
    );
  }
}
