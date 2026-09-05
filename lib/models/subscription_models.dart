import 'json_annotation_helper.dart';

/// Response wrapper for host subscription tiers.
class SubscriptionTierRoot {
  SubscriptionTierRoot({this.message, this.status = false, this.tiers = const []});

  final String? message;
  final bool status;
  final List<SubscriptionTier> tiers;

  factory SubscriptionTierRoot.fromJson(Map<String, dynamic> json) =>
      SubscriptionTierRoot(
        message: parseString(json['message']),
        status: parseBool(json['status']),
        tiers: parseList(json['tiers'] ?? json['data'], SubscriptionTier.fromJson),
      );
}

/// A subscription tier offered by a host.
///
/// Hosts create tiers with a price (in coins), duration, and exclusive photos.
/// Users who subscribe get access to the tier's exclusive photos.
class SubscriptionTier {
  SubscriptionTier({
    this.id,
    this.hostUserId,
    this.name,
    this.description,
    this.price = 0,
    this.durationDays = 30,
    this.images = const [],
    this.createdAt,
  });

  final String? id;
  final String? hostUserId;
  final String? name;
  final String? description;
  final int price;
  final int durationDays;
  final List<String> images;
  final String? createdAt;

  factory SubscriptionTier.fromJson(Map<String, dynamic> json) => SubscriptionTier(
        id: parseString(json['_id'] ?? json['id']),
        hostUserId: parseString(json['hostUserId']),
        name: parseString(json['name']),
        description: parseString(json['description']),
        price: parseInt(json['price'], 0),
        durationDays: parseInt(json['durationDays'], 30),
        images: parseList(json['images'], (e) => e.toString()),
        createdAt: parseString(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'hostUserId': hostUserId,
        'name': name,
        'description': description,
        'price': price,
        'durationDays': durationDays,
        'images': images,
        'createdAt': createdAt,
      };
}

/// Response wrapper for user's active subscriptions.
class UserSubscriptionRoot {
  UserSubscriptionRoot({
    this.message,
    this.status = false,
    this.subscriptions = const [],
  });

  final String? message;
  final bool status;
  final List<UserSubscription> subscriptions;

  factory UserSubscriptionRoot.fromJson(Map<String, dynamic> json) =>
      UserSubscriptionRoot(
        message: parseString(json['message']),
        status: parseBool(json['status']),
        subscriptions:
            parseList(json['subscriptions'] ?? json['data'], UserSubscription.fromJson),
      );
}

/// An active subscription by a user to a host's tier.
class UserSubscription {
  UserSubscription({
    this.id,
    this.userId,
    this.hostUserId,
    this.tierId,
    this.tierName,
    this.price = 0,
    this.expiresAt,
    this.isActive = true,
    this.hostName,
    this.hostImage,
    this.tierImages = const [],
  });

  final String? id;
  final String? userId;
  final String? hostUserId;
  final String? tierId;
  final String? tierName;
  final int price;
  final String? expiresAt;
  final bool isActive;
  final String? hostName;
  final String? hostImage;
  final List<String> tierImages;

  factory UserSubscription.fromJson(Map<String, dynamic> json) => UserSubscription(
        id: parseString(json['_id'] ?? json['id']),
        userId: parseString(json['userId']),
        hostUserId: parseString(json['hostUserId']),
        tierId: parseString(json['tierId']),
        tierName: parseString(json['tierName']),
        price: parseInt(json['price'], 0),
        expiresAt: parseString(json['expiresAt']),
        isActive: parseBool(json['isActive'], true),
        hostName: parseString(json['hostName']),
        hostImage: parseString(json['hostImage']),
        tierImages: parseList(json['tierImages'], (e) => e.toString()),
      );
}

/// Response to check if a user has an active subscription to a host.
class SubscriptionCheckRoot {
  SubscriptionCheckRoot({
    this.message,
    this.status = false,
    this.isSubscribed = false,
    this.subscription,
  });

  final String? message;
  final bool status;
  final bool isSubscribed;
  final UserSubscription? subscription;

  factory SubscriptionCheckRoot.fromJson(Map<String, dynamic> json) =>
      SubscriptionCheckRoot(
        message: parseString(json['message']),
        status: parseBool(json['status']),
        isSubscribed: parseBool(json['isSubscribed']),
        subscription: json['subscription'] == null
            ? null
            : UserSubscription.fromJson(json['subscription'] as Map<String, dynamic>),
      );
}
