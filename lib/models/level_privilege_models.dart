import 'json_annotation_helper.dart';

/// Response wrapper for `/api/levels/privileges`.
class LevelPrivilegesRoot {
  LevelPrivilegesRoot({this.levels = const [], this.message, this.status = false});

  final List<LevelPrivilegesItem> levels;
  final String? message;
  final bool status;

  factory LevelPrivilegesRoot.fromJson(Map<String, dynamic> json) => LevelPrivilegesRoot(
        levels: parseList(json['data']?['levels'] ?? json['levels'], LevelPrivilegesItem.fromJson),
        message: parseString(json['message']),
        status: parseBool(json['status']),
      );
}

/// One level with its list of privileges.
class LevelPrivilegesItem {
  LevelPrivilegesItem({
    this.level = 0,
    this.name,
    this.requiredBeans = 0,
    this.iconUrl,
    this.privileges = const [],
  });

  final int level;
  final String? name;
  final int requiredBeans;
  final String? iconUrl;
  final List<LevelPrivilege> privileges;

  factory LevelPrivilegesItem.fromJson(Map<String, dynamic> json) => LevelPrivilegesItem(
        level: parseInt(json['level'], 0),
        name: parseString(json['name']),
        requiredBeans: parseInt(json['requiredBeans'], 0),
        iconUrl: parseString(json['iconUrl']),
        privileges: parseList(json['privileges'], LevelPrivilege.fromJson),
      );
}

/// A single privilege/perk under a level.
class LevelPrivilege {
  LevelPrivilege({
    this.id,
    this.title,
    this.description,
    this.iconUrl,
  });

  final String? id;
  final String? title;
  final String? description;
  final String? iconUrl;

  factory LevelPrivilege.fromJson(Map<String, dynamic> json) => LevelPrivilege(
        id: parseString(json['id']),
        title: parseString(json['title']),
        description: parseString(json['description']),
        iconUrl: parseString(json['iconUrl']),
      );
}

/// Response wrapper for `/api/user/level-progress`.
class UserLevelProgressRoot {
  UserLevelProgressRoot({this.data, this.message, this.status = false});

  final UserLevelProgress? data;
  final String? message;
  final bool status;

  factory UserLevelProgressRoot.fromJson(Map<String, dynamic> json) => UserLevelProgressRoot(
        data: json['data'] == null ? null : UserLevelProgress.fromJson(json['data'] as Map<String, dynamic>),
        message: parseString(json['message']),
        status: parseBool(json['status']),
      );
}

/// Current user level progress and monthly beans.
class UserLevelProgress {
  UserLevelProgress({
    this.currentLevel = 0,
    this.currentBeans = 0,
    this.nextLevel = 1,
    this.beansNeededForNext = 0,
    this.lastMonthBeans = 0,
    this.thisMonthBeans = 0,
    this.randomCallEarningPerMin = 0,
  });

  final int currentLevel;
  final int currentBeans;
  final int nextLevel;
  final int beansNeededForNext;
  final int lastMonthBeans;
  final int thisMonthBeans;
  final int randomCallEarningPerMin;

  factory UserLevelProgress.fromJson(Map<String, dynamic> json) => UserLevelProgress(
        currentLevel: parseInt(json['currentLevel'], 0),
        currentBeans: parseInt(json['currentBeans'], 0),
        nextLevel: parseInt(json['nextLevel'], 1),
        beansNeededForNext: parseInt(json['beansNeededForNext'], 0),
        lastMonthBeans: parseInt(json['lastMonthBeans'], 0),
        thisMonthBeans: parseInt(json['thisMonthBeans'], 0),
        randomCallEarningPerMin: parseInt(json['randomCallEarningPerMin'], 0),
      );
}
