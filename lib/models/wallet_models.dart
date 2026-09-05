import 'json_annotation_helper.dart';

/// Ported from native wallet plan models.
class CoinPlanRoot {
  CoinPlanRoot({this.coinPlan = const [], this.message, this.status = false});

  final List<CoinPlan> coinPlan;
  final String? message;
  final bool status;

  factory CoinPlanRoot.fromJson(Map<String, dynamic> json) => CoinPlanRoot(
        coinPlan: parseList(json['coinPlan'] ?? json['plan'] ?? json['plans'], CoinPlan.fromJson),
        message: parseString(json['message']),
        status: parseBool(json['status']),
      );
}

class CoinPlan {
  CoinPlan({
    this.id,
    this.name,
    this.coin = 0,
    this.dollar = 0,
    this.rupee = 0,
    this.productKey,
    this.tag,
    this.isTop = false,
    this.isDelete = false,
  });

  final String? id;
  final String? name;
  final int coin;
  final int dollar;
  final int rupee;
  final String? productKey;
  final String? tag;
  final bool isTop;
  final bool isDelete;

  factory CoinPlan.fromJson(Map<String, dynamic> json) => CoinPlan(
        id: parseString(json['_id'] ?? json['id']),
        name: parseString(json['name']),
        coin: parseInt(json['coin'] ?? json['diamonds'] ?? json['coins'], 0),
        dollar: parseInt(json['dollar'] ?? json['usd'] ?? json['amount'], 0),
        rupee: parseInt(json['rupee'] ?? json['inr'] ?? json['price'], 0),
        productKey: parseString(json['productKey'] ?? json['productId'] ?? json['playStoreProductId'] ?? json['sku']),
        tag: parseString(json['tag'] ?? json['label']),
        isTop: parseBool(json['isTop'] ?? json['popular']),
        isDelete: parseBool(json['isDelete'] ?? json['deleted']),
      );
}

/// Transaction history entry.
class TransactionRoot {
  TransactionRoot({this.status = false, this.history = const [], this.message});

  final bool status;
  final List<TransactionItem> history;
  final String? message;

  factory TransactionRoot.fromJson(Map<String, dynamic> json) => TransactionRoot(
        status: parseBool(json['status']),
        history: parseList(json['history'] ?? json['transactions'], TransactionItem.fromJson),
        message: parseString(json['message']),
      );
}

class TransactionItem {
  TransactionItem({
    this.id,
    this.coin = 0,
    this.diamond = 0,
    this.type,
    this.paymentType,
    this.date,
    this.status,
  });

  final String? id;
  final int coin;
  final int diamond;
  final String? type; // credit | debit
  final String? paymentType;
  final String? date;
  final String? status;

  factory TransactionItem.fromJson(Map<String, dynamic> json) => TransactionItem(
        id: parseString(json['_id'] ?? json['id']),
        coin: parseInt(json['coin'], 0),
        diamond: parseInt(json['diamond'], 0),
        type: parseString(json['type']),
        paymentType: parseString(json['paymentType']),
        date: parseString(json['date'] ?? json['createdAt']),
        status: parseString(json['status']),
      );
}
