import 'package:flutter/material.dart';
import 'svga_player_widget.dart';

/// VIP mic wave animation widget for audio room host.
///
/// Ported from native `showHostVipMicWave`. When a VIP SVGA voice wave URL
/// is available, plays the SVGA animation. Otherwise falls back to a custom
/// animated wave with gradient colors and multiple bars.
class VipMicWaveWidget extends StatefulWidget {
  final bool isSpeaking;
  final Color? waveColor;
  final int barCount;
  /// Optional SVGA URL for VIP voice wave animation.
  final String? svgaUrl;
  /// Optional explicit size. Defaults to 100.
  final double size;

  const VipMicWaveWidget({
    super.key,
    required this.isSpeaking,
    this.waveColor,
    this.barCount = 5,
    this.svgaUrl,
    this.size = 100,
  });

  @override
  State<VipMicWaveWidget> createState() => _VipMicWaveWidgetState();
}

class _VipMicWaveWidgetState extends State<VipMicWaveWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _barAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _generateBarAnimations();
    if (widget.isSpeaking) _controller.repeat();
  }

  void _generateBarAnimations() {
    _barAnimations = List.generate(widget.barCount, (i) {
      return Tween<double>(begin: 0.2, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            (i / widget.barCount) * 0.5,
            ((i / widget.barCount) * 0.5) + 0.5,
            curve: Curves.easeInOut,
          ),
        ),
      );
    });
  }

  @override
  void didUpdateWidget(VipMicWaveWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking != oldWidget.isSpeaking) {
      if (widget.isSpeaking) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSpeaking) return const SizedBox.shrink();

    // If SVGA URL is available, use SVGA player for VIP voice wave
    if (widget.svgaUrl != null && widget.svgaUrl!.isNotEmpty) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: SvgaPlayer(
            url: widget.svgaUrl,
            repeat: true,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    // Fallback: custom animated wave bars
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return SizedBox(
          width: widget.size * 0.4,
          height: widget.size * 0.25,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.barCount, (i) {
              final value = _barAnimations[i].value;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 3,
                height: 4 + (value * 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      widget.waveColor ?? const Color(0xFF7E3FF2),
                      (widget.waveColor ?? const Color(0xFF7E3FF2))
                          .withValues(alpha: 0.5),
                    ],
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
