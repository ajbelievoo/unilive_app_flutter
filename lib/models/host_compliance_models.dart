/// Models for the AI Host Compliance & Live Presence Guard.
///
/// Mirrors the backend `LiveBan` and strike update payloads documented in
/// `HOST_COMPLIANCE_FLUTTER_INTEGRATION.md`.
library;

import 'json_annotation_helper.dart';

/// Ban status payload returned by `/hostCompliance/ban-status`.
class HostComplianceBanStatus {
  HostComplianceBanStatus({
    this.status = false,
    this.isLiveBanned = false,
    this.ban,
    this.message,
  });

  final bool status;
  final bool isLiveBanned;
  final HostComplianceBan? ban;
  final String? message;

  factory HostComplianceBanStatus.fromJson(Map<String, dynamic> json) =>
      HostComplianceBanStatus(
        status: parseBool(json['status']),
        isLiveBanned: parseBool(json['isLiveBanned']),
        ban: json['ban'] is Map<String, dynamic>
            ? HostComplianceBan.fromJson(json['ban'] as Map<String, dynamic>)
            : null,
        message: parseString(json['message']),
      );

  Map<String, dynamic> toJson() => {
        'status': status,
        'isLiveBanned': isLiveBanned,
        'ban': ban?.toJson(),
        'message': message,
      };
}

/// Active or historical live ban returned when a host is auto-banned.
class HostComplianceBan {
  HostComplianceBan({
    this.banId,
    this.reason,
    this.reasonCodes = const [],
    this.expiresAt,
    this.createdAt,
    this.isActive = true,
  });

  final String? banId;
  final String? reason;
  final List<String> reasonCodes;
  final String? expiresAt;
  final String? createdAt;
  final bool isActive;

  factory HostComplianceBan.fromJson(Map<String, dynamic> json) {
    final codes = json['reasonCodes'];
    List<String> parsedCodes = [];
    if (codes is List) {
      parsedCodes = codes.map((e) => e.toString()).toList();
    } else if (codes is String && codes.isNotEmpty) {
      parsedCodes = [codes];
    }
    return HostComplianceBan(
      banId: parseString(json['banId'] ?? json['_id'] ?? json['id']),
      reason: parseString(json['reason'] ?? json['message']),
      reasonCodes: parsedCodes,
      expiresAt: parseString(json['expiresAt'] ?? json['expireAt']),
      createdAt: parseString(json['createdAt']),
      isActive: parseBool(json['isActive'] ?? json['active'], true),
    );
  }

  Map<String, dynamic> toJson() => {
        'banId': banId,
        'reason': reason,
        'reasonCodes': reasonCodes,
        'expiresAt': expiresAt,
        'createdAt': createdAt,
        'isActive': isActive,
      };
}

/// Strike update emitted by the backend as a warning before the live is ended.
class HostComplianceStrikeUpdate {
  HostComplianceStrikeUpdate({
    this.userId,
    this.liveStreamingId,
    this.consecutiveStrike = 0,
    this.dailyStrikes = 0,
    this.reason,
    this.reasonCodes = const [],
    this.liveEnded = false,
    this.banned = false,
    this.message,
  });

  final String? userId;
  final String? liveStreamingId;
  final int consecutiveStrike;
  final int dailyStrikes;
  final String? reason;
  final List<String> reasonCodes;
  final bool liveEnded;
  final bool banned;
  final String? message;

  factory HostComplianceStrikeUpdate.fromJson(Map<String, dynamic> json) {
    final codes = json['reasonCodes'];
    List<String> parsedCodes = [];
    if (codes is List) {
      parsedCodes = codes.map((e) => e.toString()).toList();
    } else if (codes is String && codes.isNotEmpty) {
      parsedCodes = [codes];
    } else if (json['reason'] is String) {
      // Fallback: single reason string can also act as a reason code.
      final r = json['reason'].toString().toLowerCase().replaceAll(' ', '_');
      if (r.isNotEmpty) parsedCodes = [r];
    }
    return HostComplianceStrikeUpdate(
      userId: parseString(json['userId']),
      liveStreamingId: parseString(json['liveStreamingId']),
      consecutiveStrike: parseInt(json['consecutiveStrike'], 0),
      dailyStrikes: parseInt(json['dailyStrikes'], 0),
      reason: parseString(json['reason']),
      reasonCodes: parsedCodes,
      liveEnded: parseBool(json['liveEnded']),
      banned: parseBool(json['banned']),
      message: parseString(json['message']),
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'liveStreamingId': liveStreamingId,
        'consecutiveStrike': consecutiveStrike,
        'dailyStrikes': dailyStrikes,
        'reason': reason,
        'reasonCodes': reasonCodes,
        'liveEnded': liveEnded,
        'banned': banned,
        'message': message,
      };
}

/// Escalating ban tier applied after 3 continuous minutes of host
/// non-compliance (Bigo Live style).
enum HostPresenceBanTier {
  /// No ban / not yet violated.
  none,
  /// 1st violation — 5 minute streaming block.
  first,
  /// 2nd violation — 1 hour streaming block + daily reward deduction.
  second,
  /// 3rd violation — 4 hour streaming block.
  third,
}

/// Local + backend representation of an active host-presence ban.
///
/// Persisted on-device via SharedPreferences so the host cannot bypass the
/// block by restarting the app. The daily violation counter resets on
/// calendar-day rollover.
class HostPresenceBanInfo {
  HostPresenceBanInfo({
    required this.tier,
    required this.banDurationMinutes,
    required this.banStartEpochMs,
    required this.banExpiresEpochMs,
    required this.dailyViolationCount,
    required this.violationDateKey,
    this.reasonCodes = const [],
    this.reason,
  });

  final HostPresenceBanTier tier;
  final int banDurationMinutes;
  final int banStartEpochMs;
  final int banExpiresEpochMs;
  final int dailyViolationCount;
  /// `YYYY-MM-DD` of the day the violation counter belongs to. When the
  /// current day differs from this key the counter resets to zero.
  final String violationDateKey;
  final List<String> reasonCodes;
  final String? reason;

  /// Whether the ban window is still active at [now].
  bool isActive({DateTime? now}) {
    final t = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return t < banExpiresEpochMs;
  }

  /// Milliseconds remaining in the ban window (0 if expired).
  int remainingMs({DateTime? now}) {
    final t = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final left = banExpiresEpochMs - t;
    return left < 0 ? 0 : left;
  }

  factory HostPresenceBanInfo.fromJson(Map<String, dynamic> json) {
    final codes = json['reasonCodes'];
    List<String> parsedCodes = [];
    if (codes is List) {
      parsedCodes = codes.map((e) => e.toString()).toList();
    } else if (codes is String && codes.isNotEmpty) {
      parsedCodes = [codes];
    }
    return HostPresenceBanInfo(
      tier: HostPresenceBanTier.values.firstWhere(
        (e) => e.name == (json['tier']?.toString() ?? 'none'),
        orElse: () => HostPresenceBanTier.none,
      ),
      banDurationMinutes: parseInt(json['banDurationMinutes'], 0),
      banStartEpochMs: parseInt(json['banStartEpochMs'], 0),
      banExpiresEpochMs: parseInt(json['banExpiresEpochMs'], 0),
      dailyViolationCount: parseInt(json['dailyViolationCount'], 0),
      violationDateKey: parseString(json['violationDateKey'], '') ?? '',
      reasonCodes: parsedCodes,
      reason: parseString(json['reason']),
    );
  }

  Map<String, dynamic> toJson() => {
        'tier': tier.name,
        'banDurationMinutes': banDurationMinutes,
        'banStartEpochMs': banStartEpochMs,
        'banExpiresEpochMs': banExpiresEpochMs,
        'dailyViolationCount': dailyViolationCount,
        'violationDateKey': violationDateKey,
        'reasonCodes': reasonCodes,
        'reason': reason,
      };
}
