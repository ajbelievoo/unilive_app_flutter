/// AIFeatureManager — global, ChangeNotifier-based state for the Master
/// Dynamic AI Control Engine.
///
/// Responsibilities:
///  * Fetch the active AI feature config on app launch (and re-fetch when
///    the user joins any live stream / audio room).
///  * Cache the config in memory + persist a small snapshot in
///    SharedPreferences so a stale config is available offline.
///  * Expose per-feature access checks that combine the master `is_enabled`
///    flag with the current user's level / VIP tier / family / CP / host
///    status, based on the feature's `access.category` gate type.
///  * Provide a strict billing guard: callers can ask "should I initialise
///    the third-party cloud SDK for this feature?" and get `false` whenever
///    `is_enabled == false`, ensuring zero cloud cost when the admin turns
///    a feature off.
///
/// Usage from widgets:
///   final ai = context.read<AIFeatureManager>();
///   if (ai.isFeatureEnabled(AIFeatureKeys.voiceChanger)) { ... }
///
/// Usage via [AIFeatureGuard] widget:
///   AIFeatureGuard(
///     featureKey: AIFeatureKeys.voiceChanger,
///     child: IconButton(...),
///   )
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_feature_model.dart';
import '../models/user_root.dart';
import '../services/ai_feature_service.dart';
import '../services/session_manager.dart';
import '../utils/log.dart';

/// Result of an access check.
enum AIFeatureState {
  /// Feature is enabled and the current user passes the access gate.
  available,

  /// Feature is enabled but the user does not pass the access gate.
  /// The UI should apply [AIFeatureUiBehavior.disabledBehavior].
  locked,

  /// Feature is disabled by the admin (master kill-switch).
  /// The UI should hide the button entirely and the app MUST NOT call any
  /// third-party cloud SDK tied to this feature.
  disabled,
}

/// Optional per-call access context. The [AIFeatureManager] can derive most
/// gates from the logged-in [User], but family/CP membership are not stored
/// on the User model, so callers may supply them via this class.
class AIAccessContext {
  const AIAccessContext({
    this.isFamilyMember,
    this.isCp,
    this.isHost,
    this.userLevel,
    this.isVip,
    this.vipTier,
  });

  final bool? isFamilyMember;
  final bool? isCp;
  final bool? isHost;
  final int? userLevel;
  final bool? isVip;
  final int? vipTier;
}

class AIFeatureManager extends ChangeNotifier {
  AIFeatureManager({SessionManager? session}) : _session = session;

  static const String _tag = 'AIFeatureManager';
  static const String _prefKey = 'ai_feature_config_cache';

  final SessionManager? _session;
  Timer? _refreshTimer;

  AIFeatureConfigRoot _config = AIFeatureConfigRoot.empty();
  AIFeatureConfigRoot get config => _config;

  /// True after the first successful fetch in this process OR a valid cache
  /// was loaded from disk. When `false`, the manager is in **fail-open**
  /// mode: all features are treated as enabled/available so the app works
  /// exactly as it did before the AI integration (i.e. the backend endpoint
  /// not being deployed yet doesn't break the app).
  bool _hasValidConfig = false;

  /// True after the first successful fetch in this process.
  bool get hasFreshConfig => _config.status && _config.features.isNotEmpty;

  /// True when the manager has a valid config (fetched or cached).
  /// When `false`, all access checks fail-open (return enabled/available).
  bool get hasValidConfig => _hasValidConfig;

  /// Map of featureKey -> feature for O(1) lookups (already a map).
  Map<String, AIFeature> get _featureMap => _config.features;

  // ---- Voice changer preset persistence ---------------------------------
  static const String _voicePresetPrefKey = 'ai_voice_changer_preset';
  String? _voiceChangerPreset;
  String? get voiceChangerPreset => _voiceChangerPreset;
  void setVoiceChangerPreset(String key) {
    _voiceChangerPreset = key;
    _persistVoicePreset(key);
  }
  Future<void> _persistVoicePreset(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_voicePresetPrefKey, key);
    } catch (_) {}
  }
  Future<void> _loadVoicePreset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _voiceChangerPreset = prefs.getString(_voicePresetPrefKey) ?? 'off';
    } catch (_) {}
  }

  // ---- Lifecycle ---------------------------------------------------------

  /// Load the cached snapshot from disk (best-effort). Call this on app
  /// startup before the first network fetch so the UI has something to
  /// render with immediately.
  Future<void> loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null || raw.isEmpty) {
        await _loadVoicePreset();
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _config = AIFeatureConfigRoot.fromJson(decoded);
        if (_config.features.isNotEmpty) {
          _hasValidConfig = true;
          Log.d(_tag, 'loaded cached AI config: ${_config.features.length} features');
        }
      }
      await _loadVoicePreset();
    } catch (e, s) {
      Log.w(_tag, 'loadCached failed: $e');
      Log.e(_tag, 'loadCached stack', e, s);
    }
  }

  /// Fetch the active features from the backend.
  ///
  /// Set [persist] to true (default) to write the result to SharedPreferences
  /// so it survives app restarts. Errors are swallowed and the previous
  /// config is retained; callers can inspect [hasFreshConfig] afterwards.
  Future<void> fetchActiveFeatures({bool persist = true}) async {
    try {
      final root = await AIFeatureService.getActiveFeatures();
      _config = root;
      if (root.features.isNotEmpty) {
        _hasValidConfig = true;
      }
      Log.d(_tag, 'fetchActiveFeatures OK: ${root.features.length} features, hasValidConfig=$_hasValidConfig');
      notifyListeners();
      if (persist) await _persist(root);
    } catch (e) {
      Log.w(_tag, 'fetchActiveFeatures failed, keeping previous config (hasValidConfig=$_hasValidConfig): $e');
    }
  }

  /// Re-fetch on room join. Same as [fetchActiveFeatures] but named for
  /// clarity at call sites (e.g. `LiveRoomScreen.initState`).
  Future<void> refreshForRoomJoin() => fetchActiveFeatures();

  Future<void> _persist(AIFeatureConfigRoot root) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(root.toJson()));
    } catch (e) {
      Log.w(_tag, 'persist failed: $e');
    }
  }

  /// Start a periodic refresh timer (e.g. every 10 minutes) so long-running
  /// sessions pick up admin changes without a restart.
  void startPeriodicRefresh({Duration interval = const Duration(minutes: 10)}) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(interval, (_) => fetchActiveFeatures());
  }

  void stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    stopPeriodicRefresh();
    super.dispose();
  }

  // ---- Access checks -----------------------------------------------------

  /// Returns the [AIFeature] for [featureKey], or `null` if absent.
  ///
  /// Returns `null` when in fail-open mode (no valid config fetched yet).
  AIFeature? feature(String featureKey) =>
      _hasValidConfig ? _featureMap[featureKey] : null;

  /// Master kill-switch check.
  ///
  /// Returns `true` only when the feature exists AND `is_enabled == true`.
  /// Use this to gate third-party cloud SDK initialisation (STRICT BILLING
  /// RULE: never call a cloud SDK when this returns false).
  ///
  /// **Fail-open:** when no valid config has been fetched yet (e.g. the
  /// backend endpoint isn't deployed), this returns `true` so the app
  /// works as it did before the AI integration.
  bool isFeatureEnabled(String featureKey) {
    if (!_hasValidConfig) return true; // fail-open
    final f = _featureMap[featureKey];
    return f != null && f.isEnabled;
  }

  /// Combined state for the current user.
  ///
  /// Resolves to [AIFeatureState.available] only when the feature is enabled
  /// AND the current user passes the access gate (per
  /// `access.category`).
  ///
  /// **Fail-open:** when no valid config has been fetched yet, returns
  /// [AIFeatureState.available] for all features so the app works as it
  /// did before the AI integration.
  AIFeatureState stateForCurrentUser(String featureKey, {AIAccessContext? context}) {
    if (!_hasValidConfig) return AIFeatureState.available; // fail-open
    final f = _featureMap[featureKey];
    if (f == null || !f.isEnabled) return AIFeatureState.disabled;
    if (_userPassesGate(f.access, context)) return AIFeatureState.available;
    return AIFeatureState.locked;
  }

  /// Convenience: true when [stateForCurrentUser] is [AIFeatureState.available].
  bool isAvailableForCurrentUser(String featureKey, {AIAccessContext? context}) =>
      stateForCurrentUser(featureKey, context: context) == AIFeatureState.available;

  /// True when the feature should be visible at all (enabled + either
  /// available or `locked` UI behaviour — i.e. not `hide`).
  ///
  /// **Fail-open:** returns `true` when no valid config has been fetched.
  bool shouldShowButton(String featureKey, {AIAccessContext? context}) {
    if (!_hasValidConfig) return true; // fail-open
    final f = _featureMap[featureKey];
    if (f == null || !f.isEnabled) return false;
    final state = stateForCurrentUser(featureKey, context: context);
    if (state == AIFeatureState.available) return true;
    // locked or disabled-by-access: respect ui_behavior
    return f.uiBehavior.showLocked;
  }

  /// The locked message to show when the user taps a locked button.
  /// Falls back to a sensible default if the admin didn't configure one.
  String lockedMessageFor(String featureKey) {
    final f = _featureMap[featureKey];
    return (f?.uiBehavior.lockedMessage?.isNotEmpty == true)
        ? f!.uiBehavior.lockedMessage!
        : 'This feature is currently unavailable';
  }

  /// Optional locked-action route name (e.g. `vip`).
  String? lockedActionFor(String featureKey) =>
      _featureMap[featureKey]?.uiBehavior.lockedAction;

  // ---- Gate evaluation --------------------------------------------------

  /// Apply the gate defined by [AIFeatureAccess.category].
  ///
  /// Gate types:
  ///  * `all`    — everyone passes.
  ///  * `level`  — user level >= access.minLevel.
  ///  * `vip`    — user is VIP AND tier >= access.minVipTier.
  ///  * `family` — caller-supplied `isFamilyMember` (not on User model).
  ///  * `cp`     — caller-supplied `isCp` (not on User model).
  ///  * `host`   — user is a host.
  bool _userPassesGate(AIFeatureAccess access, AIAccessContext? ctx) {
    final user = _session?.getUser();
    switch (access.category) {
      case 'all':
        return true;
      case 'level':
        final lvl = ctx?.userLevel ?? user?.level?.coin.toInt() ?? 0;
        return lvl >= access.minLevel;
      case 'vip':
        final isVip = ctx?.isVip ?? user?.isVIP ?? false;
        if (!isVip) return false;
        final tier = ctx?.vipTier ?? _resolveVipTier(user) ?? 0;
        return tier >= access.minVipTier;
      case 'family':
        return ctx?.isFamilyMember ?? false;
      case 'cp':
        return ctx?.isCp ?? false;
      case 'host':
        return ctx?.isHost ?? user?.isHost ?? false;
      default:
        // Unknown gate type — fail open (treat as `all`).
        return true;
    }
  }

  int? _resolveVipTier(User? user) {
    if (user == null) return null;
    final status = user.vipStatus;
    if (status != null && status.currentLevel > 0) return status.currentLevel;
    final tierId = int.tryParse(user.vip?.tierId ?? '') ?? 0;
    if (tierId > 0) return tierId;
    if (user.isVIP) return 1;
    return 0;
  }

  // ---- Feature-specific helpers ----------------------------------------

  /// Free-form metadata for a feature (e.g. trigger words for the 3D gift
  /// trigger, pricing tier id for dynamic coin packs). Returns an empty
  /// map when the feature is absent, disabled, or no valid config exists.
  Map<String, dynamic> metadataFor(String featureKey) {
    if (!_hasValidConfig) return const {};
    final f = _featureMap[featureKey];
    if (f == null || !f.isEnabled) return const {};
    return f.metadata;
  }
}
