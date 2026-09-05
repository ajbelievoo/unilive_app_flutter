import 'json_annotation_helper.dart';

class ThemeItem {
  ThemeItem({this.id, this.name, this.theme, this.type = 0, this.createdAt, this.updatedAt});

  final String? id;
  final String? name;
  final String? theme;
  final int type;
  final String? createdAt;
  final String? updatedAt;

  factory ThemeItem.fromJson(Map<String, dynamic> json) => ThemeItem(
        id: parseString(json['_id']),
        name: parseString(json['name']) ?? parseString(json['themeName']),
        theme: parseString(json['theme']),
        type: parseInt(json['type'], 0),
        createdAt: parseString(json['createdAt']),
        updatedAt: parseString(json['updatedAt']),
      );
}

class ThemeRoot {
  ThemeRoot({this.message, this.status = false, this.theme = const []});

  final String? message;
  final bool status;
  final List<ThemeItem> theme;

  factory ThemeRoot.fromJson(Map<String, dynamic> json) => ThemeRoot(
        message: parseString(json['message']),
        status: parseBool(json['status']),
        theme: parseList(json['theme'], ThemeItem.fromJson),
      );
}
