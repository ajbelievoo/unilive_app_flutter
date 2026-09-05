import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LuckyBagHistoryEntry {
  const LuckyBagHistoryEntry({
    required this.id,
    required this.bagId,
    required this.liveStreamingId,
    required this.userId,
    required this.name,
    required this.image,
    required this.coins,
    required this.bagCount,
    required this.kind,
    required this.createdAt,
  });

  final String id;
  final String bagId;
  final String liveStreamingId;
  final String userId;
  final String name;
  final String image;
  final int coins;
  final int bagCount;
  final String kind;
  final DateTime createdAt;

  bool get isClaim => kind == 'claimed';

  factory LuckyBagHistoryEntry.fromJson(Map<String, dynamic> json) {
    return LuckyBagHistoryEntry(
      id: json['id']?.toString() ?? '',
      bagId: json['bagId']?.toString() ?? '',
      liveStreamingId: json['liveStreamingId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'User',
      image: json['image']?.toString() ?? '',
      coins: _int(json['coins'] ?? json['coin'] ?? json['totalCoins']),
      bagCount: _int(json['bagCount']),
      kind: json['kind']?.toString() ?? 'claimed',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'bagId': bagId,
    'liveStreamingId': liveStreamingId,
    'userId': userId,
    'name': name,
    'image': image,
    'coins': coins,
    'bagCount': bagCount,
    'kind': kind,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  static int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class LuckyBagHistoryService {
  LuckyBagHistoryService._();

  static final LuckyBagHistoryService instance = LuckyBagHistoryService._();
  static const _storageKey = 'lucky_bag_history_v1';
  static const _activeStorageKey = 'active_lucky_bags_v1';

  Future<void> recordCreated(Map<String, dynamic> payload) async {
    await _record(payload, 'sent');
    await _saveActive(payload);
  }

  Future<void> recordClaimed(Map<String, dynamic> payload) async {
    await _record(payload, 'claimed');
  }

  Future<List<LuckyBagHistoryEntry>> getEntries({
    String? liveStreamingId,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final entries =
          decoded
              .whereType<Map>()
              .map(
                (item) => LuckyBagHistoryEntry.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where(
                (entry) =>
                    liveStreamingId == null ||
                    liveStreamingId.isEmpty ||
                    entry.liveStreamingId == liveStreamingId,
              )
              .toList();
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return entries;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getActive(String liveStreamingId) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_activeStorageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final payload = decoded[liveStreamingId];
      if (payload is! Map) return null;
      final active = Map<String, dynamic>.from(payload);
      final createdAt = DateTime.tryParse(
        active['createdAt']?.toString() ?? '',
      );
      if (createdAt == null) return null;
      final elapsed =
          DateTime.now().toUtc().difference(createdAt.toUtc()).inSeconds;
      if (elapsed < 0 || elapsed > 37) return null;
      active['_remainingSeconds'] = (30 - elapsed).clamp(0, 30);
      return active;
    } catch (_) {
      return null;
    }
  }

  Future<void> mergeRemote(Iterable<Map<String, dynamic>> records) async {
    for (final record in records) {
      final kind =
          record['kind']?.toString() ?? record['type']?.toString() ?? 'claimed';
      final normalizedKind = kind.toLowerCase();
      await _record(
        record,
        normalizedKind.contains('sent') || normalizedKind.contains('create')
            ? 'sent'
            : 'claimed',
      );
    }
  }

  Future<void> _saveActive(Map<String, dynamic> payload) async {
    final normalized = _unwrap(payload);
    final roomId = _string(normalized, const [
      'liveStreamingId',
      'roomId',
      'liveRoomId',
      'audioLiveId',
    ]);
    if (roomId.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_activeStorageKey);
    final active = <String, dynamic>{};
    if (raw?.isNotEmpty == true) {
      try {
        final decoded = jsonDecode(raw!);
        if (decoded is Map) active.addAll(Map<String, dynamic>.from(decoded));
      } catch (_) {}
    }
    active[roomId] = {
      ...normalized,
      'liveStreamingId': roomId,
      'createdAt':
          _string(normalized, const ['createdAt']).isNotEmpty
              ? normalized['createdAt']
              : DateTime.now().toUtc().toIso8601String(),
    };
    await preferences.setString(_activeStorageKey, jsonEncode(active));
  }

  Future<void> _record(Map<String, dynamic> payload, String kind) async {
    final unwrapped = _unwrap(payload);
    final person =
        unwrapped['user'] ?? unwrapped['claimer'] ?? unwrapped['sender'];
    final normalized =
        person is Map
            ? {...Map<String, dynamic>.from(person), ...unwrapped}
            : unwrapped;
    final roomId = _string(normalized, const [
      'liveStreamingId',
      'roomId',
      'liveRoomId',
      'audioLiveId',
    ]);
    final bagId = _string(normalized, const [
      'bagId',
      'luckyBagId',
      '_id',
      'id',
    ]);
    final userId = _string(normalized, const [
      'userId',
      'claimerId',
      'hostUserId',
      'senderId',
    ]);
    final coins = _integer(
      normalized,
      kind == 'sent'
          ? const ['totalCoins', 'totalCoin', 'coins', 'amount']
          : const ['coin', 'coins', 'rewardCoin', 'rewardCoins', 'amount'],
    );
    final createdAt =
        DateTime.tryParse(
          _string(normalized, const ['claimedAt', 'createdAt', 'timestamp']),
        ) ??
        DateTime.now().toUtc();
    final id = _string(normalized, const ['claimId', 'historyId']);
    final dedupeId = id.isNotEmpty ? id : '$kind:$bagId:$roomId:$userId:$coins';
    final entry = LuckyBagHistoryEntry(
      id: dedupeId,
      bagId: bagId,
      liveStreamingId: roomId,
      userId: userId,
      name: _string(normalized, const ['name', 'userName', 'senderName']),
      image: _string(normalized, const ['image', 'userImage', 'senderImage']),
      coins: coins,
      bagCount: _integer(normalized, const [
        'bagCount',
        'winnerCount',
        'count',
      ]),
      kind: kind,
      createdAt: createdAt,
    );

    final preferences = await SharedPreferences.getInstance();
    final existing = await getEntries();
    if (existing.any((item) => item.id == entry.id)) return;
    final updated =
        [entry, ...existing].take(500).map((item) => item.toJson()).toList();
    await preferences.setString(_storageKey, jsonEncode(updated));
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic> payload) {
    for (final key in const ['data', 'payload', 'result']) {
      final nested = payload[key];
      if (nested is Map) {
        return {...payload, ...Map<String, dynamic>.from(nested)};
      }
    }
    return payload;
  }

  String _string(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final value = payload[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  int _integer(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final value = payload[key];
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }
}
