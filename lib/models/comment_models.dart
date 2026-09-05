import 'json_annotation_helper.dart';

/// Alias for [PostCommentRoot] — used by `ApiService.getComments`.
typedef CommentRoot = PostCommentRoot;

/// Ported from native `PostCommentRoot.java` + `LiveStramComment.java`.
class PostCommentRoot {
  PostCommentRoot({this.data = const [], this.message, this.status = false});

  final List<CommentItem> data;
  final String? message;
  final bool status;

  factory PostCommentRoot.fromJson(Map<String, dynamic> json) => PostCommentRoot(
        data: parseList(json['data'] ?? json['comment'], CommentItem.fromJson),
        message: parseString(json['message']),
        status: parseBool(json['status']),
      );
}

class CommentItem {
  CommentItem({
    this.id,
    this.userId,
    this.name,
    this.username,
    this.image,
    this.avatarFrameImage,
    this.comment,
    this.time,
    this.isVIP = false,
  });

  final String? id;
  final String? userId;
  final String? name;
  final String? username;
  final String? image;
  final String? avatarFrameImage;
  final String? comment;
  final String? time;
  final bool isVIP;

  factory CommentItem.fromJson(Map<String, dynamic> json) => CommentItem(
        id: parseString(json['_id'] ?? json['id']),
        userId: parseString(json['userId']),
        name: parseString(json['name']),
        username: parseString(json['username']),
        image: parseString(json['image']),
        avatarFrameImage: parseString(json['avatarFrameImage']),
        comment: parseString(json['comment']),
        time: parseString(json['time']),
        isVIP: parseBool(json['isVIP']),
      );
}

/// Likes list response (same shape as comments but only user info).
class LikeListRoot {
  LikeListRoot({this.data = const [], this.message, this.status = false});

  final List<CommentItem> data;
  final String? message;
  final bool status;

  factory LikeListRoot.fromJson(Map<String, dynamic> json) => LikeListRoot(
        data: parseList(json['data'] ?? json['like'], CommentItem.fromJson),
        message: parseString(json['message']),
        status: parseBool(json['status']),
      );
}

/// Live-stream comment (received via socket `comment` event).
class LiveStreamComment {
  LiveStreamComment({
    this.liveStreamingId,
    this.hostId,
    this.userId,
    this.name,
    this.image,
    this.avatarFrameImage,
    this.comment,
    this.reaction,
    this.type = 'comment',
    this.giftCount,
    this.imageUrl,
    this.isJoined = false,
    this.isVIP = false,
  });

  final String? liveStreamingId;
  final String? hostId;
  final String? userId;
  final String? name;
  final String? image;
  final String? avatarFrameImage;
  final String? comment;
  final String? reaction;
  final String type;
  final String? giftCount;
  final String? imageUrl;
  final bool isJoined;
  final bool isVIP;

  factory LiveStreamComment.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return LiveStreamComment(
      liveStreamingId: parseString(json['liveStreamingId']),
      hostId: parseString(json['hostId']),
      userId: parseString(json['userId'] ?? user?['_id'] ?? user?['userId']),
      name: parseString(json['name'] ?? user?['name']),
      image: parseString(json['image'] ?? user?['image']),
      avatarFrameImage: parseString(json['avatarFrameImage'] ?? user?['avatarFrameImage']),
      comment: parseString(json['comment']),
      reaction: parseString(json['reaction']),
      type: parseString(json['type']) ?? 'comment',
      giftCount: parseString(json['giftCount']),
      imageUrl: parseString(json['imageUrl']),
      isJoined: parseBool(json['isJoined']),
      isVIP: parseBool(json['isVIP'] ?? user?['isVIP']),
    );
  }
}
