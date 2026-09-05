import 'json_annotation_helper.dart';

/// Ported from native `VisitorsRoot.java`.
///
/// Response wrapper for `/user/visitors`.
class VisitorsRoot {
  VisitorsRoot({
    this.status = false,
    this.visitors = const [],
    this.totalVisitors = 0,
    this.message,
  });

  final bool status;
  final List<Visitor> visitors;
  final int totalVisitors;
  final String? message;

  factory VisitorsRoot.fromJson(Map<String, dynamic> json) => VisitorsRoot(
        status: parseBool(json['status']),
        visitors: parseList(json['visitors'], Visitor.fromJson),
        totalVisitors: parseInt(json['totalVisitors'], 0),
        message: parseString(json['message']),
      );
}

/// A single profile-visitor entry.
class Visitor {
  Visitor({
    this.id,
    this.name,
    this.uniqueId,
    this.avatar,
    this.visitedAt,
    this.isVIP = false,
    this.level,
    this.visitCount24h = 0,
    this.lastVisitedAt,
    this.totalTimeSpent = 0,
  });

  final String? id;
  final String? name;
  final String? uniqueId;
  final String? avatar;
  final String? visitedAt;
  final bool isVIP;
  final VisitorLevel? level;
  final int visitCount24h;
  final String? lastVisitedAt;
  final int totalTimeSpent;

  factory Visitor.fromJson(Map<String, dynamic> json) => Visitor(
        id: parseString(json['_id'] ?? json['id']),
        name: parseString(json['name']),
        uniqueId: parseString(json['uniqueId']),
        avatar: parseString(json['avatar'] ?? json['image']),
        visitedAt: parseString(json['visitedAt']),
        isVIP: parseBool(json['isVIP'] ?? json['isVip'] ?? json['vip']),
        level: json['level'] == null ? null : VisitorLevel.fromJson(json['level'] as Map<String, dynamic>),
        visitCount24h: parseInt(json['visitCount24h'], 0),
        lastVisitedAt: parseString(json['lastVisitedAt']),
        totalTimeSpent: parseInt(json['totalTimeSpent'], 0),
      );
}

class VisitorLevel {
  VisitorLevel({this.name, this.image});

  final String? name;
  final String? image;

  factory VisitorLevel.fromJson(Map<String, dynamic> json) => VisitorLevel(
        name: parseString(json['name']),
        image: parseString(json['image']),
      );
}
