import 'json_annotation_helper.dart';

/// Ported from native `BannerRoot.java`.
///
/// Response wrapper for `/banner`, `/broadcastBanner`, `/luckyBanner`.
class BannerRoot {
  BannerRoot({this.banner = const [], this.message, this.status = false});

  final List<BannerItem> banner;
  final String? message;
  final bool status;

  factory BannerRoot.fromJson(Map<String, dynamic> json) => BannerRoot(
        banner: parseList(json['banner'], BannerItem.fromJson),
        message: parseString(json['message']),
        status: parseBool(json['status']),
      );
}

class BannerItem {
  BannerItem({
    this.id,
    this.image,
    this.url,
    this.isVIP = false,
    this.bannerType = 0,
    this.v = 0,
  });

  final String? id;
  final String? image;
  final String? url;
  final bool isVIP;
  final int bannerType;
  final int v;

  factory BannerItem.fromJson(Map<String, dynamic> json) => BannerItem(
        id: parseString(json['_id'] ?? json['id']),
        image: parseString(json['image']),
        url: parseString(json['URL'] ?? json['url']),
        isVIP: parseBool(json['isVIP'] ?? json['isVip'] ?? json['vip']),
        bannerType: parseInt(json['bannerType'], 0),
        v: parseInt(json['__v'], 0),
      );
}
