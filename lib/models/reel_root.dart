import 'json_annotation_helper.dart';

/// Ported from native `ReliteRoot.java`.
class ReelRoot {
  ReelRoot({this.video = const [], this.message, this.status = false});

  final List<ReelItem> video;
  final String? message;
  final bool status;

  factory ReelRoot.fromJson(Map<String, dynamic> json) => ReelRoot(
        video: parseList(json['video'], ReelItem.fromJson),
        message: parseString(json['message']),
        status: parseBool(json['status']),
      );
}

class ReelItem {
  ReelItem({
    this.id,
    this.userId,
    this.name,
    this.userImage,
    this.avatarFrameImage,
    this.caption,
    this.video,
    this.thumbnail,
    this.screenshot,
    this.location,
    this.like = 0,
    this.comment = 0,
    this.showVideo = 0,
    this.isLike = false,
    this.isVIP = false,
    this.allowComment = true,
    this.isOriginalAudio = false,
    this.hashtag = const [],
    this.mentionPeople = const [],
    this.time,
    this.song,
  });

  final String? id;
  final String? userId;
  final String? name;
  final String? userImage;
  final String? avatarFrameImage;
  final String? caption;
  final String? video;
  final String? thumbnail;
  final String? screenshot;
  final String? location;
  int like;
  int comment;
  int showVideo;
  bool isLike;
  final bool isVIP;
  final bool allowComment;
  final bool isOriginalAudio;
  final List<String> hashtag;
  final List<String> mentionPeople;
  final String? time;
  final Song? song;

  factory ReelItem.fromJson(Map<String, dynamic> json) => ReelItem(
        id: parseString(json['_id'] ?? json['id']),
        userId: parseString(json['userId']),
        name: parseString(json['name']),
        userImage: parseString(json['userImage']),
        avatarFrameImage: parseString(json['avatarFrameImage']),
        caption: parseString(json['caption']),
        video: parseString(json['video']),
        thumbnail: parseString(json['thumbnail']),
        screenshot: parseString(json['screenshot']),
        location: parseString(json['location']),
        like: parseInt(json['like'], 0),
        comment: parseInt(json['comment'], 0),
        showVideo: parseInt(json['showVideo'], 0),
        isLike: parseBool(json['isLike']),
        isVIP: parseBool(json['isVIP'] ?? json['isVip'] ?? json['vip']),
        allowComment: parseBool(json['allowComment']),
        isOriginalAudio: parseBool(json['isOriginalAudio']),
        hashtag: (json['hashtag'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        mentionPeople: (json['mentionPeople'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        time: parseString(json['time']),
        song: json['song'] == null ? null : Song.fromJson(json['song'] as Map<String, dynamic>),
      );
}

class Song {
  Song({
    this.id,
    this.title,
    this.singer,
    this.song,
    this.image,
    this.createdAt,
    this.updatedAt,
    this.isDelete = false,
  });

  final String? id;
  final String? title;
  final String? singer;
  final String? song;
  final String? image;
  final String? createdAt;
  final String? updatedAt;
  final bool isDelete;

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: parseString(json['_id'] ?? json['id']),
        title: parseString(json['title']),
        singer: parseString(json['singer']),
        song: parseString(json['song']),
        image: parseString(json['image']),
        createdAt: parseString(json['createdAt']),
        updatedAt: parseString(json['updatedAt']),
        isDelete: parseBool(json['isDelete']),
      );
}
