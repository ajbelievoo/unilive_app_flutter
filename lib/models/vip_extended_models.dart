/// Extended VIP models — Bigo/Chamet-parity features.
///
/// Adds models for:
/// - VIP Leaderboard (top VIP point earners)
/// - Daily Bonus claim
/// - VIP Trial (free 1-day preview)
/// - Gifting Cashback config
/// - Special ID categories & price tiers
/// - Ban/Unban account info (reason, history, limits, cooldown)
/// - Dynamic Avatar gallery
/// - VIP Theme gallery
/// - Tier Comparison matrix
/// - VIP Gift preview (exclusive gifts for VIP users)
/// - VIP purchase celebration payload (from enhanced buyVip response)
library vip_extended_models;

import 'dart:ui' show Color;

import 'json_annotation_helper.dart';

// ---- VIP Purchase Celebration ----------------------------------------------
// Returned by the enhanced `POST /api/user/vip-tiers/buy` response in the
// `celebration` field. Drives the `VipLevelUpCelebration` overlay.

class VipCelebration {
  VipCelebration({
    this.newVipLevel = 0,
    this.tierName,
    this.tierColor,
    this.entranceAnimationUrl,
    this.levelBadgeUrl,
    this.profileFrameUrl,
    this.expiresAt,
  });

  final int newVipLevel;
  final String? tierName;
  final String? tierColor; // hex like "#FFD700"
  final String? entranceAnimationUrl;
  final String? levelBadgeUrl;
  final String? profileFrameUrl;
  final String? expiresAt; // ISO-8601

  factory VipCelebration.fromJson(Map<String, dynamic> json) => VipCelebration(
        newVipLevel: parseInt(json['newVipLevel'] ?? json['vipLevel'], 0),
        tierName: parseString(json['tierName'] ?? json['name']),
        tierColor: parseString(json['tierColor'] ?? json['color']),
        entranceAnimationUrl: parseString(json['entranceAnimationUrl'] ?? json['entrance']),
        levelBadgeUrl: parseString(json['levelBadgeUrl'] ?? json['badgeUrl']),
        profileFrameUrl: parseString(json['profileFrameUrl'] ?? json['frameUrl']),
        expiresAt: parseString(json['expiresAt'] ?? json['expiry']),
      );

  /// Parses the `celebration` object from a buyVip response map.
  /// Returns null if no celebration data is present.
  static VipCelebration? fromResponse(Map<String, dynamic>? response) {
    if (response == null) return null;
    final celeb = response['celebration'];
    if (celeb is Map) {
      return VipCelebration.fromJson(Map<String, dynamic>.from(celeb));
    }
    return null;
  }

  /// Returns the tier color as a [Color], falling back to [defaultColor].
  Color colorOrDefault(Color defaultColor) {
    if (tierColor == null || tierColor!.isEmpty) return defaultColor;
    var h = tierColor!.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    return v != null ? Color(v) : defaultColor;
  }
}

// ---- VIP Leaderboard --------------------------------------------------------

class VipLeaderboardRoot {
  VipLeaderboardRoot({this.status = false, this.message, this.data = const []});
  final bool status;
  final String? message;
  final List<VipLeaderboardItem> data;

  factory VipLeaderboardRoot.fromJson(Map<String, dynamic> json) =>
      VipLeaderboardRoot(
        status: parseBool(json['status'] ?? json['success']),
        message: parseString(json['message']),
        data: parseList(json['data'] ?? json['leaderboard'], VipLeaderboardItem.fromJson),
      );
}

class VipLeaderboardItem {
  VipLeaderboardItem({
    this.userId,
    this.name,
    this.image,
    this.vipLevel = 0,
    this.monthlyPoints = 0,
    this.totalPoints = 0,
    this.rank = 0,
  });

  final String? userId;
  final String? name;
  final String? image;
  final int vipLevel;
  final int monthlyPoints;
  final int totalPoints;
  final int rank;

  factory VipLeaderboardItem.fromJson(Map<String, dynamic> json) =>
      VipLeaderboardItem(
        userId: parseString(json['userId'] ?? json['_id']),
        name: parseString(json['name'] ?? json['userName']),
        image: parseString(json['image'] ?? json['userImage']),
        vipLevel: parseInt(json['vipLevel'] ?? json['currentLevel'], 0),
        monthlyPoints: parseInt(json['monthlyPoints'] ?? json['currentMonthEarnedPoints'], 0),
        totalPoints: parseInt(json['totalPoints'] ?? json['totalVipPoints'], 0),
        rank: parseInt(json['rank'], 0),
      );
}

// ---- Daily Bonus ------------------------------------------------------------

class VipDailyBonusRoot {
  VipDailyBonusRoot({this.status = false, this.message, this.data});
  final bool status;
  final String? message;
  final VipDailyBonus? data;

  factory VipDailyBonusRoot.fromJson(Map<String, dynamic> json) => VipDailyBonusRoot(
        status: parseBool(json['status'] ?? json['success']),
        message: parseString(json['message']),
        data: json['data'] is Map
            ? VipDailyBonus.fromJson(Map<String, dynamic>.from(json['data'] as Map))
            : null,
      );
}

class VipDailyBonus {
  VipDailyBonus({
    this.canClaim = false,
    this.todayClaimed = false,
    this.streak = 0,
    this.bonusPoints = 0,
    this.nextBonusPoints = 0,
    this.lastClaimDate,
    this.claimHistory = const [],
  });

  final bool canClaim;
  final bool todayClaimed;
  final int streak;
  final int bonusPoints;
  final int nextBonusPoints;
  final String? lastClaimDate;
  final List<VipDailyBonusHistory> claimHistory;

  factory VipDailyBonus.fromJson(Map<String, dynamic> json) => VipDailyBonus(
        canClaim: parseBool(json['canClaim']),
        todayClaimed: parseBool(json['todayClaimed'] ?? json['claimed']),
        streak: parseInt(json['streak'], 0),
        bonusPoints: parseInt(json['bonusPoints'] ?? json['points'], 0),
        nextBonusPoints: parseInt(json['nextBonusPoints'], 0),
        lastClaimDate: parseString(json['lastClaimDate']),
        claimHistory: parseList(json['claimHistory'] ?? json['history'], VipDailyBonusHistory.fromJson),
      );
}

class VipDailyBonusHistory {
  VipDailyBonusHistory({this.date, this.points = 0, this.streak = 0});
  final String? date;
  final int points;
  final int streak;

  factory VipDailyBonusHistory.fromJson(Map<String, dynamic> json) =>
      VipDailyBonusHistory(
        date: parseString(json['date'] ?? json['claimedAt']),
        points: parseInt(json['points'] ?? json['bonusPoints'], 0),
        streak: parseInt(json['streak'], 0),
      );
}

// ---- VIP Trial --------------------------------------------------------------

class VipTrialRoot {
  VipTrialRoot({this.status = false, this.message, this.data});
  final bool status;
  final String? message;
  final VipTrial? data;

  factory VipTrialRoot.fromJson(Map<String, dynamic> json) => VipTrialRoot(
        status: parseBool(json['status'] ?? json['success']),
        message: parseString(json['message']),
        data: json['data'] is Map
            ? VipTrial.fromJson(Map<String, dynamic>.from(json['data'] as Map))
            : null,
      );
}

class VipTrial {
  VipTrial({
    this.eligible = false,
    this.trialUsed = false,
    this.trialTierId,
    this.trialTierName,
    this.trialDurationHours = 24,
    this.trialExpiresAt,
    this.trialActive = false,
  });

  final bool eligible;
  final bool trialUsed;
  final String? trialTierId;
  final String? trialTierName;
  final int trialDurationHours;
  final String? trialExpiresAt;
  final bool trialActive;

  factory VipTrial.fromJson(Map<String, dynamic> json) => VipTrial(
        eligible: parseBool(json['eligible']),
        trialUsed: parseBool(json['trialUsed'] ?? json['used']),
        trialTierId: parseString(json['trialTierId'] ?? json['tierId']),
        trialTierName: parseString(json['trialTierName'] ?? json['tierName']),
        trialDurationHours: parseInt(json['trialDurationHours'] ?? json['durationHours'], 24),
        trialExpiresAt: parseString(json['trialExpiresAt'] ?? json['expiresAt']),
        trialActive: parseBool(json['trialActive'] ?? json['active']),
      );
}

// ---- Gifting Cashback -------------------------------------------------------

class VipCashbackRoot {
  VipCashbackRoot({this.status = false, this.message, this.data});
  final bool status;
  final String? message;
  final VipCashback? data;

  factory VipCashbackRoot.fromJson(Map<String, dynamic> json) => VipCashbackRoot(
        status: parseBool(json['status'] ?? json['success']),
        message: parseString(json['message']),
        data: json['data'] is Map
            ? VipCashback.fromJson(Map<String, dynamic>.from(json['data'] as Map))
            : null,
      );
}

class VipCashback {
  VipCashback({
    this.cashbackPercent = 0,
    this.cashbackType,
    this.monthlyCashbackEarned = 0,
    this.totalCashbackEarned = 0,
    this.maxMonthlyCashback = 0,
    this.enabled = false,
  });

  final int cashbackPercent;
  final String? cashbackType; // 'points' | 'coins'
  final int monthlyCashbackEarned;
  final int totalCashbackEarned;
  final int maxMonthlyCashback;
  final bool enabled;

  factory VipCashback.fromJson(Map<String, dynamic> json) => VipCashback(
        cashbackPercent: parseInt(json['cashbackPercent'] ?? json['percent'], 0),
        cashbackType: parseString(json['cashbackType'] ?? json['type']),
        monthlyCashbackEarned: parseInt(json['monthlyCashbackEarned'] ?? json['monthlyEarned'], 0),
        totalCashbackEarned: parseInt(json['totalCashbackEarned'] ?? json['totalEarned'], 0),
        maxMonthlyCashback: parseInt(json['maxMonthlyCashback'] ?? json['maxMonthly'], 0),
        enabled: parseBool(json['enabled']),
      );
}

// ---- Special ID Categories --------------------------------------------------

class SpecialIdConfigRoot {
  SpecialIdConfigRoot({this.status = false, this.message, this.categories = const [], this.suggestions = const []});
  final bool status;
  final String? message;
  final List<SpecialIdCategory> categories;
  final List<String> suggestions;

  factory SpecialIdConfigRoot.fromJson(Map<String, dynamic> json) =>
      SpecialIdConfigRoot(
        status: parseBool(json['status'] ?? json['success']),
        message: parseString(json['message']),
        categories: parseList(json['categories'], SpecialIdCategory.fromJson),
        suggestions: parseList(json['suggestions'] ?? json['popular'], (e) => parseString(e) ?? '')
            .where((s) => s.isNotEmpty)
            .toList(),
      );
}

class SpecialIdCategory {
  SpecialIdCategory({
    this.id,
    this.name,
    this.price = 0,
    this.minLength = 4,
    this.maxLength = 12,
    this.pattern,
    this.icon,
  });

  final String? id;
  final String? name;
  final int price;
  final int minLength;
  final int maxLength;
  final String? pattern;
  final String? icon;

  factory SpecialIdCategory.fromJson(Map<String, dynamic> json) => SpecialIdCategory(
        id: parseString(json['_id'] ?? json['id']),
        name: parseString(json['name']),
        price: parseInt(json['price'] ?? json['coin'], 0),
        minLength: parseInt(json['minLength'], 4),
        maxLength: parseInt(json['maxLength'], 12),
        pattern: parseString(json['pattern']),
        icon: parseString(json['icon']),
      );
}

// ---- Ban / Unban Account Info -----------------------------------------------

class BanInfoRoot {
  BanInfoRoot({this.status = false, this.message, this.data});
  final bool status;
  final String? message;
  final BanInfo? data;

  factory BanInfoRoot.fromJson(Map<String, dynamic> json) => BanInfoRoot(
        status: parseBool(json['status'] ?? json['success']),
        message: parseString(json['message']),
        data: json['data'] is Map
            ? BanInfo.fromJson(Map<String, dynamic>.from(json['data'] as Map))
            : null,
      );
}

class BanInfo {
  BanInfo({
    this.isBanned = false,
    this.banReason,
    this.bannedAt,
    this.banCount = 0,
    this.unbanUsed = 0,
    this.unbanLimit = 3,
    this.cooldownUntil,
    this.canUnban = false,
    this.requiredVipLevel = 7,
    this.banHistory = const [],
  });

  final bool isBanned;
  final String? banReason;
  final String? bannedAt;
  final int banCount;
  final int unbanUsed;
  final int unbanLimit;
  final String? cooldownUntil;
  final bool canUnban;
  final int requiredVipLevel;
  final List<BanHistoryItem> banHistory;

  factory BanInfo.fromJson(Map<String, dynamic> json) => BanInfo(
        isBanned: parseBool(json['isBanned'] ?? json['banned']),
        banReason: parseString(json['banReason'] ?? json['reason']),
        bannedAt: parseString(json['bannedAt'] ?? json['createdAt']),
        banCount: parseInt(json['banCount'], 0),
        unbanUsed: parseInt(json['unbanUsed'] ?? json['unbanCount'], 0),
        unbanLimit: parseInt(json['unbanLimit'] ?? json['limit'], 3),
        cooldownUntil: parseString(json['cooldownUntil']),
        canUnban: parseBool(json['canUnban']),
        requiredVipLevel: parseInt(json['requiredVipLevel'] ?? json['minVipLevel'], 7),
        banHistory: parseList(json['banHistory'] ?? json['history'], BanHistoryItem.fromJson),
      );
}

class BanHistoryItem {
  BanHistoryItem({this.action, this.reason, this.date, this.adminName});
  final String? action; // 'ban' | 'unban'
  final String? reason;
  final String? date;
  final String? adminName;

  factory BanHistoryItem.fromJson(Map<String, dynamic> json) => BanHistoryItem(
        action: parseString(json['action'] ?? json['type']),
        reason: parseString(json['reason']),
        date: parseString(json['date'] ?? json['createdAt']),
        adminName: parseString(json['adminName'] ?? json['admin']),
      );
}

// ---- Dynamic Avatar Gallery -------------------------------------------------

class DynamicAvatarRoot {
  DynamicAvatarRoot({this.status = false, this.message, this.avatars = const [], this.currentAvatarId});
  final bool status;
  final String? message;
  final List<DynamicAvatar> avatars;
  final String? currentAvatarId;

  factory DynamicAvatarRoot.fromJson(Map<String, dynamic> json) =>
      DynamicAvatarRoot(
        status: parseBool(json['status'] ?? json['success']),
        message: parseString(json['message']),
        avatars: parseList(json['avatars'] ?? json['data'], DynamicAvatar.fromJson),
        currentAvatarId: parseString(json['currentAvatarId'] ?? json['equipped']),
      );
}

class DynamicAvatar {
  DynamicAvatar({
    this.id,
    this.name,
    this.url,
    this.previewUrl,
    this.requiredVipLevel = 5,
    this.isGif = false,
  });

  final String? id;
  final String? name;
  final String? url;
  final String? previewUrl;
  final int requiredVipLevel;
  final bool isGif;

  factory DynamicAvatar.fromJson(Map<String, dynamic> json) => DynamicAvatar(
        id: parseString(json['_id'] ?? json['id']),
        name: parseString(json['name']),
        url: parseString(json['url'] ?? json['gifUrl']),
        previewUrl: parseString(json['previewUrl'] ?? json['thumbnail']),
        requiredVipLevel: parseInt(json['requiredVipLevel'] ?? json['minVipLevel'], 5),
        isGif: parseBool(json['isGif'] ?? json['gif']),
      );
}

// ---- VIP Theme Gallery ------------------------------------------------------

class VipThemeRoot {
  VipThemeRoot({this.status = false, this.message, this.themes = const [], this.currentThemeId});
  final bool status;
  final String? message;
  final List<VipTheme> themes;
  final String? currentThemeId;

  factory VipThemeRoot.fromJson(Map<String, dynamic> json) => VipThemeRoot(
        status: parseBool(json['status'] ?? json['success']),
        message: parseString(json['message']),
        themes: parseList(json['themes'] ?? json['data'], VipTheme.fromJson),
        currentThemeId: parseString(json['currentThemeId'] ?? json['equipped']),
      );
}

class VipTheme {
  VipTheme({
    this.id,
    this.name,
    this.previewUrl,
    this.chatBubbleUrl,
    this.profileBgUrl,
    this.roomCardUrl,
    this.requiredVipLevel = 3,
  });

  final String? id;
  final String? name;
  final String? previewUrl;
  final String? chatBubbleUrl;
  final String? profileBgUrl;
  final String? roomCardUrl;
  final int requiredVipLevel;

  factory VipTheme.fromJson(Map<String, dynamic> json) => VipTheme(
        id: parseString(json['_id'] ?? json['id']),
        name: parseString(json['name']),
        previewUrl: parseString(json['previewUrl'] ?? json['preview']),
        chatBubbleUrl: parseString(json['chatBubbleUrl']),
        profileBgUrl: parseString(json['profileBgUrl']),
        roomCardUrl: parseString(json['roomCardUrl']),
        requiredVipLevel: parseInt(json['requiredVipLevel'] ?? json['minVipLevel'], 3),
      );
}

// ---- Tier Comparison Matrix -------------------------------------------------

class VipTierComparisonRoot {
  VipTierComparisonRoot({this.status = false, this.message, this.matrix});
  final bool status;
  final String? message;
  final VipTierComparison? matrix;

  factory VipTierComparisonRoot.fromJson(Map<String, dynamic> json) =>
      VipTierComparisonRoot(
        status: parseBool(json['status'] ?? json['success']),
        message: parseString(json['message']),
        matrix: json['matrix'] is Map
            ? VipTierComparison.fromJson(Map<String, dynamic>.from(json['matrix'] as Map))
            : (json['data'] is Map
                ? VipTierComparison.fromJson(Map<String, dynamic>.from(json['data'] as Map))
                : null),
      );
}

class VipTierComparison {
  VipTierComparison({this.features = const [], this.tiers = const []});
  final List<VipComparisonFeature> features;
  final List<VipComparisonTier> tiers;

  factory VipTierComparison.fromJson(Map<String, dynamic> json) => VipTierComparison(
        features: parseList(json['features'], VipComparisonFeature.fromJson),
        tiers: parseList(json['tiers'], VipComparisonTier.fromJson),
      );
}

class VipComparisonFeature {
  VipComparisonFeature({this.name, this.key, this.icon});
  final String? name;
  final String? key;
  final String? icon;

  factory VipComparisonFeature.fromJson(Map<String, dynamic> json) =>
      VipComparisonFeature(
        name: parseString(json['name'] ?? json['label']),
        key: parseString(json['key']),
        icon: parseString(json['icon']),
      );
}

class VipComparisonTier {
  VipComparisonTier({this.level = 0, this.name, this.values = const {}});
  final int level;
  final String? name;
  final Map<String, bool> values;

  factory VipComparisonTier.fromJson(Map<String, dynamic> json) {
    final level = parseInt(json['level'], 0);
    final name = parseString(json['name']);
    final values = <String, bool>{};
    final v = json['values'] ?? json['features'];
    if (v is Map) {
      v.forEach((k, val) => values[k.toString()] = parseBool(val) == true);
    }
    return VipComparisonTier(level: level, name: name, values: values);
  }
}
