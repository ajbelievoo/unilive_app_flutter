import 'json_annotation_helper.dart';

/// Payment method available for redeem / withdrawal.
/// Returned by `GET /redeem/paymentMethods`.
class RedeemPaymentMethodRoot {
  RedeemPaymentMethodRoot({this.status = false, this.message, this.methods = const []});

  final bool status;
  final String? message;
  final List<RedeemPaymentMethod> methods;

  factory RedeemPaymentMethodRoot.fromJson(Map<String, dynamic> json) => RedeemPaymentMethodRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        methods: parseList(json['methods'] ?? json['paymentMethods'] ?? json['data']?['methods'], RedeemPaymentMethod.fromJson),
      );
}

class RedeemPaymentMethod {
  RedeemPaymentMethod({
    this.id,
    this.name,
    this.icon,
    this.isEnabled = false,
    this.mode = 'manual',
    this.currency,
    this.feePercent = 0,
    this.feeFixed = 0,
    this.feeUnit = 'points',
    this.arrivalTime,
    this.fields = const [],
    this.validationRules = const {},
    this.payoutConfig,
    this.gatewayConfig,
  });

  final String? id;
  final String? name;
  final String? icon;
  final bool isEnabled;
  final String mode;
  final String? currency;
  final double feePercent;
  final double feeFixed;
  final String feeUnit;
  final String? arrivalTime;
  final List<PaymentMethodField> fields;
  final Map<String, PaymentFieldValidation> validationRules;
  final PaymentPayoutConfig? payoutConfig;
  final PaymentGatewayConfig? gatewayConfig;

  factory RedeemPaymentMethod.fromJson(Map<String, dynamic> json) {
    final rulesJson = json['validationRules'] is Map ? json['validationRules'] as Map<String, dynamic> : <String, dynamic>{};
    final rules = <String, PaymentFieldValidation>{};
    for (final entry in rulesJson.entries) {
      if (entry.value is Map) {
        rules[entry.key] = PaymentFieldValidation.fromJson(Map<String, dynamic>.from(entry.value as Map));
      }
    }

    return RedeemPaymentMethod(
      id: parseString(json['id'] ?? json['_id'] ?? json['paymentMethodId']),
      name: parseString(json['name'] ?? json['paymentMethod']),
      icon: parseString(json['icon'] ?? json['iconUrl'] ?? json['image']),
      isEnabled: parseBool(json['isEnabled'] ?? json['enabled'] ?? json['isActive']),
      mode: parseString(json['mode'] ?? json['payoutMode'], 'manual')!,
      currency: parseString(json['currency']),
      feePercent: parseDouble(json['feePercent'] ?? json['fee_percent'] ?? json['feePercentage'], 0),
      feeFixed: parseDouble(json['feeFixed'] ?? json['fee_fixed'] ?? json['fixedFee'], 0),
      feeUnit: parseString(json['feeUnit'] ?? json['fee_unit'] ?? json['feeType'], 'points')!,
      arrivalTime: parseString(json['arrivalTime'] ?? json['arrival_time'] ?? json['processingTime']),
      fields: parseList(json['fields'], PaymentMethodField.fromJson),
      validationRules: rules,
      payoutConfig: json['payoutConfig'] is Map ? PaymentPayoutConfig.fromJson(Map<String, dynamic>.from(json['payoutConfig'] as Map)) : null,
      gatewayConfig: json['gatewayConfig'] is Map ? PaymentGatewayConfig.fromJson(Map<String, dynamic>.from(json['gatewayConfig'] as Map)) : null,
    );
  }

  bool get isAuto => mode.toLowerCase() == 'auto';

  /// User-facing fee badge (e.g. "3%" or "1000 points").
  String get feeDisplay {
    if (feePercent > 0) {
      final isWhole = feePercent.truncateToDouble() == feePercent;
      return '${feePercent.toStringAsFixed(isWhole ? 0 : 1)}%';
    }
    if (feeFixed > 0) return '${feeFixed.toInt()} $feeUnit';
    return '0';
  }

  /// Currency symbol for the payout currency (PKR uses "₨", not "₹").
  String get displaySymbol {
    const map = {
      'USD': r'$',
      'INR': '₹',
      'PKR': '₨',
      'USDT': r'$',
    };
    return map[currency] ?? currency ?? '';
  }

  /// Returns the field for a given key, or null.
  PaymentMethodField? fieldFor(String key) {
    for (final f in fields) {
      if (f.key == key) return f;
    }
    return null;
  }

  /// Returns validation for a given field key, or null.
  PaymentFieldValidation? validationFor(String key) => validationRules[key];
}

class PaymentMethodField {
  PaymentMethodField({
    this.key,
    this.label,
    this.type = 'text',
    this.required = false,
    this.options = const [],
    this.placeholder,
  });

  final String? key;
  final String? label;
  final String type;
  final bool required;
  final List<String> options;
  final String? placeholder;

  factory PaymentMethodField.fromJson(Map<String, dynamic> json) => PaymentMethodField(
        key: parseString(json['key'] ?? json['name']),
        label: parseString(json['label'] ?? json['title']),
        type: parseString(json['type'], 'text')!,
        required: parseBool(json['required'] ?? json['isRequired']),
        options: _parseStringList(json['options'] ?? json['values']),
        placeholder: parseString(json['placeholder'] ?? json['hint']),
      );

  static List<String> _parseStringList(dynamic v) {
    if (v is List) {
      return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    return [];
  }
}

class PaymentFieldValidation {
  PaymentFieldValidation({
    this.minLength,
    this.maxLength,
    this.pattern,
    this.type,
    this.min,
    this.max,
  });

  final int? minLength;
  final int? maxLength;
  final String? pattern;
  final String? type;
  final num? min;
  final num? max;

  factory PaymentFieldValidation.fromJson(Map<String, dynamic> json) => PaymentFieldValidation(
        minLength: parseIntOrNull(json['minLength'] ?? json['min_length']),
        maxLength: parseIntOrNull(json['maxLength'] ?? json['max_length']),
        pattern: parseString(json['pattern'] ?? json['regex']),
        type: parseString(json['type'] ?? json['kind']),
        min: parseNum(json['min'] ?? json['minimum'], 0) == 0 ? null : parseNum(json['min'] ?? json['minimum'], 0),
        max: parseNum(json['max'] ?? json['maximum'], 0) == 0 ? null : parseNum(json['max'] ?? json['maximum'], 0),
      );

  /// Validates a string value against the configured rules.
  String? validate(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) return null;
    final name = fieldName ?? 'Field';
    if (minLength != null && value.length < minLength!) {
      return '$name must be at least $minLength characters';
    }
    if (maxLength != null && value.length > maxLength!) {
      return '$name must be at most $maxLength characters';
    }
    if (pattern != null && pattern!.isNotEmpty) {
      try {
        if (!RegExp(pattern!).hasMatch(value)) {
          return '$name is invalid';
        }
      } catch (_) {
        // Invalid regex on the backend — ignore pattern validation.
      }
    }
    if ((type == 'email' || type == 'email_address') && !_isEmail(value)) {
      return '$name must be a valid email';
    }
    if (type == 'numeric' && num.tryParse(value) == null) {
      return '$name must be a number';
    }
    if (type == 'phone' || type == 'mobile') {
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length < 7 || digits.length > 15) {
        return '$name must be a valid phone number';
      }
    }
    return null;
  }

  static bool _isEmail(String v) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v);
  }
}

class PaymentPayoutConfig {
  PaymentPayoutConfig({
    this.minAmount = 0,
    this.maxAmount = 0,
    this.fixedAmounts = const [],
  });

  final int minAmount;
  final int maxAmount;
  final List<int> fixedAmounts;

  factory PaymentPayoutConfig.fromJson(Map<String, dynamic> json) => PaymentPayoutConfig(
        minAmount: parseInt(json['minAmount'] ?? json['min_amount'] ?? json['min'], 0),
        maxAmount: parseInt(json['maxAmount'] ?? json['max_amount'] ?? json['max'], 0),
        fixedAmounts: _parseIntList(json['fixedAmounts'] ?? json['fixed_amounts'] ?? json['amounts']),
      );

  static List<int> _parseIntList(dynamic v) {
    if (v is List) {
      return v.map((e) => parseInt(e, 0)).where((n) => n > 0).toList();
    }
    return [];
  }

  /// Returns the nearest valid amount or clamps to min/max.
  int clamp(int amount) {
    if (minAmount > 0 && amount < minAmount) return minAmount;
    if (maxAmount > 0 && amount > maxAmount) return maxAmount;
    return amount;
  }
}

class PaymentGatewayConfig {
  PaymentGatewayConfig({
    this.provider,
    this.payoutDelayMinutes = 0,
    this.autoApprove = false,
    this.sandbox = false,
  });

  final String? provider;
  final int payoutDelayMinutes;
  final bool autoApprove;
  final bool sandbox;

  factory PaymentGatewayConfig.fromJson(Map<String, dynamic> json) => PaymentGatewayConfig(
        provider: parseString(json['provider'] ?? json['gateway']),
        payoutDelayMinutes: parseInt(json['payoutDelayMinutes'] ?? json['payout_delay_minutes'] ?? json['delayMinutes'], 0),
        autoApprove: parseBool(json['autoApprove'] ?? json['auto_approve']),
        sandbox: parseBool(json['sandbox'] ?? json['isSandbox']),
      );
}
