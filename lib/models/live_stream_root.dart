import 'json_annotation_helper.dart';
import 'host_compliance_models.dart';

/// Ported from native `LiveStreamRoot.java`.
///
/// Response from `makelivestreamUser` (go live) and `singleLiveUser` (join).
class LiveStreamRoot {
  LiveStreamRoot({
    this.user,
    this.message,
    this.status = false,
    this.isLiveBanned = false,
    this.ban,
  });

  final LiveUser? user;
  final String? message;
  final bool status;

  /// True when the host is currently banned from going live (AI guard 24h ban).
  final bool isLiveBanned;

  /// Active ban details, present when [isLiveBanned] is true.
  final HostComplianceBan? ban;

  factory LiveStreamRoot.fromJson(Map<String, dynamic> json) => LiveStreamRoot(
    user:
        (json['liveUser'] ?? json['user'] ?? json['users']) == null
            ? null
            : LiveUser.fromJson(
              (json['liveUser'] ?? json['user'] ?? json['users'])
                  as Map<String, dynamic>,
            ),
    message: parseString(json['message']),
    status: parseBool(json['status']),
    isLiveBanned: parseBool(json['isLiveBanned']),
    ban:
        json['ban'] is Map<String, dynamic>
            ? HostComplianceBan.fromJson(json['ban'] as Map<String, dynamic>)
            : null,
  );
}

/// Live-stream user — host or viewer's view of a live room.
class LiveUser {
  LiveUser({
    this.id,
    this.liveStreamingId,
    this.userId,
    this.name,
    this.username,
    this.image,
    this.userImage,
    this.avatarFrameImage,
    this.roomName,
    this.roomImage,
    this.roomWelcome,
    this.channel,
    this.agoraUID = 0,
    this.token, // Agora token (backend returns this for non-livekit service)
    this.livekitUrl,
    this.livekitToken,
    this.service,
    this.isPublic = true,
    this.passcode,
    this.view = 0,
    this.totalView = 0,
    this.coin = 0,
    this.isVIP = false,
    this.isAudio = false,
    this.liveType = 'video',
    this.createdAt,
    this.uniqueId,
    this.time = 0,
    this.cpLevel = 1,
    this.friendLevel = 1,
    this.relationshipType,
    this.intimacy = 0,
    this.familyId,
    this.familyName,
    this.familyBadgeUrl,
    this.familyImage,
    this.category,
    this.broadcastType,
    this.musicPermission = 'host',
  });

  final String? id; // live document _id (liveUserMongoId)
  final String? liveStreamingId; // live streaming / room id
  final String? userId;

  /// Returns the public room id — always prefer [liveStreamingId] when present.
  String? get liveRoomId => liveStreamingId ?? id;
  final String? name;
  final String? username;
  final String? image;
  final String? userImage;
  final String? avatarFrameImage;
  final String? roomName;
  final String? roomImage;
  final String? roomWelcome;
  final String? channel;
  final int agoraUID;
  final String? token; // Agora token
  final String? livekitUrl;
  final String? livekitToken;
  final String? service; // 'livekit' | 'agora'
  final bool isPublic;
  final String? passcode;
  int view;
  int totalView;
  int coin;
  final bool isVIP;
  final bool isAudio;
  final String liveType;
  final String? createdAt;
  final String? uniqueId;
  final int time; // Unix timestamp (seconds) when the live stream started
  final int cpLevel;
  final int friendLevel;
  final String? relationshipType; // 'cp', 'friend'
  final int intimacy;
  final String? familyId;
  final String? familyName;
  final String? familyBadgeUrl;
  final String? familyImage;
  final String? category;
  final String? broadcastType;
  final String musicPermission;

  Map<String, dynamic> toJson() => {
    '_id': id,
    'liveStreamingId': liveStreamingId ?? id,
    'userId': userId,
    'name': name,
    'username': username,
    'image': image,
    'userImage': userImage,
    'avatarFrameImage': avatarFrameImage,
    'roomName': roomName,
    'roomImage': roomImage,
    'roomWelcome': roomWelcome,
    'channel': channel,
    'agoraUID': agoraUID,
    'token': token,
    'livekitUrl': livekitUrl,
    'livekitToken': livekitToken,
    'service': service,
    'isPublic': isPublic,
    'passcode': passcode,
    'view': view,
    'totalView': totalView,
    'coin': coin,
    'isVIP': isVIP,
    'isAudio': isAudio,
    'liveType': liveType,
    'createdAt': createdAt,
    'uniqueId': uniqueId,
    'time': time,
    'cpLevel': cpLevel,
    'friendLevel': friendLevel,
    'relationshipType': relationshipType,
    'intimacy': intimacy,
    'familyId': familyId,
    'familyName': familyName,
    'familyBadgeUrl': familyBadgeUrl,
    'familyImage': familyImage,
    'category': category,
    'broadcastType': broadcastType,
    'musicPermission': musicPermission,
  };

  factory LiveUser.fromJson(Map<String, dynamic> json) => LiveUser(
    id: parseString(json['_id'] ?? json['id']),
    liveStreamingId:
        parseString(json['liveStreamingId']) ??
        parseString(json['_id'] ?? json['id']),
    userId: parseString(json['userId'] ?? json['liveUserId']),
    name: parseString(json['name']),
    username: parseString(json['username']),
    image: parseString(json['image']),
    userImage: parseString(json['userImage'] ?? json['image']),
    avatarFrameImage: parseString(json['avatarFrameImage']),
    roomName: parseString(json['roomName']),
    roomImage: parseString(json['roomImage']),
    roomWelcome: parseString(json['roomWelcome']),
    channel: parseString(json['channel']),
    agoraUID: parseInt(json['agoraUID'], 0),
    token: parseString(json['token']),
    livekitUrl: parseString(json['livekitUrl']),
    livekitToken: parseString(json['livekitToken']),
    service: parseString(json['service']),
    isPublic: parseBool(json['isPublic']),
    passcode: parseString(json['passcode']),
    view: parseInt(json['view'], 0),
    totalView: parseInt(json['totalView'], 0),
    coin: parseInt(json['coin'], 0),
    isVIP: parseBool(json['isVIP'] ?? json['isVip'] ?? json['vip']),
    isAudio:
        parseBool(json['isAudio'] ?? json['audio']) ||
        (parseString(json['liveType'])?.toLowerCase() == 'audio'),
    liveType: parseString(json['liveType']) ?? 'video',
    createdAt: parseString(json['createdAt']),
    uniqueId: parseString(json['uniqueId']),
    time: parseInt(json['time'], 0),
    cpLevel: parseInt(json['cpLevel'], 1),
    friendLevel: parseInt(json['friendLevel'], 1),
    relationshipType: parseString(json['relationshipType']),
    intimacy: parseInt(json['intimacy'], 0),
    familyId: parseString(
      json['familyId'] ??
          json['family_id'] ??
          (json['familyDetails'] is Map
              ? json['familyDetails']['_id'] ?? json['familyDetails']['id']
              : null),
    ),
    familyName: parseString(
      json['familyName'] ??
          json['family_name'] ??
          json['family'] ??
          (json['familyDetails'] is Map ? json['familyDetails']['name'] : null),
    ),
    familyBadgeUrl: parseString(
      json['familyBadgeUrl'] ??
          json['familyBadge'] ??
          (json['familyDetails'] is Map
              ? json['familyDetails']['badgeUrl'] ??
                  json['familyDetails']['image']
              : null),
    ),
    familyImage: parseString(
      json['familyImage'] ??
          json['family_image'] ??
          (json['familyDetails'] is Map
              ? json['familyDetails']['image']
              : null),
    ),
    category: parseString(json['category']),
    broadcastType: parseString(json['broadcastType'] ?? json['broadcast_type']),
    musicPermission:
        parseString(json['musicPermission'])?.toLowerCase() ?? 'host',
  );
}

/// Block user response.
class BlockUserRoot {
  BlockUserRoot({this.blocked = false, this.message, this.status = false});

  final bool blocked;
  final String? message;
  final bool status;

  factory BlockUserRoot.fromJson(Map<String, dynamic> json) => BlockUserRoot(
    blocked: parseBool(json['blocked']),
    message: parseString(json['message']),
    status: parseBool(json['status']),
  );
}
