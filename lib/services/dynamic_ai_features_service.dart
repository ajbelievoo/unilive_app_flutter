/// Dynamic AI features service — wires up the three "dynamic" features
/// driven by the Master AI Control Engine:
///
///  1. **3D Gift Trigger** (`ai_3d_gift_trigger`): listens to host mic
///     audio; when the host says a trigger word (e.g. "Wow", "Thank you")
///     right after receiving a high-tier gift, fire a Lottie / 3D canvas
///     animation on screen.
///  2. **PK Battle Matchmaker** (`ai_pk_matchmaker`): one-click matchmaking
///     trigger that calls the backend random-PK endpoint and emits the
///     matched opponent back to the UI.
///  3. **Dynamic Coin Pricing** (`dynamic_coin_pricing`): fetches custom
///     coin packs from the backend based on the user's dynamic pricing
///     tier, falling back to the standard `/coinPlan` endpoint when the
///     feature is disabled.
///
/// All three are gated by [AIFeatureManager] so they no-op when the admin
/// disables them.
library;

import 'dart:async';

import '../models/ai_feature_model.dart';
import '../models/group_match_model.dart';
import '../models/live_user_root.dart' as live_user;
import '../models/wallet_models.dart';
import '../providers/ai_feature_manager.dart';
import '../services/api_service.dart';
import '../utils/log.dart';

/// A 3D gift trigger event fired when the host says a trigger word after
/// receiving a high-tier gift.
class Gift3DTriggerEvent {
  const Gift3DTriggerEvent({
    required this.triggerWord,
    required this.giftName,
    required this.giftCoins,
    required this.animationKey,
  });

  final String triggerWord;
  final String giftName;
  final int giftCoins;
  /// Key identifying which Lottie / 3D canvas animation to play.
  final String animationKey;
}

/// Result of a PK matchmaker request.
class PkMatchmakerResult {
  const PkMatchmakerResult({this.opponent, this.message});
  final live_user.LiveUser? opponent;
  final String? message;
  bool get success => opponent != null;
}

/// Service that drives the three dynamic AI features.
class DynamicAIFeaturesService {
  DynamicAIFeaturesService._();
  static final DynamicAIFeaturesService instance = DynamicAIFeaturesService._();

  static const String _tag = 'DynamicAI';

  // ---- 3D Gift Trigger ---------------------------------------------------

  /// Window (ms) after a high-tier gift during which a trigger word from
  /// the host fires the 3D animation.
  static const int _giftTriggerWindowMs = 15000;

  /// Default trigger words; the admin can override via feature metadata
  /// (`triggerWords` array).
  static const List<String> _defaultTriggerWords = [
    'wow', 'thank you', 'thanks', 'omg', 'amazing', 'awesome',
  ];

  /// Minimum gift coin value to be considered "high-tier".
  static const int _highTierGiftThreshold = 500;

  DateTime? _lastHighTierGiftAt;
  String? _lastGiftName;
  int _lastGiftCoins = 0;

  final _gift3DController = StreamController<Gift3DTriggerEvent>.broadcast();
  Stream<Gift3DTriggerEvent> get gift3DTriggerStream => _gift3DController.stream;

  /// Called by the live room when a high-tier gift is received.
  void onHighTierGiftReceived({
    required String giftName,
    required int giftCoins,
    required AIFeatureManager ai,
  }) {
    if (!ai.isFeatureEnabled(AIFeatureKeys.voiceTriggered3DGifts)) return;
    if (giftCoins < _highTierGiftThreshold) return;
    _lastHighTierGiftAt = DateTime.now();
    _lastGiftName = giftName;
    _lastGiftCoins = giftCoins;
    Log.d(_tag, 'high-tier gift received: $giftName ($giftCoins coins) — listening for trigger word');
  }

  /// Called by the audio-recognition pipeline when a host utterance is
  /// detected. If the utterance contains a trigger word and we're inside
  /// the gift-trigger window, fire the 3D animation event.
  ///
  /// The actual speech-to-text is intentionally pluggable: the host screen
  /// can feed recognised phrases from any on-device STT (e.g. Whisper,
  /// Vosk) or even a simple keyword-spotter. This service only owns the
  /// policy + event emission.
  void onHostUtterance(String text, AIFeatureManager ai) {
    if (!ai.isFeatureEnabled(AIFeatureKeys.voiceTriggered3DGifts)) return;
    final lastGift = _lastHighTierGiftAt;
    if (lastGift == null) return;
    final elapsed = DateTime.now().difference(lastGift).inMilliseconds;
    if (elapsed > _giftTriggerWindowMs) {
      _lastHighTierGiftAt = null;
      return;
    }
    final lower = text.toLowerCase();
    final triggers = _triggerWords(ai);
    for (final w in triggers) {
      if (lower.contains(w)) {
        final event = Gift3DTriggerEvent(
          triggerWord: w,
          giftName: _lastGiftName ?? 'gift',
          giftCoins: _lastGiftCoins,
          animationKey: _animationKeyFor(ai, w),
        );
        _gift3DController.add(event);
        Log.d(_tag, '3D gift trigger fired: word="$w" gift="${event.giftName}"');
        _lastHighTierGiftAt = null;
        return;
      }
    }
  }

  List<String> _triggerWords(AIFeatureManager ai) {
    final meta = ai.metadataFor(AIFeatureKeys.voiceTriggered3DGifts);
    final raw = meta['triggerWords'] ?? meta['trigger_words'];
    if (raw is List) {
      final words = raw.whereType<String>().map((e) => e.toLowerCase()).toList(growable: false);
      if (words.isNotEmpty) return words;
    }
    return _defaultTriggerWords;
  }

  String _animationKeyFor(AIFeatureManager ai, String word) {
    final meta = ai.metadataFor(AIFeatureKeys.voiceTriggered3DGifts);
    final map = meta['animations'];
    if (map is Map) {
      final v = map[word];
      if (v is String && v.isNotEmpty) return v;
    }
    // Default: pick by gift tier.
    if (_lastGiftCoins >= 5000) return '3d_gift_legendary';
    if (_lastGiftCoins >= 2000) return '3d_gift_epic';
    return '3d_gift_rare';
  }

  // ---- PK Battle Matchmaker ---------------------------------------------

  /// One-click PK matchmaking. Calls the backend random-PK endpoint and
  /// returns the matched opponent.
  ///
  /// Returns a [PkMatchmakerResult] with `success == false` when the
  /// feature is disabled or no opponent is available.
  Future<PkMatchmakerResult> findPkMatch({
    required String hostUserId,
    required AIFeatureManager ai,
  }) async {
    if (!ai.isAvailableForCurrentUser(AIFeatureKeys.pkBattleMatchmaker)) {
      return const PkMatchmakerResult(message: 'PK matchmaker is not available for your account.');
    }
    try {
      final res = await ApiService.getRandomPkMatch(hostUserId);
      final match = res.users.isNotEmpty ? res.users.first : null;
      if (match == null) {
        return const PkMatchmakerResult(message: 'No opponent found right now. Try again in a moment.');
      }
      return PkMatchmakerResult(opponent: match);
    } catch (e, s) {
      Log.e(_tag, 'findPkMatch failed', e, s);
      return const PkMatchmakerResult(message: 'Matchmaking failed. Please try again.');
    }
  }

  // ---- Dynamic Coin Pricing ---------------------------------------------

  /// Fetch coin packs for the current user.
  ///
  /// When `dynamic_coin_pricing` is enabled AND accessible, calls the AI
  /// pricing endpoint. Otherwise falls back to the standard [getCoinPlans]
  /// so the recharge screen always has something to show.
  Future<CoinPlanRoot> getCoinPacks({
    required String userId,
    required AIFeatureManager ai,
  }) async {
    if (!ai.isAvailableForCurrentUser(AIFeatureKeys.dynamicCoinPricing)) {
      return ApiService.getCoinPlans();
    }
    try {
      return await ApiService.getDynamicCoinPlans(userId: userId);
    } catch (e) {
      Log.w(_tag, 'dynamic coin packs failed, falling back to standard: $e');
      return ApiService.getCoinPlans();
    }
  }

  // ---- Group Room Matchmaker ---------------------------------------------

  /// One-click group room matchmaking. Calls the backend AI matchmaker
  /// endpoint and returns matched hosts with similar interests.
  ///
  /// Returns an empty result when the feature is disabled.
  Future<GroupMatchResult> findGroupMatch({
    required String hostUserId,
    required AIFeatureManager ai,
    List<String> interests = const [],
  }) async {
    if (!ai.isAvailableForCurrentUser(AIFeatureKeys.groupRoomMatchmaker)) {
      return const GroupMatchResult();
    }
    try {
      return await ApiService.matchGroupRoom(
        hostUserId: hostUserId,
        interests: interests,
      );
    } catch (e, s) {
      Log.e(_tag, 'findGroupMatch failed', e, s);
      return const GroupMatchResult();
    }
  }

  // ---- Cleanup -----------------------------------------------------------

  void dispose() {
    _gift3DController.close();
  }
}
