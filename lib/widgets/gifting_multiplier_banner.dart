/// AI Live Gifting Multiplier — shows a "2X Diamond Multiplier" banner
/// during high-energy moments (PK battles, gift spikes) to accelerate gifting.
///
/// Feature key: `ai_live_gifting_multiplier`
///
/// Logic:
///  - When PK battle is active OR host earnings spike rapidly, show a
///    floating "2X MULTIPLIER" banner for 30 seconds.
///  - The banner includes a countdown timer.
///  - Gated by [AIFeatureManager] — no-op when the feature is disabled.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ai_feature_manager.dart';
import '../models/ai_feature_model.dart';

/// Controller that manages the gifting multiplier state.
class GiftingMultiplierController extends ChangeNotifier {
  bool _active = false;
  double _multiplier = 2.0;
  int _secondsLeft = 0;
  Timer? _timer;

  bool get active => _active;
  double get multiplier => _multiplier;
  int get secondsLeft => _secondsLeft;
  String get multiplierLabel => '${_multiplier.toStringAsFixed(0)}X';

  /// Activate the multiplier for [duration] seconds.
  void activate({double multiplier = 2.0, int duration = 30}) {
    _multiplier = multiplier;
    _secondsLeft = duration;
    _active = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      _secondsLeft--;
      if (_secondsLeft <= 0) {
        _active = false;
        t.cancel();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  /// Auto-activate when PK battle starts.
  void onPkStart() {
    activate(multiplier: 2.0, duration: 60);
  }

  /// Auto-activate on gift spike (many gifts in short time).
  void onGiftSpike() {
    if (!_active) {
      activate(multiplier: 2.0, duration: 30);
    }
  }

  void deactivate() {
    _active = false;
    _secondsLeft = 0;
    _timer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Banner widget showing the active multiplier.
class GiftingMultiplierBanner extends StatefulWidget {
  const GiftingMultiplierBanner({super.key, required this.controller});
  final GiftingMultiplierController controller;

  @override
  State<GiftingMultiplierBanner> createState() => _GiftingMultiplierBannerState();
}

class _GiftingMultiplierBannerState extends State<GiftingMultiplierBanner> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AIFeatureManager>();

    // Gate: feature must be enabled.
    if (!ai.isFeatureEnabled(AIFeatureKeys.liveGiftingMultiplier)) {
      return const SizedBox.shrink();
    }

    if (!widget.controller.active) return const SizedBox.shrink();

    return Positioned(
      top: MediaQuery.of(context).viewPadding.top + 56,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.5),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flash_on, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                '${widget.controller.multiplierLabel} DIAMOND MULTIPLIER',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.controller.secondsLeft}s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
