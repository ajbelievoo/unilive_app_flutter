import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_models.dart';
import '../utils/log.dart';

/// Local cache for the in-app notification inbox.
///
/// Mirrors native `NotificationStore.java` behaviour: every push / socket
/// notification that reaches the app is persisted so the user can see it
/// later in the Notifications screen, even if the backend is temporarily
/// unavailable or the device was offline when the message arrived.
class NotificationStorage {
  NotificationStorage._();

  static const String _tag = 'NotificationStorage';
  static const String _keyPrefix = 'notification_inbox_v1_';

  /// Maximum number of notifications to keep on disk per user.
  static const int _maxStored = 200;

  static String _key(String userId) => '$_keyPrefix$userId';

  /// Load the cached inbox for [userId].
  static Future<List<NotificationItem>> load(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(userId));
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(NotificationItem.fromJson)
          .toList();
    } catch (e, s) {
      Log.e(_tag, 'load failed for $userId', e, s);
      return [];
    }
  }

  /// Persist [items] for [userId], keeping the most recent [_maxStored].
  static Future<void> save(String userId, List<NotificationItem> items) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final trimmed = items.length > _maxStored
          ? items.sublist(0, _maxStored)
          : List<NotificationItem>.from(items);
      final encoded = jsonEncode(trimmed.map((e) => e.toJson()).toList());
      await prefs.setString(_key(userId), encoded);
    } catch (e, s) {
      Log.e(_tag, 'save failed for $userId', e, s);
    }
  }

  /// Clear the cached inbox for [userId] (e.g. on logout).
  static Future<void> clear(String userId) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId));
    } catch (e, s) {
      Log.e(_tag, 'clear failed for $userId', e, s);
    }
  }
}
