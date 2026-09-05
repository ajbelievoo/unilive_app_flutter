import 'json_annotation_helper.dart';

/// Ported from native `FansRankingRoot.java` — fans leaderboard for PK battle.
class FansRankingRoot {
  FansRankingRoot({this.status = false, this.message, this.data = const []});

  final bool status;
  final String? message;
  final List<FansRankingGroup> data;

  factory FansRankingRoot.fromJson(Map<String, dynamic> json) => FansRankingRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        data: parseList(json['data'], FansRankingGroup.fromJson),
      );
}

class FansRankingGroup {
  FansRankingGroup({this.totalDiamond = 0, this.data = const []});

  final int totalDiamond;
  final List<FansRankingEntry> data;

  factory FansRankingGroup.fromJson(Map<String, dynamic> json) => FansRankingGroup(
        totalDiamond: parseInt(json['totalDiamond'], 0),
        data: parseList(json['data'], FansRankingEntry.fromJson),
      );
}

class FansRankingEntry {
  FansRankingEntry({
    this.id,
    this.userId,
    this.name,
    this.image,
    this.uniqueId,
    this.level,
    this.levelImage,
    this.totalSpentDiamond = 0,
  });

  final String? id;
  final String? userId;
  final String? name;
  final String? image;
  final String? uniqueId;
  final String? level;
  final String? levelImage;
  final int totalSpentDiamond;

  factory FansRankingEntry.fromJson(Map<String, dynamic> json) => FansRankingEntry(
        id: parseString(json['_id'] ?? json['id']),
        userId: parseString(json['userId']),
        name: parseString(json['name']),
        image: parseString(json['image']),
        uniqueId: parseString(json['uniqueId']),
        level: parseString(json['level']),
        levelImage: parseString(json['levelImage']),
        totalSpentDiamond: parseInt(json['totalSpentDiamond'], 0),
      );
}
