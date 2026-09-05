import 'json_annotation_helper.dart';

/// Response from `POST /redeem/calculate`.
/// Converts a Beans amount to the payout currency amount.
class RedeemCalculationRoot {
  RedeemCalculationRoot({
    this.status = false,
    this.message,
    this.beans = 0,
    this.units = 0,
    this.currency,
    this.amount = 0,
    this.symbol,
    this.display,
    this.fee = 0,
    this.feePercent = 0,
    this.feeFixed = 0,
    this.feeUnit = 'points',
    this.feeDisplay,
    this.netBeans = 0,
    this.netAmount = 0,
    this.arrivalTime,
  });

  final bool status;
  final String? message;
  final int beans;
  final double units;
  final String? currency;
  final double amount;
  final String? symbol;
  final String? display;
  final double fee;
  final double feePercent;
  final double feeFixed;
  final String feeUnit;
  final String? feeDisplay;
  final int netBeans;
  final double netAmount;
  final String? arrivalTime;

  factory RedeemCalculationRoot.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : null;
    final source = data ?? json;
    final amount = parseDouble(source['amount'] ?? source['netAmount'] ?? source['net_amount'] ?? source['value'], 0);
    final beans = parseInt(source['beans'] ?? source['coin'] ?? source['rCoin'], 0);
    final fee = parseDouble(source['fee'] ?? source['charges'], 0);
    final feePercent = parseDouble(source['feePercent'] ?? source['fee_percent'] ?? source['feePercentage'], 0);
    final feeFixed = parseDouble(source['feeFixed'] ?? source['fee_fixed'] ?? source['fixedFee'], 0);
    final feeUnit = parseString(source['feeUnit'] ?? source['fee_unit'] ?? source['feeType'], 'points')!;
    final feeDisplay = parseString(source['feeDisplay'] ?? source['fee_display'] ?? source['feeLabel']);
    final netBeans = parseInt(source['netBeans'] ?? source['net_beans'] ?? source['netCoin'], beans - fee.toInt());
    final netAmount = parseDouble(source['netAmount'] ?? source['net_amount'] ?? source['net'], amount);
    var symbol = parseString(source['symbol'] ?? source['currencySymbol']);
    final currency = parseString(source['currency']);
    var display = parseString(source['display'] ?? source['formatted']);
    final arrivalTime = parseString(source['arrivalTime'] ?? source['arrival_time'] ?? source['processingTime']);

    // PKR must use ₨, not ₹.
    const symbolMap = {
      'USD': r'$',
      'INR': '₹',
      'PKR': '₨',
      'USDT': r'$',
    };
    if ((symbol == null || symbol.isEmpty) && currency != null) {
      symbol = symbolMap[currency] ?? currency;
    }
    if (currency == 'PKR' && symbol == '₹') {
      symbol = '₨';
    }
    if (display != null && currency == 'PKR' && display.contains('₹')) {
      display = display.replaceFirst('₹', '₨');
    }

    final units = parseDouble(source['units'] ?? source['unit'], 0);
    return RedeemCalculationRoot(
      status: parseBool(json['status'] ?? source['status']),
      message: parseString(json['message'] ?? source['message']),
      beans: beans,
      units: units > 0 ? units : (amount > 0 ? amount : beans / 100),
      currency: currency,
      amount: amount,
      symbol: symbol,
      display: display,
      fee: fee,
      feePercent: feePercent,
      feeFixed: feeFixed,
      feeUnit: feeUnit,
      feeDisplay: feeDisplay,
      netBeans: netBeans,
      netAmount: netAmount,
      arrivalTime: arrivalTime,
    );
  }

  /// Returns the fee as a user-facing badge, computing it if needed.
  String get displayFee {
    if (feeDisplay != null && feeDisplay!.isNotEmpty) return feeDisplay!;
    if (feePercent > 0) {
      final isWhole = feePercent.truncateToDouble() == feePercent;
      return '${feePercent.toStringAsFixed(isWhole ? 0 : 1)}%';
    }
    if (feeFixed > 0) return '${feeFixed.toInt()} $feeUnit';
    return '${fee.toInt()} $feeUnit';
  }

  /// Returns a user-friendly display string, falling back to computed value.
  String displayAmount() {
    if (display != null && display!.isNotEmpty) return display!;
    final sym = symbol ?? currency ?? '';
    if (amount > 0) return '$sym${amount.toStringAsFixed(2)}';
    return '';
  }
}
