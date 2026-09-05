import 'audio_room_root.dart';
import 'json_annotation_helper.dart';
import 'pk_call_models.dart';

/// Ported from native `LiveUserRoot.java`.
///
/// Response wrapper for live-user list endpoints.
class LiveUserRoot {
  LiveUserRoot({this.message, this.status = false, this.users = const []});

  final String? message;
  final bool status;
  final List<LiveUser> users;

  factory LiveUserRoot.fromJson(Map<String, dynamic> json) => LiveUserRoot(
    message: parseString(json['message']),
    status: parseBool(json['status']),
    users: parseList(json['users'], LiveUser.fromJson),
  );
}

/// A single live-streaming user.
///
/// Mirrors native `PkAudioLiveUserRoot.UsersItem` — the unified live-room
/// list item returned by `/liveUser` and `/liveUser/retrieveRoomParticipantDetails`.
class LiveUser {
  LiveUser({
    this.id,
    this.name,
    this.username,
    this.image,
    this.country,
    this.countryFlagImage,
    this.diamond = 0,
    this.view = 0,
    this.rCoin = 0,
    this.channel,
    this.isVIP = false,
    this.token,
    this.service,
    this.livekitUrl,
    this.livekitToken,
    this.livekitRoom,
    this.liveStreamingType,
    this.isFake = false,
    this.isHostExists = true,
    this.isAudio = false,
    this.isPkMode = false,
    this.pkConfig,
    this.roomName,
    this.roomImage,
    this.roomWelcome,
    this.liveUserId,
    this.liveStreamingId,
    this.link,
    this.agoraUID = 0,
    this.uniqueId,
    this.createdAt,
    this.time = 0,
    this.avatarFrameImage,
    this.seat = const [],
    this.category,
    this.broadcastType,
    this.musicPermission = 'host',
  });

  final String? id;
  final String? name;
  final String? username;
  final String? image;
  final String? avatarFrameImage;
  final String? country;
  final String? countryFlagImage;
  final num diamond;
  final int view;
  final int rCoin;
  final String? channel;
  final bool isVIP;
  final String? token;
  final String? service;
  final String? livekitUrl;
  final String? livekitToken;
  final String? livekitRoom;
  final String? liveStreamingType;
  final bool isFake;
  final bool isHostExists;
  final bool isAudio;
  final bool isPkMode;
  final PkConfig? pkConfig;
  final String? roomName;
  final String? roomImage;
  final String? roomWelcome;
  final String? liveUserId;
  final String? liveStreamingId;
  final String? link;
  final int agoraUID;
  final String? uniqueId;
  final String? createdAt;
  final int time; // Unix timestamp (seconds) when the live stream started
  final List<SeatItem>
  seat; // Audio-room seat layout (empty for non-audio or list-only data)
  final String? category;
  final String? broadcastType;
  final String musicPermission;

  /// Convenience getters for compatibility with code that expects `userId`
  /// and `userImage` naming (matching the native Android model).
  String? get userId => liveUserId ?? id;
  String? get userImage => image;

  factory LiveUser.fromJson(Map<String, dynamic> json) => LiveUser(
    id: parseString(json['_id'] ?? json['id']),
    name: parseString(json['name']),
    username: parseString(json['username']),
    image: parseString(json['image']),
    country: parseString(json['country']),
    countryFlagImage: parseString(json['countryFlagImage']),
    diamond: parseNum(json['diamond'], 0),
    view: parseInt(json['view'], 0),
    rCoin: parseInt(json['rCoin'], 0),
    channel: parseString(json['channel']),
    isVIP: parseBool(json['isVIP'] ?? json['isVip'] ?? json['vip']),
    token: parseString(json['token']),
    service: parseString(json['service']),
    livekitUrl: parseString(json['livekitUrl']),
    livekitToken: parseString(json['livekitToken']),
    livekitRoom: parseString(json['livekitRoom']),
    liveStreamingType: parseString(
      json['liveStreamingType'] ?? json['liveType'],
    ),
    isFake: parseBool(json['isFake']),
    isHostExists: parseBool(json['isHostExists'], true),
    isAudio:
        parseBool(json['audio'] ?? json['isAudio']) ||
        (parseString(
              json['liveType'] ?? json['liveStreamingType'],
            )?.toLowerCase() ==
            'audio'),
    isPkMode: parseBool(json['isPkMode']),
    pkConfig:
        json['pkConfig'] is Map
            ? PkConfig.fromJson(
              Map<String, dynamic>.from(json['pkConfig'] as Map),
            )
            : null,
    roomName: parseString(json['roomName']),
    roomImage: parseString(json['roomImage']),
    roomWelcome: parseString(json['roomWelcome']),
    liveUserId: parseString(json['liveUserId']),
    liveStreamingId: parseString(
      json['liveStreamingId'] ?? json['_id'] ?? json['id'],
    ),
    link: parseString(json['link']),
    agoraUID: parseInt(json['agoraUID'], 0),
    uniqueId: parseString(json['uniqueId']),
    createdAt: parseString(json['createdAt']),
    time: parseInt(json['time'], 0),
    avatarFrameImage: parseString(json['avatarFrameImage']),
    seat: parseList(json['seat'] ?? json['seats'], SeatItem.fromJson),
    category: parseString(json['category']),
    broadcastType: parseString(json['broadcastType'] ?? json['broadcast_type']),
    musicPermission:
        parseString(json['musicPermission'])?.toLowerCase() ?? 'host',
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'liveStreamingId': liveStreamingId ?? id,
    'liveUserId': liveUserId,
    'userId': liveUserId,
    'name': name,
    'username': username,
    'image': image,
    'userImage': image,
    'avatarFrameImage': avatarFrameImage,
    'country': country,
    'countryFlagImage': countryFlagImage,
    'roomName': roomName,
    'roomImage': roomImage,
    'roomWelcome': roomWelcome,
    'channel': channel,
    'agoraUID': agoraUID,
    'token': token,
    'service': service,
    'livekitUrl': livekitUrl,
    'livekitToken': livekitToken,
    'livekitRoom': livekitRoom,
    'liveStreamingType': liveStreamingType,
    'liveType': liveStreamingType,
    'isAudio': isAudio,
    'isPublic': true,
    'isFake': isFake,
    'isPkMode': isPkMode,
    'isHostExists': isHostExists,
    'view': view,
    'rCoin': rCoin,
    'diamond': diamond,
    'uniqueId': uniqueId,
    'createdAt': createdAt,
    'time': time,
    'seat': seat.map((e) => e.toJson()).toList(),
    'category': category,
    'broadcastType': broadcastType,
    'musicPermission': musicPermission,
  };
}

/// Response from `/liveUser/retrieveRoomParticipantDetails?toUserId=...`.
///
/// Returns the full room state (`users` field) for joining a live/audio/PK room.
class RoomParticipantRoot {
  RoomParticipantRoot({this.user, this.message, this.status = false});

  final LiveUser? user;
  final String? message;
  final bool status;

  factory RoomParticipantRoot.fromJson(Map<String, dynamic> json) =>
      RoomParticipantRoot(
        user:
            json['users'] == null
                ? null
                : LiveUser.fromJson(json['users'] as Map<String, dynamic>),
        message: parseString(json['message']),
        status: parseBool(json['status']),
      );
}
