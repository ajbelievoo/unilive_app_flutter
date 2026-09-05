import 'json_annotation_helper.dart';

/// Response wrapper for GET /splashPoster endpoint.
class SplashPosterRoot {
  SplashPosterRoot({
    this.status = false,
    this.message,
    this.data,
  });

  final bool status;
  final String? message;
  final SplashPoster? data;

  factory SplashPosterRoot.fromJson(Map<String, dynamic> json) {
    return SplashPosterRoot(
      status: parseBool(json['status']),
      message: parseString(json['message']),
      data: json['data'] != null
          ? SplashPoster.fromJson(json['data'] as Map<String, dynamic>)
          : json['splashPoster'] != null
              ? SplashPoster.fromJson(json['splashPoster'] as Map<String, dynamic>)
              : null,
    );
  }
}

/// Splash poster configuration controlled from admin panel.
class SplashPoster {
  SplashPoster({
    this.id,
    this.enabled = false,
    this.image,
    this.duration = 4,
    this.linkUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final bool enabled;
  final String? image;
  final int duration;
  final String? linkUrl;
  final String? createdAt;
  final String? updatedAt;

  factory SplashPoster.fromJson(Map<String, dynamic> json) {
    return SplashPoster(
      id: parseString(json['_id'] ?? json['id']),
      enabled: parseBool(json['enabled']),
      image: parseString(json['image']),
      duration: parseInt(json['duration'], 4),
      linkUrl: parseString(json['linkUrl']),
      createdAt: parseString(json['createdAt']),
      updatedAt: parseString(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'enabled': enabled,
        'image': image,
        'duration': duration,
        'linkUrl': linkUrl,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}
