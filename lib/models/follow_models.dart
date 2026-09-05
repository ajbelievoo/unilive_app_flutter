import 'guest_profile_root.dart';
import 'json_annotation_helper.dart';
import 'user_root.dart';

/// Ported from native `FollowersRoot.java` — follower/following/search user list.
///
/// Response wrapper for `/follower/followerList`, `/follower/followingList`,
/// and `/user/user/search`.
class FollowersRoot {
  FollowersRoot({this.message, this.status = false, this.users = const []});

  final String? message;
  final bool status;
  final List<FollowUser> users;

  factory FollowersRoot.fromJson(Map<String, dynamic> json) => FollowersRoot(
        message: parseString(json['message']),
        status: parseBool(json['status']),
        users: parseList(
          json['user'] ?? json['users'] ?? json['friends'],
          FollowUser.fromJson,
        ),
      );
}

/// A single user in a follower/following/search list.
///
/// Mirrors native `FollowersRoot.User` — a lightweight user shape returned by
/// follower, following, and search endpoints.
class FollowUser {
  FollowUser({
    this.id,
    this.name,
    this.username,
    this.uniqueId,
    this.image,
    this.country,
    this.countryFlagImage,
    this.bio,
    this.gender,
    this.age = 0,
    this.coin = 0,
    this.diamond = 0,
    this.followers = 0,
    this.following = 0,
    this.isVIP = false,
    this.isVerified = false,
    this.isHost = false,
    this.isBd = false,
    this.isAgency = false,
    this.isCoinSeller = false,
    this.isFollow = false,
    this.isBlock = false,
    this.isFake = false,
    this.isLiked = false,
    this.isOnline = false,
    this.link,
    this.avatarFrameImage,
    this.vipBadgeUrl,
    this.level,
    this.hostLevel,
    this.liveType = 0,
    this.tags = const [],
  });

  final String? id;
  final String? name;
  final String? username;
  final String? uniqueId;
  final String? image;
  final String? country;
  final String? countryFlagImage;
  final String? bio;
  final String? gender;
  final int age;
  final num coin;
  final num diamond;
  final int followers;
  final int following;
  final bool isVIP;
  final bool isVerified;
  final bool isHost;
  final bool isBd;
  final bool isAgency;
  final bool isCoinSeller;
  final bool isFollow;
  final bool isBlock;
  final bool isFake;
  final bool isLiked;
  final bool isOnline;
  final String? link;
  final String? avatarFrameImage;
  final String? vipBadgeUrl;
  final Level? level;
  final HostLevel? hostLevel;
  final int liveType;
  final List<String> tags;

  factory FollowUser.fromJson(Map<String, dynamic> json) => FollowUser(
        id: parseString(json['userId'] ?? json['_id'] ?? json['id']),
        name: parseString(json['name']),
        username: parseString(json['username']),
        uniqueId: parseString(json['uniqueId']),
        image: parseString(json['image']),
        country: parseString(json['country']),
        countryFlagImage: parseString(json['countryFlagImage']),
        bio: parseString(json['bio']),
        gender: parseString(json['gender']),
        age: parseInt(json['age'], 0),
        coin: parseNum(json['coin'], 0),
        diamond: parseNum(json['diamond'], 0),
        followers: parseInt(json['followers'], 0),
        following: parseInt(json['following'], 0),
        isVIP: parseBool(json['isVIP'] ?? json['isVip'] ?? json['vip']),
        isVerified: parseBool(json['isVerified']),
        isHost: parseBool(json['isHost']),
        isBd: parseBool(json['isBd']),
        isAgency: parseBool(json['isAgency']),
        isCoinSeller: parseBool(json['isCoinSeller']),
        isFollow: parseBool(json['isFollow']),
        isBlock: parseBool(json['isBlock']),
        isFake: parseBool(json['isFake']),
        isLiked: parseBool(json['isLiked']),
        isOnline: parseBool(json['isOnline']),
        link: parseString(json['link']),
        avatarFrameImage: parseString(json['avatarFrameImage']),
        vipBadgeUrl: parseString(json['vipBadgeUrl']),
        level: json['level'] == null ? null : Level.fromJson(json['level'] as Map<String, dynamic>),
        hostLevel: json['hostLevel'] == null ? null : HostLevel.fromJson(json['hostLevel'] as Map<String, dynamic>),
        liveType: parseInt(json['liveType'], 0),
        tags: _parseTags(json['tags']),
      );

  static List<String> _parseTags(dynamic raw) {
    if (raw is List) {
      return raw.whereType<String>().toList();
    }
    if (raw is String) {
      return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }

  /// Creates a [FollowUser] from a full [GuestUser] profile (e.g. from
  /// `/user/getUsersUniqueId` + `/user/profile` flow used by coin-seller).
  factory FollowUser.fromGuestUser(GuestUser guest) => FollowUser(
        id: guest.id,
        name: guest.name,
        username: guest.username,
        uniqueId: guest.uniqueId,
        image: guest.image,
        country: guest.country,
        bio: guest.bio,
        gender: guest.gender,
        age: guest.age,
        coin: guest.coin,
        followers: guest.followers,
        following: guest.following,
        isVIP: guest.isVIP,
        isVerified: guest.isVerified,
        isHost: guest.isHost,
        isBd: guest.isBd,
        isAgency: guest.isAgency,
        isCoinSeller: guest.isCoinSeller,
        isFollow: guest.isFollow,
        isBlock: guest.isBlock,
        isFake: guest.isFake,
        isLiked: guest.isLiked,
        isOnline: guest.isOnline,
        link: guest.link,
        avatarFrameImage: guest.avatarFrameImage,
        vipBadgeUrl: guest.vipBadgeUrl,
        level: guest.level,
        hostLevel: guest.hostLevel,
        liveType: guest.liveType,
      );
}
