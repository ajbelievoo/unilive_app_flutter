/// Friend system models — mirrors the CP system but for platonic friend
/// relationships (max 9 friends, different privileges & rules).
///
/// Ported from the Bigo Live-style "CP/Friend" feature shown in the
/// reference screenshots. Friends earn intimacy via gifts and co-streaming,
/// level up to unlock privileges (broadcast, background, emoji, icon&medal,
/// frame), and can be removed (unbind) for a coin cost.
library friend_models;

import 'json_annotation_helper.dart';

/// Generic response wrapper for Friend endpoints.
class FriendRoot {
  FriendRoot({
    this.status = false,
    this.message,
    this.total = 0,
    this.data = const [],
  });

  final bool status;
  final String? message;
  final int total;
  final List<FriendItem> data;

  factory FriendRoot.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    List<FriendItem> items;
    if (rawData is Map) {
      items = [FriendItem.fromJson(Map<String, dynamic>.from(rawData))];
    } else {
      items = parseList(rawData, FriendItem.fromJson);
    }
    return FriendRoot(
      status: parseBool(json['status']),
      message: parseString(json['message']),
      total: parseInt(json['total'], 0),
      data: items,
    );
  }
}

/// A friend relationship between two users.
class FriendItem {
  FriendItem({
    this.id,
    this.user1,
    this.user2,
    this.level = 1,
    this.intimacy = 0,
    this.totalGift = 0,
    this.totalCall = 0,
    this.totalLive = 0,
    this.status = 'active',
    this.createdAt,
    this.daysTogether = 0,
    this.isOwner = false,
    this.ownerSide = '1',
    this.slotIndex = 0, // 0-8 (max 9 friends)
    this.equippedRing,
  });

  final String? id;
  final FriendUser? user1;
  final FriendUser? user2;
  final int level;
  final int intimacy;
  final int totalGift;
  final int totalCall;
  final int totalLive;
  final String status;
  final String? createdAt;
  final int daysTogether;
  final bool isOwner;
  final String ownerSide;
  final int slotIndex;
  final String? equippedRing;

  /// The partner of the current user.
  FriendUser? get partner => ownerSide == '1' ? user2 : user1;
  FriendUser? get self => ownerSide == '1' ? user1 : user2;

  factory FriendItem.fromJson(Map<String, dynamic> json) => FriendItem(
    id: parseString(json['_id'] ?? json['id']),
    user1:
        json['user1'] == null
            ? null
            : FriendUser.fromJson(json['user1'] as Map<String, dynamic>),
    user2:
        json['user2'] == null
            ? null
            : FriendUser.fromJson(json['user2'] as Map<String, dynamic>),
    level: parseInt(json['level'], 1),
    intimacy: parseInt(json['intimacy'], 0),
    totalGift: parseInt(json['totalGift'], 0),
    totalCall: parseInt(json['totalCall'], 0),
    totalLive: parseInt(json['totalLive'], 0),
    status: parseString(json['status']) ?? 'active',
    createdAt: parseString(json['createdAt']),
    daysTogether: parseInt(json['daysTogether'], 0),
    isOwner: parseBool(json['isOwner']),
    ownerSide: parseString(json['ownerSide']) ?? '1',
    slotIndex: parseInt(json['slotIndex'], 0),
    equippedRing: parseString(json['equippedRing']),
  );

  FriendItem copyWith({
    String? id,
    FriendUser? user1,
    FriendUser? user2,
    int? level,
    int? intimacy,
    int? totalGift,
    int? totalCall,
    int? totalLive,
    String? status,
    String? createdAt,
    int? daysTogether,
    bool? isOwner,
    String? ownerSide,
    int? slotIndex,
    String? equippedRing,
  }) =>
      FriendItem(
        id: id ?? this.id,
        user1: user1 ?? this.user1,
        user2: user2 ?? this.user2,
        level: level ?? this.level,
        intimacy: intimacy ?? this.intimacy,
        totalGift: totalGift ?? this.totalGift,
        totalCall: totalCall ?? this.totalCall,
        totalLive: totalLive ?? this.totalLive,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        daysTogether: daysTogether ?? this.daysTogether,
        isOwner: isOwner ?? this.isOwner,
        ownerSide: ownerSide ?? this.ownerSide,
        slotIndex: slotIndex ?? this.slotIndex,
        equippedRing: equippedRing ?? this.equippedRing,
      );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'user1': user1?.toJson(),
    'user2': user2?.toJson(),
    'level': level,
    'intimacy': intimacy,
    'totalGift': totalGift,
    'totalCall': totalCall,
    'totalLive': totalLive,
    'status': status,
    'createdAt': createdAt,
    'daysTogether': daysTogether,
    'isOwner': isOwner,
    'ownerSide': ownerSide,
    'slotIndex': slotIndex,
    'equippedRing': equippedRing,
  };
}

/// Simplified user inside a Friend relationship.
class FriendUser {
  FriendUser({
    this.id,
    this.name,
    this.image,
    this.username,
    this.level = 1,
    this.gender,
    this.isOnline = false,
    this.isLive = false,
    this.bio,
  });

  final String? id;
  final String? name;
  final String? image;
  final String? username;
  final int level;
  final String? gender;
  final bool isOnline;
  final bool isLive;
  final String? bio;

  String? get avatar => image;

  factory FriendUser.fromJson(Map<String, dynamic> json) => FriendUser(
    id: parseString(json['_id'] ?? json['id'] ?? json['userId']),
    name: parseString(json['name']),
    image: parseString(json['image'] ?? json['avatar']),
    username: parseString(json['username']),
    level: parseInt(json['level'], 1),
    gender: parseString(json['gender']),
    isOnline: parseBool(json['isOnline']),
    isLive: parseBool(json['isLive']),
    bio: parseString(json['bio']),
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    'image': image,
    'username': username,
    'level': level,
    'gender': gender,
    'isOnline': isOnline,
    'isLive': isLive,
    'bio': bio,
  };
}

/// A friend request.
class FriendRequest {
  FriendRequest({
    this.id,
    this.fromUser,
    this.toUser,
    this.message,
    this.status = 'pending',
    this.createdAt,
    this.expiresAt,
    this.friendshipId,
  });

  final String? id;
  final FriendUser? fromUser;
  final FriendUser? toUser;
  final String? message;
  final String status;
  final String? createdAt;
  final String? expiresAt;
  final String? friendshipId;

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
    id: parseString(json['_id'] ?? json['id']),
    fromUser:
        json['fromUser'] == null
            ? null
            : FriendUser.fromJson(json['fromUser'] as Map<String, dynamic>),
    toUser:
        json['toUser'] == null
            ? null
            : FriendUser.fromJson(json['toUser'] as Map<String, dynamic>),
    message: parseString(json['message']),
    status: parseString(json['status']) ?? 'pending',
    createdAt: parseString(json['createdAt']),
    expiresAt: parseString(json['expiresAt']),
    friendshipId: parseString(json['friendshipId']),
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'fromUser': fromUser?.toJson(),
    'toUser': toUser?.toJson(),
    'message': message,
    'status': status,
    'createdAt': createdAt,
    'expiresAt': expiresAt,
    'friendshipId': friendshipId,
  };
}

/// Response wrapper for friend request lists.
class FriendRequestRoot {
  FriendRequestRoot({
    this.status = false,
    this.message,
    this.total = 0,
    this.requests = const [],
  });

  final bool status;
  final String? message;
  final int total;
  final List<FriendRequest> requests;

  factory FriendRequestRoot.fromJson(Map<String, dynamic> json) =>
      FriendRequestRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        total: parseInt(json['total'], 0),
        requests: parseList(
          json['data'] ?? json['requests'],
          FriendRequest.fromJson,
        ),
      );
}

/// Friend bond level with privileges.
/// Dynamic — admin can create N levels (1, 2, ... 15, 20, 30 ...).
/// Each level has privilege items (files: PNG/SVG/GIF) with main + preview URLs.
class FriendLevel {
  FriendLevel({
    this.level = 1,
    this.name,
    this.requiredIntimacy = 0,
    this.privileges = const [],
    this.privilegeItems = const [],
    this.icon,
    this.levelBadgeUrl,
    this.frameUrl,
    this.backgroundUrl,
    this.emojiUrl,
    this.iconMedalUrl,
    this.broadcastUrl,
  });

  final int level;
  final String? name;
  final int requiredIntimacy;
  final List<FriendPrivilege> privileges;

  /// Dynamic privilege items for this level (from admin/backend).
  final List<FriendPrivilegeItem> privilegeItems;

  final String? icon;
  final String? levelBadgeUrl;
  final String? frameUrl;
  final String? backgroundUrl;
  final String? emojiUrl;
  final String? iconMedalUrl;
  final String? broadcastUrl;

  factory FriendLevel.fromJson(Map<String, dynamic> json) => FriendLevel(
    level: parseInt(json['level'], 1),
    name: parseString(json['name']),
    requiredIntimacy: parseInt(json['requiredIntimacy'], 0),
    privileges: parseList(json['privileges'], FriendPrivilege.fromJson),
    privilegeItems: parseList(
      json['privilegeItems'] ?? json['items'],
      FriendPrivilegeItem.fromJson,
    ),
    icon: parseString(json['icon'] ?? json['levelIcon']),
    levelBadgeUrl: parseString(json['levelBadgeUrl'] ?? json['badgeUrl']),
    frameUrl: parseString(json['frameUrl'] ?? json['frameImage']),
    backgroundUrl: parseString(
      json['backgroundUrl'] ?? json['profileBackgroundUrl'],
    ),
    emojiUrl: parseString(json['emojiUrl'] ?? json['emojiImage']),
    iconMedalUrl: parseString(json['iconMedalUrl'] ?? json['iconMedalImage']),
    broadcastUrl: parseString(json['broadcastUrl'] ?? json['broadcastImage']),
  );

  Map<String, dynamic> toJson() => {
    'level': level,
    'name': name,
    'requiredIntimacy': requiredIntimacy,
    'privileges': privileges.map((p) => p.toJson()).toList(),
    'privilegeItems': privilegeItems.map((p) => p.toJson()).toList(),
    'icon': icon,
    'levelBadgeUrl': levelBadgeUrl,
    'frameUrl': frameUrl,
    'backgroundUrl': backgroundUrl,
    'emojiUrl': emojiUrl,
    'iconMedalUrl': iconMedalUrl,
    'broadcastUrl': broadcastUrl,
  };
}

/// Response wrapper for friend levels.
class FriendLevelRoot {
  FriendLevelRoot({this.status = false, this.message, this.levels = const []});

  final bool status;
  final String? message;
  final List<FriendLevel> levels;

  factory FriendLevelRoot.fromJson(Map<String, dynamic> json) =>
      FriendLevelRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        levels: parseList(json['data'] ?? json['levels'], FriendLevel.fromJson),
      );
}

/// A privilege unlocked at a specific friend level.
/// Types from screenshots: Broadcast, Background, Gift, Emoji, Icon&Medal, Frame
/// Now supports file uploads (main + preview) like VIP system.
class FriendPrivilege {
  FriendPrivilege({
    this.type,
    this.name,
    this.icon,
    this.unlocked = false,
    this.unlockLevel = 1,
    this.description,
    this.mainFileUrl,
    this.previewFileUrl,
    this.fileType,
    this.items = const [],
  });

  final String?
  type; // 'broadcast', 'background', 'gift', 'emoji', 'icon_medal', 'frame', 'custom'
  final String? name;
  final String? icon;
  final bool unlocked;
  final int unlockLevel;
  final String? description;

  /// Main file URL — the actual asset used in the app.
  final String? mainFileUrl;

  /// Preview file URL — a PNG/image shown in the privileges screen for display.
  final String? previewFileUrl;

  /// File type: 'png', 'svg', 'gif', 'jpg', etc.
  final String? fileType;

  /// Sub-items for this privilege.
  final List<FriendPrivilegeItem> items;

  /// Effective preview URL — falls back to icon then mainFileUrl.
  String? get effectivePreviewUrl {
    if (previewFileUrl != null && previewFileUrl!.isNotEmpty) {
      return previewFileUrl;
    }
    if (mainFileUrl != null && mainFileUrl!.isNotEmpty) return mainFileUrl;
    return icon;
  }

  factory FriendPrivilege.fromJson(Map<String, dynamic> json) =>
      FriendPrivilege(
        type: parseString(json['type']),
        name: parseString(json['name']),
        icon: parseString(json['icon']),
        unlocked: parseBool(json['unlocked']),
        unlockLevel: parseInt(json['unlockLevel'], 1),
        description: parseString(json['description']),
        mainFileUrl: parseString(json['mainFileUrl'] ?? json['mainFile']),
        previewFileUrl: parseString(
          json['previewFileUrl'] ?? json['previewFile'],
        ),
        fileType: parseString(json['fileType'] ?? 'png'),
        items: parseList(json['items'], FriendPrivilegeItem.fromJson),
      );

  Map<String, dynamic> toJson() => {
    'type': type,
    'name': name,
    'icon': icon,
    'unlocked': unlocked,
    'unlockLevel': unlockLevel,
    'description': description,
    'mainFileUrl': mainFileUrl,
    'previewFileUrl': previewFileUrl,
    'fileType': fileType,
    'items': items.map((e) => e.toJson()).toList(),
  };
}

/// A privilege item attached to a Friend level.
/// Admin uploads: mainFile (used by app) + previewFile (shown in privileges UI).
/// Supports PNG, SVG, GIF, and any other image format.
class FriendPrivilegeItem {
  FriendPrivilegeItem({
    this.id,
    this.type,
    this.name,
    this.description,
    this.mainFileUrl,
    this.previewFileUrl,
    this.fileType,
    this.unlockLevel = 1,
    this.unlocked = false,
  });

  final String? id;
  final String? type;
  final String? name;
  final String? description;
  final String? mainFileUrl;
  final String? previewFileUrl;
  final String? fileType;
  final int unlockLevel;
  final bool unlocked;

  String? get effectivePreviewUrl =>
      (previewFileUrl != null && previewFileUrl!.isNotEmpty)
          ? previewFileUrl
          : mainFileUrl;

  factory FriendPrivilegeItem.fromJson(Map<String, dynamic> json) =>
      FriendPrivilegeItem(
        id: parseString(json['_id'] ?? json['id']),
        type: parseString(json['type']),
        name: parseString(json['name']),
        description: parseString(json['description']),
        mainFileUrl: parseString(
          json['mainFileUrl'] ?? json['mainFile'] ?? json['fileUrl'],
        ),
        previewFileUrl: parseString(
          json['previewFileUrl'] ?? json['previewFile'] ?? json['previewUrl'],
        ),
        fileType: parseString(json['fileType'] ?? 'png'),
        unlockLevel: parseInt(json['unlockLevel'] ?? json['level'], 1),
        unlocked: parseBool(json['unlocked']),
      );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'type': type,
    'name': name,
    'description': description,
    'mainFileUrl': mainFileUrl,
    'previewFileUrl': previewFileUrl,
    'fileType': fileType,
    'unlockLevel': unlockLevel,
    'unlocked': unlocked,
  };
}

/// A friend ranking leaderboard entry.
class FriendRankItem {
  FriendRankItem({
    this.rank = 0,
    this.friend,
    this.intimacy = 0,
    this.trend = 0,
  });

  final int rank;
  final FriendItem? friend;
  final int intimacy;
  final int trend;

  factory FriendRankItem.fromJson(Map<String, dynamic> json) => FriendRankItem(
    rank: parseInt(json['rank'], 0),
    friend:
        json['friend'] == null || json['friend'] is! Map
            ? (json['_id'] != null || json['id'] != null
                ? FriendItem.fromJson(json)
                : null)
            : FriendItem.fromJson(json['friend'] as Map<String, dynamic>),
    intimacy: parseInt(json['intimacy'], 0),
    trend: parseInt(json['trend'], 0),
  );
}

/// Response wrapper for friend ranking.
class FriendRankRoot {
  FriendRankRoot({this.status = false, this.message, this.friends = const []});

  final bool status;
  final String? message;
  final List<FriendRankItem> friends;

  factory FriendRankRoot.fromJson(Map<String, dynamic> json) => FriendRankRoot(
    status: parseBool(json['status']),
    message: parseString(json['message']),
    friends: parseList(
      json['data'] ?? json['friends'],
      FriendRankItem.fromJson,
    ),
  );
}

/// A friend history (removed friendship) entry.
class FriendHistoryItem {
  FriendHistoryItem({
    this.id,
    this.partner,
    this.level = 1,
    this.intimacy = 0,
    this.startedAt,
    this.endedAt,
    this.daysTogether = 0,
    this.reason,
  });

  final String? id;
  final FriendUser? partner;
  final int level;
  final int intimacy;
  final String? startedAt;
  final String? endedAt;
  final int daysTogether;
  final String? reason;

  factory FriendHistoryItem.fromJson(Map<String, dynamic> json) =>
      FriendHistoryItem(
        id: parseString(json['_id'] ?? json['id']),
        partner:
            json['partner'] == null
                ? null
                : FriendUser.fromJson(json['partner'] as Map<String, dynamic>),
        level: parseInt(json['level'], 1),
        intimacy: parseInt(json['intimacy'], 0),
        startedAt: parseString(json['startedAt'] ?? json['createdAt']),
        endedAt: parseString(json['endedAt']),
        daysTogether: parseInt(json['daysTogether'], 0),
        reason: parseString(json['reason']),
      );
}

/// Response wrapper for friend history.
class FriendHistoryRoot {
  FriendHistoryRoot({
    this.status = false,
    this.message,
    this.history = const [],
  });

  final bool status;
  final String? message;
  final List<FriendHistoryItem> history;

  factory FriendHistoryRoot.fromJson(Map<String, dynamic> json) =>
      FriendHistoryRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        history: parseList(
          json['data'] ?? json['history'],
          FriendHistoryItem.fromJson,
        ),
      );
}

/// A ring in the friend ring gallery (collected/unlocked).
class FriendRing {
  FriendRing({
    this.id,
    this.name,
    this.image,
    this.unlockLevel = 1,
    this.isUnlocked = false,
    this.isEquipped = false,
    this.price = 0,
    this.description,
  });

  final String? id;
  final String? name;
  final String? image;
  final int unlockLevel;
  final bool isUnlocked;
  final bool isEquipped;
  final int price;
  final String? description;

  factory FriendRing.fromJson(Map<String, dynamic> json) => FriendRing(
    id: parseString(json['_id'] ?? json['id']),
    name: parseString(json['name']),
    image: parseString(json['image']),
    unlockLevel: parseInt(json['unlockLevel'], 1),
    isUnlocked: parseBool(json['isUnlocked']),
    isEquipped: parseBool(json['isEquipped']),
    price: parseInt(json['price'], 0),
    description: parseString(json['description']),
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    'image': image,
    'unlockLevel': unlockLevel,
    'isUnlocked': isUnlocked,
    'isEquipped': isEquipped,
    'price': price,
    'description': description,
  };
}

/// Response wrapper for friend ring gallery.
class FriendRingRoot {
  FriendRingRoot({this.status = false, this.message, this.rings = const []});

  final bool status;
  final String? message;
  final List<FriendRing> rings;

  factory FriendRingRoot.fromJson(Map<String, dynamic> json) => FriendRingRoot(
    status: parseBool(json['status']),
    message: parseString(json['message']),
    rings: parseList(json['data'] ?? json['rings'], FriendRing.fromJson),
  );
}

/// Response wrapper for friend privileges.
class FriendPrivilegeRoot {
  FriendPrivilegeRoot({
    this.status = false,
    this.message,
    this.privileges = const [],
  });

  final bool status;
  final String? message;
  final List<FriendPrivilege> privileges;

  factory FriendPrivilegeRoot.fromJson(Map<String, dynamic> json) =>
      FriendPrivilegeRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        privileges: parseList(
          json['data'] ?? json['privileges'],
          FriendPrivilege.fromJson,
        ),
      );
}
