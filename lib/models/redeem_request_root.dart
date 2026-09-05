import 'json_annotation_helper.dart';

/// Ported from native `RedeemRoot.java` — coin seller redeem request list.
/// Updated for the new redeem/withdrawal system.
class RedeemRequestRoot {
  RedeemRequestRoot({this.status = false, this.message, this.redeem = const []});

  final bool status;
  final String? message;
  final List<RedeemRequestItem> redeem;

  factory RedeemRequestRoot.fromJson(Map<String, dynamic> json) => RedeemRequestRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        redeem: parseList(json['redeem'] ?? json['redeemRequests'] ?? json['data']?['redeem'], RedeemRequestItem.fromJson),
      );
}

class RedeemRequestItem {
  RedeemRequestItem({
    this.id,
    this.user,
    this.userId,
    this.coinSellerId,
    this.amount = 0,
    this.rCoin = 0,
    this.currency,
    this.status,
    this.paymentGateway,
    this.paymentMethodId,
    this.accountDetails,
    this.transactionId,
    this.description,
    this.notes,
    this.proof,
    this.person,
    this.isHost = false,
    this.isAuto = false,
    this.fee = 0,
    this.feePercent = 0,
    this.feeFixed = 0,
    this.feeUnit = 'points',
    this.arrivalTime,
    this.date,
    this.paidAt,
    this.acceptDeclineDate,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final RedeemRequestUser? user;
  final RedeemRequestUser? userId;
  final String? coinSellerId;
  final double amount;
  final double rCoin;
  final String? currency;
  final int? status;
  final String? paymentGateway;
  final String? paymentMethodId;
  final Map<String, dynamic>? accountDetails;
  final String? transactionId;
  final String? description;
  final String? notes;
  final String? proof;
  final String? person;
  final bool isHost;
  final bool isAuto;
  final double fee;
  final double feePercent;
  final double feeFixed;
  final String feeUnit;
  final String? arrivalTime;
  final String? date;
  final String? paidAt;
  final String? acceptDeclineDate;
  final String? createdAt;
  final String? updatedAt;

  /// Status mapping:
  /// 0 = pending
  /// 1 = in_progress
  /// 2 = approved
  /// 3 = declined
  /// 4 = auto_approved (paid)
  factory RedeemRequestItem.fromJson(Map<String, dynamic> json) {
    final raw = json['status'];
    final rawStatus = raw is num
        ? raw.toInt()
        : raw is String
            ? _statusFromString(raw)
            : parseInt(raw, 0);

    // Defensive: tolerate legacy statuses if seed migration has not run.
    final int normalizedStatus;
    if (rawStatus == 10) {
      normalizedStatus = 2;
    } else if (rawStatus == 20) {
      normalizedStatus = 3;
    } else if (rawStatus >= 0 && rawStatus <= 4) {
      normalizedStatus = rawStatus;
    } else if (raw == 'accepted' || raw == 'solved') {
      normalizedStatus = 2;
    } else if (raw == 'declined') {
      normalizedStatus = 3;
    } else {
      normalizedStatus = 0;
    }

    Map<String, dynamic>? details;
    final detailsRaw = json['accountDetails'] ?? json['account_details'] ?? json['paymentDetails'];
    if (detailsRaw is Map) {
      details = Map<String, dynamic>.from(detailsRaw);
    } else if (detailsRaw is String && detailsRaw.isNotEmpty) {
      // Legacy string details are preserved as a single key.
      details = {'details': detailsRaw};
    }

    final userRaw = json['userId'] ?? json['user'];
    RedeemRequestUser? parsedUser;
    if (userRaw is Map<String, dynamic>) {
      parsedUser = RedeemRequestUser.fromJson(userRaw);
    }

    return RedeemRequestItem(
      id: parseString(json['_id'] ?? json['id']),
      user: parsedUser,
      userId: parsedUser,
      coinSellerId: parseString(json['coinSellerId']),
      amount: parseDouble(json['amount'], 0),
      rCoin: parseDouble(json['rCoin'] ?? json['coin'] ?? json['beans'], 0),
      currency: parseString(json['currency']),
      status: normalizedStatus,
      paymentGateway: parseString(json['paymentGateway'] ?? json['paymentMethod']),
      paymentMethodId: parseString(json['paymentMethodId'] ?? json['payment_method_id']),
      accountDetails: details,
      transactionId: parseString(json['transactionId'] ?? json['transaction_id'] ?? json['txnId']),
      description: parseString(json['description']),
      notes: parseString(json['notes'] ?? json['adminNote']),
      proof: parseString(json['proof']),
      person: parseString(json['person']),
      isHost: parseBool(json['isHost']),
      isAuto: parseBool(json['isAuto'] ?? json['auto']),
      fee: parseDouble(json['fee'] ?? json['feeAmount'], 0),
      feePercent: parseDouble(json['feePercent'] ?? json['fee_percent'] ?? json['feePercentage'], 0),
      feeFixed: parseDouble(json['feeFixed'] ?? json['fee_fixed'] ?? json['fixedFee'], 0),
      feeUnit: parseString(json['feeUnit'] ?? json['fee_unit'] ?? json['feeType'], 'points')!,
      arrivalTime: parseString(json['arrivalTime'] ?? json['arrival_time'] ?? json['processingTime']),
      date: parseString(json['date']),
      paidAt: parseString(json['paidAt'] ?? json['paid_at'] ?? json['paymentDate']),
      acceptDeclineDate: parseString(json['acceptDeclineDate'] ?? json['resolvedAt']),
      createdAt: parseString(json['createdAt'] ?? json['created_at']),
      updatedAt: parseString(json['updatedAt'] ?? json['updated_at']),
    );
  }

  static int _statusFromString(String s) {
    switch (s.toLowerCase()) {
      case 'pending':
        return 0;
      case 'in_progress':
      case 'inprogress':
      case 'processing':
        return 1;
      case 'approved':
      case 'accepted':
      case 'solved':
        return 2;
      case 'declined':
      case 'rejected':
        return 3;
      case 'auto_approved':
      case 'paid':
        return 4;
      default:
        return 0;
    }
  }

  /// User-facing status label.
  String get statusLabel {
    switch (status) {
      case 0:
        return 'PENDING';
      case 1:
        return 'IN PROGRESS';
      case 2:
      case 4:
        return 'APPROVED';
      case 3:
        return 'DECLINED';
      default:
        return 'PENDING';
    }
  }

  /// Whether this request has been paid (approved or auto-approved).
  bool get isPaid => status == 2 || status == 4;

  /// User-facing fee string (e.g. "3%" or "1000 points").
  String get feeDisplay {
    if (feePercent > 0) {
      final isWhole = feePercent.truncateToDouble() == feePercent;
      return '${feePercent.toStringAsFixed(isWhole ? 0 : 1)}%';
    }
    if (feeFixed > 0) return '${feeFixed.toInt()} $feeUnit';
    return '${fee.toInt()} $feeUnit';
  }
}

class RedeemRequestUser {
  RedeemRequestUser({this.id, this.name, this.image, this.uniqueId, this.country});

  final String? id;
  final String? name;
  final String? image;
  final String? uniqueId;
  final String? country;

  factory RedeemRequestUser.fromJson(Map<String, dynamic> json) => RedeemRequestUser(
        id: parseString(json['_id'] ?? json['id']),
        name: parseString(json['name']),
        image: parseString(json['image']),
        uniqueId: parseString(json['uniqueId']),
        country: parseString(json['country']),
      );
}
