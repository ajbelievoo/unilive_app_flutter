import 'json_annotation_helper.dart';

/// Ported from native `GiftRoot.java` + `GiftCategoryRoot.java` + `StickerRoot.java`.
class GiftRoot {
  GiftRoot({this.gift = const [], this.message, this.status = false, this.bigGiftThreshold = 5000});

  final List<GiftItem> gift;
  final String? message;
  final bool status;
  final int bigGiftThreshold;

  factory GiftRoot.fromJson(Map<String, dynamic> json) => GiftRoot(
        gift: parseList(json['gift'], GiftItem.fromJson),
        message: parseString(json['message']),
        status: parseBool(json['status']),
        bigGiftThreshold: parseInt(json['bigGiftThreshold'], 5000),
      );
}

class GiftItem {
  GiftItem({
    this.id,
    this.name,
    this.image,
    this.svgaImage,
    this.coin = 0,
    this.type = 0,
    this.category,
    this.categoryName,
    this.isVipGift = false,
    this.isVipExclusive = false,
    this.isBigGift = false,
    this.isCpOnly = false,
    this.isFriendOnly = false,
    this.receiverUserName,
    this.createdAt,
    this.updatedAt,
    this.count = 1,
  });

  final String? id;
  final String? name;
  final String? image;
  final String? svgaImage;
  final int coin;
  final int type;
  final String? category;
  final String? categoryName;
  final bool isVipGift;
  final bool isVipExclusive;
  final bool isBigGift;
  /// CP-exclusive gift — only sendable to your CP partner.
  final bool isCpOnly;
  /// Friend-exclusive gift — only sendable to your Friend.
  final bool isFriendOnly;
  final String? receiverUserName;
  final String? createdAt;
  final String? updatedAt;
  int count; // runtime count for sending

  /// True when this gift is restricted to a CP or Friend recipient.
  bool get isRelationshipExclusive => isCpOnly || isFriendOnly;

  factory GiftItem.fromJson(Map<String, dynamic> json) => GiftItem(
        id: parseString(json['_id'] ?? json['id']),
        name: parseString(json['name']),
        image: parseString(json['image']),
        svgaImage: parseString(json['svgaImage']),
        coin: parseInt(json['coin'], 0),
        type: parseInt(json['type'], 0),
        category: parseString(json['category']),
        categoryName: parseString(json['categoryName']),
        isVipGift: parseBool(json['isVipGift']),
        isVipExclusive: parseBool(json['isVipExclusive']),
        isBigGift: parseBool(json['isBigGift']),
        isCpOnly: parseBool(json['isCpOnly'] ?? json['is_cp_only']),
        isFriendOnly: parseBool(json['isFriendOnly'] ?? json['is_friend_only']),
        receiverUserName: parseString(json['receiverUserName']),
        createdAt: parseString(json['createdAt']),
        updatedAt: parseString(json['updatedAt']),
      );
}

class GiftCategoryRoot {
  GiftCategoryRoot({this.category = const [], this.message, this.status = false});

  final List<GiftCategory> category;
  final String? message;
  final bool status;

  factory GiftCategoryRoot.fromJson(Map<String, dynamic> json) => GiftCategoryRoot(
        category: parseList(json['category'], GiftCategory.fromJson),
        message: parseString(json['message']),
        status: parseBool(json['status']),
      );
}

class GiftCategory {
  GiftCategory({
    this.id,
    this.name,
    this.image,
    this.giftCount = 0,
    this.createdAt,
  });

  final String? id;
  final String? name;
  final String? image;
  final int giftCount;
  final String? createdAt;

  factory GiftCategory.fromJson(Map<String, dynamic> json) => GiftCategory(
        id: parseString(json['_id'] ?? json['id']),
        name: parseString(json['name']),
        image: parseString(json['image']),
        giftCount: parseInt(json['giftCount'], 0),
        createdAt: parseString(json['createdAt']),
      );
}

class StickerRoot {
  StickerRoot({this.sticker = const [], this.message, this.status = false});

  final List<StickerItem> sticker;
  final String? message;
  final bool status;

  factory StickerRoot.fromJson(Map<String, dynamic> json) => StickerRoot(
        sticker: parseList(json['sticker'], StickerItem.fromJson),
        message: parseString(json['message']),
        status: parseBool(json['status']),
      );
}

class StickerItem {
  StickerItem({this.id, this.sticker, this.createdAt, this.updatedAt});

  final String? id;
  final String? sticker;
  final String? createdAt;
  final String? updatedAt;

  factory StickerItem.fromJson(Map<String, dynamic> json) => StickerItem(
        id: parseString(json['_id'] ?? json['id']),
        sticker: parseString(json['sticker']),
        createdAt: parseString(json['createdAt']),
        updatedAt: parseString(json['updatedAt']),
      );
}
