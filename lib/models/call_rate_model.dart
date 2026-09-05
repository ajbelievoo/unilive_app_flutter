import 'json_annotation_helper.dart';

/// Represents a single level-to-rate mapping from `/api/call-rate/config`.
class CallRateLevel {
  CallRateLevel({
    this.level = 0,
    this.rate = 0,
    this.label,
  });

  final int level;
  final int rate;
  final String? label;

  factory CallRateLevel.fromJson(Map<String, dynamic> json) => CallRateLevel(
        level: parseInt(json['level']),
        rate: parseInt(json['rate']),
        label: parseString(json['label']),
      );

  Map<String, dynamic> toJson() => {
        'level': level,
        'rate': rate,
        'label': label,
      };
}

/// Response from `GET /api/call-rate/config`.
class CallRateConfigRoot {
  CallRateConfigRoot({this.status = false, this.levels = const []});

  final bool status;
  final List<CallRateLevel> levels;

  factory CallRateConfigRoot.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    return CallRateConfigRoot(
      status: parseBool(json['status']),
      levels: parseList(data['levels'], CallRateLevel.fromJson),
    );
  }
}

/// Response from `GET /api/call-rate/host?userId=...`.
class HostCallRate {
  HostCallRate({
    this.userId,
    this.hostLevel = 0,
    this.customRate,
    this.effectiveRate = 0,
    this.maxAllowedRate = 0,
    this.availableRates = const [],
  });

  final String? userId;
  final int hostLevel;
  final int? customRate;
  final int effectiveRate;
  final int maxAllowedRate;
  final List<int> availableRates;

  factory HostCallRate.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    final rates = <int>[];
    if (data['availableRates'] is List) {
      for (final r in data['availableRates'] as List) {
        rates.add(parseInt(r));
      }
    }
    return HostCallRate(
      userId: parseString(data['userId']),
      hostLevel: parseInt(data['hostLevel']),
      customRate: parseIntOrNull(data['customRate']),
      effectiveRate: parseInt(data['effectiveRate']),
      maxAllowedRate: parseInt(data['maxAllowedRate']),
      availableRates: rates,
    );
  }
}

/// Response from `POST /api/call-rate/set` or `POST /api/call-rate/reset`.
class CallRateUpdateRoot {
  CallRateUpdateRoot({this.status = false, this.message, this.data});

  final bool status;
  final String? message;
  final HostCallRate? data;

  factory CallRateUpdateRoot.fromJson(Map<String, dynamic> json) {
    HostCallRate? rate;
    if (json['data'] is Map<String, dynamic>) {
      rate = HostCallRate.fromJson(json);
    }
    return CallRateUpdateRoot(
      status: parseBool(json['status']),
      message: parseString(json['message']),
      data: rate,
    );
  }
}
