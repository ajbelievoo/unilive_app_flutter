import 'json_annotation_helper.dart';

/// Ported from native `ActivityRoot.java` — activity center items.
class ActivityRoot {
  ActivityRoot({this.status = false, this.message, this.data = const [], this.total = 0});

  final bool status;
  final String? message;
  final List<ActivityItem> data;
  final int total;

  factory ActivityRoot.fromJson(Map<String, dynamic> json) => ActivityRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        data: parseList(json['data'], ActivityItem.fromJson),
        total: parseInt(json['total']),
      );
}

class ActivityItem {
  ActivityItem({
    this.id,
    this.title,
    this.description,
    this.type,
    this.image,
    this.createdAt,
  });

  final String? id;
  final String? title;
  final String? description;
  final String? type;
  final String? image;
  final String? createdAt;

  factory ActivityItem.fromJson(Map<String, dynamic> json) => ActivityItem(
        id: parseString(json['_id'] ?? json['id']),
        title: parseString(json['title']),
        description: parseString(json['description']),
        type: parseString(json['type']),
        image: parseString(json['image']),
        createdAt: parseString(json['createdAt']),
      );
}

/// Ported from native `AdsRoot.java` — advertisement config.
class AdsRoot {
  AdsRoot({this.status = false, this.message, this.advertisement});

  final bool status;
  final String? message;
  final Advertisement? advertisement;

  factory AdsRoot.fromJson(Map<String, dynamic> json) => AdsRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        advertisement: json['advertisement'] == null
            ? null
            : Advertisement.fromJson(json['advertisement'] as Map<String, dynamic>),
      );
}

class Advertisement {
  Advertisement({
    this.id,
    this.banner,
    this.interstitial,
    this.reward,
    this.nativeAd,
    this.show = false,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String? banner;
  final String? interstitial;
  final String? reward;
  final String? nativeAd;
  final bool show;
  final String? createdAt;
  final String? updatedAt;

  factory Advertisement.fromJson(Map<String, dynamic> json) => Advertisement(
        id: parseString(json['_id'] ?? json['id']),
        banner: parseString(json['banner']),
        interstitial: parseString(json['interstitial']),
        reward: parseString(json['reward']),
        nativeAd: parseString(json['native']),
        show: parseBool(json['show']),
        createdAt: parseString(json['createdAt']),
        updatedAt: parseString(json['updatedAt']),
      );
}

/// Ported from native `BlockUserRoot.java` — temp block check.
class BlockUserRoot {
  BlockUserRoot({this.blocked = false, this.expiresAt, this.status = false});

  final bool blocked;
  final String? expiresAt;
  final bool status;

  factory BlockUserRoot.fromJson(Map<String, dynamic> json) => BlockUserRoot(
        blocked: parseBool(json['blocked']),
        expiresAt: parseString(json['expiresAt']),
        status: parseBool(json['status']),
      );
}

/// Ported from native `BroadcastBannerRoot.java`.
class BroadcastBannerRoot {
  BroadcastBannerRoot({this.status = false, this.message, this.broadcastBanner = const []});

  final bool status;
  final String? message;
  final List<BroadcastBannerItem> broadcastBanner;

  factory BroadcastBannerRoot.fromJson(Map<String, dynamic> json) => BroadcastBannerRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        broadcastBanner: parseList(json['broadcastBanner'], BroadcastBannerItem.fromJson),
      );
}

class BroadcastBannerItem {
  BroadcastBannerItem({this.id, this.image, this.createdAt, this.updatedAt});

  final String? id;
  final String? image;
  final String? createdAt;
  final String? updatedAt;

  factory BroadcastBannerItem.fromJson(Map<String, dynamic> json) => BroadcastBannerItem(
        id: parseString(json['_id'] ?? json['id']),
        image: parseString(json['image']),
        createdAt: parseString(json['createdAt']),
        updatedAt: parseString(json['updatedAt']),
      );
}

/// Ported from native `CallRequestRoot.java` — call request response.
class CallRequestRoot {
  CallRequestRoot({this.status = false, this.message, this.callId, this.token});

  final bool status;
  final String? message;
  final String? callId;
  final String? token;

  factory CallRequestRoot.fromJson(Map<String, dynamic> json) => CallRequestRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        callId: parseString(json['callId']),
        token: parseString(json['token']),
      );
}

/// Ported from native `CountryRoot.java` — country picker item.
class CountryRoot {
  CountryRoot({this.countryName, this.countryImage = 0});

  final String? countryName;
  final int countryImage;

  factory CountryRoot.fromJson(Map<String, dynamic> json) => CountryRoot(
        countryName: parseString(json['countryName']),
        countryImage: parseInt(json['countryImage']),
      );
}

/// Ported from native `CreateUserStripe.java` — Stripe customer creation.
class CreateUserStripe {
  CreateUserStripe({
    this.status = false,
    this.publishableKey,
    this.customer,
    this.ephemeralKey,
    this.paymentIntent,
    this.clientSecret,
  });

  final bool status;
  final String? publishableKey;
  final String? customer;
  final String? ephemeralKey;
  final String? paymentIntent;
  final String? clientSecret;

  factory CreateUserStripe.fromJson(Map<String, dynamic> json) => CreateUserStripe(
        status: parseBool(json['status']),
        publishableKey: parseString(json['publishableKey']),
        customer: parseString(json['customer']),
        ephemeralKey: parseString(json['ephemeralKey']),
        paymentIntent: parseString(json['paymentIntent']),
        clientSecret: parseString(json['clientSecret']),
      );
}

/// Ported from native `FilterRoot.java` — beauty filter item.
class FilterRoot {
  FilterRoot({this.title});

  final String? title;

  factory FilterRoot.fromJson(Map<String, dynamic> json) => FilterRoot(
        title: parseString(json['title']),
      );
}

/// Ported from native `GuestLiveModel.java` — guest user live data.
class GuestLiveModel {
  GuestLiveModel({this.status = false, this.message, this.users});

  final bool status;
  final String? message;
  final Map<String, dynamic>? users;

  factory GuestLiveModel.fromJson(Map<String, dynamic> json) => GuestLiveModel(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        users: json['users'] is Map<String, dynamic> ? json['users'] : null,
      );
}

/// Ported from native `HeshtagsRoot.java` — hashtag search results.
class HashtagRoot {
  HashtagRoot({this.status = false, this.message, this.hashtag = const []});

  final bool status;
  final String? message;
  final List<HashtagItem> hashtag;

  factory HashtagRoot.fromJson(Map<String, dynamic> json) => HashtagRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        hashtag: parseList(json['hashtag'], HashtagItem.fromJson),
      );
}

class HashtagItem {
  HashtagItem({this.id, this.hashtag, this.count = 0});

  final String? id;
  final String? hashtag;
  final int count;

  factory HashtagItem.fromJson(Map<String, dynamic> json) => HashtagItem(
        id: parseString(json['_id'] ?? json['id']),
        hashtag: parseString(json['hashtag']),
        count: parseInt(json['count']),
      );
}

/// Ported from native `HostLevelRoot.java` — host level list.
class HostLevelRoot {
  HostLevelRoot({this.status = false, this.message, this.level = const []});

  final bool status;
  final String? message;
  final List<HostLevelItem> level;

  factory HostLevelRoot.fromJson(Map<String, dynamic> json) => HostLevelRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        level: parseList(json['level'], HostLevelItem.fromJson),
      );
}

class HostLevelItem {
  HostLevelItem({
    this.id,
    this.name,
    this.image,
    this.bgColor,
    this.coin = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String? name;
  final String? image;
  final String? bgColor;
  final int coin;
  final String? createdAt;
  final String? updatedAt;

  factory HostLevelItem.fromJson(Map<String, dynamic> json) => HostLevelItem(
        id: parseString(json['_id'] ?? json['id']),
        name: parseString(json['name']),
        image: parseString(json['image']),
        bgColor: parseString(json['bgColor']),
        coin: parseInt(json['coin']),
        createdAt: parseString(json['createdAt']),
        updatedAt: parseString(json['updatedAt']),
      );
}

/// Ported from native `LuckyIDRoot.java` — lucky ID list.
class LuckyIdRoot {
  LuckyIdRoot({this.status = false, this.message, this.data = const []});

  final bool status;
  final String? message;
  final List<LuckyIdItem> data;

  factory LuckyIdRoot.fromJson(Map<String, dynamic> json) => LuckyIdRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        data: parseList(json['data'], LuckyIdItem.fromJson),
      );
}

class LuckyIdItem {
  LuckyIdItem({
    this.id,
    this.luckyId,
    this.coin = 0,
    this.isPurchased = false,
    this.user,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String? luckyId;
  final int coin;
  final bool isPurchased;
  final Map<String, dynamic>? user;
  final String? createdAt;
  final String? updatedAt;

  factory LuckyIdItem.fromJson(Map<String, dynamic> json) => LuckyIdItem(
        id: parseString(json['_id'] ?? json['id']),
        luckyId: parseString(json['luckyId']),
        coin: parseInt(json['coin']),
        isPurchased: parseBool(json['isPurchased']),
        user: json['user'] is Map<String, dynamic> ? json['user'] : null,
        createdAt: parseString(json['createdAt']),
        updatedAt: parseString(json['updatedAt']),
      );
}

/// Ported from native `RatingRoot.java` — host rating response.
class RatingRoot {
  RatingRoot({this.status = false, this.message, this.rating});

  final bool status;
  final String? message;
  final RatingData? rating;

  factory RatingRoot.fromJson(Map<String, dynamic> json) => RatingRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        rating: json['rating'] == null
            ? null
            : RatingData.fromJson(json['rating'] as Map<String, dynamic>),
      );
}

class RatingData {
  RatingData({
    this.averageRating = 0,
    this.totalRatings = 0,
    this.userRating = 0,
    this.userFeedback,
  });

  final double averageRating;
  final int totalRatings;
  final int userRating;
  final String? userFeedback;

  factory RatingData.fromJson(Map<String, dynamic> json) => RatingData(
        averageRating: parseDouble(json['averageRating']),
        totalRatings: parseInt(json['totalRatings']),
        userRating: parseInt(json['userRating']),
        userFeedback: parseString(json['userFeedback']),
      );
}

/// Ported from native `ReactionRoot.java` — reaction list.
class ReactionRoot {
  ReactionRoot({this.status = false, this.message, this.data = const []});

  final bool status;
  final String? message;
  final List<ReactionItem> data;

  factory ReactionRoot.fromJson(Map<String, dynamic> json) => ReactionRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        data: parseList(json['data'], ReactionItem.fromJson),
      );
}

class ReactionItem {
  ReactionItem({this.id, this.name, this.image, this.createdAt, this.updatedAt});

  final String? id;
  final String? name;
  final String? image;
  final String? createdAt;
  final String? updatedAt;

  factory ReactionItem.fromJson(Map<String, dynamic> json) => ReactionItem(
        id: parseString(json['_id'] ?? json['id']),
        name: parseString(json['name']),
        image: parseString(json['image']),
        createdAt: parseString(json['createdAt']),
        updatedAt: parseString(json['updatedAt']),
      );
}

/// Ported from native `SearchLocationRoot.java` — location search results.
class SearchLocationRoot {
  SearchLocationRoot({this.data = const []});

  final List<SearchLocationItem> data;

  factory SearchLocationRoot.fromJson(Map<String, dynamic> json) => SearchLocationRoot(
        data: parseList(json['data'], SearchLocationItem.fromJson),
      );
}

class SearchLocationItem {
  SearchLocationItem({
    this.name,
    this.label,
    this.type,
    this.country,
    this.countryCode,
    this.county,
    this.region,
    this.regionCode,
    this.locality,
    this.continent,
  });

  final String? name;
  final String? label;
  final String? type;
  final String? country;
  final String? countryCode;
  final String? county;
  final String? region;
  final String? regionCode;
  final String? locality;
  final String? continent;

  factory SearchLocationItem.fromJson(Map<String, dynamic> json) => SearchLocationItem(
        name: parseString(json['name']),
        label: parseString(json['label']),
        type: parseString(json['type']),
        country: parseString(json['country']),
        countryCode: parseString(json['country_code']),
        county: parseString(json['county']),
        region: parseString(json['region']),
        regionCode: parseString(json['region_code']),
        locality: parseString(json['locality']),
        continent: parseString(json['continent']),
      );
}

/// Ported from native `StickerRoot.java` — sticker list.
class StickerRoot {
  StickerRoot({this.status = false, this.message, this.sticker = const []});

  final bool status;
  final String? message;
  final List<StickerItem> sticker;

  factory StickerRoot.fromJson(Map<String, dynamic> json) => StickerRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        sticker: parseList(json['sticker'], StickerItem.fromJson),
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

/// Ported from native `SvgaListRoot.java` — SVGA effects list.
class SvgaListRoot {
  SvgaListRoot({this.status = false, this.message, this.data = const []});

  final bool status;
  final String? message;
  final List<SvgaItem> data;

  factory SvgaListRoot.fromJson(Map<String, dynamic> json) => SvgaListRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        data: parseList(json['data'], SvgaItem.fromJson),
      );
}

class SvgaItem {
  SvgaItem({
    this.id,
    this.name,
    this.image,
    this.thumbnail,
    this.type,
    this.diamond = 0,
    this.isPurchase = false,
    this.isSelected = false,
    this.validationTag,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String? name;
  final String? image;
  final String? thumbnail;
  final String? type;
  final int diamond;
  bool isPurchase;
  bool isSelected;
  final String? validationTag;
  final String? createdAt;
  final String? updatedAt;

  factory SvgaItem.fromJson(Map<String, dynamic> json) => SvgaItem(
        id: parseString(json['_id'] ?? json['id']),
        name: parseString(json['name']),
        image: parseString(json['image']),
        thumbnail: parseString(json['thumbnail']),
        type: parseString(json['type']),
        diamond: parseInt(json['diamond']),
        isPurchase: parseBool(json['isPurchase'] ?? json['isPurchased']),
        isSelected: parseBool(json['isSelected']),
        validationTag: parseString(json['validationTag']),
        createdAt: parseString(json['createdAt']),
        updatedAt: parseString(json['updatedAt']),
      );
}

/// Ported from native `UpdateLiveTime.java` — live elapsed time response.
class UpdateLiveTime {
  UpdateLiveTime({
    this.elapsedTime = 0,
    this.serverTimestamp = 0,
    this.message,
    this.status,
  });

  final int elapsedTime;
  final int serverTimestamp;
  final String? message;
  final String? status;

  factory UpdateLiveTime.fromJson(Map<String, dynamic> json) => UpdateLiveTime(
        elapsedTime: parseInt(json['elapsedTime']),
        serverTimestamp: parseInt(json['serverTimestamp']),
        message: parseString(json['message']),
        status: parseString(json['status']),
      );
}

/// Ported from native `UploadImageRoot.java` — chat image upload response.
class UploadImageRoot {
  UploadImageRoot({this.status = false, this.message, this.chat});

  final bool status;
  final String? message;
  final Map<String, dynamic>? chat;

  factory UploadImageRoot.fromJson(Map<String, dynamic> json) => UploadImageRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        chat: json['chat'] is Map<String, dynamic> ? json['chat'] : null,
      );
}

/// Ported from native `WhoBlockedmeRoot.java` — who blocked me list.
class WhoBlockedmeRoot {
  WhoBlockedmeRoot({
    this.status = false,
    this.message,
    this.blockedUsers = const [],
    this.total = 0,
  });

  final bool status;
  final String? message;
  final List<BlockedUsersItem> blockedUsers;
  final int total;

  factory WhoBlockedmeRoot.fromJson(Map<String, dynamic> json) => WhoBlockedmeRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        blockedUsers: parseList(json['blockedUsers'], BlockedUsersItem.fromJson),
        total: parseInt(json['total']),
      );
}

class BlockedUsersItem {
  BlockedUsersItem({this.id, this.userId});

  final String? id;
  final BlockedUser? userId;

  factory BlockedUsersItem.fromJson(Map<String, dynamic> json) => BlockedUsersItem(
        id: parseString(json['_id'] ?? json['id']),
        userId: json['userId'] is Map<String, dynamic>
            ? BlockedUser.fromJson(json['userId'])
            : null,
      );
}

class BlockedUser {
  BlockedUser({
    this.id,
    this.name,
    this.image,
    this.country,
    this.countryFlagImage,
    this.username,
  });

  final String? id;
  final String? name;
  final String? image;
  final String? country;
  final String? countryFlagImage;
  final String? username;

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
        id: parseString(json['_id'] ?? json['id']),
        name: parseString(json['name']),
        image: parseString(json['image']),
        country: parseString(json['country']),
        countryFlagImage: parseString(json['countryFlagImage']),
        username: parseString(json['username']),
      );
}

/// Ported from native `FakeGiftRoot.java` — fake gift for testing.
class FakeGiftRoot {
  FakeGiftRoot({this.id = 0, this.url = 0, this.coin = 0, this.type = 0});

  final int id;
  final int url;
  final int coin;
  final int type;

  static const int imageType = 1;
  static const int svgaType = 2;
  static const int gifType = 3;
}
