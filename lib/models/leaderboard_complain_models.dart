/// Leaderboard and complaint models.
///
/// Ported from native leaderboard and complaint endpoints. Supports
/// ranking displays and user feedback/complaint tracking.
library leaderboard_complain_models;

import 'json_annotation_helper.dart';

/// Root for the complaint list endpoint.
class ComplainRoot {
  ComplainRoot({
    this.status = false,
    this.message,
    this.complain = const [],
  });

  final bool status;
  final String? message;
  final List<ComplainItem> complain;

  factory ComplainRoot.fromJson(Map<String, dynamic> json) => ComplainRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        complain: parseList(json['data'] ?? json['complain'], ComplainItem.fromJson),
      );
}

/// A single complaint / feedback entry submitted by a user.
class ComplainItem {
  ComplainItem({
    this.id,
    this.userId,
    this.userName,
    this.userImage,
    this.issue,
    this.message,
    this.contactDetails,
    this.proofImage,
    this.status,
    this.createdAt,
  });

  final String? id;
  final String? userId;
  final String? userName;
  final String? userImage;
  final String? issue;
  final String? message;
  final String? contactDetails;
  final String? proofImage;
  final String? status;
  final String? createdAt;

  factory ComplainItem.fromJson(Map<String, dynamic> json) => ComplainItem(
        id: parseString(json['_id'] ?? json['id']),
        userId: parseString(json['userId']),
        userName: parseString(json['userName'] ?? json['name']),
        userImage: parseString(json['userImage'] ?? json['image']),
        issue: parseString(json['issue']),
        message: parseString(json['message'] ?? json['issue']),
        contactDetails: parseString(json['contactDetails'] ?? json['contact']),
        proofImage: parseString(json['proofImage']),
        status: parseString(json['status']),
        createdAt: parseString(json['createdAt']),
      );
}

/// Root for the leaderboard endpoint.
///
/// Matches the native `LeaderboadDataRoot.java` response from:
/// - `/liveUser/fetchUserSpendingRankings`
/// - `/liveUser/fetchHostReceivingRankings`
/// - `/liveUser/fetchAgencyReceivingRankings`
class LeaderboardRoot {
  LeaderboardRoot({
    this.status = false,
    this.message,
    this.leaderboard = const [],
  });

  final bool status;
  final String? message;
  final List<LeaderboardEntry> leaderboard;

  factory LeaderboardRoot.fromJson(Map<String, dynamic> json) => LeaderboardRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        leaderboard: parseList(json['data'] ?? json['leaderboard'], LeaderboardEntry.fromJson),
      );
}

/// A single entry in a leaderboard ranking.
///
/// Fields vary by leaderboard type:
/// - **user** (spending): `totalSpentDiamond` is populated
/// - **host** (receiving): `totalEarnrCoin` is populated
/// - **agency**: `finalTotalAmount` and `agency` nested object are populated
class LeaderboardEntry {
  LeaderboardEntry({
    this.id,
    this.name,
    this.image,
    this.userId,
    this.level,
    this.levelImage,
    this.avatarFrameImage,
    this.vipBadgeUrl,
    this.country,
    this.isVIP = false,
    this.isVerified = false,
    this.totalSpentDiamond = 0,
    this.totalEarnrCoin = 0,
    this.finalTotalAmount = 0,
    this.uniqueId = 0,
    this.agency,
  });

  final String? id;
  final String? name;
  final String? image;
  final String? userId;
  final String? level;
  final String? levelImage;
  final String? avatarFrameImage;
  final String? vipBadgeUrl;
  /// Country code (e.g. 'IN', 'BD', 'PH') for showing the flag in fan ranking.
  final String? country;
  final bool isVIP;
  final bool isVerified;
  final double totalSpentDiamond;
  final int totalEarnrCoin;
  final int finalTotalAmount;
  final int uniqueId;
  final LeaderboardAgency? agency;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
        id: parseString(json['_id'] ?? json['id']),
        name: parseString(json['name']),
        image: parseString(json['image']),
        userId: parseString(json['userId']),
        level: parseString(json['level']),
        levelImage: parseString(json['levelImage']),
        avatarFrameImage: parseString(json['avatarFrameImage'] ?? json['frameImage'] ?? json['frameUrl']),
        vipBadgeUrl: parseString(json['vipBadgeUrl']),
        country: parseString(json['country'] ?? json['countryCode'] ?? json['nationality']),
        isVIP: parseBool(json['isVIP'] ?? json['isVip'] ?? json['vip']),
        isVerified: parseBool(json['isVerified']),
        totalSpentDiamond: (json['totalSpentDiamond'] as num?)?.toDouble() ?? 0,
        totalEarnrCoin: parseInt(json['totalEarnrCoin'], 0),
        finalTotalAmount: parseInt(json['finalTotalAmount'], 0),
        uniqueId: parseInt(json['uniqueId'], 0),
        agency: json['agency'] is Map<String, dynamic>
            ? LeaderboardAgency.fromJson(json['agency'] as Map<String, dynamic>)
            : null,
      );

  /// Returns the ranking value based on type:
  /// - `user` ? `totalSpentDiamond`
  /// - `host` ? `totalEarnrCoin`
  /// - `agency` ? `finalTotalAmount`
  int rankingValue(String type) {
    switch (type) {
      case 'host':
        return totalEarnrCoin;
      case 'agency':
        return finalTotalAmount;
      default:
        return totalSpentDiamond.toInt();
    }
  }

  /// Beans shown in Chamet-style fan ranking (host receiving rankings use
  /// totalEarnrCoin; user spending rankings use totalSpentDiamond).
  int get fanRankingValue => totalEarnrCoin > 0
      ? totalEarnrCoin
      : totalSpentDiamond.toInt();

  /// Effective display name (agency name for agency type).
  String get displayName => agency?.name ?? name ?? 'Unknown';

  /// Effective image URL (agency image for agency type).
  String? get displayImage => agency?.image ?? image;
}

/// Nested agency info inside a leaderboard entry (agency type only).
class LeaderboardAgency {
  LeaderboardAgency({this.name, this.image});

  final String? name;
  final String? image;

  factory LeaderboardAgency.fromJson(Map<String, dynamic> json) => LeaderboardAgency(
        name: parseString(json['name']),
        image: parseString(json['image']),
      );
}

