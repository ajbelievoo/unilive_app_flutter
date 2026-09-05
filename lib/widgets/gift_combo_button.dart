/// Combo button for Lucky gifts — ports native `showComboButton()`.
///
/// When a Lucky gift is sent, native shows a combo button (`layCombo`) with:
/// - A Lottie `combo.json` pulsing animation
/// - A `RoundProgressBar` circular countdown (10 seconds)
/// - Tapping it re-sends the same gift
///
/// Since the native Lottie asset is an empty placeholder, we render an
/// equivalent animated combo button with a custom pulsing glow + circular
/// progress bar. Tapping calls [onTap] to re-send the gift.
library gift_combo_button;

import 'dart:math' show pi;

import 'package:flutter/material.dart';

/// Combo button overlay widget.
///
/// Embed in a Stack. Call [show] to display the combo button with a 10-second
/// countdown. [onTap] is called each time the user taps the button to re-send.
class GiftComboButton extends StatefulWidget {
  const GiftComboButton({
    super.key,
    required this.onTap,
    this.duration = const Duration(seconds: 10),
  });

  final VoidCallback onTap;
  final Duration duration;

  @override
  State<GiftComboButton> createState() => GiftComboButtonState();
}

class GiftComboButtonState extends State<GiftComboButton>
    with TickerProviderStateMixin {
  bool _visible = false;
  AnimationController? _progressController; // circular countdown
  AnimationController? _pulseController; // pulsing glow

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _progressController?.dispose();
    _pulseController?.dispose();
    super.dispose();
  }

  /// Show the combo button with a fresh countdown.
  void show() {
    if (!mounted) return;
    _progressController?.dispose();
    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    setState(() => _visible = true);
    _pulseController!.repeat(reverse: true);
    _progressController!.forward().then((_) {
      if (mounted) hide();
    });
  }

  /// Hide the combo button.
  void hide() {
    if (!mounted) return;
    _pulseController?.stop();
    setState(() => _visible = false);
  }

  void _handleTap() {
    widget.onTap();
    // Restart the countdown for another round.
    show();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 140,
      right: 20,
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_progressController!, _pulseController!]),
          builder: (_, __) {
            final pulse = _pulseController!.value;
            final progress = _progressController!.value;

            return SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pulsing glow background.
                  Container(
                    width: 70 + pulse * 10,
                    height: 70 + pulse * 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFFD700).withValues(alpha: 0.4 + pulse * 0.3),
                          const Color(0xFFFF6B00).withValues(alpha: 0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  // Circular progress bar (countdown).
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: CustomPaint(
                      painter: _ComboProgressPainter(
                        progress: 1.0 - progress,
                        color: const Color(0xFFFFD700),
                      ),
                    ),
                  ),
                  // Combo icon + text.
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFF6B00)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B00).withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ImageIcon(const AssetImage("assets/gift/official_gift.png"), color: Colors.white, size: 16 + pulse * 2),
                        const Text(
                          'Combo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Circular progress painter for the combo countdown.
class _ComboProgressPainter extends CustomPainter {
  _ComboProgressPainter({required this.progress, required this.color});
  final double progress; // 0.0 → 1.0 (remaining time)
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    // Background ring.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: 0.2),
    );

    // Progress arc.
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        progress * 2 * pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_ComboProgressPainter old) => old.progress != progress;
}
