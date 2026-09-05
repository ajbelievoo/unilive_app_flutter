import 'json_annotation_helper.dart';

List<String> _parseStringList(dynamic v) {
  if (v is List) {
    return v.map((e) => parseString(e) ?? '').where((s) => s.isNotEmpty).toList();
  }
  return const [];
}

/// Ported from native `VipPlanRoot.java` + `VipTierRoot.java`.
class VipPlanRoot {
  VipPlanRoot({this.vipPlan = const [], this.message, this.status = false});

  final List<VipPlanItem> vipPlan;
  final String? message;
  final bool status;

  factory VipPlanRoot.fromJson(Map<String, dynamic> json) => VipPlanRoot(
        vipPlan: parseList(json['vipPlan'] ?? json['plan'], VipPlanItem.fromJson),
        message: parseString(json['message']),
        status: parseBool(json['status']),
      );
}

class VipPlanItem {
  VipPlanItem({
    this.id,
    this.name,
    this.rupee = 0,
    this.dollar = 0,
    this.productKey,
    this.validityType,
    this.validity = 0,
    this.tag,
    this.isAutoRenew = false,
    this.isTop = false,
    this.isDelete = false,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String? name;
  final int rupee;
  final int dollar;
  final String? productKey;
  final String? validityType; // day | month | year
  final int validity;
  final String? tag;
  final bool isAutoRenew;
  final bool isTop;
  final bool isDelete;
  final String? createdAt;
  final String? updatedAt;

  factory VipPlanItem.fromJson(Map<String, dynamic> json) => VipPlanItem(
        id: parseString(json['_id'] ?? json['id']),
        name: parseString(json['name']),
        rupee: parseInt(json['rupee'], 0),
        dollar: parseInt(json['dollar'], 0),
        productKey: parseString(json['productKey']),
        validityType: parseString(json['validityType']),
        validity: parseInt(json['validity'], 0),
        tag: parseString(json['tag']),
        isAutoRenew: parseBool(json['isAutoRenew']),
        isTop: parseBool(json['isTop']),
        isDelete: parseBool(json['isDelete']),
        createdAt: parseString(json['createdAt']),
        updatedAt: parseString(json['updatedAt']),
      );
}

class VipTierRoot {
  VipTierRoot({this.data = const [], this.message, this.status = false});

  final List<VipTier> data;
  final String? message;
  final bool status;

  factory VipTierRoot.fromJson(Map<String, dynamic> json) => VipTierRoot(
        data: parseList(json['data'] ?? json['vipTiers'] ?? json['tiers'], VipTier.fromJson),
        message: parseString(json['message']),
        status: parseBool(json['status'] ?? json['success']),
      );
}

class VipTier {
  VipTier({
    this.id,
    this.name,
    this.coinPrice = 0,
    this.price = 0,
    this.validityDays = 0,
    this.sortOrder = 0,
    this.tagUrl,
    this.profileFrameUrl,
    this.frameImage,
    this.levelBadgeUrl,
    this.badgeUrl,
    this.entranceAnimationUrl,
    this.entryEffectImage,
    this.nameColor,
    this.chatColor,
    this.nameUrl,
    this.chatBubbleUrl,
    this.roomCardUrl,
    this.backgroundImage,
    this.voiceWaveUrl,
    this.profileBackgroundUrl,
    this.profileBackgroundsUrl = const [],
    this.exclusiveThemeUrl,
    this.audioLivePremiumThemeUrl,
    this.durationValue = 0,
    this.durationType,
    this.privileges,
    this.features = const [],
    this.hiddenItems = const [],
  });

  final String? id;
  final String? name;
  final int coinPrice;
  final int price;
  final int validityDays;
  final int sortOrder;
  final String? tagUrl;
  final String? profileFrameUrl;
  final String? frameImage;
  final String? levelBadgeUrl;
  final String? badgeUrl;
  final String? entranceAnimationUrl;
  final String? entryEffectImage;
  final String? nameColor;
  final String? chatColor;
  final String? nameUrl;
  final String? chatBubbleUrl;
  final String? roomCardUrl;
  final String? backgroundImage;
  final String? voiceWaveUrl;
  final String? profileBackgroundUrl;
  final List<String> profileBackgroundsUrl;
  final String? exclusiveThemeUrl;
  final String? audioLivePremiumThemeUrl;
  final int durationValue;
  final String? durationType;
  final dynamic privileges;
  final List<VipFeature> features;
  final List<VipHiddenItem> hiddenItems;

  String? get effectiveProfileFrameUrl =>
      (profileFrameUrl != null && profileFrameUrl!.isNotEmpty) ? profileFrameUrl : frameImage;

  String? get effectiveLevelBadgeUrl =>
      (levelBadgeUrl != null && levelBadgeUrl!.isNotEmpty) ? levelBadgeUrl : badgeUrl;

  String? get effectiveEntranceAnimationUrl =>
      (entranceAnimationUrl != null && entranceAnimationUrl!.isNotEmpty) ? entranceAnimationUrl : entryEffectImage;

  String? get effectiveNameColor =>
      (nameColor != null && nameColor!.isNotEmpty) ? nameColor : chatColor;

  String? get effectiveChatColor =>
      (chatColor != null && chatColor!.isNotEmpty) ? chatColor : nameColor;

  String? get effectiveRoomCardUrl =>
      (roomCardUrl != null && roomCardUrl!.isNotEmpty) ? roomCardUrl : backgroundImage;

  String? get effectiveProfileBackgroundUrl {
    if (profileBackgroundUrl != null && profileBackgroundUrl!.isNotEmpty) {
      return profileBackgroundUrl;
    }
    if (profileBackgroundsUrl.isNotEmpty) return profileBackgroundsUrl.first;
    return null;
  }

  int get effectiveValidityDays {
    if (validityDays > 0) return validityDays;
    return 30;
  }

  int get effectiveDurationValue {
    if (durationValue > 0) return durationValue;
    return effectiveValidityDays;
  }

  String get effectiveDurationType {
    if (durationType != null && durationType!.isNotEmpty) return durationType!;
    return 'months';
  }

  int get effectiveCoinPrice => coinPrice > 0 ? coinPrice : price;

  Map<String, bool> getPrivilegeFlags() {
    final flags = <String, bool>{};
    if (privileges == null) return flags;

    if (privileges is Map<String, dynamic>) {
      const flagKeys = [
        'isBadgeAndFrameEnabled',
        'isColoredChatEnabled',
        'isSpecialRoomEntranceAnimationEnabled',
        'isPremiumEmojiAndStickersEnabled',
        'isAntiKickEnabled',
        'isAntiMuteEnabled',
        'isDedicatedSupportEnabled',
        'isHigherProfileVisibilityEnabled',
        'isHigherPositionInViewerListsEnabled',
        'isExclusiveProfileThemesAndBackgroundsEnabled',
        'isNameAnimationEnabled',
        'isViewVisitorRecordsEnabled',
        'isRoomOnlineListTopEnabled',
        'isSendRoomPicturesEnabled',
        'isProfileBackgroundEnabled',
        'isLudoDiceSkinEnabled',
        'isLudoDiceRefreshEnabled',
        'isSendMessagePicturesEnabled',
        'isSvipGiftsEnabled',
        'isMultipleProfileBackgroundsEnabled',
        'isGoldenNameEnabled',
        'isExpBoostEnabled',
        'isHideVisitRecordsEnabled',
        'isCustomizedThemeEnabled',
        'isPremiumThemeEnabled',
      ];
      for (final key in flagKeys) {
        if (privileges.containsKey(key)) {
          flags[key] = privileges[key] == true;
        }
      }
      return flags;
    }

    if (privileges is List) {
      for (final e in privileges as List) {
        if (e is Map<String, dynamic>) {
          final name = (e['name'] as String?) ?? '';
          final lower = name.toLowerCase();
          if (lower.contains('visitor') || lower.contains('visit record')) {
            flags['isViewVisitorRecordsEnabled'] = true;
          }
          if (lower.contains('top') || lower.contains('position')) {
            flags['isRoomOnlineListTopEnabled'] = true;
          }
          if (lower.contains('picture') || lower.contains('image') || lower.contains('photo')) {
            flags['isSendRoomPicturesEnabled'] = true;
            flags['isSendMessagePicturesEnabled'] = true;
          }
          if (lower.contains('profile') || lower.contains('background')) {
            flags['isProfileBackgroundEnabled'] = true;
          }
          if (lower.contains('dice') || lower.contains('ludo')) {
            flags['isLudoDiceSkinEnabled'] = true;
            flags['isLudoDiceRefreshEnabled'] = true;
          }
          if (lower.contains('emoji') || lower.contains('sticker')) {
            flags['isPremiumEmojiAndStickersEnabled'] = true;
          }
          if (lower.contains('gift')) {
            flags['isSvipGiftsEnabled'] = true;
          }
          if (lower.contains('golden') || lower.contains('gold name')) {
            flags['isGoldenNameEnabled'] = true;
          }
          if (lower.contains('exp') || lower.contains('speed') || lower.contains('boost')) {
            flags['isExpBoostEnabled'] = true;
          }
          if (lower.contains('hide')) {
            flags['isHideVisitRecordsEnabled'] = true;
          }
          if (lower.contains('theme') || lower.contains('custom')) {
            flags['isCustomizedThemeEnabled'] = true;
          }
          if (lower.contains('premium theme') || lower.contains('audio live theme')) {
            flags['isPremiumThemeEnabled'] = true;
          }
          if (lower.contains('badge') || lower.contains('frame')) {
            flags['isBadgeAndFrameEnabled'] = true;
          }
          if (lower.contains('chat') || lower.contains('color')) {
            flags['isColoredChatEnabled'] = true;
          }
          if (lower.contains('entrance') || lower.contains('entry')) {
            flags['isSpecialRoomEntranceAnimationEnabled'] = true;
          }
        }
      }
    }

    return flags;
  }

  factory VipTier.fromJson(Map<String, dynamic> json) => VipTier(
        id: parseString(json['_id'] ?? json['id']),
        name: parseString(json['name']),
        coinPrice: parseInt(json['coinPrice'] ?? json['price'], 0),
        price: parseInt(json['price'], 0),
        validityDays: parseInt(json['validityDays'] ?? json['validity'], 0),
        sortOrder: parseInt(json['sortOrder'], 0),
        tagUrl: parseString(json['tagUrl'] ?? json['iconUrl'] ?? json['vipTagUrl']),
        profileFrameUrl: parseString(json['profileFrameUrl']),
        frameImage: parseString(json['frameImage']),
        levelBadgeUrl: parseString(json['levelBadgeUrl']),
        badgeUrl: parseString(json['badgeUrl']),
        entranceAnimationUrl: parseString(json['entranceAnimationUrl']),
        entryEffectImage: parseString(json['entryEffectImage']),
        nameColor: parseString(json['nameColor']),
        chatColor: parseString(json['chatColor']),
        nameUrl: parseString(json['nameUrl']),
        chatBubbleUrl: parseString(json['chatBubbleUrl']),
        roomCardUrl: parseString(json['roomCardUrl'] ?? json['profileCardUrl']),
        backgroundImage: parseString(json['backgroundImage']),
        voiceWaveUrl: parseString(json['voiceWaveUrl']),
        profileBackgroundUrl: parseString(json['profileBackgroundUrl']),
        profileBackgroundsUrl: _parseStringList(json['profileBackgroundsUrl']),
        exclusiveThemeUrl: parseString(json['exclusiveThemeUrl']),
        audioLivePremiumThemeUrl: parseString(json['audioLivePremiumThemeUrl']),
        durationValue: parseInt(json['durationValue'], 0),
        durationType: parseString(json['durationType']),
        privileges: json['privileges'],
        features: parseList(json['features'], VipFeature.fromJson),
        hiddenItems: parseList(json['hiddenItems'], VipHiddenItem.fromJson),
      );
}

class VipFeature {
  VipFeature({
    this.key,
    this.title,
    this.description,
    this.previewImages = const [],
  });

  final String? key;
  final String? title;
  final String? description;
  final List<String> previewImages;

  factory VipFeature.fromJson(Map<String, dynamic> json) => VipFeature(
        key: parseString(json['key']),
        title: parseString(json['title']),
        description: parseString(json['description']),
        previewImages: _parseStringList(json['previewImages']),
      );
}

class VipHiddenItem {
  VipHiddenItem({
    this.name,
    this.description,
    this.iconUrl,
    this.url,
    this.type,
    this.requiredLevel = 0,
    this.active = false,
  });

  final String? name;
  final String? description;
  final String? iconUrl;
  final String? url;
  final String? type;
  final int requiredLevel;
  final bool active;

  factory VipHiddenItem.fromJson(Map<String, dynamic> json) => VipHiddenItem(
        name: parseString(json['name']),
        description: parseString(json['description']),
        iconUrl: parseString(json['iconUrl']),
        url: parseString(json['url']),
        type: parseString(json['type']),
        requiredLevel: parseInt(json['requiredLevel'] ?? json['unlockLevel'] ?? json['level'], 0),
        active: parseBool(json['active']),
      );
}
