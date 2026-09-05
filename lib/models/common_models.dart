import 'json_annotation_helper.dart';

/// Generic `{message, status}` response wrapper.
class RestResponse {
  RestResponse({this.message, this.status = false, this.data});

  final String? message;
  final bool status;
  /// Extra fields from the API response (e.g. isFollow, isLiked, likeCount).
  final Map<String, dynamic>? data;

  factory RestResponse.fromJson(Map<String, dynamic> json) => RestResponse(
        message: parseString(json['message']),
        status: parseBool(json['status']),
        data: json,
      );

  Map<String, dynamic> toJson() => {'message': message, 'status': status};

  /// Extracts the user's remaining coin balance from the response data, if present.
  /// The /gift/send API may return updated coins in various fields.
  int? get coins {
    if (data == null) return null;
    final raw = data!['coin'] ?? data!['coins'] ?? data!['coinBalance'] ??
        data!['walletCoin'] ?? data!['balance'] ?? data!['remainingCoin'];
    if (raw == null) return null;
    return (raw is num) ? raw.toInt() : int.tryParse(raw.toString());
  }
}

/// IP lookup response from `https://ip-api.com/json`.
class IpAddressRoot {
  IpAddressRoot({
    this.status,
    this.country,
    this.countryCode,
    this.region,
    this.regionName,
    this.city,
    this.zip,
    this.lat,
    this.lon,
    this.timezone,
    this.isp,
    this.org,
    this.as,
    this.query,
  });

  final String? status;
  final String? country;
  final String? countryCode;
  final String? region;
  final String? regionName;
  final String? city;
  final String? zip;
  final double? lat;
  final double? lon;
  final String? timezone;
  final String? isp;
  final String? org;
  final String? as;
  final String? query;

  factory IpAddressRoot.fromJson(Map<String, dynamic> json) => IpAddressRoot(
        status: parseString(json['status']),
        country: parseString(json['country']),
        countryCode: parseString(json['countryCode']),
        region: parseString(json['region']),
        regionName: parseString(json['regionName']),
        city: parseString(json['city']),
        zip: parseString(json['zip']),
        lat: json['lat'] == null ? null : parseDouble(json['lat']),
        lon: json['lon'] == null ? null : parseDouble(json['lon']),
        timezone: parseString(json['timezone']),
        isp: parseString(json['isp']),
        org: parseString(json['org']),
        as: parseString(json['as']),
        query: parseString(json['query']),
      );

  Map<String, dynamic> toJson() => {
        'status': status,
        'country': country,
        'countryCode': countryCode,
        'region': region,
        'regionName': regionName,
        'city': city,
        'zip': zip,
        'lat': lat,
        'lon': lon,
        'timezone': timezone,
        'isp': isp,
        'org': org,
        'as': as,
        'query': query,
      };
}
