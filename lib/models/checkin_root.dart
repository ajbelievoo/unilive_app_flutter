import 'json_annotation_helper.dart';

/// One reward slot in the daily check-in table.
/// [type] is 'rcoin' (beans) or 'coin' (diamonds).
class CheckInReward {
  CheckInReward({this.day = 0, this.type = 'rcoin', this.amount = 0});

  final int day;
  final String type;
  final int amount;

  factory CheckInReward.fromJson(Map<String, dynamic> json) => CheckInReward(
        day: parseInt(json['day']),
        type: parseString(json['type'], 'rcoin') ?? 'rcoin',
        amount: parseInt(json['amount']),
      );
}

/// One past claim entry (day, reward type/amount, date).
class CheckInHistoryEntry {
  CheckInHistoryEntry({this.day = 0, this.type = 'rcoin', this.amount = 0, this.date = ''});

  final int day;
  final String type;
  final int amount;
  final String date;

  factory CheckInHistoryEntry.fromJson(Map<String, dynamic> json) => CheckInHistoryEntry(
        day: parseInt(json['day']),
        type: parseString(json['type'], 'rcoin') ?? 'rcoin',
        amount: parseInt(json['amount']),
        date: parseString(json['date']) ?? '',
      );
}

/// `GET /checkin/status` payload.
class CheckInStatus {
  CheckInStatus({
    this.canClaim = false,
    this.nextDay = 1,
    this.claimedDay = 0,
    this.lastClaimDate = '',
    this.totalClaims = 0,
    this.rewards = const [],
    this.history = const [],
  });

  final bool canClaim;
  final int nextDay;

  /// Cycle day claimed *today* (0 = nothing claimed today).
  final int claimedDay;
  final String lastClaimDate;
  final int totalClaims;
  final List<CheckInReward> rewards;
  final List<CheckInHistoryEntry> history;

  factory CheckInStatus.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : json;
    return CheckInStatus(
      canClaim: parseBool(data['canClaim']),
      nextDay: parseInt(data['nextDay'], 1),
      claimedDay: parseInt(data['claimedDay']),
      lastClaimDate: parseString(data['lastClaimDate']) ?? '',
      totalClaims: parseInt(data['totalClaims']),
      rewards: parseList(data['rewards'], CheckInReward.fromJson),
      history: parseList(data['history'], CheckInHistoryEntry.fromJson),
    );
  }
}

/// `POST /checkin/claim` payload.
class CheckInClaimRoot {
  CheckInClaimRoot({this.status = false, this.message, this.day, this.reward, this.nextDay});

  final bool status;
  final String? message;
  final int? day;
  final CheckInReward? reward;
  final int? nextDay;

  factory CheckInClaimRoot.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : <String, dynamic>{};
    return CheckInClaimRoot(
      status: parseBool(json['status']),
      message: parseString(json['message']),
      day: parseIntOrNull(data['day']),
      nextDay: parseIntOrNull(data['nextDay']),
      reward: data['reward'] is Map<String, dynamic> ? CheckInReward.fromJson(data['reward']) : null,
    );
  }
}
