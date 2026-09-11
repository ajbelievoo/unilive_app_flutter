import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/const.dart';
import '../models/user_root.dart';
import '../models/setting_root.dart';
import '../utils/log.dart';

/// Ported from native `SessionManager.java`.
///
/// Wraps [SharedPreferences] to persist the logged-in user, app settings,
/// FCM token, country/city/IP, and miscellaneous boolean/string flags.
class SessionManager {
  SessionManager._(this._pref);

  static const String _tag = 'SessionManager';
  static User? _cachedUser;
  static Setting? _cachedSetting;

  final SharedPreferences _pref;
  static SessionManager? _instance;

  /// Current singleton instance, set by [create]. Useful for services that
  /// need preferences without a BuildContext (e.g., deep-link handler).
  static SessionManager? get instance => _instance;

  /// Initialise (or fetch) the singleton instance backed by SharedPreferences.
  static Future<SessionManager> create() async {
    final prefs = await SharedPreferences.getInstance();
    _instance = SessionManager._(prefs);
    return _instance!;
  }

  /// Used when [SharedPreferences.getInstance] hangs on startup.
  static SessionManager fallback() {
    _instance = SessionManager._(_EmptyPreferences());
    return _instance!;
  }

  // ---- Generic helpers ----------------------------------------------------
  void saveBool(String key, bool value) {
    _pref.setBool(key, value);
  }

  bool getBool(String key) => _pref.getBool(key) ?? false;

  void saveString(String key, String value) {
    _pref.setString(key, value);
  }

  String getString(String key) => _pref.getString(key) ?? '';

  // ---- FCM token ----------------------------------------------------------
  void saveFcmToken(String token) => _pref.setString(Const.fcmToken, token);
  String getFcmToken() => _pref.getString(Const.fcmToken) ?? '';

  // ---- Settings -----------------------------------------------------------
  void saveSetting(Setting setting) {
    _cachedSetting = setting;
    _pref.setString(Const.setting, jsonEncode(setting.toJson()));
  }

  Setting? getSetting() {
    if (_cachedSetting != null) return _cachedSetting;
    final raw = _pref.getString(Const.setting);
    if (raw == null || raw.isEmpty) return null;
    try {
      _cachedSetting = Setting.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return _cachedSetting;
    } catch (e, s) {
      Log.e(_tag, 'getSetting failed', e, s);
      return null;
    }
  }

  // ---- User ---------------------------------------------------------------
  void saveUser(User? user) {
    if (user == null) {
      _pref.remove(Const.userStr);
      _cachedUser = null;
    } else {
      _cachedUser = user;
      _pref.setString(Const.userStr, jsonEncode(user.toJson()));
    }
  }

  User? getUser() {
    if (_cachedUser != null) return _cachedUser;
    final raw = _pref.getString(Const.userStr);
    if (raw == null || raw.isEmpty || raw == 'null') return null;
    try {
      _cachedUser = User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return _cachedUser;
    } catch (e, s) {
      Log.e(_tag, 'getUser failed', e, s);
      return null;
    }
  }

  void clearUser() {
    _cachedUser = null;
    _pref.remove(Const.userStr);
    _pref.setBool(Const.isLogin, false);
  }

  // ---- Convenience accessors ---------------------------------------------
  String get userId => getUser()?.id ?? '';
  String get userName => getUser()?.name ?? '';
  String get userImage => getUser()?.image ?? '';
  String get userUniqueId => getUser()?.uniqueId ?? '';
  bool get isUserHost => getUser()?.isHost ?? false;
  bool get isUserVip => getUser()?.isVIP ?? false;
  bool get isLoggedIn => getBool(Const.isLogin);

  /// Convenience getter for user's diamond balance (reads `coin` field —
  /// backend merges coin/diamond into a single synced field, Option A).
  int get diamonds => getUser()?.coin.toInt() ?? 0;

  /// Alias for [userName].
  String get name => userName;

  /// Convenience getter for user's coin balance.
  int get coins => getUser()?.coin.toInt() ?? 0;

  /// Convenience getter for user's R-coin balance.
  int get rCoins => getUser()?.rCoin ?? 0;

  /// Convenience getter for the auth token.
  String? get token => getUser()?.token;

  // ---- Country / City / IP -----------------------------------------------
  void saveCountry(String value) => saveString(Const.country, value);
  String getCountry() => getString(Const.country);

  void saveCity(String value) => saveString(Const.currentCity, value);
  String getCity() => getString(Const.currentCity);

  void saveIpAddress(String value) => saveString(Const.ipAddress, value);
  String getIpAddress() => getString(Const.ipAddress);

  // ---- Search history -----------------------------------------------------
  /// Persist the search history as a JSON-encoded list of strings.
  void saveSearchHistory(List<String> history) {
    _pref.setString(Const.searchHistory, jsonEncode(history));
  }

  /// Retrieve the search history as a list of strings (most-recent first).
  List<String> getSearchHistory() {
    final raw = _pref.getString(Const.searchHistory);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<String>();
    } catch (e) {
      Log.w(_tag, 'getSearchHistory decode failed: $e');
      return [];
    }
  }

  /// Add a single search term to the history (deduped, most-recent first,
  /// capped at 20 entries).
  void addSearchHistory(String term) {
    if (term.trim().isEmpty) return;
    final list = getSearchHistory();
    list.removeWhere((e) => e.toLowerCase() == term.toLowerCase());
    list.insert(0, term);
    if (list.length > 20) list.removeRange(20, list.length);
    saveSearchHistory(list);
  }

  /// Clear all search history.
  void clearSearchHistory() {
    _pref.remove(Const.searchHistory);
  }

  // ---- Login state --------------------------------------------------------
  /// Mark the user as logged-in in SharedPreferences.
  set isLoggedIn(bool value) {
    _pref.setBool(Const.isLogin, value);
  }

  /// Explicit setter alias for [isLoggedIn].
  void setLoggedIn(bool value) {
    _pref.setBool(Const.isLogin, value);
  }

  // ---- Notification state -------------------------------------------------
  void saveNotification(bool value) => saveBool(Const.isNotification, value);
  bool getNotification() {
    final v = _pref.getBool(Const.isNotification);
    return v ?? true;
  }

  // ---- Policy acceptance --------------------------------------------------
  void savePolicyAccepted(bool value) => saveBool(Const.policyAccepted, value);
  bool getPolicyAccepted() => getBool(Const.policyAccepted);

  // ---- Maintenance mode ---------------------------------------------------
  void saveMaintenanceMode(bool value) => saveBool(Const.maintenanceMode, value);
  bool getMaintenanceMode() => getBool(Const.maintenanceMode);

  // ---- Logout -------------------------------------------------------------
  /// Clear all user-related data and mark as logged-out.
  ///
  /// Does **not** clear settings, country/city/IP, or FCM token — those
  /// persist across logins so the next login is faster.
  void logout() {
    clearUser();
    _pref.setBool(Const.isLogin, false);
    _cachedUser = null;
    Log.d(_tag, 'logout — user data cleared');
  }

  /// Full reset — clears everything including settings and FCM token.
  /// Used when the user explicitly asks to clear all data.
  Future<void> clearAll() async {
    _cachedUser = null;
    _cachedSetting = null;
    await _pref.clear();
    Log.d(_tag, 'clearAll — all preferences cleared');
  }

  // ---- Referral -----------------------------------------------------------
  void savePendingReferralCode(String code) {
    _pref.setString(Const.referralCode, code);
    Log.d(_tag, 'pending referral code saved: $code');
  }

  String? getPendingReferralCode() {
    return _pref.getString(Const.referralCode);
  }

  void clearPendingReferralCode() {
    _pref.remove(Const.referralCode);
  }

  String get _hostRequestSubmittedKey => '${Const.hostRequestSubmitted}_$userId';

  bool get hostRequestSubmitted => getBool(_hostRequestSubmittedKey);

  set hostRequestSubmitted(bool value) => saveBool(_hostRequestSubmittedKey, value);
}

/// Minimal [SharedPreferences] implementation used as a fallback when the
/// real SharedPreferences instance cannot be obtained on startup.
class _EmptyPreferences implements SharedPreferences {
  @override
  Future<bool> clear() async => true;

  @override
  bool containsKey(String key) => false;

  @override
  Object? get(String key) => null;

  @override
  bool? getBool(String key) => null;

  @override
  double? getDouble(String key) => null;

  @override
  int? getInt(String key) => null;

  @override
  Set<String> getKeys() => const {};

  @override
  String? getString(String key) => null;

  @override
  List<String>? getStringList(String key) => null;

  @override
  Future<void> reload() async {}

  @override
  Future<bool> remove(String key) async => true;

  @override
  Future<bool> setBool(String key, bool value) async => true;

  @override
  Future<bool> setDouble(String key, double value) async => true;

  @override
  Future<bool> setInt(String key, int value) async => true;

  @override
  Future<bool> setString(String key, String value) async => true;

  @override
  Future<bool> setStringList(String key, List<String> value) async => true;

  @override
  Future<bool> commit() async => true;
}
