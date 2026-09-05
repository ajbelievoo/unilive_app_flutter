import 'json_annotation_helper.dart';

/// A generic tag or badge assigned to a user.
///
/// Backends may send tags as either:
/// - a list of objects `{_id, name, image}`
/// - a list of plain strings `["Official Manager", "Region Head"]`
///
/// `fromRaw` and `parseAssignedTags` handle both shapes defensively.
class AssignedTag {
  AssignedTag({this.id, this.name, this.image});

  final String? id;
  final String? name;
  final String? image;

  factory AssignedTag.fromJson(Map<String, dynamic> json) => AssignedTag(
        id: parseString(json['_id'] ?? json['id']),
        name: parseString(json['name']),
        image: parseString(json['image']),
      );

  /// Parse a tag from a backend value that may be a String, a Map, or null.
  factory AssignedTag.fromRaw(dynamic v) {
    if (v is String) {
      final trimmed = v.trim();
      return trimmed.isEmpty ? AssignedTag() : AssignedTag(name: trimmed);
    }
    if (v is Map) {
      return AssignedTag.fromJson(Map<String, dynamic>.from(v));
    }
    return AssignedTag();
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'image': image,
      };
}

/// Parse a mixed `tags` list (objects and/or strings) into [AssignedTag]s.
List<AssignedTag> parseAssignedTags(dynamic v) {
  if (v is! List) return const [];
  return v
      .map(AssignedTag.fromRaw)
      .where((t) => t.name?.isNotEmpty == true || t.image?.isNotEmpty == true)
      .toList();
}
