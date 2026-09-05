import 'json_annotation_helper.dart';

/// Ported from native `CallHistoryRoot.java`.
class CallHistoryRoot {
  CallHistoryRoot({this.status = false, this.message, this.history = const []});

  final bool status;
  final String? message;
  final List<CallHistoryItem> history;

  factory CallHistoryRoot.fromJson(Map<String, dynamic> json) {
    final list = json['history'] ?? json['data'] ?? json['calls'] ?? json['records'];
    return CallHistoryRoot(
      status: parseBool(json['status']),
      message: parseString(json['message']),
      history: parseList(list, CallHistoryItem.fromJson),
    );
  }
}

class CallHistoryItem {
  CallHistoryItem({
    this.id,
    this.callerUserId,
    this.receiverUserId,
    this.callType,
    this.duration = 0,
    this.coin = 0,
    this.status,
    this.date,
    this.name,
    this.image,
    this.isAudio = false,
  });

  final String? id;
  final String? callerUserId;
  final String? receiverUserId;
  final String? callType; // "audio" | "video"
  final int duration; // seconds
  final int coin;
  final String? status; // "completed" | "missed" | "rejected"
  final String? date;
  final String? name;
  final String? image;
  final bool isAudio;

  factory CallHistoryItem.fromJson(Map<String, dynamic> json) {
    final callType = parseString(json['callType']);
    return CallHistoryItem(
      id: parseString(json['_id'] ?? json['id']),
      callerUserId: parseString(json['callerUserId']),
      receiverUserId: parseString(json['receiverUserId']),
      callType: callType,
      duration: parseInt(json['duration'], 0),
      coin: parseInt(json['coin'], 0),
      status: parseString(json['status']),
      date: parseString(json['date'] ?? json['createdAt']),
      name: parseString(json['name']),
      image: parseString(json['image']),
      isAudio: json['isAudio'] != null
          ? parseBool(json['isAudio'])
          : (callType?.toLowerCase() == 'audio'),
    );
  }
}
