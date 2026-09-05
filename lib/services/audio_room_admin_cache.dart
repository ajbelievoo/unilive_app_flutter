/// Local cache for audio room admin assignments.
///
/// The backend stores room admins keyed by `liveStreamingId`. When a host
/// restarts the broadcast, a new `liveStreamingId` is generated and all
/// previous admin assignments are lost. This cache persists the admin list
/// locally (keyed by host user id) so it can be re-applied automatically
/// when the host starts a new room.
library audio_room_admin_cache;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/live_moderation_sheet.dart';

class AudioRoomAdminCache {
  static const String _prefix = 'audio_room_admins_';

  /// Save the admin list for [hostUserId].
  static Future<void> saveAdmins(
    String hostUserId,
    List<AdminEntry> admins,
  ) async {
    if (hostUserId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final jsonList = admins
        .where((a) => a.adminUserId?.id != null && a.adminUserId!.id!.isNotEmpty)
        .map((a) => a.toJson())
        .toList();
    await prefs.setString('$_prefix$hostUserId', jsonEncode(jsonList));
  }

  /// Load the cached admin list for [hostUserId].
  /// Returns an empty list if none cached.
  static Future<List<AdminEntry>> loadAdmins(String hostUserId) async {
    if (hostUserId.isEmpty) return const [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$hostUserId');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((e) => AdminEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Clear the cached admin list for [hostUserId].
  static Future<void> clearAdmins(String hostUserId) async {
    if (hostUserId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$hostUserId');
  }
}
