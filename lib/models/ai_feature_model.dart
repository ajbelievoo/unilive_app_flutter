/// AI Feature Configuration models.
///
/// These mirror the response of the Master Admin AI Control Engine endpoint
/// `GET /api/v1/ai-config/get-active-features` as defined in
/// `FLUTTER_AI_FEATURES_INTEGRATION.md` (26 features, 14 free + 12 paid).
///
/// Each feature is described by:
///  * `featureKey`  — stable identifier (see [AIFeatureKeys]).
///  * `name`        — admin display name (informational).
///  * `category`    — `'free'` or `'paid'` (paid features carry cloud cost
///                    and must never be invoked when `is_enabled == false`).
///  * `is_enabled`  — master kill-switch.
///  * `access`      — access policy. `access.category` is the **gate type**
///                    (`all`, `level`, `vip`, `family`, `cp`, `host`) that
///                    decides which check is applied; `minLevel` and
///                    `minVipTier` are the thresholds for the `level` and
///                    `vip` gates.
///  * `ui_behavior` — how to render the feature when it is disabled or the
///                    user does not pass the gate (`hide` or `locked` +
///                    `lockedMessage`).
///
/// The backend returns `features` as a **JSON object keyed by `featureKey`**
/// (not an array). This model preserves that map shape for O(1) lookups.
library;

import 'json_annotation_helper.dart';

/// Top-level response wrapper for `get-active-features`.
class AIFeatureConfigRoot {
  AIFeatureConfigRoot({
    this.status = false,
    this.total = 0,
    this.message,
    this.features = const {},
    this.fetchedAt,
  });

  final bool status;
  final int total;
  final String? message;

  /// Map of featureKey -> feature (matches the backend's JSON object shape).
  final Map<String, AIFeature> features;

  /// Local timestamp (ms since epoch) of the last successful fetch.
  /// Mutated by the service after parsing so consumers can staleness-check.
  int? fetchedAt;

  factory AIFeatureConfigRoot.fromJson(Map<String, dynamic> json) {
    final raw = json['features'];
    final Map<String, AIFeature> map = {};
    if (raw is Map<String, dynamic>) {
      raw.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          map[key] = AIFeature.fromJson(key, value);
        } else if (value is Map) {
          map[key] = AIFeature.fromJson(key, Map<String, dynamic>.from(value));
        }
      });
    } else if (raw is List) {
      // Tolerate an array shape too: each item must contain a featureKey.
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          final key = parseString(item['featureKey'] ?? item['key'], '') ?? '';
          if (key.isNotEmpty) map[key] = AIFeature.fromJson(key, item);
        } else if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final key = parseString(m['featureKey'] ?? m['key'], '') ?? '';
          if (key.isNotEmpty) map[key] = AIFeature.fromJson(key, m);
        }
      }
    }
    return AIFeatureConfigRoot(
      status: parseBool(json['status'] ?? json['success']),
      total: parseInt(json['total'] ?? (raw is Map ? raw.length : (raw is List ? raw.length : 0))),
      message: parseString(json['message']),
      features: map,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'total': total,
        'message': message,
        'features': {for (final e in features.entries) e.key: e.value.toJson()},
        if (fetchedAt != null) 'fetchedAt': fetchedAt,
      };

  /// Empty / failed-state config (used when the API is unreachable so the
  /// client can fall back to "everything disabled" safely).
  factory AIFeatureConfigRoot.empty() => AIFeatureConfigRoot(status: false);
}

/// A single AI feature entry returned by the admin engine.
class AIFeature {
  AIFeature({
    required this.featureKey,
    this.name,
    this.category = 'free',
    this.isEnabled = false,
    this.access = const AIFeatureAccess(),
    this.uiBehavior = const AIFeatureUiBehavior(),
    this.metadata = const {},
  });

  /// Stable identifier used by the client to look up the feature.
  final String featureKey;

  /// Admin display name (informational).
  final String? name;

  /// `'free'` or `'paid'`. Paid features carry cloud cost and must never
  /// be invoked when [isEnabled] is false.
  final String category;

  /// Master kill-switch. When `false` the client MUST NOT initialise any
  /// third-party cloud SDK tied to this feature (zero cloud cost).
  final bool isEnabled;

  /// Per-user access policy. [AIFeatureAccess.category] is the **gate type**
  /// (`all`, `level`, `vip`, `family`, `cp`, `host`) that decides which
  /// check is applied.
  final AIFeatureAccess access;

  /// UI behaviour to apply when the feature is disabled or the user does
  /// not pass the [access] gate.
  final AIFeatureUiBehavior uiBehavior;

  /// Free-form admin metadata (e.g. trigger words for 3D gifts). Stored
  /// as-is for feature-specific consumers. Not part of the core contract.
  final Map<String, dynamic> metadata;

  bool get isFree => category == 'free';
  bool get isPaid => category == 'paid';

  factory AIFeature.fromJson(String key, Map<String, dynamic> json) {
    final accessJson = json['access'];
    final uiJson = json['ui_behavior'] ?? json['uiBehavior'];
    final meta = json['metadata'] ?? json['config'] ?? json['settings'];
    return AIFeature(
      featureKey: parseString(json['featureKey'] ?? json['key'], key) ?? key,
      name: parseString(json['name']),
      category: parseString(json['category'], 'free') ?? 'free',
      isEnabled: parseBool(json['is_enabled'] ?? json['isEnabled']),
      access: accessJson is Map<String, dynamic>
          ? AIFeatureAccess.fromJson(accessJson)
          : accessJson is Map
              ? AIFeatureAccess.fromJson(Map<String, dynamic>.from(accessJson))
              : const AIFeatureAccess(),
      uiBehavior: uiJson is Map<String, dynamic>
          ? AIFeatureUiBehavior.fromJson(uiJson)
          : uiJson is Map
              ? AIFeatureUiBehavior.fromJson(Map<String, dynamic>.from(uiJson))
              : const AIFeatureUiBehavior(),
      metadata: meta is Map<String, dynamic>
          ? meta
          : meta is Map
              ? Map<String, dynamic>.from(meta)
              : const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'featureKey': featureKey,
        'name': name,
        'category': category,
        'is_enabled': isEnabled,
        'access': access.toJson(),
        'ui_behavior': uiBehavior.toJson(),
        'metadata': metadata,
      };
}

/// Access policy for a feature.
///
/// [category] is the **gate type** that decides which check is applied:
///  * `'all'`    — everyone passes.
///  * `'level'`  — user level must be >= [minLevel].
///  * `'vip'`    — user must be VIP with tier >= [minVipTier].
///  * `'family'` — user must be a family member.
///  * `'cp'`     — user must have an active CP (couple).
///  * `'host'`   — user must be a host.
///
/// `minLevel` and `minVipTier` are only consulted for the `level` and `vip`
/// gates respectively; the other gates are boolean membership checks.
class AIFeatureAccess {
  const AIFeatureAccess({
    this.category = 'all',
    this.minLevel = 0,
    this.minVipTier = 0,
  });

  final String category;
  final int minLevel;
  final int minVipTier;

  factory AIFeatureAccess.fromJson(Map<String, dynamic> json) =>
      AIFeatureAccess(
        category: parseString(json['category'], 'all') ?? 'all',
        minLevel: parseInt(json['minLevel'] ?? json['min_level']),
        minVipTier: parseInt(json['minVipTier'] ?? json['min_vip_tier'] ?? json['vipTier']),
      );

  Map<String, dynamic> toJson() => {
        'category': category,
        'minLevel': minLevel,
        'minVipTier': minVipTier,
      };
}

/// UI behaviour to apply when a feature is not available to the user.
class AIFeatureUiBehavior {
  const AIFeatureUiBehavior({
    this.disabledBehavior = 'hide',
    this.lockedMessage,
    this.lockedAction,
  });

  /// One of `'hide'` or `'locked'`.
  ///
  /// - `hide`: the feature button/icon is removed from the UI entirely.
  /// - `locked`: the button is shown with a lock badge; tapping it shows a
  ///   toast/snackbar with [lockedMessage].
  final String disabledBehavior;

  /// Message shown when the locked button is tapped (e.g.
  /// "Upgrade to VIP Tier 2 to unlock").
  final String? lockedMessage;

  /// Optional deep-link / route the locked toast should offer as an action
  /// (e.g. `vip` to open the VIP screen). Not part of the core backend
  /// contract but tolerated if present.
  final String? lockedAction;

  bool get shouldHide => disabledBehavior == 'hide';
  bool get showLocked => disabledBehavior == 'locked';

  factory AIFeatureUiBehavior.fromJson(Map<String, dynamic> json) =>
      AIFeatureUiBehavior(
        disabledBehavior:
            parseString(json['disabledBehavior'] ?? json['disabled_behavior'], 'hide') ?? 'hide',
        lockedMessage: parseString(
            json['lockedMessage'] ?? json['locked_message'],
            'This feature is currently unavailable'),
        lockedAction: parseString(json['lockedAction'] ?? json['locked_action']),
      );

  Map<String, dynamic> toJson() => {
        'disabledBehavior': disabledBehavior,
        'lockedMessage': lockedMessage,
        'lockedAction': lockedAction,
      };
}

/// Well-known feature keys used across the app — matches the 26 keys in
/// `FLUTTER_AI_FEATURES_INTEGRATION.md` exactly.
class AIFeatureKeys {
  AIFeatureKeys._();

  // ---- Free (14) --------------------------------------------------------
  /// AI Host Compliance & Live Presence Guard (on-device face detection).
  static const String hostComplianceGuard = 'ai_host_compliance_guard';

  /// Voice-triggered 3D gifts (host says a trigger word after high-tier gift).
  static const String voiceTriggered3DGifts = 'ai_voice_triggered_3d_gifts';

  /// PK battle 1-click matchmaker.
  static const String pkBattleMatchmaker = 'ai_pk_battle_matchmaker';

  /// Smart recommendation feed.
  static const String smartRecommendationFeed = 'ai_smart_recommendation_feed';

  /// Agora real-time AI voice changer extension.
  static const String voiceChanger = 'ai_realtime_voice_changer';

  /// Dynamic gift predictor.
  static const String dynamicGiftPredictor = 'ai_dynamic_gift_predictor';

  /// Karaoke pitch corrector.
  static const String karaokePitchCorrector = 'ai_karaoke_pitch_corrector';

  /// VIP churn predictor.
  static const String vipChurnPredictor = 'ai_vip_churn_predictor';

  /// Smart push notifications.
  static const String smartPushNotifications = 'ai_smart_push_notifications';

  /// Live gifting multiplier.
  static const String liveGiftingMultiplier = 'ai_live_gifting_multiplier';

  /// Auto social publisher.
  static const String autoSocialPublisher = 'ai_auto_social_publisher';

  /// Agora 3D spatial audio extension.
  static const String spatialAudio = 'ai_3d_spatial_audio';

  /// Dynamic per-user coin pack pricing.
  static const String dynamicCoinPricing = 'ai_dynamic_coin_pricing';

  /// Group room matchmaker.
  static const String groupRoomMatchmaker = 'ai_group_room_matchmaker';

  // ---- Paid (12) --------------------------------------------------------
  /// AI Virtual Bot Host.
  static const String virtualBotHost = 'ai_virtual_bot_host';

  /// AI real-time beauty & makeup (cloud).
  static const String beautyMakeup = 'ai_realtime_beauty_makeup';

  /// AI live background swap (cloud).
  static const String liveBackgroundSwap = 'ai_live_background_swap';

  /// AI VIP viewer voice greeting (cloud TTS).
  static const String vipViewerVoiceGreeting = 'ai_vip_viewer_voice_greeting';

  /// AI live audience sentiment (cloud).
  static const String liveAudienceSentiment = 'ai_live_audience_sentiment';

  /// AI voice search & discovery (cloud).
  static const String voiceSearchDiscovery = 'ai_voice_search_discovery';

  /// AI deepfake impersonation shield (cloud).
  static const String deepfakeImpersonationShield = 'ai_deepfake_impersonation_shield';

  /// AI nudity & abuse blocker (cloud moderation).
  static const String nudityAbuseBlocker = 'ai_nudity_abuse_blocker';

  /// AI noise suppression (Agora AINS, cloud).
  static const String noiseSuppression = 'ai_noise_suppression';

  /// AI personal host digital twin (cloud).
  static const String personalHostDigitalTwin = 'ai_personal_host_digital_twin';

  /// AI smart video clips / reels (cloud).
  static const String smartVideoClipsReels = 'ai_smart_video_clips_reels';

  /// AI live translation & subtitles (cloud, highest cost).
  static const String liveTranslationSubtitles = 'ai_live_translation_subtitles';

  // ---- Bigo-parity features (admin-toggleable) ---------------------------
  /// AR face stickers / masks / animoji (real-time face tracking).
  static const String arFaceStickers = 'ai_ar_face_stickers';

  /// Game LIVE / screen share broadcast mode.
  static const String gameLiveScreenShare = 'ai_game_live_screen_share';

  /// Virtual avatar / VTuber faceless mode.
  static const String virtualAvatar = 'ai_virtual_avatar';

  /// Co-watch / watch-together (shared video playback in room).
  static const String coWatch = 'ai_co_watch';

  /// Draw and Guess interactive multi-guest game.
  static const String drawAndGuess = 'ai_draw_and_guess';

  /// Voice emoji (visual + audio combo in audio rooms).
  static const String voiceEmoji = 'ai_voice_emoji';

  /// Live events / contests / talent shows platform.
  static const String liveEvents = 'ai_live_events';

  /// Fan club / fan community / supporter tiers.
  static const String fanClub = 'ai_fan_club';
}
