/// Call configuration model — fetched from backend admin panel.
///
/// The backend Control Center exposes a GET /call/config endpoint that
/// returns all the admin-configurable settings for the video call system
/// (free trial, billing, feature flags, etc.). This model parses that
/// response so the Flutter client uses dynamic values instead of hardcoded
/// constants.
library;

import 'json_annotation_helper.dart';

class CallConfigRoot {
  CallConfigRoot({
    this.status = false,
    this.config,
  });

  final bool status;
  final CallConfig? config;

  factory CallConfigRoot.fromJson(Map<String, dynamic> json) {
    return CallConfigRoot(
      status: parseBool(json['status']),
      config: json['data'] is Map<String, dynamic>
          ? CallConfig.fromJson(json['data'])
          : json['config'] is Map<String, dynamic>
              ? CallConfig.fromJson(json['config'])
              : null,
    );
  }
}

class CallConfig {
  const CallConfig({
    this.freeTrialEnabled = true,
    this.freeTrialSeconds = 15,
    this.vipFreeTrialSeconds = 0,
    this.fallbackCallRate = 50,
    this.audioCallDiscountPercent = 70,
    this.deductionIntervalSec = 10,
    this.minBalanceMinutes = 1,
    this.lowBalanceWarningSec = 30,
    this.criticalBalanceSec = 10,
    this.autoDisconnectOnLowBalance = true,
    this.missedCallNotificationEnabled = true,
    this.callTimeoutSec = 45,
    this.callAgainCooldownSec = 0,
    this.dndEnabled = true,
    this.dndAutoDeclineMessage = 'User is on Do Not Disturb',
    // Phase 2 feature flags
    this.callChatEnabled = true,
    this.virtualBackgroundEnabled = true,
    this.backgroundMusicEnabled = true,
    this.voiceWaveEnabled = true,
    this.qualitySettingsEnabled = true,
    this.pipModeEnabled = true,
    this.vipFrameInCallEnabled = true,
    this.vipDetailsInCallRequest = false,
    // Phase 3 feature flags
    this.blockFromCallingEnabled = true,
    this.callScreenshotEnabled = true,
    this.callDeepLinkEnabled = true,
    this.callTimerMilestonesEnabled = true,
    this.callTimerMilestones = '5,10,30,60,120',
    this.callRatingReviewEnabled = true,
    this.callReviewMaxChars = 300,
    this.autoAnswerVipEnabled = true,
    this.autoAnswerVipMinTier = 1,
    this.screenSharingEnabled = true,
    this.callThemesEnabled = true,
    this.callMiniGamesEnabled = true,
    this.callFiltersEnabled = true,
    this.privacyGuardEnabled = true,
    this.callRecordingEnabled = false,
    this.callHighlightsEnabled = false,
    this.callTranslationEnabled = false,
    this.callTranscriptionEnabled = false,
    this.callSchedulingEnabled = false,
  });

  // Phase 1 — Free trial
  final bool freeTrialEnabled;
  final int freeTrialSeconds;
  final int vipFreeTrialSeconds; // 0 = use default

  // Phase 1 — Billing
  /// Fallback call rate (coins/min) used when host has no level rate.
  /// Primary rate comes from Host Level → `getHostCallRate` API.
  final int fallbackCallRate;
  /// Audio discount percentage (0-100). Audio rate = video rate × (100 - this) / 100.
  /// Default 70 → audio rate = 30% of video rate.
  final int audioCallDiscountPercent;
  final int deductionIntervalSec;
  final int minBalanceMinutes;
  final int lowBalanceWarningSec;
  final int criticalBalanceSec;
  final bool autoDisconnectOnLowBalance;

  // Phase 1 — Missed call
  final bool missedCallNotificationEnabled;
  final int callTimeoutSec;
  final int callAgainCooldownSec;

  // Phase 1 — DND
  final bool dndEnabled;
  final String dndAutoDeclineMessage;

  // Phase 2 — Feature flags
  final bool callChatEnabled;
  final bool virtualBackgroundEnabled;
  final bool backgroundMusicEnabled;
  final bool voiceWaveEnabled;
  final bool qualitySettingsEnabled;
  final bool pipModeEnabled;
  final bool vipFrameInCallEnabled;
  final bool vipDetailsInCallRequest;

  // Phase 3 — Feature flags
  final bool blockFromCallingEnabled;
  final bool callScreenshotEnabled;
  final bool callDeepLinkEnabled;
  final bool callTimerMilestonesEnabled;
  final String callTimerMilestones;
  final bool callRatingReviewEnabled;
  final int callReviewMaxChars;
  final bool autoAnswerVipEnabled;
  final int autoAnswerVipMinTier;
  final bool screenSharingEnabled;
  final bool callThemesEnabled;
  final bool callMiniGamesEnabled;
  final bool callFiltersEnabled;

  // Privacy guard for 1-on-1 calls: hide remote stream if local face is gone.
  final bool privacyGuardEnabled;

  // Phase 3 — Backend-gated
  final bool callRecordingEnabled;
  final bool callHighlightsEnabled;
  final bool callTranslationEnabled;
  final bool callTranscriptionEnabled;
  final bool callSchedulingEnabled;

  /// Parse the milestone string "5,10,30,60,120" into a list of ints.
  List<int> get milestoneMinutes {
    return callTimerMilestones
        .split(',')
        .map((s) => int.tryParse(s.trim()) ?? 0)
        .where((n) => n > 0)
        .toList();
  }

  factory CallConfig.fromJson(Map<String, dynamic> json) {
    return CallConfig(
      // Phase 1
      freeTrialEnabled: parseBool(json['freeTrialEnabled'] ?? true),
      freeTrialSeconds: parseInt(json['freeTrialSeconds'], 15),
      vipFreeTrialSeconds: parseInt(json['vipFreeTrialSeconds'], 0),
      fallbackCallRate: parseInt(json['fallbackCallRate'], 50),
      audioCallDiscountPercent: parseInt(json['audioCallDiscountPercent'], 70),
      deductionIntervalSec: parseInt(json['deductionIntervalSec'], 10),
      minBalanceMinutes: parseInt(json['minBalanceMinutes'], 1),
      lowBalanceWarningSec: parseInt(json['lowBalanceWarningSec'], 30),
      criticalBalanceSec: parseInt(json['criticalBalanceSec'], 10),
      autoDisconnectOnLowBalance: parseBool(json['autoDisconnectOnLowBalance'] ?? true),
      missedCallNotificationEnabled: parseBool(json['missedCallNotificationEnabled'] ?? true),
      callTimeoutSec: parseInt(json['callTimeoutSec'], 45),
      callAgainCooldownSec: parseInt(json['callAgainCooldownSec'], 0),
      dndEnabled: parseBool(json['dndEnabled'] ?? true),
      dndAutoDeclineMessage: parseString(json['dndAutoDeclineMessage']) ?? 'User is on Do Not Disturb',
      // Phase 2
      callChatEnabled: parseBool(json['callChatEnabled'] ?? true),
      virtualBackgroundEnabled: parseBool(json['virtualBackgroundEnabled'] ?? true),
      backgroundMusicEnabled: parseBool(json['backgroundMusicEnabled'] ?? true),
      voiceWaveEnabled: parseBool(json['voiceWaveEnabled'] ?? true),
      qualitySettingsEnabled: parseBool(json['qualitySettingsEnabled'] ?? true),
      pipModeEnabled: parseBool(json['pipModeEnabled'] ?? true),
      vipFrameInCallEnabled: parseBool(json['vipFrameInCallEnabled'] ?? true),
      vipDetailsInCallRequest: parseBool(json['vipDetailsInCallRequest'] ?? false),
      // Phase 3
      blockFromCallingEnabled: parseBool(json['blockFromCallingEnabled'] ?? true),
      callScreenshotEnabled: parseBool(json['callScreenshotEnabled'] ?? true),
      callDeepLinkEnabled: parseBool(json['callDeepLinkEnabled'] ?? true),
      callTimerMilestonesEnabled: parseBool(json['callTimerMilestonesEnabled'] ?? true),
      callTimerMilestones: parseString(json['callTimerMilestones']) ?? '5,10,30,60,120',
      callRatingReviewEnabled: parseBool(json['callRatingReviewEnabled'] ?? true),
      callReviewMaxChars: parseInt(json['callReviewMaxChars'], 300),
      autoAnswerVipEnabled: parseBool(json['autoAnswerVipEnabled'] ?? true),
      autoAnswerVipMinTier: parseInt(json['autoAnswerVipMinTier'], 1),
      screenSharingEnabled: parseBool(json['screenSharingEnabled'] ?? true),
      callThemesEnabled: parseBool(json['callThemesEnabled'] ?? true),
      callMiniGamesEnabled: parseBool(json['callMiniGamesEnabled'] ?? true),
      callFiltersEnabled: parseBool(json['callFiltersEnabled'] ?? true),
      privacyGuardEnabled: parseBool(json['privacyGuardEnabled'] ?? true),
      // Backend-gated
      callRecordingEnabled: parseBool(json['callRecordingEnabled'] ?? false),
      callHighlightsEnabled: parseBool(json['callHighlightsEnabled'] ?? false),
      callTranslationEnabled: parseBool(json['callTranslationEnabled'] ?? false),
      callTranscriptionEnabled: parseBool(json['callTranscriptionEnabled'] ?? false),
      callSchedulingEnabled: parseBool(json['callSchedulingEnabled'] ?? false),
    );
  }

  /// Default config used when the backend is unreachable.
  static CallConfig get defaultConfig => const CallConfig();
}
