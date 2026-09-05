import 'json_annotation_helper.dart';

/// Ported from native `PostRoot.java`.
class PostRoot {
  PostRoot({this.post = const [], this.message, this.status = false});

  final List<PostItem> post;
  final String? message;
  final bool status;

  factory PostRoot.fromJson(Map<String, dynamic> json) => PostRoot(
        post: parseList(json['post'], PostItem.fromJson),
        message: parseString(json['message']),
        status: parseBool(json['status']),
      );
}

class PostItem {
  PostItem({
    this.id,
    this.userId,
    this.name,
    this.userImage,
    this.avatarFrameImage,
    this.caption,
    this.post,
    this.location,
    this.like = 0,
    this.comment = 0,
    this.isLike = false,
    this.isVIP = false,
    this.allowComment = true,
    this.createdAt,
    this.time,
  });

  final String? id;
  final String? userId;
  final String? name;
  final String? userImage;
  final String? avatarFrameImage;
  final String? caption;
  final String? post; // image URL
  final String? location;
  int like;
  int comment;
  bool isLike;
  final bool isVIP;
  final bool allowComment;
  final String? createdAt;
  final String? time;

  factory PostItem.fromJson(Map<String, dynamic> json) => PostItem(
        id: parseString(json['_id'] ?? json['id']),
        userId: parseString(json['userId']),
        name: parseString(json['name']),
        userImage: parseString(json['userImage']),
        avatarFrameImage: parseString(json['avatarFrameImage']),
        caption: parseString(json['caption']),
        post: parseString(json['post']),
        location: parseString(json['location']),
        like: parseInt(json['like'], 0),
        comment: parseInt(json['comment'], 0),
        isLike: parseBool(json['isLike']),
        isVIP: parseBool(json['isVIP'] ?? json['isVip'] ?? json['vip']),
        allowComment: parseBool(json['allowComment']),
        createdAt: parseString(json['createdAt']),
        time: parseString(json['time']),
      );
}
