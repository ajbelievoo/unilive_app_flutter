import 'json_annotation_helper.dart';

// ---------------------------------------------------------------------------
//  Level Rewards — admin-configurable rewards per user/host level
// ---------------------------------------------------------------------------
//
//  One level can grant multiple rewards.  Admins create/edit/delete these
//  rewards from the admin panel.  The Flutter app renders the rewards on
//  the Level & Host Level screens.
//
//  Reward types (admin-defined, extendable):
//    medal       : Level medal badge image (e.g. Lv.10 Medal)
//    frame       : Profile avatar frame with duration in days
//    customId    : Short/custom user ID digits with duration
//    background  : Profile background image with duration
//    openingPage : App launch/splash cover with duration
//    entrance    : Room entry animation with duration
//    privilege   : Privilege card (e.g. Entry Bar, Portrait Frame)
//    rule        : Level rule / benefit description (read-only display)
//
// ---------------------------------------------------------------------------

/// Reward granted to a user when they reach a specific level.
class LevelReward {
  LevelReward({
    this.id,
    this.levelId,
    this.type = '',
    this.name,
    this.image,
    this.value,
    this.durationInDays = 0,
    this.isPermanent = false,
    this.isLocked = false,
    this.requiredLevel = 0,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String? levelId;
  final String type;
  final String? name;
  final String? image;
  final String? value;
  final int durationInDays;
  final bool isPermanent;
  final bool isLocked;
  final int requiredLevel;
  final String? description;
  final String? createdAt;
  final String? updatedAt;

  factory LevelReward.fromJson(Map<String, dynamic> json) => LevelReward(
        id: parseString(json['_id'] ?? json['id']),
        levelId: parseString(json['levelId']),
        type: (json['type'] as String? ?? '').toLowerCase(),
        name: parseString(json['name']),
        image: parseString(json['image']),
        value: parseString(json['value']),
        durationInDays: parseInt(json['durationInDays'] ?? json['duration'], 0),
        isPermanent: parseBool(json['isPermanent']),
        isLocked: parseBool(json['isLocked']),
        requiredLevel: parseInt(json['requiredLevel'], 0),
        description: parseString(json['description']),
        createdAt: parseString(json['createdAt']),
        updatedAt: parseString(json['updatedAt']),
      );

  /// Display label for the reward type.
  String get typeLabel {
    switch (type) {
      case 'medal':
        return 'Medal';
      case 'frame':
        return 'Frame';
      case 'customid':
      case 'custom_id':
        return 'Custom ID';
      case 'background':
        return 'Profile Background';
      case 'openingpage':
      case 'opening_page':
        return 'Opening Page';
      case 'entrance':
        return 'Entrance';
      case 'privilege':
        return 'Privilege';
      case 'rule':
        return 'Rule';
      default:
        return type.toUpperCase();
    }
  }

  /// Whether this reward can be "used" by the user.
  bool get isUsable => type == 'frame' ||
      type == 'customid' ||
      type == 'background' ||
      type == 'openingpage' ||
      type == 'opening_page' ||
      type == 'entrance';
}

/// A group of rewards for a single level (returned by admin-config endpoint).
class LevelRewardGroup {
  LevelRewardGroup({
    this.level = 0,
    this.name,
    this.image,
    this.coin = 0,
    this.rewards = const [],
  });

  final int level;
  final String? name;
  final String? image;
  final int coin;
  final List<LevelReward> rewards;

  factory LevelRewardGroup.fromJson(Map<String, dynamic> json) => LevelRewardGroup(
        level: parseInt(json['level'], 0),
        name: parseString(json['name']),
        image: parseString(json['image']),
        coin: parseInt(json['coin'], 0),
        rewards: parseList(json['rewards'], LevelReward.fromJson),
      );

  /// Rewards grouped by their UI tab.
  Map<String, List<LevelReward>> rewardsByTab() {
    final map = <String, List<LevelReward>>{};
    for (final r in rewards) {
      map.putIfAbsent(r.type, () => []).add(r);
    }
    return map;
  }
}

/// Response from the backend containing all user-level rewards.
class LevelRewardsRoot {
  LevelRewardsRoot({
    this.status = false,
    this.message,
    this.data = const [],
  });

  final bool status;
  final String? message;
  final List<LevelRewardGroup> data;

  factory LevelRewardsRoot.fromJson(Map<String, dynamic> json) => LevelRewardsRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        data: parseList(json['data'] ?? json['level'], LevelRewardGroup.fromJson),
      );
}

/// Response from the backend containing all host-level rewards.
class HostLevelRewardsRoot {
  HostLevelRewardsRoot({
    this.status = false,
    this.message,
    this.data = const [],
  });

  final bool status;
  final String? message;
  final List<LevelRewardGroup> data;

  factory HostLevelRewardsRoot.fromJson(Map<String, dynamic> json) => HostLevelRewardsRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        data: parseList(json['data'] ?? json['hostLevel'], LevelRewardGroup.fromJson),
      );
}
