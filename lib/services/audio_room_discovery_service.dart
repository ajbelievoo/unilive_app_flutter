/// Audio room discovery service — search, categories, trending, history.
///
/// Ports native audio room discovery features:
/// - Room search by name/host
/// - Category-based filtering (Music, Talk, Gaming, etc.)
/// - Trending/popular rooms
/// - Recently visited rooms (local history)
/// - Quick rejoin last room
/// - Scheduled rooms
library audio_room_discovery;
import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/audio_room_root.dart';
import '../services/api_service.dart';
import '../utils/log.dart';

/// Room categories — match native category types.
class RoomCategory {
  final String id;
  final String name;
  final String icon;
  final String? color;

  const RoomCategory({
    required this.id,
    required this.name,
    required this.icon,
    this.color,
  });

  static const List<RoomCategory> all = [
    RoomCategory(id: 'all', name: 'All', icon: '🎯'),
    RoomCategory(id: 'music', name: 'Music', icon: '🎵'),
    RoomCategory(id: 'talk', name: 'Talk', icon: '💬'),
    RoomCategory(id: 'gaming', name: 'Gaming', icon: '🎮'),
    RoomCategory(id: 'poetry', name: 'Poetry', icon: '📜'),
    RoomCategory(id: 'comedy', name: 'Comedy', icon: '😂'),
    RoomCategory(id: 'story', name: 'Story', icon: '📖'),
    RoomCategory(id: 'education', name: 'Education', icon: '📚'),
    RoomCategory(id: 'love', name: 'Love & Dating', icon: '❤️'),
    RoomCategory(id: 'business', name: 'Business', icon: '💼'),
  ];
}

/// Recently visited room entry (stored locally).
class RoomHistoryEntry {
  final String roomId;
  final String roomName;
  final String? hostName;
  final String? hostImage;
  final int viewerCount;
  final DateTime visitedAt;

  RoomHistoryEntry({
    required this.roomId,
    required this.roomName,
    this.hostName,
    this.hostImage,
    this.viewerCount = 0,
    required this.visitedAt,
  });

  Map<String, dynamic> toJson() => {
    'roomId': roomId,
    'roomName': roomName,
    'hostName': hostName,
    'hostImage': hostImage,
    'viewerCount': viewerCount,
    'visitedAt': visitedAt.toIso8601String(),
  };

  factory RoomHistoryEntry.fromJson(Map<String, dynamic> json) => RoomHistoryEntry(
    roomId: json['roomId']?.toString() ?? '',
    roomName: json['roomName']?.toString() ?? '',
    hostName: json['hostName']?.toString(),
    hostImage: json['hostImage']?.toString(),
    viewerCount: (json['viewerCount'] as num?)?.toInt() ?? 0,
    visitedAt: DateTime.tryParse(json['visitedAt']?.toString() ?? '') ?? DateTime.now(),
  );
}

/// Scheduled room entry.
class ScheduledRoom {
  final String id;
  final String roomName;
  final String? hostName;
  final String? hostImage;
  final DateTime scheduledAt;
  final String? category;
  final bool reminderSet;

  ScheduledRoom({
    required this.id,
    required this.roomName,
    this.hostName,
    this.hostImage,
    required this.scheduledAt,
    this.category,
    this.reminderSet = false,
  });

  factory ScheduledRoom.fromJson(Map<String, dynamic> json) => ScheduledRoom(
    id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
    roomName: json['roomName']?.toString() ?? '',
    hostName: json['hostName']?.toString(),
    hostImage: json['hostImage']?.toString(),
    scheduledAt: DateTime.tryParse(json['scheduledAt']?.toString() ?? '') ?? DateTime.now(),
    category: json['category']?.toString(),
    reminderSet: json['reminderSet'] == true,
  );
}

/// Audio room discovery service — manages search, categories, history.
class AudioRoomDiscoveryService {
  static const String _tag = 'RoomDiscovery';
  static const String _historyKey = 'audio_room_history';
  static const int _maxHistory = 20;

  /// Search audio rooms by name/host.
  static Future<List<AudioRoomUser>> searchRooms(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final res = await ApiService.getAudioRooms(type: 'All', start: 0, limit: 50);
      final all = res.rooms;
      final q = query.toLowerCase();
      return all.where((r) {
        final name = (r.roomName ?? r.name ?? '').toLowerCase();
        final host = (r.name ?? '').toLowerCase();
        final uniqueId = (r.uniqueId ?? r.roomOwnerUniqueId ?? '').toLowerCase();
        return name.contains(q) || host.contains(q) || uniqueId.contains(q);
      }).toList();
    } catch (e) {
      Log.e(_tag, 'searchRooms failed', e);
      return [];
    }
  }

  /// Get trending/popular rooms sorted by viewer count.
  static Future<List<AudioRoomUser>> getTrendingRooms({int limit = 20}) async {
    try {
      final res = await ApiService.getAudioRooms(type: 'All', start: 0, limit: 100);
      final rooms = res.rooms.toList();
      rooms.sort((a, b) => b.view.compareTo(a.view));
      return rooms.take(limit).toList();
    } catch (e) {
      Log.e(_tag, 'getTrendingRooms failed', e);
      return [];
    }
  }

  /// Get rooms by category.
  static Future<List<AudioRoomUser>> getRoomsByCategory(String categoryId, {int limit = 20}) async {
    try {
      if (categoryId == 'all') {
        return getTrendingRooms(limit: limit);
      }
      final res = await ApiService.getAudioRooms(type: categoryId, start: 0, limit: limit);
      return res.rooms;
    } catch (e) {
      Log.e(_tag, 'getRoomsByCategory failed', e);
      return [];
    }
  }

  /// Add room to local history.
  static Future<void> addToHistory(RoomHistoryEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await getHistory();
      // Remove duplicate
      history.removeWhere((e) => e.roomId == entry.roomId);
      history.insert(0, entry);
      // Trim to max
      if (history.length > _maxHistory) {
        history.removeRange(_maxHistory, history.length);
      }
      final jsonList = history.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(_historyKey, jsonList);
    } catch (e) {
      Log.e(_tag, 'addToHistory failed', e);
    }
  }

  /// Get room visit history.
  static Future<List<RoomHistoryEntry>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_historyKey) ?? [];
      return jsonList
          .map((j) => RoomHistoryEntry.fromJson(jsonDecode(j) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Log.e(_tag, 'getHistory failed', e);
      return [];
    }
  }

  /// Get last visited room for quick rejoin.
  static Future<RoomHistoryEntry?> getLastRoom() async {
    final history = await getHistory();
    return history.isNotEmpty ? history.first : null;
  }

  /// Clear room history.
  static Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (e) {
      Log.e(_tag, 'clearHistory failed', e);
    }
  }

  /// Get scheduled rooms (from API).
  static Future<List<ScheduledRoom>> getScheduledRooms() async {
    try {
      // This would call a dedicated API endpoint
      // For now, return empty — backend needs to implement /audioRoom/scheduled
      return [];
    } catch (e) {
      Log.e(_tag, 'getScheduledRooms failed', e);
      return [];
    }
  }
}
