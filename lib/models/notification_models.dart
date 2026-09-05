import 'dart:convert';

import '../utils/log.dart';
import 'json_annotation_helper.dart';

/// Ported from native `BlockedUserListRoot.java` + `BlockUserRoot.java`.
class BlockedUserListRoot {
  BlockedUserListRoot({this.status = false, this.message, this.blockedUsers = const [], this.total = 0});

  final bool status;
  final String? message;
  final List<BlockedUsersItem> blockedUsers;
  final int total;

  factory BlockedUserListRoot.fromJson(Map<String, dynamic> json) => BlockedUserListRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        blockedUsers: parseList(json['blockedUsers'], BlockedUsersItem.fromJson),
        total: parseInt(json['total'], 0),
      );
}

class BlockedUsersItem {
  BlockedUsersItem({this.id, this.toUserId});

  final String? id;
  final BlockedUser? toUserId;

  factory BlockedUsersItem.fromJson(Map<String, dynamic> json) => BlockedUsersItem(
        id: parseString(json['_id'] ?? json['id']),
        toUserId: json['toUserId'] == null ? null : BlockedUser.fromJson(json['toUserId'] as Map<String, dynamic>),
      );
}

class BlockedUser {
  BlockedUser({this.id, this.name, this.image, this.country, this.countryFlagImage, this.uniqueId});

  final String? id;
  final String? name;
  final String? image;
  final String? country;
  final String? countryFlagImage;
  final String? uniqueId;

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
        id: parseString(json['_id'] ?? json['id']),
        name: parseString(json['name']),
        image: parseString(json['image']),
        country: parseString(json['country']),
        countryFlagImage: parseString(json['countryFlagImage']),
        uniqueId: parseString(json['uniqueId']),
      );
}

/// Ported from native `NotificationRoot.java`.
class NotificationRoot {
  NotificationRoot({this.status = false, this.message, this.data = const [], this.total = 0, this.unreadCount = 0});

  final bool status;
  final String? message;
  final List<NotificationItem> data;
  final int total;
  final int unreadCount;

  factory NotificationRoot.fromJson(Map<String, dynamic> json) => NotificationRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        data: parseList(json['data'], NotificationItem.fromJson),
        total: parseInt(json['total'], 0),
        unreadCount: parseInt(json['unreadCount'], 0),
      );
}

class NotificationItem {
  NotificationItem({
    this.id,
    this.title,
    this.message,
    this.type,
    this.image,
    this.createdAt,
    this.isRead = false,
    this.actionType,
    this.actionData,
  });

  final String? id;
  final String? title;
  final String? message;
  final String? type; // MESSAGE | USER | POST | RELITE | LIVE | CALL
  final String? image;
  final String? createdAt;
  bool isRead;
  final String? actionType;
  final String? actionData;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final item = NotificationItem(
      id: parseString(json['_id'] ?? json['id']),
      title: parseString(json['title']),
      message: parseString(json['message']),
      type: parseString(json['type']),
      image: parseString(json['image']),
      createdAt: parseString(json['createdAt']),
      isRead: parseBool(json['isRead']),
      actionType: parseString(json['actionType'] ?? json['action_type']),
      actionData: _extractActionData(json),
    );
    Log.d('NotificationItem', 'parsed: type=${item.type}, actionType=${item.actionType}, actionData=${item.actionData}, title=${item.title}');
    return item;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'type': type,
        'image': image,
        'createdAt': createdAt,
        'isRead': isRead,
        'actionType': actionType,
        'actionData': actionData,
      };

  @override
  String toString() => const JsonEncoder.withIndent(' ').convert(toJson());
}

/// Backend notification payloads may carry the actionable id under many
/// different field names or nested shapes. This helper coerces all of them
/// into a single string value that [NotificationRouter] can use.
String? _extractActionData(Map<String, dynamic> json) {
  // 1. Direct actionData / action_data fields.
  final candidates = [
    json['actionData'],
    json['action_data'],
    json['payload'],
    json['data'],
  ];

  for (final v in candidates) {
    final extracted = _coerceActionData(v);
    if (extracted != null && extracted.isNotEmpty) {
      return extracted;
    }
  }

  // 2. If the whole notification object has a user/post/live id at the top level.
  final topLevelKeys = [
    'userId',
    'senderId',
    'fromUserId',
    'actorId',
    'receiverId',
    'postId',
    'reelId',
    'videoId',
    'liveStreamingId',
    'liveId',
    'roomId',
    'cpId',
    'requestId',
    'friendshipId',
    'chatTopic',
    'topic',
  ];
  for (final key in topLevelKeys) {
    final value = json[key];
    if (value != null) {
      if (value is String && value.isNotEmpty) return value;
      if (value is Map) return _coerceActionData(value);
    }
  }

  return null;
}

/// Coerces an [actionData] value that may be a plain id string, a JSON string,
/// or a map containing the id under various keys.
String? _coerceActionData(dynamic value) {
  if (value == null) return null;

  if (value is String) {
    if (value.isEmpty) return null;
    // Some backends double-encode the payload as a JSON string.
    final trimmed = value.trim();
    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      try {
        final decoded = jsonDecode(trimmed);
        return _coerceActionData(decoded);
      } catch (_) {
        // Not valid JSON, use the string as-is.
      }
    }
    return value;
  }

  if (value is Map) {
    final keys = [
      'userId',
      'senderId',
      'fromUserId',
      'actorId',
      'receiverId',
      'postId',
      'reelId',
      'videoId',
      'liveStreamingId',
      'liveId',
      'roomId',
      'cpId',
      'requestId',
      'friendshipId',
      'chatTopic',
      'topic',
      '_id',
      'id',
    ];
    for (final key in keys) {
      final inner = value[key];
      if (inner != null) {
        if (inner is String && inner.isNotEmpty) return inner;
        if (inner is Map) return _coerceActionData(inner);
      }
    }
    // Last resort: if the map itself has a single string value, use it.
    for (final v in value.values) {
      if (v is String && v.isNotEmpty) return v;
    }
  }

  return value.toString();
}
