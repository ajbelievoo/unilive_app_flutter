import 'assigned_tag.dart';
import 'json_annotation_helper.dart';
import 'user_root.dart';

/// Ported from native `GuestProfileRoot.java`.
///
/// Response wrapper for `/user/getGuestProfile` and
/// `/user/getGuestProfileByUserName`.
class GuestProfileRoot {
  GuestProfileRoot({this.message, this.status = false, this.user});

  final String? message;
  final bool status;
  final GuestUser? user;

  factory GuestProfileRoot.fromJson(Map<String, dynamic> json) => GuestProfileRoot(
        message: parseString(json['message']),
        status: parseBool(json['status']),
        user: json['user'] == null ? null : GuestUser.fromJson(json['user'] as Map<String, dynamic>),
      );
}

/// Guest profile user — same shape as [User] but with a few extra fields
/// (like `isFollow`, `isLiked`, `liveType`, rating, tags, medals).
class GuestUser {
  GuestUser({
    this.id,
    this.name,
    this.username,
    this.uniqueId,
    this.image,
    this.coverImage,
    this.bio,
    this.gender,
    this.age = 0,
    this.country,
    this.birthDate,
    this.link,
    this.coin = 0,
    this.followers = 0,
    this.following = 0,
    this.post = 0,
    this.video = 0,
    this.likeCount = 0,
    this.profileVisits = 0,
    this.friends = 0,
    this.isVIP = false,
    this.isVerified = false,
    this.isHost = false,
    this.isBd = false,
    this.isAgency = false,
    this.isCoinSeller = false,
    this.isSuperSeller = false,
    this.isSuperAdmin = false,
    this.isOfficialManager = false,
    this.isRegionHead = false,
    this.isFollow = false,
    this.isBlock = false,
    this.isFake = false,
    this.isLiked = false,
    this.isVipProtected = false,
    this.isOnline = false,
    this.liveType = 0,
    this.averageRating = 0,
    this.totalRatings = 0,
    this.userRating = 0,
    this.userFeedback,
    this.role,
    this.level,
    this.hostLevel,
    this.vipDetails,
    this.vipBadgeUrl,
    this.vipChatColor,
    this.vipBackgroundImage,
    this.profileBackgroundImage,
    this.avatarFrameImage,
    this.family,
    this.familyId,
    this.familyName,
    this.familyBadgeUrl,
    this.familyImage,
    this.tags = const [],
    this.vipLevel = 0,
    this.vipLevelName,
    this.customCallRate,
    this.liveRoom,
    this.medals = const [],
    this.achievements = const [],
  });

  final String? id;
  final String? name;
  final String? username;
  final String? uniqueId;
  final String? image;
  final String? coverImage;
  final String? bio;
  final String? gender;
  final int age;
  final String? country;
  final String? birthDate;
  final String? link;
  final num coin;
  final int followers;
  final int following;
  final int post;
  final int video;
  final int likeCount;
  final int profileVisits;
  final int friends;
  final bool isVIP;
  final bool isVerified;
  final bool isHost;
  final bool isBd;
  final bool isAgency;
  final bool isCoinSeller;
  final bool isSuperSeller;
  final bool isSuperAdmin;
  final bool isOfficialManager;
  final bool isRegionHead;
  final bool isFollow;
  final bool isBlock;
  final bool isFake;
  final bool isLiked;
  final bool isVipProtected;
  final bool isOnline;
  final int liveType;
  final double averageRating;
  final int totalRatings;
  final int userRating;
  final String? userFeedback;
  final String? role;
  final Level? level;
  final HostLevel? hostLevel;
  final VipDetails? vipDetails;
  final String? vipBadgeUrl;
  final String? vipChatColor;
  final String? vipBackgroundImage;
  final String? profileBackgroundImage;
  final String? avatarFrameImage;
  final String? family;
  final String? familyId;
  final String? familyName;
  final String? familyBadgeUrl;
  final String? familyImage;
  final List<AssignedTag> tags;
  final int vipLevel;
  final String? vipLevelName;
  final num? customCallRate;
  /// The live room this user is currently in (host or viewer), if any.
  /// Populated by the backend so the profile sheet can show a LIVE indicator
  /// and a "Join Room" button. See docs/PROFILE_LIVE_INDICATOR_BACKEND_API.md.
  final GuestLiveRoom? liveRoom;
  /// Earned medal image URLs.
  final List<String> medals;
  /// Achievement badge image URLs.
  final List<String> achievements;

  /// Whether this user is currently inside a live room.
  bool get isInLiveRoom => liveRoom?.isLive == true && liveRoom?.liveUserId != null;

  GuestUser copyWith({
    String? id,
    String? name,
    String? username,
    String? uniqueId,
    String? image,
    String? coverImage,
    String? bio,
    String? gender,
    int? age,
    String? country,
    String? birthDate,
    String? link,
    num? coin,
    int? followers,
    int? following,
    int? post,
    int? video,
    int? likeCount,
    int? profileVisits,
    int? friends,
    bool? isVIP,
    bool? isVerified,
    bool? isHost,
    bool? isBd,
    bool? isAgency,
    bool? isCoinSeller,
    bool? isSuperSeller,
    bool? isSuperAdmin,
    bool? isOfficialManager,
    bool? isRegionHead,
    bool? isFollow,
    bool? isBlock,
    bool? isFake,
    bool? isLiked,
    bool? isVipProtected,
    bool? isOnline,
    int? liveType,
    double? averageRating,
    int? totalRatings,
    int? userRating,
    String? userFeedback,
    String? role,
    Level? level,
    HostLevel? hostLevel,
    VipDetails? vipDetails,
    String? vipBadgeUrl,
    String? vipChatColor,
    String? vipBackgroundImage,
    String? profileBackgroundImage,
    String? avatarFrameImage,
    String? family,
    String? familyId,
    String? familyName,
    String? familyBadgeUrl,
    String? familyImage,
    List<AssignedTag>? tags,
    int? vipLevel,
    String? vipLevelName,
    num? customCallRate,
    GuestLiveRoom? liveRoom,
    List<String>? medals,
    List<String>? achievements,
  }) {
    return GuestUser(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      uniqueId: uniqueId ?? this.uniqueId,
      image: image ?? this.image,
      coverImage: coverImage ?? this.coverImage,
      bio: bio ?? this.bio,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      country: country ?? this.country,
      birthDate: birthDate ?? this.birthDate,
      link: link ?? this.link,
      coin: coin ?? this.coin,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      post: post ?? this.post,
      video: video ?? this.video,
      likeCount: likeCount ?? this.likeCount,
      profileVisits: profileVisits ?? this.profileVisits,
      friends: friends ?? this.friends,
      isVIP: isVIP ?? this.isVIP,
      isVerified: isVerified ?? this.isVerified,
      isHost: isHost ?? this.isHost,
      isBd: isBd ?? this.isBd,
      isAgency: isAgency ?? this.isAgency,
      isCoinSeller: isCoinSeller ?? this.isCoinSeller,
      isSuperSeller: isSuperSeller ?? this.isSuperSeller,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      isOfficialManager: isOfficialManager ?? this.isOfficialManager,
      isRegionHead: isRegionHead ?? this.isRegionHead,
      isFollow: isFollow ?? this.isFollow,
      isBlock: isBlock ?? this.isBlock,
      isFake: isFake ?? this.isFake,
      isLiked: isLiked ?? this.isLiked,
      isVipProtected: isVipProtected ?? this.isVipProtected,
      isOnline: isOnline ?? this.isOnline,
      liveType: liveType ?? this.liveType,
      averageRating: averageRating ?? this.averageRating,
      totalRatings: totalRatings ?? this.totalRatings,
      userRating: userRating ?? this.userRating,
      userFeedback: userFeedback ?? this.userFeedback,
      role: role ?? this.role,
      level: level ?? this.level,
      hostLevel: hostLevel ?? this.hostLevel,
      vipDetails: vipDetails ?? this.vipDetails,
      vipBadgeUrl: vipBadgeUrl ?? this.vipBadgeUrl,
      vipChatColor: vipChatColor ?? this.vipChatColor,
      vipBackgroundImage: vipBackgroundImage ?? this.vipBackgroundImage,
      profileBackgroundImage: profileBackgroundImage ?? this.profileBackgroundImage,
      avatarFrameImage: avatarFrameImage ?? this.avatarFrameImage,
      family: family ?? this.family,
      familyId: familyId ?? this.familyId,
      familyName: familyName ?? this.familyName,
      familyBadgeUrl: familyBadgeUrl ?? this.familyBadgeUrl,
      familyImage: familyImage ?? this.familyImage,
      tags: tags ?? this.tags,
      vipLevel: vipLevel ?? this.vipLevel,
      vipLevelName: vipLevelName ?? this.vipLevelName,
      customCallRate: customCallRate ?? this.customCallRate,
      liveRoom: liveRoom ?? this.liveRoom,
      medals: medals ?? this.medals,
      achievements: achievements ?? this.achievements,
    );
  }

  factory GuestUser.fromJson(Map<String, dynamic> json) {
    return GuestUser(
      id: parseString(json['_id'] ?? json['id']),
      name: parseString(json['name']),
      username: parseString(json['username']),
      uniqueId: parseString(json['uniqueId']),
      image: parseString(json['image']),
      coverImage: parseString(json['coverImage']),
      bio: parseString(json['bio']),
      gender: parseString(json['gender']),
      age: parseInt(json['age'], 0),
      country: parseString(json['country']),
      birthDate: parseString(json['birthDate']),
      link: parseString(json['link']),
      coin: parseNum(json['coin'], 0),
      followers: parseInt(json['followers'], 0),
      following: parseInt(json['following'], 0),
      post: parseInt(json['post'], 0),
      video: parseInt(json['video'], 0),
      likeCount: parseInt(json['likeCount'], 0),
      profileVisits: parseInt(json['profileVisits'], 0),
      friends: _parseFriendsCount(json['friends']),
      isVIP: parseBool(json['isVIP'] ?? json['isVip'] ?? json['vip']),
      isVerified: parseBool(json['isVerified']),
      isHost: parseBool(json['isHost']),
      isBd: parseBool(json['isBd']),
      isAgency: parseBool(json['isAgency']),
      isCoinSeller: parseBool(json['isCoinSeller']),
      isSuperSeller: parseBool(json['isSuperSeller']),
      isSuperAdmin: parseBool(json['isSuperAdmin']),
      isOfficialManager: parseBool(json['isOfficialManager'] ?? json['isOfficial'] ?? json['officialManager']),
      isRegionHead: parseBool(json['isRegionHead'] ?? json['regionHead']),
      isFollow: parseBool(json['isFollow']),
      isBlock: parseBool(json['isBlock']),
      isFake: parseBool(json['isFake']),
      isLiked: parseBool(json['isLiked']),
      isVipProtected: parseBool(json['isVipProtected']),
      isOnline: parseBool(json['isOnline']),
      liveType: parseInt(json['liveType'], 0),
      averageRating: parseDouble(json['averageRating']),
      totalRatings: parseInt(json['totalRatings'], 0),
      userRating: parseInt(json['userRating'], 0),
      userFeedback: parseString(json['userFeedback']),
      role: parseString(json['role'] ?? json['designation'] ?? json['userRole'] ??
          json['adminRole'] ?? json['staffRole']),
      level: json['level'] == null ? null : Level.fromJson(json['level'] as Map<String, dynamic>),
      hostLevel: json['hostLevel'] == null ? null : HostLevel.fromJson(json['hostLevel'] as Map<String, dynamic>),
      vipDetails: json['vipDetails'] == null ? null : VipDetails.fromJson(json['vipDetails'] as Map<String, dynamic>),
      vipBadgeUrl: parseString(json['vipBadgeUrl']),
      vipChatColor: parseString(json['vipChatColor']),
      vipBackgroundImage: parseString(json['vipBackgroundImage']),
      profileBackgroundImage: parseString(json['profileBackgroundImage']),
      avatarFrameImage: parseString(
        json['avatarFrameImage'] ??
            json['avatar_frame_image'] ??
            json['avatarFrame'] ??
            json['avatar_frame'] ??
            json['frameUrl'] ??
            json['frame_url'] ??
            json['profileFrame'] ??
            json['profile_frame'] ??
            json['selectedFrame'] ??
            json['selected_frame'] ??
            json['activeFrame'] ??
            json['active_frame'] ??
            (json['store'] is Map ? json['store']['avatarFrameImage'] : null) ??
            (json['frame'] is Map ? json['frame']['image'] ?? json['frame']['url'] : null),
      ),
      family: parseString(json['family']),
      familyId: parseString(json['familyId'] ?? json['family_id'] ??
          (json['familyDetails'] is Map ? json['familyDetails']['_id'] ?? json['familyDetails']['id'] : null)),
      familyName: parseString(json['familyName'] ?? json['family_name'] ?? json['family'] ??
          (json['familyDetails'] is Map ? json['familyDetails']['name'] : null)),
      familyBadgeUrl: parseString(json['familyBadgeUrl'] ?? json['familyBadge'] ??
          (json['familyDetails'] is Map ? json['familyDetails']['badgeUrl'] ?? json['familyDetails']['image'] : null)),
      familyImage: parseString(json['familyImage'] ?? json['family_image'] ??
          (json['familyDetails'] is Map ? json['familyDetails']['image'] : null)),
      tags: parseAssignedTags(json['tags']),
      vipLevel: parseInt(json['vipStatus'] is Map ? (json['vipStatus'] as Map)['currentLevel'] : 0, 0),
      vipLevelName: parseString(json['vipStatus'] is Map ? (json['vipStatus'] as Map)['currentLevelName'] : null),
      customCallRate: json['customCallRate'] != null ? parseNum(json['customCallRate'], 0) : null,
      liveRoom: json['liveRoom'] == null
          ? null
          : GuestLiveRoom.fromJson(json['liveRoom'] as Map<String, dynamic>),
      medals: parseStringList(json['medals'] ?? json['badgeUrls'] ?? json['badges']),
      achievements: parseStringList(json['achievements'] ?? json['achievementBadges']),
    );
  }
}

/// Snapshot of the live room a user is currently in (host or viewer).
class GuestLiveRoom {
  GuestLiveRoom({
    this.liveStreamingId,
    this.liveUserId,
    this.isLive = false,
    this.isAudio = false,
    this.liveStreamingType,
    this.roomName,
    this.roomImage,
    this.isHost = false,
  });

  final String? liveStreamingId;
  /// The host's userId (the room owner) — used to join via socket.
  final String? liveUserId;
  final bool isLive;
  final bool isAudio;
  final String? liveStreamingType;
  final String? roomName;
  final String? roomImage;
  /// Whether this user is the host of the room (vs a viewer/co-host).
  final bool isHost;

  factory GuestLiveRoom.fromJson(Map<String, dynamic> json) => GuestLiveRoom(
        liveStreamingId: parseString(json['liveStreamingId'] ?? json['liveStreamId']),
        liveUserId: parseString(json['liveUserId'] ?? json['hostId'] ?? json['userId']),
        isLive: parseBool(json['isLive'] ?? json['live'], true),
        isAudio: parseBool(json['isAudio'] ?? json['audio']) ||
            (parseString(json['liveStreamingType'] ?? json['liveType'])?.toLowerCase() == 'audio'),
        liveStreamingType: parseString(json['liveStreamingType'] ?? json['liveType']),
        roomName: parseString(json['roomName']),
        roomImage: parseString(json['roomImage']),
        isHost: parseBool(json['isHost']),
      );
}

/// Parses the friends count from the backend, tolerating both a raw
/// numeric count and a list of friends (the latter returns its length).
int _parseFriendsCount(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is num) return v.toInt();
  if (v is List) return v.length;
  if (v is String) {
    final parsed = int.tryParse(v);
    if (parsed != null) return parsed;
    final d = double.tryParse(v);
    if (d != null) return d.toInt();
  }
  return 0;
}


