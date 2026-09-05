import 'json_annotation_helper.dart';

/// Ported from native `SongRoot.java` — song list for reel music picker.
class SongRoot {
  SongRoot({this.song = const [], this.message, this.status = false});

  final List<SongItem> song;
  final String? message;
  final bool status;

  factory SongRoot.fromJson(Map<String, dynamic> json) => SongRoot(
        song: parseList(json['song'], SongItem.fromJson),
        message: parseString(json['message']),
        status: parseBool(json['status']),
      );
}

class SongItem {
  SongItem({
    this.id,
    this.song,
    this.image,
    this.title,
    this.singer,
    this.isDelete = false,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String? song;
  final String? image;
  final String? title;
  final String? singer;
  final bool isDelete;
  final String? createdAt;
  final String? updatedAt;

  factory SongItem.fromJson(Map<String, dynamic> json) => SongItem(
        id: parseString(json['_id'] ?? json['id']),
        song: parseString(json['song']),
        image: parseString(json['image']),
        title: parseString(json['title']),
        singer: parseString(json['singer']),
        isDelete: parseBool(json['isDelete']),
        createdAt: parseString(json['createdAt']),
        updatedAt: parseString(json['updatedAt']),
      );
}
