import 'json_annotation_helper.dart';
import 'level_rewards_models.dart';

/// Alias for [LevelRoot] — used by `ApiService.getLevelSummary`.
typedef LevelSummaryRoot = LevelRoot;

/// Ported from native `LevelRoot.java` — user level list.
class LevelRoot {
  LevelRoot({this.level = const [], this.message, this.status = false});

  final List<LevelItem> level;
  final String? message;
  final bool status;

  factory LevelRoot.fromJson(Map<String, dynamic> json) => LevelRoot(
        level: parseList(json['level'], LevelItem.fromJson),
        message: parseString(json['message']),
        status: parseBool(json['status']),
      );
}

class LevelItem {
  LevelItem({
    this.id,
    this.name,
    this.image,
    this.coin = 0,
    this.cashOut = false,
    this.freeCall = false,
    this.liveStreaming = false,
    this.uploadPost = false,
    this.uploadVideo = false,
    this.game = false,
    this.commentColor,
    this.reportBanThreshold = 0,
    this.rewards = const [],
    this.rewardGroups,
  });

  final String? id;
  final String? name;
  final String? image;
  final int coin;
  final bool cashOut;
  final bool freeCall;
  final bool liveStreaming;
  final bool uploadPost;
  final bool uploadVideo;
  final bool game;

  /// Hex color string (e.g. `#be00cc`) used for the user's comment text.
  final String? commentColor;

  /// Auto-ban threshold for reports. `0` means disabled.
  final int reportBanThreshold;

  /// Admin-configurable rewards for this level (legacy flat list).
  final List<LevelReward> rewards;

  /// Grouped admin-configurable rewards for this level (preferred).
  final LevelRewardGroup? rewardGroups;

  factory LevelItem.fromJson(Map<String, dynamic> json) {
    // Support both nested `accessibleFunction` object (new backend) and
    // flat top-level fields (legacy backend) for backward compatibility.
    final af = json['accessibleFunction'];
    final afMap = af is Map<String, dynamic>
        ? af
        : af is Map
            ? Map<String, dynamic>.from(af)
            : null;

    return LevelItem(
      id: parseString(json['_id'] ?? json['id']),
      name: parseString(json['name']),
      image: parseString(json['image']),
      coin: parseInt(json['coin'], 0),
      cashOut: parseBool(afMap?['cashOut'] ?? json['cashOut']),
      freeCall: parseBool(afMap?['freeCall'] ?? json['freeCall']),
      liveStreaming: parseBool(afMap?['liveStreaming'] ?? json['liveStreaming']),
      uploadPost: parseBool(afMap?['uploadPost'] ?? json['uploadPost']),
      uploadVideo: parseBool(afMap?['uploadVideo'] ?? json['uploadVideo']),
      game: parseBool(afMap?['game'] ?? json['game']),
      commentColor: parseString(json['commentColor']),
      reportBanThreshold: parseInt(json['reportBanThreshold'], 0),
      rewards: parseList(json['rewards'], LevelReward.fromJson),
      rewardGroups: json['rewardGroup'] is Map<String, dynamic>
          ? LevelRewardGroup.fromJson(json['rewardGroup'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Ported from native `HostLevelRoot.java` — host level list.
class HostLevelRoot {
  HostLevelRoot({this.hostLevel = const [], this.message, this.status = false});

  final List<HostLevelItem> hostLevel;
  final String? message;
  final bool status;

  factory HostLevelRoot.fromJson(Map<String, dynamic> json) => HostLevelRoot(
        hostLevel: parseList(json['hostLevel'] ?? json['level'], HostLevelItem.fromJson),
        message: parseString(json['message']),
        status: parseBool(json['status']),
      );
}

class HostLevelItem {
  HostLevelItem({
    this.id,
    this.name,
    this.image,
    this.coin = 0,
    this.bgColor,
    this.reportBanThreshold = 0,
    this.callRate = 0,
    this.rewards = const [],
    this.rewardGroup,
  });

  final String? id;
  final String? name;
  final String? image;
  final int coin;
  final String? bgColor;

  /// Auto-ban threshold for reports. `0` means disabled.
  final int reportBanThreshold;

  /// Maximum allowed call rate (coins/minute) for hosts at this level.
  final int callRate;

  /// Admin-configurable host-level rewards (legacy flat list).
  final List<LevelReward> rewards;

  /// Grouped admin-configurable rewards for this level.
  final LevelRewardGroup? rewardGroup;

  factory HostLevelItem.fromJson(Map<String, dynamic> json) => HostLevelItem(
        id: parseString(json['_id'] ?? json['id']),
        name: parseString(json['name']),
        image: parseString(json['image']),
        coin: parseInt(json['coin'], 0),
        bgColor: parseString(json['bgColor']),
        reportBanThreshold: parseInt(json['reportBanThreshold'], 0),
        callRate: parseInt(json['callRate'], 0),
        rewards: parseList(json['rewards'], LevelReward.fromJson),
        rewardGroup: json['rewardGroup'] is Map<String, dynamic>
            ? LevelRewardGroup.fromJson(json['rewardGroup'] as Map<String, dynamic>)
            : null,
      );
}

/// Ported from native `LiveSummaryRoot.java` — post-stream statistics.
class LiveSummaryRoot {
  LiveSummaryRoot({
    this.status = false,
    this.message,
    this.duration = 0,
    this.comments = 0,
    this.rCoin = 0,
    this.user = 0,
    this.gifts = 0,
    this.fans = 0,
    this.createdAt,
  });

  final bool status;
  final String? message;
  final int duration; // seconds
  final int comments;
  final int rCoin;
  final int user; // joined count
  final int gifts;
  final int fans; // new fans
  final String? createdAt;

  factory LiveSummaryRoot.fromJson(Map<String, dynamic> json) => LiveSummaryRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        duration: parseInt(json['duration'] ?? json['time'] ?? json['streamDuration'], 0),
        comments: parseInt(json['comments'] ?? json['comment'] ?? json['totalComments'], 0),
        rCoin: parseInt(json['rCoin'] ?? json['rcoin'] ?? json['r_coin'] ?? json['coin'] ?? json['totalCoin'], 0),
        user: parseInt(json['user'] ?? json['viewers'] ?? json['views'] ?? json['viewCount'] ?? json['view'], 0),
        gifts: parseInt(json['gifts'] ?? json['gift'] ?? json['giftCount'] ?? json['totalGifts'], 0),
        fans: parseInt(json['fans'] ?? json['newFans'] ?? json['newFan'] ?? json['fan'], 0),
        createdAt: parseString(json['createdAt']),
      );

  LiveSummaryRoot copyWith({
    bool? status,
    String? message,
    int? duration,
    int? comments,
    int? rCoin,
    int? user,
    int? gifts,
    int? fans,
    String? createdAt,
  }) =>
      LiveSummaryRoot(
        status: status ?? this.status,
        message: message ?? this.message,
        duration: duration ?? this.duration,
        comments: comments ?? this.comments,
        rCoin: rCoin ?? this.rCoin,
        user: user ?? this.user,
        gifts: gifts ?? this.gifts,
        fans: fans ?? this.fans,
        createdAt: createdAt ?? this.createdAt,
      );
}

/// Ported from native `HeshtagsRoot.java` — hashtag search results.
class HashtagRoot {
  HashtagRoot({this.data = const [], this.message, this.status = false});

  final List<HashtagItem> data;
  final String? message;
  final bool status;

  factory HashtagRoot.fromJson(Map<String, dynamic> json) => HashtagRoot(
        data: parseList(json['data'] ?? json['hashtag'], HashtagItem.fromJson),
        message: parseString(json['message']),
        status: parseBool(json['status']),
      );
}

class HashtagItem {
  HashtagItem({this.id, this.hashtag = '', this.count = 0});

  final String? id;
  final String hashtag;
  final int count;

  factory HashtagItem.fromJson(Map<String, dynamic> json) => HashtagItem(
        id: parseString(json['_id'] ?? json['id']),
        hashtag: parseString(json['hashtag']) ?? '',
        count: parseInt(json['count'], 0),
      );
}

/// Ported from native `ActivityRoot.java` — activity center items.
class ActivityRoot {
  ActivityRoot({this.data = const [], this.message, this.status = false});

  final List<ActivityItem> data;
  final String? message;
  final bool status;

  factory ActivityRoot.fromJson(Map<String, dynamic> json) => ActivityRoot(
        data: parseList(json['data'] ?? json['activity'], ActivityItem.fromJson),
        message: parseString(json['message']),
        status: parseBool(json['status']),
      );
}

class ActivityItem {
  ActivityItem({
    this.id,
    this.title,
    this.description,
    this.type,
    this.image,
    this.createdAt,
    this.actionType,
    this.actionData,
  });

  final String? id;
  final String? title;
  final String? description;
  final String? type;
  final String? image;
  final String? createdAt;
  final String? actionType;
  final String? actionData;

  factory ActivityItem.fromJson(Map<String, dynamic> json) => ActivityItem(
        id: parseString(json['_id'] ?? json['id']),
        title: parseString(json['title']),
        description: parseString(json['description']),
        type: parseString(json['type']),
        image: parseString(json['image']),
        createdAt: parseString(json['createdAt']),
        actionType: parseString(json['actionType'] ?? json['action_type']),
        actionData: parseString(json['actionData'] ?? json['action_data'] ?? json['userId'] ?? json['fromUserId']),
      );
}

/// Ported from native `RatingRoot.java` — host rating.
class RatingRoot {
  RatingRoot({this.status = false, this.message, this.averageRating = 0, this.totalRatings = 0, this.userRating = 0});

  final bool status;
  final String? message;
  final double averageRating;
  final int totalRatings;
  final int userRating;

  factory RatingRoot.fromJson(Map<String, dynamic> json) => RatingRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        averageRating: parseDouble(json['averageRating']),
        totalRatings: parseInt(json['totalRatings'], 0),
        userRating: parseInt(json['userRating'], 0),
      );
}
