import 'json_annotation_helper.dart';

/// Free-Diamonds ad reward system — models for the dynamic ad engine that
/// mixes **Google AdMob rewarded ads** with **admin-created in-house ads**.
///
/// See `docs/FREE_DIAMONDS_ADS_BACKEND_API.md` for the full backend contract.
///
/// Anti-fraud: every ad watch starts with a server-issued [AdWatchSession]
/// token. The reward is only credited on `claimAdReward` after the backend
/// verifies the elapsed watch duration >= the ad's required duration. Tokens
/// are single-use and short-lived. Daily/per-ad limits are enforced
/// server-side.

/// Status of a single ad watch attempt.
enum AdWatchStatus { earned, failed, skipped, pending }

/// Type of ad source.
///
/// - `google` — standard Google AdMob rewarded ad.
/// - `interstitial` — Google AdMob rewarded interstitial ad.
/// - `inhouse` — admin-created in-house ad.
enum AdSourceType { google, interstitial, inhouse }

AdSourceType _adSourceType(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'google':
    case 'admob':
      return AdSourceType.google;
    case 'interstitial':
      return AdSourceType.interstitial;
    case 'inhouse':
    default:
      return AdSourceType.inhouse;
  }
}

String adSourceTypeName(AdSourceType t) {
  switch (t) {
    case AdSourceType.google:
      return 'google';
    case AdSourceType.interstitial:
      return 'interstitial';
    case AdSourceType.inhouse:
      return 'inhouse';
  }
}

AdWatchStatus _adWatchStatus(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'earned':
    case 'success':
    case 'completed':
      return AdWatchStatus.earned;
    case 'failed':
    case 'error':
      return AdWatchStatus.failed;
    case 'skipped':
    case 'skip':
      return AdWatchStatus.skipped;
    default:
      return AdWatchStatus.pending;
  }
}

/// Admin-created in-house ad shown in the Free Diamonds screen.
///
/// The admin sets: the media (image/video URL), a clickable target link, the
/// reward in diamonds, the required watch duration, and a per-day limit
/// (0 = unlimited). The reward may be 0 (branding/traffic ad) or any positive
/// amount — independent of the Google ad reward.
class InHouseAd {
  InHouseAd({
    this.id,
    this.title,
    this.description,
    this.mediaUrl,
    this.mediaType = 'image',
    this.thumbnailUrl,
    this.targetUrl,
    this.rewardCoins = 0,
    this.durationSec = 0,
    this.dailyLimit = 0,
    this.watchesToday = 0,
    this.isActive = true,
    this.sortOrder = 0,
    this.createdAt,
  });

  final String? id;
  final String? title;
  final String? description;
  final String? mediaUrl;
  /// `image` or `video`.
  final String mediaType;
  final String? thumbnailUrl;
  /// Clickable link — opens in an in-app browser when the user taps the ad.
  final String? targetUrl;
  final int rewardCoins;
  /// Required watch duration in seconds before the reward can be claimed.
  final int durationSec;
  /// Max watches per day. `0` means unlimited.
  final int dailyLimit;
  /// How many times this ad has been watched today (backend may include).
  final int watchesToday;
  final bool isActive;
  final int sortOrder;
  final String? createdAt;

  bool get isVideo => mediaType.toLowerCase() == 'video';
  bool get isUnlimited => dailyLimit <= 0;
  bool get hasLink => targetUrl != null && targetUrl!.isNotEmpty;
  bool get isDailyLimitReached =>
      dailyLimit > 0 && watchesToday >= dailyLimit;

  factory InHouseAd.fromJson(Map<String, dynamic> json) => InHouseAd(
        id: parseString(json['_id'] ?? json['id']),
        title: parseString(json['title']),
        description: parseString(json['description']),
        mediaUrl: parseString(json['mediaUrl'] ?? json['image'] ?? json['videoUrl']),
        mediaType: parseString(json['mediaType'] ?? json['type'], 'image') ?? 'image',
        thumbnailUrl: parseString(json['thumbnailUrl'] ?? json['thumbnail']),
        targetUrl: parseString(json['targetUrl'] ?? json['link'] ?? json['url']),
        rewardCoins: parseInt(json['rewardCoins'] ?? json['reward'] ?? json['coin'], 0),
        durationSec: parseInt(json['durationSec'] ?? json['duration'], 0),
        dailyLimit: parseInt(json['dailyLimit'] ?? json['limit'], 0),
        watchesToday: parseInt(json['watchesToday'] ?? json['watchedToday'], 0),
        isActive: parseBool(json['isActive'] ?? json['active'], true),
        sortOrder: parseInt(json['sortOrder'] ?? json['order'], 0),
        createdAt: parseString(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'title': title,
        'description': description,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'thumbnailUrl': thumbnailUrl,
        'targetUrl': targetUrl,
        'rewardCoins': rewardCoins,
        'durationSec': durationSec,
        'dailyLimit': dailyLimit,
        'watchesToday': watchesToday,
        'isActive': isActive,
        'sortOrder': sortOrder,
      };
}

/// Runtime config for the Free Diamonds ad engine.
class AdRewardConfig {
  AdRewardConfig({
    this.status = false,
    this.googleAdReward = 0,
    this.googleAdDailyLimit = 5,
    this.interstitialAdReward = 0,
    this.interstitialAdDailyLimit = 5,
    this.inHouseAdDailyLimit = 0,
    this.adsWatchedToday = 0,
    this.googleAdsWatchedToday = 0,
    this.interstitialAdsWatchedToday = 0,
    this.totalEarnedToday = 0,
    this.googleToInHouseAdRatio = 5,
    this.nextAdType = 'google',
    this.adsUntilInHouse = 5,
    this.adMobAppId,
    this.rewardedAdUnit,
    this.rewardedInterstitialAdUnit,
    this.interstitialAdUnit,
    this.inHouseAds = const [],
    this.message,
  });

  final bool status;
  /// Diamonds rewarded per Google AdMob rewarded ad watch.
  final int googleAdReward;
  /// Max standard rewarded ad watches per day.
  final int googleAdDailyLimit;
  /// Diamonds rewarded per Google AdMob rewarded interstitial ad watch.
  final int interstitialAdReward;
  /// Max rewarded interstitial ad watches per day.
  final int interstitialAdDailyLimit;
  /// Max in-house ad watches per day (across all in-house ads). 0 = unlimited.
  final int inHouseAdDailyLimit;
  final int adsWatchedToday;
  final int googleAdsWatchedToday;
  final int interstitialAdsWatchedToday;
  final int totalEarnedToday;
  /// How many Google ads are shown before an in-house ad is forced.
  final int googleToInHouseAdRatio;
  /// `google` or `inhouse` — what the backend expects next.
  final String nextAdType;
  /// How many more Google ads until the next in-house ad is forced.
  final int adsUntilInHouse;
  /// AdMob app ID (build-time reference only; not set at runtime).
  final String? adMobAppId;
  /// AdMob rewarded ad unit ID.
  final String? rewardedAdUnit;
  /// AdMob rewarded interstitial ad unit ID.
  final String? rewardedInterstitialAdUnit;
  /// Legacy interstitial ad unit ID (kept for backward compatibility).
  final String? interstitialAdUnit;
  final List<InHouseAd> inHouseAds;
  final String? message;

  bool get googleLimitReached =>
      googleAdDailyLimit > 0 && googleAdsWatchedToday >= googleAdDailyLimit;

  bool get interstitialLimitReached =>
      interstitialAdDailyLimit > 0 &&
      interstitialAdsWatchedToday >= interstitialAdDailyLimit;

  bool get allGoogleLimitsReached =>
      googleLimitReached &&
      (interstitialLimitReached ||
          (rewardedInterstitialAdUnit?.isEmpty ?? true));

  /// Total Google ad watches today (rewarded + interstitial).
  int get totalGoogleAdsWatchedToday =>
      googleAdsWatchedToday + interstitialAdsWatchedToday;

  factory AdRewardConfig.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return AdRewardConfig(
      status: parseBool(json['status'] ?? data['status']),
      message: parseString(json['message'] ?? data['message']),
      googleAdReward: parseInt(
        data['googleAdReward'] ?? data['adReward'] ?? data['rewardPerAd'],
        0,
      ),
      googleAdDailyLimit: parseInt(
        data['googleAdDailyLimit'] ?? data['maxAdPerDay'] ?? data['dailyLimit'],
        5,
      ),
      interstitialAdReward: parseInt(data['interstitialAdReward'], 0),
      interstitialAdDailyLimit: parseInt(
        data['interstitialAdDailyLimit'] ?? data['interstitialAdLimit'],
        5,
      ),
      inHouseAdDailyLimit: parseInt(data['inHouseAdDailyLimit'], 0),
      adsWatchedToday: parseInt(data['adsWatchedToday'] ?? data['watchedToday'], 0),
      googleAdsWatchedToday: parseInt(data['googleAdsWatchedToday'], 0),
      interstitialAdsWatchedToday:
          parseInt(data['interstitialAdsWatchedToday'] ?? data['interstitialWatchedToday'], 0),
      totalEarnedToday: parseInt(data['totalEarnedToday'] ?? data['earnedToday'], 0),
      googleToInHouseAdRatio: parseInt(data['googleToInHouseAdRatio'] ?? data['adRatio'], 5),
      nextAdType: parseString(data['nextAdType'] ?? data['nextType'], 'google') ?? 'google',
      adsUntilInHouse: parseInt(data['adsUntilInHouse'] ?? data['untilInHouse'], 5),
      adMobAppId: parseString(data['adMobAppId']),
      rewardedAdUnit: parseString(data['rewardedAdUnit'] ?? data['rewardAdUnit']),
      rewardedInterstitialAdUnit: parseString(
          data['rewardedInterstitialAdUnit'] ?? data['rewardInterstitialAdUnit']),
      interstitialAdUnit: parseString(data['interstitialAdUnit'] ?? data['interstitialUnit']),
      inHouseAds: parseList(data['inHouseAds'] ?? data['ads'], InHouseAd.fromJson),
    );
  }
}

/// Server-issued ad-watch session — proof that a watch started on the server.
///
/// The client must present this token (and the elapsed duration) when claiming
/// the reward. The backend validates: token not expired, token not already
/// claimed, elapsed >= required duration, daily limits not exceeded.
class AdWatchSession {
  AdWatchSession({
    this.status = false,
    this.watchToken,
    this.expiresAt,
    this.adType = AdSourceType.google,
    this.adId,
    this.rewardCoins = 0,
    this.requiredDurationSec = 0,
    this.nextAdType,
    this.recommendedAdId,
    this.message,
  });

  final bool status;
  final String? watchToken;
  final String? expiresAt;
  final AdSourceType adType;
  final String? adId;
  final int rewardCoins;
  final int requiredDurationSec;
  /// When the backend rejects a Google ad start because an in-house ad is due,
  /// it returns the expected next ad type here.
  final String? nextAdType;
  /// When an in-house ad is due, the backend may recommend a specific ad ID.
  final String? recommendedAdId;
  final String? message;

  factory AdWatchSession.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final parsedAdType = _adSourceType(data['adType']?.toString() ?? data['type']?.toString());
    final parsedNextAdType = data.containsKey('nextAdType')
        ? parseString(data['nextAdType'])
        : null;
    return AdWatchSession(
      status: parseBool(json['status'] ?? data['status']),
      message: parseString(json['message'] ?? data['message']),
      watchToken: parseString(data['watchToken'] ?? data['token'] ?? data['sessionId']),
      expiresAt: parseString(data['expiresAt'] ?? data['expiry']),
      adType: parsedAdType,
      adId: parseString(data['adId'] ?? data['id']),
      rewardCoins: parseInt(data['rewardCoins'] ?? data['reward'], 0),
      requiredDurationSec: parseInt(data['requiredDurationSec'] ?? data['durationSec'], 0),
      nextAdType: parsedNextAdType,
      recommendedAdId: parsedNextAdType != null
          ? parseString(data['recommendedAdId'] ?? data['adId'])
          : null,
    );
  }
}

/// Result of claiming an ad reward.
class AdClaimResult {
  AdClaimResult({
    this.status = false,
    this.message,
    this.reward = 0,
    this.totalEarnedToday = 0,
    this.adsWatchedToday = 0,
    this.googleAdsWatchedToday = 0,
    this.interstitialAdsWatchedToday = 0,
    this.balance = 0,
    this.nextAdType,
    this.adsUntilInHouse,
  });

  final bool status;
  final String? message;
  /// Diamonds credited for this watch (0 if rejected).
  final int reward;
  final int totalEarnedToday;
  final int adsWatchedToday;
  final int googleAdsWatchedToday;
  final int interstitialAdsWatchedToday;
  final int balance;
  /// Backend may hint what the next ad type should be.
  final String? nextAdType;
  /// Backend may return the updated in-house countdown.
  final int? adsUntilInHouse;

  factory AdClaimResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return AdClaimResult(
      status: parseBool(json['status'] ?? data['status']),
      message: parseString(json['message'] ?? data['message']),
      reward: parseInt(data['reward'] ?? data['rewardCoins'] ?? data['coin'], 0),
      totalEarnedToday: parseInt(data['totalEarnedToday'] ?? data['earnedToday'], 0),
      adsWatchedToday: parseInt(data['adsWatchedToday'] ?? data['watchedToday'], 0),
      googleAdsWatchedToday: parseInt(data['googleAdsWatchedToday'], 0),
      interstitialAdsWatchedToday:
          parseInt(data['interstitialAdsWatchedToday'] ?? data['interstitialWatchedToday'], 0),
      balance: parseInt(data['balance'] ?? data['coin'] ?? data['coinBalance'], 0),
      nextAdType: parseString(data['nextAdType']),
      adsUntilInHouse: parseIntOrNull(data['adsUntilInHouse'] ?? data['untilInHouse']),
    );
  }
}

/// A single ad-watch history entry.
class AdWatchHistoryItem {
  AdWatchHistoryItem({
    this.id,
    this.adType = AdSourceType.google,
    this.adId,
    this.adTitle,
    this.reward = 0,
    this.status = AdWatchStatus.pending,
    this.durationSec = 0,
    this.watchedAt,
    this.reason,
  });

  final String? id;
  final AdSourceType adType;
  final String? adId;
  final String? adTitle;
  final int reward;
  final AdWatchStatus status;
  final int durationSec;
  final String? watchedAt;
  /// Failure reason (when status == failed).
  final String? reason;

  factory AdWatchHistoryItem.fromJson(Map<String, dynamic> json) =>
      AdWatchHistoryItem(
        id: parseString(json['_id'] ?? json['id']),
        adType: _adSourceType(json['adType']?.toString() ?? json['type']?.toString()),
        adId: parseString(json['adId']),
        adTitle: parseString(json['adTitle'] ?? json['title']),
        reward: parseInt(json['reward'] ?? json['rewardCoins'] ?? json['coin'], 0),
        status: _adWatchStatus(json['status']?.toString()),
        durationSec: parseInt(json['durationSec'] ?? json['duration'], 0),
        watchedAt: parseString(json['watchedAt'] ?? json['createdAt']),
        reason: parseString(json['reason'] ?? json['failureReason']),
      );
}

/// Ad-watch history list + aggregate totals.
class AdWatchHistoryRoot {
  AdWatchHistoryRoot({
    this.status = false,
    this.history = const [],
    this.totalWatched = 0,
    this.totalEarned = 0,
    this.totalFailed = 0,
    this.total = 0,
  });

  final bool status;
  final List<AdWatchHistoryItem> history;
  final int totalWatched;
  final int totalEarned;
  final int totalFailed;
  final int total;

  factory AdWatchHistoryRoot.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return AdWatchHistoryRoot(
      status: parseBool(json['status'] ?? data['status']),
      history: parseList(data['history'] ?? data['ads'], AdWatchHistoryItem.fromJson),
      totalWatched: parseInt(data['totalWatched'] ?? data['watched'], 0),
      totalEarned: parseInt(data['totalEarned'] ?? data['earned'], 0),
      totalFailed: parseInt(data['totalFailed'] ?? data['failed'], 0),
      total: parseInt(data['total'] ?? json['total'], 0),
    );
  }
}
