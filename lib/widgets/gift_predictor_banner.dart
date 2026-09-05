/// AI Dynamic Gift Predictor — shows smart pop-ups to free viewers
/// encouraging them to send gifts when the host is close to a milestone.
///
/// Feature key: `ai_dynamic_gift_predictor`
///
/// Logic:
///  - Tracks the host's session earnings (coins received this stream).
///  - When earnings cross a milestone threshold (e.g. 500, 1000, 5000...),
///    shows a banner to non-VIP viewers: "Host is X coins from next level!
///    Send a Rose to help!" with a quick-gift button.
///  - Gated by [AIFeatureManager] — no-op when the feature is disabled.
library;

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../providers/ai_feature_manager.dart';
import '../models/ai_feature_model.dart';

/// Milestone thresholds (in coins) at which the predictor fires.
const List<int> _kMilestones = [100, 500, 1000, 2000, 5000, 10000, 20000, 50000];

/// Controller that tracks host earnings and fires gift predictor pop-ups.
class GiftPredictorController extends ChangeNotifier {
  int _hostEarnings = 0;
  int _lastMilestoneIndex = -1;
  bool _popupVisible = false;
  String _popupText = '';
  int _coinsToNext = 0;

  int get hostEarnings => _hostEarnings;
  bool get popupVisible => _popupVisible;
  String get popupText => _popupText;
  int get coinsToNext => _coinsToNext;

  void setHostEarnings(int total) {
    _hostEarnings = total;
    _checkMilestone();
  }

  void addCoins(int coins) {
    _hostEarnings += coins;
    _checkMilestone();
  }

  void _checkMilestone() {
    // Find the next milestone we haven't announced yet.
    for (int i = 0; i < _kMilestones.length; i++) {
      final threshold = _kMilestones[i];
      if (_hostEarnings >= threshold && i > _lastMilestoneIndex) {
        _lastMilestoneIndex = i;
        // Only fire if there's a next milestone to aim for.
        if (i + 1 < _kMilestones.length) {
          final next = _kMilestones[i + 1];
          _coinsToNext = next - _hostEarnings;
          if (_coinsToNext > 0 && _coinsToNext <= 200) {
            _popupText = 'Host is only $_coinsToNext Diamonds from the next milestone! Send a gift!';
            _popupVisible = true;
            notifyListeners();
          }
        }
        return;
      }
    }
  }

  void dismissPopup() {
    _popupVisible = false;
    notifyListeners();
  }
}

/// Banner widget shown to viewers when the gift predictor fires.
/// Only shows for non-VIP viewers (VIP users already gift regularly).
class GiftPredictorBanner extends StatefulWidget {
  const GiftPredictorBanner({
    super.key,
    required this.controller,
    required this.isVip,
    required this.onQuickGift,
  });

  final GiftPredictorController controller;
  final bool isVip;
  final VoidCallback onQuickGift;

  @override
  State<GiftPredictorBanner> createState() => _GiftPredictorBannerState();
}

class _GiftPredictorBannerState extends State<GiftPredictorBanner> {
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
    if (!ai.isFeatureEnabled(AIFeatureKeys.dynamicGiftPredictor)) {
      return const SizedBox.shrink();
    }

    // Don't show to VIP users (they already gift).
    if (widget.isVip) return const SizedBox.shrink();

    if (!widget.controller.popupVisible) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;

    return Positioned(
      top: size.height * 0.35,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.controller.popupText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  widget.onQuickGift();
                  widget.controller.dismissPopup();
                  Fluttertoast.showToast(
                    msg: 'Tap a gift to send!',
                    backgroundColor: Colors.orange.shade900,
                    textColor: Colors.white,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Gift',
                    style: TextStyle(
                      color: Color(0xFFFF3D00),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => widget.controller.dismissPopup(),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, color: Colors.white54, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
