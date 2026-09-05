/// Screen shake wrapper — wraps any widget and shakes it when
/// [ScreenShakeController.shake] is called.
///
/// Used by the gift system to shake the screen on big gifts and combo
/// milestones (Bigo / Chamet style). Intensity scales with gift value.
///
/// IMPORTANT: When idle (no shake in progress), this widget returns [child]
/// untouched with NO Transform — so it does not cause continuous jitter on
/// every rebuild (e.g. from live video frames).
library screen_shake_widget;

import 'dart:math';

import 'package:flutter/material.dart';

/// Controller that triggers a shake on the attached [ScreenShakeWidget].
class ScreenShakeController {
  void Function(double intensity)? _callback;

  void attach(void Function(double intensity) callback) => _callback = callback;
  void detach() => _callback = null;

  /// Shake the screen. [intensity] controls amplitude (typical 4..18).
  void shake(double intensity) => _callback?.call(intensity);
}

/// Wraps [child] and translates it with a decaying random shake when
/// [controller.shake] is called. When idle, returns [child] untouched.
class ScreenShakeWidget extends StatefulWidget {
  const ScreenShakeWidget({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScreenShakeController controller;
  final Widget child;

  @override
  State<ScreenShakeWidget> createState() => _ScreenShakeWidgetState();
}

class _ScreenShakeWidgetState extends State<ScreenShakeWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  double _intensity = 8;
  final _rng = Random();
  bool _shaking = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) setState(() => _shaking = false);
      }
    });
    widget.controller.attach(_onShake);
  }

  @override
  void dispose() {
    _controller.dispose();
    widget.controller.detach();
    super.dispose();
  }

  void _onShake(double intensity) {
    if (!mounted) return;
    _intensity = intensity;
    setState(() => _shaking = true);
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // When idle, return child untouched — NO Transform, NO jitter.
    if (!_shaking) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        final t = _controller.value;
        // Decay: amplitude drops as t → 1.
        final decay = (1 - t) * (1 - t);
        final amp = _intensity * decay;
        // If amplitude is negligible, skip transform.
        if (amp < 0.5) return child!;
        final dx = (_rng.nextDouble() - 0.5) * amp * 2;
        final dy = (_rng.nextDouble() - 0.5) * amp * 2;
        final rot = (_rng.nextDouble() - 0.5) * amp * 0.01;
        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(angle: rot, child: child),
        );
      },
      child: widget.child,
    );
  }
}
