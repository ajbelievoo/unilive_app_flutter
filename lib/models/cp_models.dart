/// CP (Couple / 情侣) system models.
///
/// A "CP" is a paired relationship between two users — a popular social
/// feature in live-streaming apps. Two users become a couple, earn intimacy
/// points together (via gifts, calls, co-streaming), level up their bond,
/// unlock couple perks (frames, badges, entrance effects), complete couple
/// tasks for rewards, and compete on a couple ranking leaderboard.
///
/// This model set mirrors the structure of [family_models.dart] so the
/// provider / API / screens follow the same conventions.
library cp_models;

import 'json_annotation_helper.dart';

/// Generic list/CRUD response wrapper for CP endpoints.
class CPRoot {
  CPRoot({
    this.status = false,
    this.message,
    this.total = 0,
    this.data = const [],
  });

  final bool status;
  final String? message;
  final int total;
  final List<CPItem> data;

  factory CPRoot.fromJson(Map<String, dynamic> json) {
    // `data` can be a List (from /cp/list) or a single Map object
    // (from /cp/create or /cp/{id}).
    final rawData = json['data'];
    List<CPItem> items;
    if (rawData is Map) {
      items = [CPItem.fromJson(Map<String, dynamic>.from(rawData))];
    } else {
      items = parseList(rawData, CPItem.fromJson);
    }
    return CPRoot(
      status: parseBool(json['status']),
      message: parseString(json['message']),
      total: parseInt(json['total'], 0),
      data: items,
    );
  }
}

/// A couple relationship between two users.
class CPItem {
  CPItem({
    this.id,
    this.user1,
    this.user2,
    this.level = 1,
    this.intimacy = 0,
    this.charm = 0,
    this.totalGift = 0,
    this.totalCall = 0,
    this.totalLive = 0,
    this.status = 'active', // 'active', 'pending', 'broken'
    this.createdAt,
    this.anniversary, // first-became-couple date
    this.daysTogether = 0,
    this.badge,
    this.frame,
    this.entranceEffect,
    this.title, // couple nickname e.g. "Romeo & Juliet"
    this.bio,
    this.coverImage,
    this.isOwner = false,
    this.ownerSide = '1', // '1' or '2' — which side the current user is
    this.equippedRing,
  });

  final String? id;
  final CPUser? user1;
  final CPUser? user2;
  final int level;
  final int intimacy;
  final int charm;
  final int totalGift;
  final int totalCall;
  final int totalLive;
  final String status;
  final String? createdAt;
  final String? anniversary;
  final int daysTogether;
  final String? badge;
  final String? frame;
  final String? entranceEffect;
  final String? title;
  final String? bio;
  final String? coverImage;
  final bool isOwner;
  final String ownerSide;
  final String? equippedRing;

  /// The partner of the current user (based on ownerSide).
  CPUser? get partner => ownerSide == '1' ? user2 : user1;

  /// The current user side.
  CPUser? get self => ownerSide == '1' ? user1 : user2;

  factory CPItem.fromJson(Map<String, dynamic> json) => CPItem(
    id: parseString(json['_id'] ?? json['id']),
    user1:
        json['user1'] == null
            ? null
            : CPUser.fromJson(json['user1'] as Map<String, dynamic>),
    user2:
        json['user2'] == null
            ? null
            : CPUser.fromJson(json['user2'] as Map<String, dynamic>),
    level: parseInt(json['level'], 1),
    intimacy: parseInt(json['intimacy'], 0),
    charm: parseInt(json['charm'], 0),
    totalGift: parseInt(json['totalGift'], 0),
    totalCall: parseInt(json['totalCall'], 0),
    totalLive: parseInt(json['totalLive'], 0),
    status: parseString(json['status']) ?? 'active',
    createdAt: parseString(json['createdAt']),
    anniversary: parseString(json['anniversary'] ?? json['createdAt']),
    daysTogether: parseInt(json['daysTogether'], 0),
    badge: parseString(json['badge']),
    frame: parseString(json['frame']),
    entranceEffect: parseString(json['entranceEffect']),
    title: parseString(json['title']),
    bio: parseString(json['bio']),
    coverImage: parseString(json['coverImage'] ?? json['bannerImage']),
    isOwner: parseBool(json['isOwner']),
    ownerSide: parseString(json['ownerSide']) ?? '1',
    equippedRing: parseString(json['equippedRing']),
  );

  CPItem copyWith({
    String? id,
    CPUser? user1,
    CPUser? user2,
    int? level,
    int? intimacy,
    int? charm,
    int? totalGift,
    int? totalCall,
    int? totalLive,
    String? status,
    String? createdAt,
    String? anniversary,
    int? daysTogether,
    String? badge,
    String? frame,
    String? entranceEffect,
    String? title,
    String? bio,
    String? coverImage,
    bool? isOwner,
    String? ownerSide,
    String? equippedRing,
  }) =>
      CPItem(
        id: id ?? this.id,
        user1: user1 ?? this.user1,
        user2: user2 ?? this.user2,
        level: level ?? this.level,
        intimacy: intimacy ?? this.intimacy,
        charm: charm ?? this.charm,
        totalGift: totalGift ?? this.totalGift,
        totalCall: totalCall ?? this.totalCall,
        totalLive: totalLive ?? this.totalLive,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        anniversary: anniversary ?? this.anniversary,
        daysTogether: daysTogether ?? this.daysTogether,
        badge: badge ?? this.badge,
        frame: frame ?? this.frame,
        entranceEffect: entranceEffect ?? this.entranceEffect,
        title: title ?? this.title,
        bio: bio ?? this.bio,
        coverImage: coverImage ?? this.coverImage,
        isOwner: isOwner ?? this.isOwner,
        ownerSide: ownerSide ?? this.ownerSide,
        equippedRing: equippedRing ?? this.equippedRing,
      );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'user1': user1?.toJson(),
    'user2': user2?.toJson(),
    'level': level,
    'intimacy': intimacy,
    'charm': charm,
    'totalGift': totalGift,
    'totalCall': totalCall,
    'totalLive': totalLive,
    'status': status,
    'createdAt': createdAt,
    'anniversary': anniversary,
    'daysTogether': daysTogether,
    'badge': badge,
    'frame': frame,
    'entranceEffect': entranceEffect,
    'title': title,
    'bio': bio,
    'coverImage': coverImage,
    'isOwner': isOwner,
    'ownerSide': ownerSide,
    'equippedRing': equippedRing,
  };
}

/// Simplified user inside a CP.
class CPUser {
  CPUser({
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

  factory CPUser.fromJson(Map<String, dynamic> json) => CPUser(
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

/// A CP request sent from one user to another.
class CPRequest {
  CPRequest({
    this.id,
    this.fromUser,
    this.toUser,
    this.message,
    this.status = 'pending', // 'pending', 'accepted', 'rejected', 'cancelled'
    this.createdAt,
    this.expiresAt,
    this.cpId, // set after acceptance
  });

  final String? id;
  final CPUser? fromUser;
  final CPUser? toUser;
  final String? message;
  final String status;
  final String? createdAt;
  final String? expiresAt;
  final String? cpId;

  factory CPRequest.fromJson(Map<String, dynamic> json) => CPRequest(
    id: parseString(json['_id'] ?? json['id']),
    fromUser:
        json['fromUser'] == null
            ? null
            : CPUser.fromJson(json['fromUser'] as Map<String, dynamic>),
    toUser:
        json['toUser'] == null
            ? null
            : CPUser.fromJson(json['toUser'] as Map<String, dynamic>),
    message: parseString(json['message']),
    status: parseString(json['status']) ?? 'pending',
    createdAt: parseString(json['createdAt']),
    expiresAt: parseString(json['expiresAt']),
    cpId: parseString(json['cpId']),
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'fromUser': fromUser?.toJson(),
    'toUser': toUser?.toJson(),
    'message': message,
    'status': status,
    'createdAt': createdAt,
    'expiresAt': expiresAt,
    'cpId': cpId,
  };
}

/// Response wrapper for CP request lists.
class CPRequestRoot {
  CPRequestRoot({
    this.status = false,
    this.message,
    this.total = 0,
    this.requests = const [],
  });

  final bool status;
  final String? message;
  final int total;
  final List<CPRequest> requests;

  factory CPRequestRoot.fromJson(Map<String, dynamic> json) => CPRequestRoot(
    status: parseBool(json['status']),
    message: parseString(json['message']),
    total: parseInt(json['total'], 0),
    requests: parseList(json['data'] ?? json['requests'], CPRequest.fromJson),
  );
}

/// A couple task that both partners contribute to.
///
/// Supports both the current UI fields (`type`, `target`, `reward`, `rewardType`)
/// and the backend doc fields (`targetType`, `targetCount`, `rewardIntimacy`,
/// `rewardCharm`, `isActive`) by mapping them with safe fallbacks.
class CPTask {
  CPTask({
    this.id,
    this.title,
    this.description,
    this.type = 'daily', // 'daily', 'weekly', 'special', 'anniversary' or targetType
    this.reward = 0,
    this.rewardType = 'intimacy', // 'intimacy', 'coin', 'diamond', 'charm'
    this.target = 0,
    this.progress = 0,
    this.myProgress = 0,
    this.partnerProgress = 0,
    this.isCompleted = false,
    this.isClaimed = false,
    this.isActive = true,
    this.expiresAt,
  });

  final String? id;
  final String? title;
  final String? description;
  final String type;
  final int reward;
  final String rewardType;
  final int target;
  final int progress;
  final int myProgress;
  final int partnerProgress;
  final bool isCompleted;
  final bool isClaimed;
  final bool isActive;
  final String? expiresAt;

  double get progressPercent =>
      target == 0 ? 0 : (progress / target).clamp(0.0, 1.0);

  factory CPTask.fromJson(Map<String, dynamic> json) => CPTask(
    id: parseString(json['_id'] ?? json['id']),
    title: parseString(json['title']),
    description: parseString(json['description']),
    type: parseString(json['type'] ?? json['targetType']) ?? 'daily',
    reward: parseInt(
      json['reward'] ?? json['rewardIntimacy'] ?? json['rewardCharm'],
      0,
    ),
    rewardType: _parseRewardType(json),
    target: parseInt(json['target'] ?? json['targetCount'], 0),
    progress: parseInt(json['progress'], 0),
    myProgress: parseInt(json['myProgress'], 0),
    partnerProgress: parseInt(json['partnerProgress'], 0),
    isCompleted: parseBool(json['isCompleted']),
    isClaimed: parseBool(json['isClaimed']),
    isActive: parseBool(json['isActive'], true),
    expiresAt: parseString(json['expiresAt']),
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'title': title,
    'description': description,
    'type': type,
    'reward': reward,
    'rewardType': rewardType,
    'target': target,
    'progress': progress,
    'myProgress': myProgress,
    'partnerProgress': partnerProgress,
    'isCompleted': isCompleted,
    'isClaimed': isClaimed,
    'isActive': isActive,
    'expiresAt': expiresAt,
  };
}

/// Decide the reward type from a CP task JSON, supporting the doc schema
/// (`rewardType`, `rewardIntimacy`, `rewardCharm`) and falling back to the UI
/// default of `'intimacy'`.
String _parseRewardType(Map<String, dynamic> json) {
  final explicit = parseString(json['rewardType']);
  if (explicit != null && explicit.isNotEmpty) {
    return explicit;
  }
  if (json['rewardCharm'] != null) {
    return 'charm';
  }
  if (json['rewardIntimacy'] != null) {
    return 'intimacy';
  }
  return 'intimacy';
}

/// Response wrapper for CP task lists.
class CPTaskRoot {
  CPTaskRoot({this.status = false, this.message, this.tasks = const []});

  final bool status;
  final String? message;
  final List<CPTask> tasks;

  factory CPTaskRoot.fromJson(Map<String, dynamic> json) => CPTaskRoot(
    status: parseBool(json['status']),
    message: parseString(json['message']),
    tasks: parseList(json['data'] ?? json['tasks'], CPTask.fromJson),
  );
}

/// A couple ranking leaderboard entry.
class CPRankItem {
  CPRankItem({
    this.rank = 0,
    this.cp,
    this.intimacy = 0,
    this.charm = 0,
    this.trend = 0, // change since last period: +n / -n / 0
  });

  final int rank;
  final CPItem? cp;
  final int intimacy;
  final int charm;
  final int trend;

  factory CPRankItem.fromJson(Map<String, dynamic> json) => CPRankItem(
    rank: parseInt(json['rank'], 0),
    cp:
        json['cp'] == null || json['cp'] is! Map
            ? (json['_id'] != null || json['id'] != null
                ? CPItem.fromJson(json)
                : null)
            : CPItem.fromJson(json['cp'] as Map<String, dynamic>),
    intimacy: parseInt(json['intimacy'], 0),
    charm: parseInt(json['charm'], 0),
    trend: parseInt(json['trend'], 0),
  );
}

/// Response wrapper for CP ranking.
class CPRankRoot {
  CPRankRoot({this.status = false, this.message, this.couples = const []});

  final bool status;
  final String? message;
  final List<CPRankItem> couples;

  factory CPRankRoot.fromJson(Map<String, dynamic> json) => CPRankRoot(
    status: parseBool(json['status']),
    message: parseString(json['message']),
    couples: parseList(json['data'] ?? json['couples'], CPRankItem.fromJson),
  );
}

/// A CP bond level with its perks.
/// Dynamic — admin can create N levels (1, 2, ... 15, 20, 30 ...).
/// Each level has privilege items (files: PNG/SVG/GIF) with main + preview URLs.
class CPLevel {
  CPLevel({
    this.level = 1,
    this.name,
    this.requiredIntimacy = 0,
    this.badge,
    this.frame,
    this.entranceEffect,
    this.perks = const [],
    this.privilegeItems = const [],
    this.levelIcon,
    this.levelBadgeUrl,
    this.frameUrl,
    this.entranceAnimationUrl,
    this.themeUrl,
    this.emojiUrl,
    this.profileBackgroundUrl,
    this.ringUrl,
  });

  final int level;
  final String? name;
  final int requiredIntimacy;
  final String? badge;
  final String? frame;
  final String? entranceEffect;
  final List<String> perks;

  /// Dynamic privilege items for this level (from admin/backend).
  /// Each item has a main file (used in app) + preview file (shown in UI).
  final List<CPPrivilegeItem> privilegeItems;

  /// Asset URLs for this level (like VIP tier assets).
  final String? levelIcon;
  final String? levelBadgeUrl;
  final String? frameUrl;
  final String? entranceAnimationUrl;
  final String? themeUrl;
  final String? emojiUrl;
  final String? profileBackgroundUrl;
  final String? ringUrl;

  factory CPLevel.fromJson(Map<String, dynamic> json) => CPLevel(
    level: parseInt(json['level'], 1),
    name: parseString(json['name']),
    requiredIntimacy: parseInt(json['requiredIntimacy'], 0),
    badge: parseString(json['badge']),
    frame: parseString(json['frame']),
    entranceEffect: parseString(json['entranceEffect']),
    perks: parseList<String>(
      json['perks'],
      (m) => parseString(m['perk'] ?? m) ?? '',
    ),
    privilegeItems: parseList(
      json['privilegeItems'] ?? json['items'],
      CPPrivilegeItem.fromJson,
    ),
    levelIcon: parseString(json['levelIcon'] ?? json['icon']),
    levelBadgeUrl: parseString(json['levelBadgeUrl'] ?? json['badgeUrl']),
    frameUrl: parseString(json['frameUrl'] ?? json['frameImage']),
    entranceAnimationUrl: parseString(
      json['entranceAnimationUrl'] ?? json['entranceEffectUrl'],
    ),
    themeUrl: parseString(json['themeUrl'] ?? json['themeImage']),
    emojiUrl: parseString(json['emojiUrl'] ?? json['emojiImage']),
    profileBackgroundUrl: parseString(
      json['profileBackgroundUrl'] ?? json['backgroundUrl'],
    ),
    ringUrl: parseString(json['ringUrl'] ?? json['ringImage']),
  );

  Map<String, dynamic> toJson() => {
    'level': level,
    'name': name,
    'requiredIntimacy': requiredIntimacy,
    'badge': badge,
    'frame': frame,
    'entranceEffect': entranceEffect,
    'perks': perks,
    'privilegeItems': privilegeItems.map((e) => e.toJson()).toList(),
    'levelIcon': levelIcon,
    'levelBadgeUrl': levelBadgeUrl,
    'frameUrl': frameUrl,
    'entranceAnimationUrl': entranceAnimationUrl,
    'themeUrl': themeUrl,
    'emojiUrl': emojiUrl,
    'profileBackgroundUrl': profileBackgroundUrl,
    'ringUrl': ringUrl,
  };
}

/// A privilege item attached to a CP level.
/// Admin uploads: mainFile (used by app) + previewFile (shown in privileges UI).
/// Supports PNG, SVG, GIF, and any other image format.
class CPPrivilegeItem {
  CPPrivilegeItem({
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
  final String?
  type; // 'badge', 'frame', 'entrance', 'theme', 'emoji', 'ring', 'background', 'custom'
  final String? name;
  final String? description;

  /// Main file URL — the actual asset used in the app (e.g. frame overlay, badge image).
  final String? mainFileUrl;

  /// Preview file URL — a PNG/image shown in the privileges screen for display.
  final String? previewFileUrl;

  /// File type: 'png', 'svg', 'gif', 'jpg', etc.
  final String? fileType;

  final int unlockLevel;
  final bool unlocked;

  /// Effective preview URL — falls back to mainFileUrl if preview not set.
  String? get effectivePreviewUrl =>
      (previewFileUrl != null && previewFileUrl!.isNotEmpty)
          ? previewFileUrl
          : mainFileUrl;

  factory CPPrivilegeItem.fromJson(Map<String, dynamic> json) =>
      CPPrivilegeItem(
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
        fileType: parseString(json['fileType'] ?? json['type'] ?? 'png'),
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

/// Response wrapper for CP levels.
class CPLevelRoot {
  CPLevelRoot({this.status = false, this.message, this.levels = const []});

  final bool status;
  final String? message;
  final List<CPLevel> levels;

  factory CPLevelRoot.fromJson(Map<String, dynamic> json) => CPLevelRoot(
    status: parseBool(json['status']),
    message: parseString(json['message']),
    levels: parseList(json['data'] ?? json['levels'], CPLevel.fromJson),
  );
}

/// A couple milestone / anniversary record.
class CPMilestone {
  CPMilestone({
    this.id,
    this.type, // 'days_7', 'days_30', 'days_100', 'days_365', 'gift_milestone', 'custom'
    this.title,
    this.description,
    this.date,
    this.icon,
    this.days,
    this.rewardCoin,
    this.rewardIntimacy,
    this.value = 0,
    this.isUnlocked = false,
    this.isClaimed = false,
  });

  final String? id;
  final String? type;
  final String? title;
  final String? description;
  final String? date;
  final String? icon;
  final int? days;
  final int? rewardCoin;
  final int? rewardIntimacy;
  final int value;
  final bool isUnlocked;
  final bool isClaimed;

  factory CPMilestone.fromJson(Map<String, dynamic> json) {
    final reward = json['reward'] is Map<String, dynamic>
        ? json['reward'] as Map<String, dynamic>
        : <String, dynamic>{};
    return CPMilestone(
      id: parseString(json['_id'] ?? json['id']),
      type: parseString(json['type']),
      title: parseString(json['title']),
      description: parseString(json['description']),
      date: parseString(json['date']),
      icon: parseString(json['icon']),
      days: parseIntOrNull(json['days']),
      rewardCoin: parseIntOrNull(reward['coin'] ?? json['rewardCoin']),
      rewardIntimacy: parseIntOrNull(reward['intimacy'] ?? json['rewardIntimacy']),
      value: parseInt(json['value'], 0),
      isUnlocked: parseBool(json['isUnlocked']),
      isClaimed: parseBool(json['isClaimed']),
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'type': type,
    'title': title,
    'description': description,
    'date': date,
    'icon': icon,
    'days': days,
    'rewardCoin': rewardCoin,
    'rewardIntimacy': rewardIntimacy,
    'value': value,
    'isUnlocked': isUnlocked,
    'isClaimed': isClaimed,
  };
}

/// Response wrapper for CP milestones.
class CPMilestoneRoot {
  CPMilestoneRoot({
    this.status = false,
    this.message,
    this.milestones = const [],
  });

  final bool status;
  final String? message;
  final List<CPMilestone> milestones;

  factory CPMilestoneRoot.fromJson(Map<String, dynamic> json) =>
      CPMilestoneRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        milestones: parseList(
          json['data'] ?? json['milestones'],
          CPMilestone.fromJson,
        ),
      );
}

/// A past (broken) CP relationship entry — for the CP history screen.
class CPHistoryItem {
  CPHistoryItem({
    this.id,
    this.partner,
    this.level = 1,
    this.intimacy = 0,
    this.startedAt,
    this.endedAt,
    this.daysTogether = 0,
    this.reason, // 'mutual', 'by_user1', 'by_user2'
  });

  final String? id;
  final CPUser? partner;
  final int level;
  final int intimacy;
  final String? startedAt;
  final String? endedAt;
  final int daysTogether;
  final String? reason;

  factory CPHistoryItem.fromJson(Map<String, dynamic> json) => CPHistoryItem(
    id: parseString(json['_id'] ?? json['id']),
    partner:
        json['partner'] == null
            ? null
            : CPUser.fromJson(json['partner'] as Map<String, dynamic>),
    level: parseInt(json['level'], 1),
    intimacy: parseInt(json['intimacy'], 0),
    startedAt: parseString(json['startedAt'] ?? json['createdAt']),
    endedAt: parseString(json['endedAt']),
    daysTogether: parseInt(json['daysTogether'], 0),
    reason: parseString(json['reason']),
  );
}

/// Response wrapper for CP history.
class CPHistoryRoot {
  CPHistoryRoot({this.status = false, this.message, this.history = const []});

  final bool status;
  final String? message;
  final List<CPHistoryItem> history;

  factory CPHistoryRoot.fromJson(Map<String, dynamic> json) => CPHistoryRoot(
    status: parseBool(json['status']),
    message: parseString(json['message']),
    history: parseList(json['data'] ?? json['history'], CPHistoryItem.fromJson),
  );
}

/// A CP privilege unlocked at a specific bond level.
/// Types from screenshots: Broadcast, Frame&Theme, Ring Gallery, Room Emoji, Room Profile
/// Now supports file uploads (main + preview) like VIP system.
class CPPrivilege {
  CPPrivilege({
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
  type; // 'broadcast', 'frame_theme', 'ring_gallery', 'room_emoji', 'room_profile', 'custom'
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

  /// Sub-items for this privilege (e.g. multiple frames, multiple emojis).
  final List<CPPrivilegeItem> items;

  /// Effective preview URL — falls back to icon then mainFileUrl.
  String? get effectivePreviewUrl {
    if (previewFileUrl != null && previewFileUrl!.isNotEmpty) {
      return previewFileUrl;
    }
    if (mainFileUrl != null && mainFileUrl!.isNotEmpty) return mainFileUrl;
    return icon;
  }

  factory CPPrivilege.fromJson(Map<String, dynamic> json) => CPPrivilege(
    type: parseString(json['type']),
    name: parseString(json['name']),
    icon: parseString(json['icon']),
    unlocked: parseBool(json['unlocked']),
    unlockLevel: parseInt(json['unlockLevel'], 1),
    description: parseString(json['description']),
    mainFileUrl: parseString(json['mainFileUrl'] ?? json['mainFile']),
    previewFileUrl: parseString(json['previewFileUrl'] ?? json['previewFile']),
    fileType: parseString(json['fileType'] ?? 'png'),
    items: parseList(json['items'], CPPrivilegeItem.fromJson),
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

/// A ring in the ring gallery (couple rings collected/unlocked).
class CPRing {
  CPRing({
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

  factory CPRing.fromJson(Map<String, dynamic> json) => CPRing(
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

/// Response wrapper for ring gallery.
class CPRingRoot {
  CPRingRoot({this.status = false, this.message, this.rings = const []});

  final bool status;
  final String? message;
  final List<CPRing> rings;

  factory CPRingRoot.fromJson(Map<String, dynamic> json) => CPRingRoot(
    status: parseBool(json['status']),
    message: parseString(json['message']),
    rings: parseList(json['data'] ?? json['rings'], CPRing.fromJson),
  );
}

/// Response wrapper for CP privileges.
class CPPrivilegeRoot {
  CPPrivilegeRoot({
    this.status = false,
    this.message,
    this.privileges = const [],
  });

  final bool status;
  final String? message;
  final List<CPPrivilege> privileges;

  factory CPPrivilegeRoot.fromJson(Map<String, dynamic> json) =>
      CPPrivilegeRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        privileges: parseList(
          json['data'] ?? json['privileges'],
          CPPrivilege.fromJson,
        ),
      );
}

// ---- CP / Friend Star Event (real backend event) ---------------------------

/// A single reward rule for a star event rank range.
class CPStarEventReward {
  CPStarEventReward({
    this.rewardId,
    this.rankFrom = 0,
    this.rankTo = 0,
    this.coin = 0,
    this.itemUrl,
    this.isClaimed = false,
  });

  final String? rewardId;
  final int rankFrom;
  final int rankTo;
  final int coin;
  final String? itemUrl;
  final bool isClaimed;

  factory CPStarEventReward.fromJson(Map<String, dynamic> json) =>
      CPStarEventReward(
        rewardId: parseString(json['rewardId'] ?? json['_id'] ?? json['id']),
        rankFrom: parseInt(json['rankFrom'] ?? json['rank']?['from'], 0),
        rankTo: parseInt(json['rankTo'] ?? json['rank']?['to'], 0),
        coin: parseInt((json['reward'] is Map
            ? json['reward']['coin']
            : json['coin']), 0),
        itemUrl: parseString(json['reward'] is Map
            ? json['reward']['itemUrl'] ?? json['reward']['frame']
            : json['itemUrl']),
        isClaimed: parseBool(json['isClaimed']),
      );
}

/// An active (or upcoming/ended) CP/Friend Star Event.
class CPStarEvent {
  CPStarEvent({
    this.id,
    this.type,
    this.name,
    this.bannerImage,
    this.backgroundUrl,
    this.startTime,
    this.endTime,
    this.status,
    this.pointMultiplier = 1,
    this.rewards = const [],
  });

  final String? id;
  final String? type; // 'cp' | 'friend'
  final String? name;
  final String? bannerImage;
  final String? backgroundUrl;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? status; // 'upcoming' | 'active' | 'ended'
  final int pointMultiplier;
  final List<CPStarEventReward> rewards;

  bool get isActive => status == 'active';
  bool get isEnded => status == 'ended';

  /// Seconds remaining until the event ends (0 if ended/no end time).
  int get remainingSeconds {
    final end = endTime;
    if (end == null) return 0;
    final diff = end.difference(DateTime.now());
    return diff.isNegative ? 0 : diff.inSeconds;
  }

  factory CPStarEvent.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString()).toUtc();
      } catch (_) {
        // Try epoch millis.
        final ms = int.tryParse(v.toString());
        if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
        return null;
      }
    }

    return CPStarEvent(
      id: parseString(json['_id'] ?? json['id']),
      type: parseString(json['type']),
      name: parseString(json['name']),
      bannerImage: parseString(json['bannerImage']),
      backgroundUrl: parseString(json['backgroundUrl']),
      startTime: parseDate(json['startTime']),
      endTime: parseDate(json['endTime']),
      status: parseString(json['status']),
      pointMultiplier: parseInt(json['pointMultiplier'], 1),
      rewards: parseList(json['rewardRules'] ?? json['rewards'],
          CPStarEventReward.fromJson),
    );
  }
}

/// Response wrapper for the active star event endpoint.
/// `event` is null when no event is active.
class CPStarEventRoot {
  CPStarEventRoot({this.status = false, this.message, this.event});

  final bool status;
  final String? message;
  final CPStarEvent? event;

  factory CPStarEventRoot.fromJson(Map<String, dynamic> json) =>
      CPStarEventRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        event: json['data'] == null || json['data'] is! Map
            ? null
            : CPStarEvent.fromJson(json['data'] as Map<String, dynamic>),
      );
}

/// The current user's rank + points in a star event.
class CPStarEventMyRank {
  CPStarEventMyRank({
    this.rank = 0,
    this.eventPoints = 0,
    this.cpId,
  });

  final int rank;
  final int eventPoints;
  final String? cpId;

  factory CPStarEventMyRank.fromJson(Map<String, dynamic> json) =>
      CPStarEventMyRank(
        rank: parseInt(json['rank'], 0),
        eventPoints: parseInt(json['eventPoints'] ?? json['points'], 0),
        cpId: parseString(json['cpId'] ?? json['friendshipId']),
      );
}

class CPStarEventMyRankRoot {
  CPStarEventMyRankRoot({this.status = false, this.message, this.rank});

  final bool status;
  final String? message;
  final CPStarEventMyRank? rank;

  factory CPStarEventMyRankRoot.fromJson(Map<String, dynamic> json) =>
      CPStarEventMyRankRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        rank: json['data'] is Map
            ? CPStarEventMyRank.fromJson(json['data'] as Map<String, dynamic>)
            : null,
      );
}

/// Claimable + claimed rewards for the user's CP in a star event.
class CPStarEventRewardsRoot {
  CPStarEventRewardsRoot({
    this.status = false,
    this.message,
    this.rewards = const [],
  });

  final bool status;
  final String? message;
  final List<CPStarEventReward> rewards;

  factory CPStarEventRewardsRoot.fromJson(Map<String, dynamic> json) =>
      CPStarEventRewardsRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        rewards: parseList(json['data'] ?? json['rewards'],
            CPStarEventReward.fromJson),
      );
}

/// Response wrapper for claiming a star event reward.
class CPStarEventClaimRoot {
  CPStarEventClaimRoot({this.status = false, this.message, this.reward});

  final bool status;
  final String? message;
  final CPStarEventReward? reward;

  factory CPStarEventClaimRoot.fromJson(Map<String, dynamic> json) =>
      CPStarEventClaimRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        reward: json['data'] is Map
            ? CPStarEventReward.fromJson(json['data'] as Map<String, dynamic>)
            : null,
      );
}

// ---- Breakup / Remove penalty + cooldown status ---------------------------

/// Breakup / remove status for the current user.
/// See `docs/CP_FRIEND_BACKEND_REMAINING.md` §9.
class CpBreakupStatus {
  CpBreakupStatus({
    this.canBreakup = true,
    this.canRemove = true,
    this.cooldownUntil,
    this.penaltyCoins = 0,
  });

  final bool canBreakup;
  final bool canRemove;
  final DateTime? cooldownUntil;
  final int penaltyCoins;

  /// True when the user is still in the cooldown period.
  bool get inCooldown {
    final c = cooldownUntil;
    if (c == null) return false;
    return c.isAfter(DateTime.now());
  }

  /// Remaining cooldown in seconds (0 if not in cooldown).
  int get remainingCooldownSeconds {
    final c = cooldownUntil;
    if (c == null) return 0;
    final diff = c.difference(DateTime.now());
    return diff.isNegative ? 0 : diff.inSeconds;
  }

  factory CpBreakupStatus.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        final ms = int.tryParse(v.toString());
        if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
        return null;
      }
    }

    return CpBreakupStatus(
      canBreakup: parseBool(json['canBreakup'] ?? json['canBreakUp']),
      canRemove: parseBool(json['canRemove']),
      cooldownUntil: parseDate(json['cooldownUntil']),
      penaltyCoins: parseInt(json['penaltyCoins'] ?? json['penalty'], 0),
    );
  }
}

class CpBreakupStatusRoot {
  CpBreakupStatusRoot({this.status = false, this.message, this.data});

  final bool status;
  final String? message;
  final CpBreakupStatus? data;

  factory CpBreakupStatusRoot.fromJson(Map<String, dynamic> json) =>
      CpBreakupStatusRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        data: json['data'] is Map
            ? CpBreakupStatus.fromJson(json['data'] as Map<String, dynamic>)
            : null,
      );
}
