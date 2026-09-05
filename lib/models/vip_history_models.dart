import 'json_annotation_helper.dart';

/// Ported from native `VipPointsHistoryRoot.java`.
class VipPointsHistoryRoot {
  VipPointsHistoryRoot({this.status = false, this.message, this.data = const []});

  final bool status;
  final String? message;
  final List<VipPointsHistoryItem> data;

  factory VipPointsHistoryRoot.fromJson(Map<String, dynamic> json) => VipPointsHistoryRoot(
        status: parseBool(json['status'] ?? json['success']),
        message: parseString(json['message']),
        data: parseList(json['data'] ?? json['history'], VipPointsHistoryItem.fromJson),
      );
}

class VipPointsHistoryItem {
  VipPointsHistoryItem({
    this.id,
    this.points = 0,
    this.type,
    this.description,
    this.createdAt,
  });

  final String? id;
  final int points;
  final String? type; // "earned" | "spent" | "bonus"
  final String? description;
  final String? createdAt;

  factory VipPointsHistoryItem.fromJson(Map<String, dynamic> json) => VipPointsHistoryItem(
        id: parseString(json['_id'] ?? json['id']),
        points: parseInt(json['points'], 0),
        type: parseString(json['type']),
        description: parseString(json['description']),
        createdAt: parseString(json['createdAt']),
      );
}

/// Ported from native `VipPurchaseRecordRoot.java`.
class VipPurchaseRecordRoot {
  VipPurchaseRecordRoot({this.status = false, this.message, this.data = const []});

  final bool status;
  final String? message;
  final List<VipPurchaseRecord> data;

  factory VipPurchaseRecordRoot.fromJson(Map<String, dynamic> json) => VipPurchaseRecordRoot(
        status: parseBool(json['status'] ?? json['success']),
        message: parseString(json['message']),
        data: parseList(json['data'] ?? json['records'], VipPurchaseRecord.fromJson),
      );
}

class VipPurchaseRecord {
  VipPurchaseRecord({
    this.id,
    this.tierName,
    this.price = 0,
    this.durationValue = 0,
    this.durationType,
    this.purchaseDate,
    this.expiryDate,
    this.status,
  });

  final String? id;
  final String? tierName;
  final int price;
  final int durationValue;
  final String? durationType;
  final String? purchaseDate;
  final String? expiryDate;
  final String? status; // "active" | "expired"

  factory VipPurchaseRecord.fromJson(Map<String, dynamic> json) => VipPurchaseRecord(
        id: parseString(json['_id'] ?? json['id']),
        tierName: parseString(json['tierName'] ?? json['name']),
        price: parseInt(json['price'], 0),
        durationValue: parseInt(json['durationValue'], 0),
        durationType: parseString(json['durationType']),
        purchaseDate: parseString(json['purchaseDate'] ?? json['createdAt']),
        expiryDate: parseString(json['expiryDate']),
        status: parseString(json['status']),
      );
}
