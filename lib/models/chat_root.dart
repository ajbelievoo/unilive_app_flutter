import 'json_annotation_helper.dart';

/// Ported from native `ChatItem.java` + `ChatRoot.java`.
///
/// Represents a single chat message in a 1-1 conversation.
class ChatItem {
  ChatItem({
    this.id,
    this.senderId,
    this.receiverId,
    this.topic,
    this.messageType = 'message',
    this.message,
    this.image,
    this.time,
    this.date,
    this.status = 'sent',
    this.isRead = false,
    this.isStarred = false,
    this.isMuted = false,
    this.giftImage,
    this.giftName,
    this.giftCoin = 0,
    this.count = 1,
    this.callType,
    this.callDuration = 0,
    this.callStatus,
    this.replyToId,
    this.replyToMessage,
    this.replyToSenderName,
    this.audioUrl,
    this.audioDuration = 0,
    this.svgaImage,
    this.giftType = 0,
    this.liveData,
    this.reactions = const [],
    this.translatedText,
    this.isPinnedInChat = false,
    this.disappearingSeconds = 0,
    this.expiresAt,
  });

  final String? id;
  final String? senderId;
  final String? receiverId;
  final String? topic;
  final String messageType; // message | image | gift | voice | call | liveShare | sticker | reaction | location | video
  final String? message;
  final String? image;
  final String? time;
  final String? date;
  String status; // sent | delivered | read
  bool isRead;
  bool isStarred;
  bool isMuted;
  final String? giftImage;
  final String? giftName;
  final int giftCoin;
  final int count;
  final String? callType;
  final int callDuration;
  final String? callStatus;
  final String? replyToId;
  final String? replyToMessage;
  final String? replyToSenderName;
  final String? audioUrl;
  final int audioDuration;
  final String? svgaImage;
  final int giftType;
  final LiveData? liveData;

  /// Inline emoji reactions on this message (Bigo-style: long-press → emoji).
  /// Each entry: { userId, emoji, name? }
  List<MessageReaction> reactions;

  /// Translated text (filled by ChatTranslationService, null if not translated).
  String? translatedText;

  /// Whether this message is pinned at the top of the conversation.
  bool isPinnedInChat;

  /// Disappearing-message timer in seconds (0 = off). Set per-topic.
  int disappearingSeconds;

  /// When this message should auto-delete (ISO timestamp), if disappearing.
  final String? expiresAt;

  /// True if this message was sent by the current user (sender matches).
  bool isMine(String myUserId) => senderId == myUserId;

  factory ChatItem.fromJson(Map<String, dynamic> json) => ChatItem(
        id: parseString(json['_id'] ?? json['id'] ?? json['chatId']),
        senderId: parseString(json['senderId'] ?? json['sender'] ?? json['userId'] ?? json['fromUserId']),
        receiverId: parseString(json['receiverId'] ?? json['receiver'] ?? json['toUserId']),
        topic: parseString(json['topic'] ?? json['topicId']),
        messageType: parseString(json['messageType']) ?? 'message',
        message: parseString(json['message']),
        image: parseString(json['image']),
        time: parseString(json['time'] ?? json['createdAt'] ?? json['updatedAt']),
        date: parseString(json['date'] ?? json['chatDate']),
        status: parseString(json['status']) ?? 'sent',
        isRead: parseBool(json['isRead']),
        isStarred: parseBool(json['isStarred']),
        isMuted: parseBool(json['isMuted']),
        giftImage: parseString(json['giftImage']),
        giftName: parseString(json['giftName']),
        giftCoin: parseInt(json['giftCoin'], 0),
        count: parseInt(json['count'], 1),
        callType: parseString(json['callType']),
        callDuration: parseInt(json['callDuration'], 0),
        callStatus: parseString(json['callStatus']),
        replyToId: parseString(json['replyToId']),
        replyToMessage: parseString(json['replyToMessage']),
        replyToSenderName: parseString(json['replyToSenderName']),
        audioUrl: parseString(json['audioUrl']),
        audioDuration: parseInt(json['audioDuration'], 0),
        svgaImage: parseString(json['svgaImage']),
        giftType: parseInt(json['giftType'], 0),
        liveData: json['liveData'] == null ? null : LiveData.fromJson(json['liveData'] as Map<String, dynamic>),
        reactions: parseList(json['reactions'], MessageReaction.fromJson),
        translatedText: parseString(json['translatedText']),
        isPinnedInChat: parseBool(json['isPinnedInChat'] ?? json['isPinned']),
        disappearingSeconds: parseInt(json['disappearingSeconds'], 0),
        expiresAt: parseString(json['expiresAt']),
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'senderId': senderId,
        'receiverId': receiverId,
        'topic': topic,
        'messageType': messageType,
        'message': message,
        'image': image,
        'time': time,
        'date': date,
        'status': status,
        'isRead': isRead,
        'isStarred': isStarred,
        'giftImage': giftImage,
        'giftName': giftName,
        'giftCoin': giftCoin,
        'count': count,
        'callType': callType,
        'callDuration': callDuration,
        'callStatus': callStatus,
        'audioUrl': audioUrl,
        'audioDuration': audioDuration,
        'svgaImage': svgaImage,
        'giftType': giftType,
        'liveData': liveData?.toJson(),
        'reactions': reactions.map((r) => r.toJson()).toList(),
        'translatedText': translatedText,
        'isPinnedInChat': isPinnedInChat,
        'disappearingSeconds': disappearingSeconds,
        'expiresAt': expiresAt,
      };

  ChatItem copyWith({
    String? id,
    String? status,
    bool? isRead,
    bool? isStarred,
    List<MessageReaction>? reactions,
    String? translatedText,
    bool? isPinnedInChat,
    int? disappearingSeconds,
  }) =>
      ChatItem(
        id: id ?? this.id,
        senderId: senderId,
        receiverId: receiverId,
        topic: topic,
        messageType: messageType,
        message: message,
        image: image,
        time: time,
        date: date,
        status: status ?? this.status,
        isRead: isRead ?? this.isRead,
        isStarred: isStarred ?? this.isStarred,
        isMuted: isMuted,
        giftImage: giftImage,
        giftName: giftName,
        giftCoin: giftCoin,
        count: count,
        callType: callType,
        callDuration: callDuration,
        callStatus: callStatus,
        replyToId: replyToId,
        replyToMessage: replyToMessage,
        replyToSenderName: replyToSenderName,
        audioUrl: audioUrl,
        audioDuration: audioDuration,
        svgaImage: svgaImage,
        giftType: giftType,
        liveData: liveData,
        reactions: reactions ?? this.reactions,
        translatedText: translatedText ?? this.translatedText,
        isPinnedInChat: isPinnedInChat ?? this.isPinnedInChat,
        disappearingSeconds: disappearingSeconds ?? this.disappearingSeconds,
        expiresAt: expiresAt,
      );
}

/// A single emoji reaction on a chat message (Bigo-style inline reactions).
class MessageReaction {
  MessageReaction({this.userId, this.emoji, this.name, this.image});

  final String? userId;
  final String? emoji;
  final String? name;
  final String? image;

  factory MessageReaction.fromJson(Map<String, dynamic> json) => MessageReaction(
        userId: parseString(json['userId'] ?? json['user']),
        emoji: parseString(json['emoji'] ?? json['reaction']),
        name: parseString(json['name'] ?? json['userName']),
        image: parseString(json['image'] ?? json['userImage']),
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'emoji': emoji,
        'name': name,
        'image': image,
      };
}

/// Live-share payload embedded in chat messages of type `liveShare`.
class LiveData {
  LiveData({
    this.image,
    this.name,
    this.roomName,
    this.roomImage,
    this.isAudio = false,
    this.liveStreamingId,
    this.liveUserId,
    this.uniqueId,
  });

  final String? image;
  final String? name;
  final String? roomName;
  final String? roomImage;
  final bool isAudio;
  final String? liveStreamingId;
  final String? liveUserId;
  final String? uniqueId;

  factory LiveData.fromJson(Map<String, dynamic> json) => LiveData(
        image: parseString(json['image']),
        name: parseString(json['name']),
        roomName: parseString(json['roomName']),
        roomImage: parseString(json['roomImage']),
        isAudio: parseBool(json['isAudio']),
        liveStreamingId: parseString(json['liveStreamingId']),
        liveUserId: parseString(json['liveUserId']),
        uniqueId: parseString(json['uniqueId']),
      );

  Map<String, dynamic> toJson() => {
        'image': image,
        'name': name,
        'roomName': roomName,
        'roomImage': roomImage,
        'isAudio': isAudio,
        'liveStreamingId': liveStreamingId,
        'liveUserId': liveUserId,
        'uniqueId': uniqueId,
      };
}

/// Response wrapper for chat history endpoint.
class ChatRoot {
  ChatRoot({this.status = false, this.chat = const [], this.message});

  final bool status;
  final List<ChatItem> chat;
  final String? message;

  factory ChatRoot.fromJson(Map<String, dynamic> json) {
    // Helper: from a map, pick the first value that is a List (the messages).
    dynamic pickList(Map m) {
      for (final key in ['chat', 'chats', 'messages', 'oldChat', 'result']) {
        final v = m[key];
        if (v is List) return v;
      }
      return null;
    }

    // Try chat/chats/messages/oldChat/result at top level first
    dynamic chatData = pickList(json);

    // If 'chat' is a Map (chatTopic document), dig into it for the message list.
    if (chatData == null && json['chat'] is Map) {
      chatData = pickList(json['chat'] as Map);
    }

    // If not found, check inside 'data' field (server may wrap responses)
    if (chatData == null) {
      final data = json['data'];
      if (data is Map) {
        chatData = pickList(data);
        // If data.chat is a Map (chatTopic doc), dig further.
        if (chatData == null && data['chat'] is Map) {
          chatData = pickList(data['chat'] as Map);
        }
        // Check data.chatTopic.messages (some backends nest messages here)
        if (chatData == null && data['chatTopic'] is Map) {
          chatData = pickList(data['chatTopic'] as Map);
        }
      } else if (data is List) {
        chatData = data;
      }
    }

    // Also check chatTopic at top level (some backends nest messages here)
    if (chatData == null && json['chatTopic'] is Map) {
      chatData = pickList(json['chatTopic'] as Map);
    }

    return ChatRoot(
      status: parseBool(json['status']),
      chat: parseList(chatData, ChatItem.fromJson),
      message: parseString(json['message']),
    );
  }
}

/// Response wrapper for create-chat-topic endpoint.
class ChatTopicRoot {
  ChatTopicRoot({this.status = false, this.topic, this.message});

  final bool status;
  final String? topic;
  final String? message;

  factory ChatTopicRoot.fromJson(Map<String, dynamic> json) {
    // Some endpoints wrap the response in a 'data' field.
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : null;

    String? topicFromMap(Map<String, dynamic> map) {
      final chatTopic = map['chatTopic'];
      if (chatTopic is Map<String, dynamic>) {
        final t = parseString(chatTopic['chat']) ??
            parseString(chatTopic['topic']) ??
            parseString(chatTopic['topicId']) ??
            parseString(chatTopic['_id']) ??
            parseString(chatTopic['id']);
        if (t != null && t.isNotEmpty) return t;
      }

      // Look for the conversation id as a string. Avoid picking a message map
      // here - 'chat' in a chatTopic document is the topic string.
      for (final key in ['topic', 'topicId', 'chat', '_id', 'id']) {
        final v = map[key];
        if (v is String && v.isNotEmpty) return v;
      }
      return null;
    }

    final topic = topicFromMap(json) ?? (data != null ? topicFromMap(data) : null);

    return ChatTopicRoot(
      status: parseBool(json['status'] ?? data?['status']),
      topic: topic,
      message: parseString(json['message'] ?? data?['message']),
    );
  }
}
