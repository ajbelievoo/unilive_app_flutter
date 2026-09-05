/// Call configuration provider — fetches and caches the admin-configured
/// call system settings from the backend Control Center.
///
/// The provider is initialised on app launch and re-fetched periodically
/// (every 10 min) so that admin changes propagate to the client without
/// requiring an app update.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/call_config.dart';
import '../services/api_service.dart';
import '../utils/log.dart';

class CallConfigProvider extends ChangeNotifier {
  static const String _tag = 'CallConfigProvider';
  static const String _privacyGuardKey = 'call_privacy_guard_enabled';

  CallConfig _config = CallConfig.defaultConfig;
  bool _loading = false;
  Timer? _refreshTimer;
  bool _privacyGuardEnabled = true;

  /// The current call configuration. Falls back to defaults if the backend
  /// is unreachable.
  CallConfig get config => _config;

  bool get isLoading => _loading;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Fetch the config from the backend. Safe to call multiple times.
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      final res = await ApiService.getCallConfig();
      if (res.status && res.config != null) {
        _config = res.config!;
        // Load the user-level toggle from SharedPreferences. If absent,
        // inherit the admin default from the backend.
        final prefs = await SharedPreferences.getInstance();
        _privacyGuardEnabled = prefs.getBool(_privacyGuardKey) ??
            _config.privacyGuardEnabled;
        Log.d(_tag, 'call config loaded: freeTrial=${_config.freeTrialSeconds}s, fallbackRate=${_config.fallbackCallRate}, audioDiscount=${_config.audioCallDiscountPercent}%');
        notifyListeners();
      }
    } catch (e) {
      Log.e(_tag, 'load failed', e);
    } finally {
      _loading = false;
    }
  }

  /// Start a periodic refresh timer (every 10 minutes).
  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 10), (_) => load());
  }

  /// Stop the periodic refresh.
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  // ---- Convenience accessors -----------------------------------------------

  int get freeTrialSeconds => _config.freeTrialEnabled ? _config.freeTrialSeconds : 0;
  int get lowBalanceWarningSec => _config.lowBalanceWarningSec;
  int get criticalBalanceSec => _config.criticalBalanceSec;
  int get callTimeoutSec => _config.callTimeoutSec;
  int get reviewMaxChars => _config.callReviewMaxChars;
  List<int> get milestoneMinutes =>
      _config.callTimerMilestonesEnabled ? _config.milestoneMinutes : [];

  // Feature flag checks
  bool get isCallChatEnabled => _config.callChatEnabled;
  bool get isVirtualBackgroundEnabled => _config.virtualBackgroundEnabled;
  bool get isBackgroundMusicEnabled => _config.backgroundMusicEnabled;
  bool get isVoiceWaveEnabled => _config.voiceWaveEnabled;
  bool get isQualitySettingsEnabled => _config.qualitySettingsEnabled;
  bool get isPipEnabled => _config.pipModeEnabled;
  bool get isVipFrameEnabled => _config.vipFrameInCallEnabled;
  bool get isBlockFromCallingEnabled => _config.blockFromCallingEnabled;
  bool get isCallScreenshotEnabled => _config.callScreenshotEnabled;
  bool get isCallDeepLinkEnabled => _config.callDeepLinkEnabled;
  bool get isCallRatingReviewEnabled => _config.callRatingReviewEnabled;
  bool get isAutoAnswerVipEnabled => _config.autoAnswerVipEnabled;
  int get autoAnswerMinVipTier => _config.autoAnswerVipMinTier;
  bool get isScreenSharingEnabled => _config.screenSharingEnabled;
  bool get isCallThemesEnabled => _config.callThemesEnabled;
  bool get isCallMiniGamesEnabled => _config.callMiniGamesEnabled;
  bool get isCallFiltersEnabled => _config.callFiltersEnabled;

  /// Whether the face-privacy guard is enabled (remote stream hidden when
  /// local face is not detected). User toggle is persisted locally and
  /// overrides the admin default.
  bool get privacyGuardEnabled => _privacyGuardEnabled;

  Future<void> setPrivacyGuardEnabled(bool value) async {
    _privacyGuardEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyGuardKey, value);
    notifyListeners();
  }

  bool get isCallRecordingEnabled => _config.callRecordingEnabled;
}
