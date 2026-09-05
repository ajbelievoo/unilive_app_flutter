/// AI Group Room Matchmaker response model.
///
/// Matches the response of `POST /api/v1/ai/match-group`:
/// ```json
/// {
///   "status": true,
///   "matchedHosts": [
///     { "_id": "...", "name": "...", "image": "...", "country": "...",
///       "tags": ["Singing"], "matchScore": 1, "isLive": true }
///   ]
/// }
/// ```
library;

import 'json_annotation_helper.dart';

class GroupMatchResult {
  const GroupMatchResult({this.status = false, this.matchedHosts = const []});

  final bool status;
  final List<GroupMatchedHost> matchedHosts;

  factory GroupMatchResult.fromJson(Map<String, dynamic> json) {
    final raw = json['matchedHosts'] ?? json['matched_hosts'];
    List<GroupMatchedHost> hosts = [];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          hosts.add(GroupMatchedHost.fromJson(item));
        } else if (item is Map) {
          hosts.add(GroupMatchedHost.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return GroupMatchResult(
      status: parseBool(json['status']),
      matchedHosts: hosts,
    );
  }
}

class GroupMatchedHost {
  GroupMatchedHost({
    this.id,
    this.name,
    this.image,
    this.country,
    this.tags = const [],
    this.matchScore = 0,
    this.isLive = false,
  });

  final String? id;
  final String? name;
  final String? image;
  final String? country;
  final List<String> tags;
  final int matchScore;
  final bool isLive;

  factory GroupMatchedHost.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    List<String> tags = [];
    if (rawTags is List) {
      tags = rawTags.whereType<String>().toList();
    }
    return GroupMatchedHost(
      id: parseString(json['_id'] ?? json['id']),
      name: parseString(json['name']),
      image: parseString(json['image']),
      country: parseString(json['country']),
      tags: tags,
      matchScore: parseInt(json['matchScore'] ?? json['match_score']),
      isLive: parseBool(json['isLive'] ?? json['is_live']),
    );
  }
}
