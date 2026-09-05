/// Phase 9 implementation: Family system models.
///
/// Ported from native `FamilyRoot.java` + extended with Bigo Live-style
/// features (member management, tasks, ranking, create flow).
///
/// The native app only had a minimal family list + join. This model
/// supports the full feature set we're building.
library family_models;
import 'json_annotation_helper.dart';

/// Alias for [FamilyRoot] â€” used by `ApiService.getFamilies`.
typedef FamilyListRoot = FamilyRoot;

/// Ported from native `FamilyRoot.java`.
class FamilyRoot {
  FamilyRoot({this.status = false, this.message, this.total = 0, this.data = const []});

  final bool status;
  final String? message;
  final int total;
  final List<FamilyItem> data;

  factory FamilyRoot.fromJson(Map<String, dynamic> json) {
    // `data` can be a List (from /family/list) or a single Map object
    // (from /family/create or /family/{id}).
    final rawData = json['data'];
    List<FamilyItem> items;
    if (rawData is Map) {
      items = [FamilyItem.fromJson(Map<String, dynamic>.from(rawData))];
    } else {
      items = parseList(rawData, FamilyItem.fromJson);
    }
    return FamilyRoot(
      status: parseBool(json['status']),
      message: parseString(json['message']),
      total: parseInt(json['total'], 0),
      data: items,
    );
  }
}

/// A family/group that users can join.
class FamilyItem {
  FamilyItem({
    this.id,
    this.name,
    this.description,
    this.image,
    this.coverImage,
    this.joinCode,
    this.isPublic = true,
    this.leaderId,
    this.leader,
    this.members = const [],
    this.memberCount = 0,
    this.totalCoin = 0,
    this.totalDiamond = 0,
    this.level = 1,
    this.rank = 0,
    this.createdAt,
    this.isMember = false,
    this.userRole,
    this.welcomeMessage,
    this.maxMembers = 0,
    this.slogan,
    this.announcement,
    this.roomId,
    this.treasury = 0,
    this.dailyCoins = 0,
    this.dailySignInReward = 10,
    this.hasSignedInToday = false,
    this.signInStreak = 0,
    this.unlockedPerks = const [],
    this.minLevelToJoin = 0,
    this.requireApproval = false,
  });

  final String? id;
  final String? name;
  final String? description;
  final String? image;
  final String? coverImage;
  final String? joinCode;
  final bool isPublic;
  final String? leaderId;
  final FamilyLeader? leader;
  final List<FamilyMember> members;
  final int memberCount;
  final int totalCoin;
  final int totalDiamond;
  final int level;
  final int rank;
  final String? createdAt;
  final bool isMember;
  final String? userRole;
  final String? welcomeMessage;
  final int maxMembers;
  final String? slogan;
  final String? announcement;
  final String? roomId;
  final int treasury;
  final int dailyCoins;

  /// Exp/coins reward for daily sign-in (set by family owner).
  final int dailySignInReward;
  /// Whether the current user has already signed in today.
  final bool hasSignedInToday;
  /// Current daily sign-in streak count.
  final int signInStreak;
  /// List of perk keys that have been unlocked by this family.
  final List<String> unlockedPerks;
  /// Minimum user level required to join this family (owner setting).
  final int minLevelToJoin;
  /// Whether join requests require leader approval (owner setting).
  final bool requireApproval;

  factory FamilyItem.fromJson(Map<String, dynamic> json) => FamilyItem(
        id: parseString(json['_id'] ?? json['id']),
        name: parseString(json['name']),
        description: parseString(json['description']),
        image: parseString(json['image']),
        coverImage: parseString(json['coverImage'] ?? json['bannerImage']),
        joinCode: parseString(json['joinCode']),
        isPublic: json['isPublic'] == null ? true : parseBool(json['isPublic']),
        leaderId: parseString(json['leaderId'] ?? (json['leader'] != null ? (json['leader']['_id'] ?? json['leader']['id']) : null)),
        leader: json['leader'] == null ? null : FamilyLeader.fromJson(json['leader'] as Map<String, dynamic>),
        members: parseList(json['members'], FamilyMember.fromJson),
        memberCount: parseInt(json['memberCount'], 0),
        totalCoin: parseInt(json['totalCoin'], 0),
        totalDiamond: parseInt(json['totalDiamond'], 0),
        level: parseInt(json['level'], 1),
        rank: parseInt(json['rank'], 0),
        createdAt: parseString(json['createdAt']),
        isMember: parseBool(json['isMember']),
        userRole: parseString(json['userRole']),
        welcomeMessage: parseString(json['welcomeMessage']),
        roomId: parseString(json['roomId']),
        treasury: parseInt(json['treasury'], 0),
        dailyCoins: parseInt(json['dailyCoins'], 0),
        dailySignInReward: parseInt(json['dailySignInReward'], 10),
        hasSignedInToday: parseBool(json['hasSignedInToday']),
        signInStreak: parseInt(json['signInStreak'], 0),
        unlockedPerks: parseList(json['unlockedPerks'], (e) => parseString(e) ?? ''),
        minLevelToJoin: parseInt(json['minLevelToJoin'], 0),
        requireApproval: parseBool(json['requireApproval']),
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'description': description,
        'image': image,
        'coverImage': coverImage,
        'joinCode': joinCode,
        'isPublic': isPublic,
        'leaderId': leaderId,
        'leader': leader?.toJson(),
        'members': members.map((m) => m.toJson()).toList(),
        'memberCount': memberCount,
        'totalCoin': totalCoin,
        'totalDiamond': totalDiamond,
        'level': level,
        'rank': rank,
        'createdAt': createdAt,
        'isMember': isMember,
        'userRole': userRole,
        'maxMembers': maxMembers,
        'slogan': slogan,
        'announcement': announcement,
        'roomId': roomId,
        'treasury': treasury,
        'dailyCoins': dailyCoins,
        'dailySignInReward': dailySignInReward,
        'hasSignedInToday': hasSignedInToday,
        'signInStreak': signInStreak,
        'unlockedPerks': unlockedPerks,
        'minLevelToJoin': minLevelToJoin,
        'requireApproval': requireApproval,
      };
}

/// Family leader info (simplified user).
class FamilyLeader {
  FamilyLeader({this.id, this.name, this.image, this.username});

  final String? id;
  final String? name;
  final String? image;
  final String? username;

  factory FamilyLeader.fromJson(Map<String, dynamic> json) => FamilyLeader(
        id: parseString(json['_id'] ?? json['id']),
        name: parseString(json['name']),
        image: parseString(json['image']),
        username: parseString(json['username']),
      );

  Map<String, dynamic> toJson() => {'_id': id, 'name': name, 'image': image, 'username': username};
}

/// Family member with role.
class FamilyMember {
  FamilyMember({
    this.userId,
    this.name,
    this.image,
    this.username,
    this.role = 'member',
    this.joinedAt,
    this.contribution = 0,
    this.isOnline = false,
    this.level = 1,
    this.lastActive,
    this.specialTitle,
  });

  final String? userId;
  final String? name;
  final String? image;
  final String? username;
  final String role; // 'leader', 'co-leader', 'member'
  final String? joinedAt;
  final int contribution;
  final bool isOnline;
  final int level;
  final String? lastActive;
  final String? specialTitle;

  String? get id => userId;
  String? get avatar => image;

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
        userId: parseString(json['userId'] is Map ? (json['userId']['_id'] ?? json['userId']['id']) : json['userId']),
        name: parseString(json['name'] ?? (json['userId'] is Map ? json['userId']['name'] : null)),
        image: parseString(json['image'] ?? (json['userId'] is Map ? json['userId']['image'] : null)),
        username: parseString(json['username'] ?? (json['userId'] is Map ? json['userId']['username'] : null)),
        role: parseString(json['role']) ?? 'member',
        joinedAt: parseString(json['joinedAt']),
        contribution: parseInt(json['contribution'], 0),
        isOnline: parseBool(json['isOnline']),
        level: parseInt(json['level'] ?? (json['userId'] is Map ? json['userId']['level'] : null), 1),
        lastActive: parseString(json['lastActive'] ?? (json['userId'] is Map ? json['userId']['lastActive'] : null)),
        specialTitle: parseString(json['specialTitle']),
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'image': image,
        'username': username,
        'role': role,
        'joinedAt': joinedAt,
        'contribution': contribution,
        'isOnline': isOnline,
        'specialTitle': specialTitle,
      };
}

/// Family task with reward.
class FamilyTask {
  FamilyTask({
    this.id,
    this.title,
    this.description,
    this.type = 'daily',
    this.reward = 0,
    this.target = 0,
    this.progress = 0,
    this.isCompleted = false,
    this.isClaimed = false,
    this.expiresAt,
  });

  final String? id;
  final String? title;
  final String? description;
  final String type; // 'daily', 'weekly', 'special'
  final int reward;
  final int target;
  final int progress;
  final bool isCompleted;
  final bool isClaimed;
  final String? expiresAt;

  factory FamilyTask.fromJson(Map<String, dynamic> json) => FamilyTask(
        id: parseString(json['_id'] ?? json['id']),
        title: parseString(json['title']),
        description: parseString(json['description']),
        type: parseString(json['type']) ?? 'daily',
        reward: parseInt(json['reward'], 0),
        target: parseInt(json['target'], 0),
        progress: parseInt(json['progress'], 0),
        isCompleted: parseBool(json['isCompleted']),
        isClaimed: parseBool(json['isClaimed']),
        expiresAt: parseString(json['expiresAt']),
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'title': title,
        'description': description,
        'type': type,
        'reward': reward,
        'target': target,
        'progress': progress,
        'isCompleted': isCompleted,
        'isClaimed': isClaimed,
        'expiresAt': expiresAt,
      };
}

/// Family task list response.
class FamilyTaskRoot {
  FamilyTaskRoot({this.status = false, this.message, this.tasks = const []});

  final bool status;
  final String? message;
  final List<FamilyTask> tasks;

  factory FamilyTaskRoot.fromJson(Map<String, dynamic> json) => FamilyTaskRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        tasks: parseList(json['tasks'] ?? json['data'], FamilyTask.fromJson),
      );
}

/// Family ranking item (for leaderboard).
class FamilyRankItem {
  FamilyRankItem({
    this.id,
    this.name,
    this.image,
    this.level = 1,
    this.memberCount = 0,
    this.totalCoin = 0,
    this.totalDiamond = 0,
    this.rank = 0,
    this.members = const [],
  });

  final String? id;
  final String? name;
  final String? image;
  final int level;
  final int memberCount;
  final int totalCoin;
  final int totalDiamond;
  final int rank;
  final List<FamilyMember> members;

  factory FamilyRankItem.fromJson(Map<String, dynamic> json) => FamilyRankItem(
        id: parseString(json['_id'] ?? json['id']),
        name: parseString(json['name']),
        image: parseString(json['image']),
        level: parseInt(json['level'], 1),
        memberCount: parseInt(json['memberCount'], 0),
        totalCoin: parseInt(json['totalCoin'], 0),
        totalDiamond: parseInt(json['totalDiamond'], 0),
        rank: parseInt(json['rank'], 0),
        members: parseList(json['members'], FamilyMember.fromJson),
      );
}

/// Family ranking response.
class FamilyRankRoot {
  FamilyRankRoot({this.status = false, this.message, this.families = const []});

  final bool status;
  final String? message;
  final List<FamilyRankItem> families;

  factory FamilyRankRoot.fromJson(Map<String, dynamic> json) => FamilyRankRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        families: parseList(json['data'] ?? json['families'], FamilyRankItem.fromJson),
      );
}

/// Weekly ranking configuration — controlled by admin/backend.
/// Drives the countdown timer on the Family Honor screen.
class FamilyWeekConfig {
  FamilyWeekConfig({
    this.isActive = false,
    this.weekStart,
    this.weekEnd,
    this.nextReset,
    this.label,
  });

  /// Whether the weekly ranking is currently active.
  final bool isActive;

  /// ISO 8601 timestamp — start of current ranking week.
  final String? weekStart;

  /// ISO 8601 timestamp — end of current ranking week (countdown target).
  final String? weekEnd;

  /// ISO 8601 timestamp — when the next weekly reset happens.
  final String? nextReset;

  /// Optional display label, e.g. "Week 35" or "Season 3".
  final String? label;

  factory FamilyWeekConfig.fromJson(Map<String, dynamic> json) => FamilyWeekConfig(
        isActive: parseBool(json['isActive']),
        weekStart: parseString(json['weekStart']),
        weekEnd: parseString(json['weekEnd']),
        nextReset: parseString(json['nextReset']),
        label: parseString(json['label']),
      );
}

/// Join request entry — a user requesting to join a family that requires
/// approval. Mirrors Bigo/Chamet's join approval queue.
class FamilyJoinRequest {
  FamilyJoinRequest({
    this.id,
    this.userId,
    this.userName,
    this.userImage,
    this.username,
    this.level = 1,
    this.country,
    this.familyId,
    this.status = 'pending', // 'pending', 'approved', 'rejected'
    this.requestedAt,
    this.message,
  });

  final String? id;
  final String? userId;
  final String? userName;
  final String? userImage;
  final String? username;
  final int level;
  final String? country;
  final String? familyId;
  final String status;
  final String? requestedAt;
  final String? message;

  factory FamilyJoinRequest.fromJson(Map<String, dynamic> json) => FamilyJoinRequest(
        id: parseString(json['_id'] ?? json['id']),
        userId: parseString(json['userId'] is Map
            ? (json['userId']['_id'] ?? json['userId']['id'])
            : json['userId']),
        userName: parseString(json['userName'] ??
            (json['userId'] is Map ? json['userId']['name'] : null) ??
            json['name']),
        userImage: parseString(json['userImage'] ??
            (json['userId'] is Map ? json['userId']['image'] : null) ??
            json['image']),
        username: parseString(json['username'] ??
            (json['userId'] is Map ? json['userId']['username'] : null)),
        level: parseInt(json['level'] ??
            (json['userId'] is Map ? json['userId']['level'] : null), 1),
        country: parseString(json['country'] ??
            (json['userId'] is Map ? json['userId']['country'] : null)),
        familyId: parseString(json['familyId']),
        status: parseString(json['status']) ?? 'pending',
        requestedAt: parseString(json['requestedAt'] ?? json['createdAt']),
        message: parseString(json['message']),
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'userId': userId,
        'userName': userName,
        'userImage': userImage,
        'username': username,
        'level': level,
        'country': country,
        'familyId': familyId,
        'status': status,
        'requestedAt': requestedAt,
        'message': message,
      };
}

/// Join request list response.
class FamilyJoinRequestRoot {
  FamilyJoinRequestRoot({this.status = false, this.message, this.requests = const []});

  final bool status;
  final String? message;
  final List<FamilyJoinRequest> requests;

  factory FamilyJoinRequestRoot.fromJson(Map<String, dynamic> json) => FamilyJoinRequestRoot(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        requests: parseList(json['data'] ?? json['requests'], FamilyJoinRequest.fromJson),
      );
}

/// Banned/blocked family member entry.
class FamilyBannedUser {
  FamilyBannedUser({
    this.userId,
    this.userName,
    this.userImage,
    this.bannedAt,
    this.reason,
  });

  final String? userId;
  final String? userName;
  final String? userImage;
  final String? bannedAt;
  final String? reason;

  factory FamilyBannedUser.fromJson(Map<String, dynamic> json) => FamilyBannedUser(
        userId: parseString(json['userId'] is Map
            ? (json['userId']['_id'] ?? json['userId']['id'])
            : json['userId']),
        userName: parseString(json['userName'] ??
            (json['userId'] is Map ? json['userId']['name'] : null)),
        userImage: parseString(json['userImage'] ??
            (json['userId'] is Map ? json['userId']['image'] : null)),
        bannedAt: parseString(json['bannedAt'] ?? json['createdAt']),
        reason: parseString(json['reason']),
      );
}

/// Treasury transaction entry — donation, perk purchase, fund share, etc.
class FamilyTransaction {
  FamilyTransaction({
    this.id,
    this.type, // 'donation', 'perk_purchase', 'fund_share', 'reward', 'admin'
    this.amount,
    this.userId,
    this.userName,
    this.userImage,
    this.description,
    this.timestamp,
    this.balanceAfter,
  });

  final String? id;
  final String? type;
  final int? amount;
  final String? userId;
  final String? userName;
  final String? userImage;
  final String? description;
  final String? timestamp;
  final int? balanceAfter;

  bool get isCredit => type == 'donation' || type == 'reward';
  bool get isDebit => type == 'perk_purchase' || type == 'fund_share';

  factory FamilyTransaction.fromJson(Map<String, dynamic> json) => FamilyTransaction(
        id: parseString(json['_id'] ?? json['id']),
        type: parseString(json['type']),
        amount: parseInt(json['amount'], 0),
        userId: parseString(json['userId'] is Map
            ? (json['userId']['_id'] ?? json['userId']['id'])
            : json['userId']),
        userName: parseString(json['userName'] ??
            (json['userId'] is Map ? json['userId']['name'] : null)),
        userImage: parseString(json['userImage'] ??
            (json['userId'] is Map ? json['userId']['image'] : null)),
        description: parseString(json['description']),
        timestamp: parseString(json['timestamp'] ?? json['createdAt']),
        balanceAfter: parseInt(json['balanceAfter'], 0),
      );
}

/// Claimable family level reward — Bigo/Chamet parity.
class FamilyLevelReward {
  FamilyLevelReward({
    this.id,
    required this.level,
    this.rewardType, // 'coins', 'badge', 'frame', 'perk'
    required this.amount,
    this.name,
    this.description,
    this.iconUrl,
    this.isClaimed = false,
    this.isClaimable = false,
  });

  final String? id;
  final int level;
  final String? rewardType;
  final int amount;
  final String? name;
  final String? description;
  final String? iconUrl;
  final bool isClaimed;
  final bool isClaimable;

  factory FamilyLevelReward.fromJson(Map<String, dynamic> json) => FamilyLevelReward(
        id: parseString(json['_id'] ?? json['id']),
        level: parseInt(json['level'], 1),
        rewardType: parseString(json['rewardType']),
        amount: parseInt(json['amount'], 0),
        name: parseString(json['name']),
        description: parseString(json['description']),
        iconUrl: parseString(json['iconUrl']),
        isClaimed: parseBool(json['isClaimed']),
        isClaimable: parseBool(json['isClaimable']),
      );
}

/// Family PK battle history entry — Bigo/Chamet parity.
class FamilyBattleHistory {
  FamilyBattleHistory({
    this.id,
    this.familyId,
    this.familyName,
    this.familyImage,
    this.opponentFamilyId,
    this.opponentFamilyName,
    this.opponentFamilyImage,
    this.result, // 'win', 'loss', 'draw'
    this.familyScore = 0,
    this.opponentScore = 0,
    this.duration = 0,
    this.startedAt,
    this.endedAt,
    this.rewardAmount = 0,
  });

  final String? id;
  final String? familyId;
  final String? familyName;
  final String? familyImage;
  final String? opponentFamilyId;
  final String? opponentFamilyName;
  final String? opponentFamilyImage;
  final String? result;
  final int familyScore;
  final int opponentScore;
  final int duration;
  final String? startedAt;
  final String? endedAt;
  final int rewardAmount;

  bool get isWin => result == 'win';
  bool get isLoss => result == 'loss';

  factory FamilyBattleHistory.fromJson(Map<String, dynamic> json) => FamilyBattleHistory(
        id: parseString(json['_id'] ?? json['id']),
        familyId: parseString(json['familyId']),
        familyName: parseString(json['familyName']),
        familyImage: parseString(json['familyImage']),
        opponentFamilyId: parseString(json['opponentFamilyId'] ?? json['targetFamilyId']),
        opponentFamilyName: parseString(json['opponentFamilyName'] ?? json['targetFamilyName']),
        opponentFamilyImage: parseString(json['opponentFamilyImage'] ?? json['targetFamilyImage']),
        result: parseString(json['result']),
        familyScore: parseInt(json['familyScore'] ?? json['myScore'], 0),
        opponentScore: parseInt(json['opponentScore'] ?? json['opponentFamilyScore'], 0),
        duration: parseInt(json['duration'], 0),
        startedAt: parseString(json['startedAt'] ?? json['createdAt']),
        endedAt: parseString(json['endedAt']),
        rewardAmount: parseInt(json['rewardAmount'], 0),
      );
}

/// Family announcement post — Bigo/Chamet parity.
class FamilyAnnouncement {
  FamilyAnnouncement({
    this.id,
    this.title,
    this.content,
    this.authorId,
    this.authorName,
    this.authorImage,
    this.isPinned = false,
    this.createdAt,
    this.likes = 0,
    this.comments = 0,
    this.hasLiked = false,
  });

  final String? id;
  final String? title;
  final String? content;
  final String? authorId;
  final String? authorName;
  final String? authorImage;
  final bool isPinned;
  final String? createdAt;
  final int likes;
  final int comments;
  final bool hasLiked;

  factory FamilyAnnouncement.fromJson(Map<String, dynamic> json) => FamilyAnnouncement(
        id: parseString(json['_id'] ?? json['id']),
        title: parseString(json['title']),
        content: parseString(json['content']),
        authorId: parseString(json['authorId'] is Map
            ? (json['authorId']['_id'] ?? json['authorId']['id'])
            : json['authorId']),
        authorName: parseString(json['authorName'] ??
            (json['authorId'] is Map ? json['authorId']['name'] : null)),
        authorImage: parseString(json['authorImage'] ??
            (json['authorId'] is Map ? json['authorId']['image'] : null)),
        isPinned: parseBool(json['isPinned']),
        createdAt: parseString(json['createdAt']),
        likes: parseInt(json['likes'], 0),
        comments: parseInt(json['comments'], 0),
        hasLiked: parseBool(json['hasLiked']),
      );
}

/// Family event entry — PK battles, celebrations, anniversaries.
class FamilyEvent {
  FamilyEvent({
    this.id,
    this.type, // 'pk_battle', 'celebration', 'anniversary', 'meeting'
    this.title,
    this.description,
    this.imageUrl,
    this.startTime,
    this.endTime,
    this.status, // 'upcoming', 'ongoing', 'ended'
    this.participants = 0,
  });

  final String? id;
  final String? type;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? startTime;
  final String? endTime;
  final String? status;
  final int participants;

  factory FamilyEvent.fromJson(Map<String, dynamic> json) => FamilyEvent(
        id: parseString(json['_id'] ?? json['id']),
        type: parseString(json['type']),
        title: parseString(json['title']),
        description: parseString(json['description']),
        imageUrl: parseString(json['imageUrl']),
        startTime: parseString(json['startTime'] ?? json['start']),
        endTime: parseString(json['endTime'] ?? json['end']),
        status: parseString(json['status']),
        participants: parseInt(json['participants'], 0),
      );
}

/// Family achievement — replaces hardcoded placeholders. Bigo/Chamet parity.
class FamilyAchievement {
  FamilyAchievement({
    this.id,
    this.name,
    this.description,
    this.category, // 'ranking', 'battle', 'activity'
    this.iconUrl,
    this.isUnlocked = false,
    this.unlockedAt,
    this.progress = 0,
    this.target = 0,
  });

  final String? id;
  final String? name;
  final String? description;
  final String? category;
  final String? iconUrl;
  final bool isUnlocked;
  final String? unlockedAt;
  final int progress;
  final int target;

  double get progressPercent => target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;

  factory FamilyAchievement.fromJson(Map<String, dynamic> json) => FamilyAchievement(
        id: parseString(json['_id'] ?? json['id']),
        name: parseString(json['name']),
        description: parseString(json['description']),
        category: parseString(json['category']),
        iconUrl: parseString(json['iconUrl'] ?? json['image']),
        isUnlocked: parseBool(json['isUnlocked'] ?? json['unlocked']),
        unlockedAt: parseString(json['unlockedAt']),
        progress: parseInt(json['progress'], 0),
        target: parseInt(json['target'], 0),
      );
}

/// Family level info from backend — replaces hardcoded formulas.
/// Bigo/Chamet parity: level/capacity/growth all come from backend.
class FamilyLevelInfo {
  FamilyLevelInfo({
    this.level = 1,
    this.xp = 0,
    this.xpToNextLevel = 0,
    this.maxMembers = 50,
    this.dailyGrowth = 0,
    this.weeklyGrowth = 0,
    this.totalGrowth = 0,
    this.levelName,
    this.levelBadgeUrl,
    this.perks = const [],
  });

  final int level;
  final int xp;
  final int xpToNextLevel;
  final int maxMembers;
  final int dailyGrowth;
  final int weeklyGrowth;
  final int totalGrowth;
  final String? levelName;
  final String? levelBadgeUrl;
  final List<String> perks;

  double get levelProgress => xpToNextLevel > 0 ? (xp / xpToNextLevel).clamp(0.0, 1.0) : 0.0;

  factory FamilyLevelInfo.fromJson(Map<String, dynamic> json) => FamilyLevelInfo(
        level: parseInt(json['level'], 1),
        xp: parseInt(json['xp'] ?? json['exp'], 0),
        xpToNextLevel: parseInt(json['xpToNextLevel'] ?? json['nextLevelXp'], 0),
        maxMembers: parseInt(json['maxMembers'] ?? json['capacity'], 50),
        dailyGrowth: parseInt(json['dailyGrowth'], 0),
        weeklyGrowth: parseInt(json['weeklyGrowth'], 0),
        totalGrowth: parseInt(json['totalGrowth'], 0),
        levelName: parseString(json['levelName'] ?? json['name']),
        levelBadgeUrl: parseString(json['levelBadgeUrl'] ?? json['badgeUrl']),
        perks: parseList(json['perks'], (e) => parseString(e) ?? ''),
      );
}
