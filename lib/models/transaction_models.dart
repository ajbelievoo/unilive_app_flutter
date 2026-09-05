import 'json_annotation_helper.dart';

/// Ported from native `TransactionHistoryRoot.java`.
class TransactionHistoryRoot {
  TransactionHistoryRoot({
    this.status = false,
    this.message,
    this.total = 0,
    this.history = const [],
  });

  final bool status;
  final String? message;
  final int total;
  final List<TransactionItem> history;

  factory TransactionHistoryRoot.fromJson(Map<String, dynamic> json) {
    // Tolerate `{status, data: {history, total}}` wrapping used by some
    // backend responses, as well as the flat `{status, history, total}` shape.
    final rawData = json['data'];
    final data = rawData is Map ? Map<String, dynamic>.from(rawData) : null;
    final historyJson =
        json['history'] ??
        json['transactions'] ??
        json['records'] ??
        (rawData is List ? rawData : null) ??
        data?['history'] ??
        data?['transactions'] ??
        data?['records'] ??
        data?['items'];
    final totalJson = json['total'] ?? data?['total'];
    return TransactionHistoryRoot(
      status: parseBool(
        json['status'] ??
            json['success'] ??
            data?['status'] ??
            data?['success'],
      ),
      message: parseString(json['message'] ?? data?['message']),
      total: parseInt(totalJson, historyJson is List ? historyJson.length : 0),
      history: parseList(historyJson, TransactionItem.fromJson),
    );
  }
}

class TransactionItem {
  TransactionItem({
    this.id,
    this.userId,
    this.type,
    this.category,
    this.title,
    this.description,
    this.amount = 0,
    this.currency,
    this.balanceAfter = 0,
    this.relatedUserId,
    this.relatedUserName,
    this.relatedUserImage,
    this.paymentGateway,
    this.idempotencyKey,
    this.icon,
    this.createdAt,
  });

  final String? id;
  final String? userId;
  final String? type; // credit, debit, bet, call
  final String? category;
  final String? title;
  final String? description;
  final double amount;
  final String? currency;
  final double balanceAfter;
  final String? relatedUserId;
  final String? relatedUserName;
  final String? relatedUserImage;
  final String? paymentGateway;
  final String? idempotencyKey;
  final String? icon;
  final String? createdAt;

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    // The amount field is called different things by different backend
    // endpoints (`amount`, `coin`, `rCoin`, `diamond`, `coins`, `value`).
    // Resolve the first non-zero one so the history never shows "0" when the
    // backend actually recorded a value under a different key.
    final amountRaw =
        json['amount'] ??
        json['coin'] ??
        json['coins'] ??
        json['diamond'] ??
        json['diamonds'] ??
        json['rCoin'] ??
        json['rcoin'] ??
        json['value'];
    final balanceRaw =
        json['balanceAfter'] ??
        json['balance'] ??
        json['remainingCoin'] ??
        json['remainingBalance'] ??
        json['coinBalance'];
    return TransactionItem(
      id: parseString(json['_id'] ?? json['id']),
      userId: parseString(json['userId']),
      type: parseString(json['type']),
      category: parseString(json['category']),
      title: parseString(json['title']),
      description: parseString(json['description']),
      amount: parseDouble(amountRaw, 0),
      currency: parseString(json['currency']),
      balanceAfter: parseDouble(balanceRaw, 0),
      relatedUserId: parseString(
        json['relatedUserId'] ?? json['sellerId'] ?? json['fromUserId'],
      ),
      relatedUserName: parseString(json['relatedUserName'] ?? json['userName']),
      relatedUserImage: parseString(
        json['relatedUserImage'] ?? json['userImage'],
      ),
      paymentGateway: parseString(json['paymentGateway']),
      idempotencyKey: parseString(json['idempotencyKey']),
      icon: parseString(json['icon']),
      createdAt: parseString(json['createdAt'] ?? json['created_at']),
    );
  }
}

/// Ported from native `TransactionSummaryRoot.java`.
class TransactionSummaryRoot {
  TransactionSummaryRoot({
    this.status = false,
    this.totalCredit = 0,
    this.totalDebit = 0,
    this.totalBet = 0,
    this.totalCall = 0,
    this.currentBalance,
  });

  final bool status;
  final double totalCredit;
  final double totalDebit;
  final double totalBet;
  final double totalCall;
  final TransactionBalance? currentBalance;

  factory TransactionSummaryRoot.fromJson(Map<String, dynamic> json) {
    // Tolerate `{status, data: {...}}` wrapping as well as the flat shape.
    final rawData = json['data'];
    final data = rawData is Map ? Map<String, dynamic>.from(rawData) : null;
    final source = (data ?? json);
    final balanceJson = source['currentBalance'] ?? source['balance'];
    return TransactionSummaryRoot(
      status: parseBool(json['status'] ?? source['status']),
      totalCredit: parseDouble(
        source['totalCredit'] ??
            source['total_credit'] ??
            source['credit'] ??
            source['totalCreditAmount'],
        0,
      ),
      totalDebit: parseDouble(
        source['totalDebit'] ??
            source['total_debit'] ??
            source['debit'] ??
            source['totalDebitAmount'],
        0,
      ),
      totalBet: parseDouble(
        source['totalBet'] ?? source['total_bet'] ?? source['bet'],
        0,
      ),
      totalCall: parseDouble(
        source['totalCall'] ?? source['total_call'] ?? source['call'],
        0,
      ),
      currentBalance:
          balanceJson is Map<String, dynamic>
              ? TransactionBalance.fromJson(balanceJson)
              : null,
    );
  }
}

class TransactionBalance {
  TransactionBalance({this.diamonds = 0, this.coins = 0, this.rcoins = 0});

  final double diamonds;
  final double coins;
  final double rcoins;

  factory TransactionBalance.fromJson(
    Map<String, dynamic> json,
  ) => TransactionBalance(
    diamonds: parseDouble(
      json['diamonds'] ?? json['diamond'] ?? json['coin'],
      0,
    ),
    coins: parseDouble(json['coins'] ?? json['coin'] ?? json['walletCoin'], 0),
    rcoins: parseDouble(json['rcoins'] ?? json['rCoin'] ?? json['rcoin'], 0),
  );
}

/// Ported from native `ReedemListRoot.java`.
class RedeemListRoot {
  RedeemListRoot({this.status = false, this.message, this.redeem = const []});

  final bool status;
  final String? message;
  final List<RedeemItem> redeem;

  factory RedeemListRoot.fromJson(Map<String, dynamic> json) => RedeemListRoot(
    status: parseBool(json['status']),
    message: parseString(json['message']),
    redeem: parseList(json['redeem'], RedeemItem.fromJson),
  );
}

class RedeemItem {
  RedeemItem({
    this.id,
    this.userId,
    this.rCoin = 0,
    this.description,
    this.paymentGateway,
    this.status,
    this.createdAt,
  });

  final String? id;
  final String? userId;
  final double rCoin;
  final String? description;
  final String? paymentGateway;
  final String? status;
  final String? createdAt;

  factory RedeemItem.fromJson(Map<String, dynamic> json) => RedeemItem(
    id: parseString(json['_id'] ?? json['id']),
    userId: parseString(json['userId']),
    rCoin: parseDouble(json['rCoin'], 0),
    description: parseString(json['description']),
    paymentGateway: parseString(json['paymentGateway']),
    status: parseString(json['status']),
    createdAt: parseString(json['createdAt']),
  );
}
