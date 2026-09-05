import 'json_annotation_helper.dart';

/// User auto-withdrawal threshold setting.
/// GET/POST `/redeem/autoWithdrawal`.
class AutoWithdrawalRoot {
  AutoWithdrawalRoot({
    this.status = false,
    this.message,
    this.enabled = false,
    this.isActive = false,
    this.threshold = 0,
    this.paymentMethodId,
    this.accountDetails,
  });

  final bool status;
  final String? message;
  final bool enabled;
  final bool isActive;
  final int threshold;
  final String? paymentMethodId;
  final Map<String, dynamic>? accountDetails;

  factory AutoWithdrawalRoot.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : null;
    final source = data ?? json;
    return AutoWithdrawalRoot(
      status: parseBool(json['status'] ?? source['status']),
      message: parseString(json['message'] ?? source['message']),
      enabled: parseBool(source['enabled'] ?? source['isEnabled']),
      isActive: parseBool(source['isActive'] ?? source['active']),
      threshold: parseInt(source['threshold'] ?? source['amount'], 0),
      paymentMethodId: parseString(source['paymentMethodId'] ?? source['paymentMethod'] ?? source['methodId']),
      accountDetails: source['accountDetails'] is Map ? Map<String, dynamic>.from(source['accountDetails'] as Map) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'isActive': isActive,
        'threshold': threshold,
        'paymentMethodId': paymentMethodId,
        'accountDetails': accountDetails,
      };
}
