/// CP / Friend visual styling helper.
///
/// Centralises the Bigo/Chamet-style "relationship" visual treatment so the
/// live room, audio room, chat bubbles, host info box and seat avatars all
/// render the same look:
///   - **CP**  → pink/magenta gradient name + heart badge
///   - **Friend** → blue/cyan gradient name + star badge
///
/// VIP styling always wins over CP/Friend styling (a VIP+CP user shows the
/// VIP golden/coloured name, but still shows the CP badge chip next to the
/// name). This mirrors Bigo Live where VIP name effects take priority.
library cp_style_helper;

import 'package:flutter/material.dart';

import '../widgets/relationship_badge.dart';

class CpStyleHelper {
  CpStyleHelper._();

  /// CP pink/magenta name colour.
  static const Color cpNameColor = Color(0xFFFF6FB5);

  /// Friend blue/cyan name colour.
  static const Color friendNameColor = Color(0xFF4FC3F7);

  /// Returns the relationship name colour for a chat sender, or null when no
  /// relationship is set. Caller should let VIP styling override this.
  static Color? nameColorFor({
    String? relationshipType,
    int? cpLevel,
    int? friendLevel,
  }) {
    if (relationshipType == null || relationshipType.isEmpty) return null;
    final t = relationshipType.toLowerCase();
    if (t == 'cp') return cpNameColor;
    if (t == 'friend' || t == 'friends') return friendNameColor;
    return null;
  }

  /// True when the user has an active relationship (CP or Friend).
  static bool hasRelationship(String? relationshipType) {
    final t = relationshipType?.toLowerCase();
    return t == 'cp' || t == 'friend' || t == 'friends';
  }

  /// Builds the small relationship badge chip (CP heart / Friend star) with
  /// the bond level. Returns an empty box when there is no relationship.
  static Widget badgeChip({
    String? relationshipType,
    int? cpLevel,
    int? friendLevel,
    double size = 14,
  }) {
    if (!hasRelationship(relationshipType)) return const SizedBox.shrink();
    final isCp = relationshipType!.toLowerCase() == 'cp';
    final level = isCp ? (cpLevel ?? 1) : (friendLevel ?? 1);
    return RelationshipBadge(
      type: isCp ? 'cp' : 'friend',
      level: level,
      size: size,
    );
  }

  /// Parses relationship fields from a socket payload (chat / join / seat).
  /// Backend must send `relationshipType` + `cpLevel` + `friendLevel` on the
  /// user object or the payload root. See
  /// `docs/CP_FRIEND_BACKEND_REMAINING.md` § "Socket payload enrichment".
  static CpRelationshipInfo parseFromPayload(Map<String, dynamic> map) {
    final user = map['user'] is Map ? map['user'] as Map<String, dynamic> : null;
    final cpDetails = map['cpDetails'] is Map
        ? map['cpDetails'] as Map<String, dynamic>
        : (user?['cpDetails'] is Map
            ? user!['cpDetails'] as Map<String, dynamic>
            : null);
    String? rel = parseString(map['relationshipType']) ??
        parseString(user?['relationshipType']) ??
        parseString(cpDetails?['relationshipType']);
    int cpLevel = parseInt(map['cpLevel'] ?? user?['cpLevel'] ?? cpDetails?['cpLevel'], 0);
    int friendLevel = parseInt(
        map['friendLevel'] ?? user?['friendLevel'] ?? cpDetails?['friendLevel'], 0);
    int intimacy = parseInt(map['intimacy'] ?? user?['intimacy'] ?? cpDetails?['intimacy'], 0);
    String? cpId = parseString(map['cpId'] ?? user?['cpId'] ?? cpDetails?['cpId']);
    String? partnerName = parseString(map['cpPartnerName'] ??
        user?['cpPartnerName'] ??
        cpDetails?['partnerName']);
    String? partnerImage = parseString(map['cpPartnerImage'] ??
        user?['cpPartnerImage'] ??
        cpDetails?['partnerImage']);
    String? badgeUrl = parseString(map['cpBadgeUrl'] ??
        user?['cpBadgeUrl'] ??
        cpDetails?['badgeUrl']);
    String? frameUrl = parseString(map['cpFrameUrl'] ??
        user?['cpFrameUrl'] ??
        cpDetails?['frameUrl']);
    String? entranceUrl = parseString(map['cpEntranceUrl'] ??
        user?['cpEntranceUrl'] ??
        cpDetails?['entranceAnimationUrl']);

    // Infer relationship type from cpLevel/friendLevel when not explicit.
    if ((rel == null || rel.isEmpty)) {
      if (cpLevel > 0) {
        rel = 'cp';
      } else if (friendLevel > 0) {
        rel = 'friend';
      }
    }
    return CpRelationshipInfo(
      relationshipType: (rel?.isNotEmpty == true) ? rel : null,
      cpLevel: cpLevel > 0 ? cpLevel : null,
      friendLevel: friendLevel > 0 ? friendLevel : null,
      intimacy: intimacy,
      cpId: cpId,
      partnerName: partnerName,
      partnerImage: partnerImage,
      badgeUrl: badgeUrl,
      frameUrl: frameUrl,
      entranceUrl: entranceUrl,
    );
  }

  static String? parseString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int parseInt(dynamic v, [int def = 0]) {
    if (v == null) return def;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? def;
  }
}

/// Parsed relationship info extracted from a socket payload.
class CpRelationshipInfo {
  const CpRelationshipInfo({
    this.relationshipType,
    this.cpLevel,
    this.friendLevel,
    this.intimacy = 0,
    this.cpId,
    this.partnerName,
    this.partnerImage,
    this.badgeUrl,
    this.frameUrl,
    this.entranceUrl,
  });

  /// `'cp'` or `'friend'` (null when the user has no relationship).
  final String? relationshipType;
  final int? cpLevel;
  final int? friendLevel;
  final int intimacy;
  final String? cpId;
  final String? partnerName;
  final String? partnerImage;
  final String? badgeUrl;
  final String? frameUrl;
  final String? entranceUrl;

  bool get isCp => relationshipType?.toLowerCase() == 'cp';
  bool get isFriend =>
      relationshipType?.toLowerCase() == 'friend' ||
      relationshipType?.toLowerCase() == 'friends';
  bool get hasRelationship => isCp || isFriend;

  int get effectiveLevel => isCp ? (cpLevel ?? 1) : (friendLevel ?? 1);
}
