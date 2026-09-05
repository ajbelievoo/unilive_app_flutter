/// Service that loads and shows Google AdMob **Rewarded Ads** and
/// **Rewarded Interstitial Ads**.
///
/// Wraps the native ad flow:
/// 1. `MobileAds.initialize()` — called once on app start.
/// 2. `load()` — pre-loads either a `RewardedAd` or a `RewardedInterstitialAd`
///    using the ad-unit ID from the backend ad config.
/// 3. `show()` — displays the full-screen ad. The `onEarned` callback fires
///    only after the user earns the reward.
///
/// Usage:
/// ```dart
/// await RewardedAdService.instance.initialize();
/// await RewardedAdService.instance.load(
///   adUnitId: config.rewardedAdUnit,
///   adType: AdSourceType.google,
/// );
/// RewardedAdService.instance.show(
///   onEarned: () => api.claimAdReward(...),
///   onDismissed: () => preloadNext(),
/// );
/// ```
library rewarded_ad_service;

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../models/ad_reward_models.dart';
import '../utils/log.dart';

const String _tag = 'RewardedAdService';

/// Google AdMob test rewarded-ad unit ID.
const String _testRewardedAdUnitId =
    'ca-app-pub-3940256099942544/5224354917';

/// Google AdMob test rewarded interstitial ad unit ID.
const String _testRewardedInterstitialAdUnitId =
    'ca-app-pub-3940256099942544/5354046379';

/// Callback type fired when the user earns the reward (watches the ad to the end).
typedef OnAdEarned = void Function();

/// Callback type fired when the ad is dismissed (either after earning or by skipping).
typedef OnAdDismissed = void Function();

/// Callback type fired when the ad fails to show.
typedef OnAdError = void Function(String message);

/// Singleton-ish service that wraps `google_mobile_ads` rewarded and rewarded
/// interstitial ads.
///
/// Call [initialize] once at app startup (e.g. in `main.dart`).
/// Call [load] to pre-load an ad, then [show] to display it.
class RewardedAdService {
  RewardedAdService._();
  static final RewardedAdService instance = RewardedAdService._();

  /// The currently loaded ad — either [RewardedAd] or [RewardedInterstitialAd].
  Object? _ad;
  AdSourceType? _adType;
  bool _loading = false;
  bool _initialized = false;

  /// Whether an ad is loaded and ready to show.
  bool get isReady => _ad != null;

  /// The type of the currently loaded ad (`google` or `interstitial`).
  AdSourceType? get loadedAdType => _adType;

  /// Initialize the Google Mobile Ads SDK. Call once at app startup.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await MobileAds.instance.initialize();
      Log.i(_tag, 'MobileAds initialized');
    } catch (e, s) {
      Log.e(_tag, 'MobileAds initialize failed', e, s);
    }
  }

  /// Pre-load an ad.
  ///
  /// [adUnitId] should come from the backend ad config. If null/empty, a
  /// Google test ad unit is used for the requested [adType].
  /// [adType] must be [AdSourceType.google] or [AdSourceType.interstitial].
  Future<void> load({
    String? adUnitId,
    required AdSourceType adType,
  }) async {
    if (_loading || _ad != null) return;
    if (adType == AdSourceType.inhouse) {
      Log.e(_tag, 'load: inhouse ads must use InHouseAdPlayer');
      return;
    }
    _loading = true;
    _ad = null;
    _adType = null;

    final fallbackId = adType == AdSourceType.interstitial
        ? _testRewardedInterstitialAdUnitId
        : _testRewardedAdUnitId;
    final unitId =
        (adUnitId != null && adUnitId.isNotEmpty) ? adUnitId : fallbackId;

    Log.d(_tag, 'load: adType=${adSourceTypeName(adType)}, adUnitId=$unitId');

    if (adType == AdSourceType.interstitial) {
      await RewardedInterstitialAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _ad = ad;
            _adType = AdSourceType.interstitial;
            _loading = false;
            Log.i(_tag, 'RewardedInterstitialAd loaded');
          },
          onAdFailedToLoad: (err) {
            _ad = null;
            _adType = null;
            _loading = false;
            Log.e(_tag, 'RewardedInterstitialAd load failed: ${err.message}',
                null, null);
          },
        ),
      );
    } else {
      await RewardedAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _ad = ad;
            _adType = AdSourceType.google;
            _loading = false;
            Log.i(_tag, 'RewardedAd loaded');
          },
          onAdFailedToLoad: (err) {
            _ad = null;
            _adType = null;
            _loading = false;
            Log.e(_tag, 'RewardedAd load failed: ${err.message}', null, null);
          },
        ),
      );
    }
  }

  /// Show the loaded ad full-screen.
  ///
  /// [onEarned] is called when the user earns the reward (watches to completion).
  /// [onDismissed] is called when the ad is closed (after earning or skipping).
  /// [onError] is called if the ad can't be shown (e.g. not loaded yet).
  ///
  /// After the ad is dismissed, the internal reference is cleared so [load]
  /// must be called again before the next [show].
  void show({
    required OnAdEarned onEarned,
    required OnAdDismissed onDismissed,
    OnAdError? onError,
  }) {
    final ad = _ad;
    if (ad == null) {
      Log.w(_tag, 'show: no ad loaded');
      onError?.call('Ad not loaded yet');
      onDismissed();
      return;
    }

    if (ad is RewardedAd) {
      ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
        onAdShowedFullScreenContent: (ad) {
          Log.d(_tag, 'onAdShowedFullScreenContent');
        },
        onAdDismissedFullScreenContent: (ad) {
          Log.d(_tag, 'onAdDismissedFullScreenContent');
          _clearAd();
          onDismissed();
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          Log.e(_tag, 'onAdFailedToShow: ${err.message}', null, null);
          _clearAd();
          onError?.call(err.message);
          onDismissed();
        },
      );
      ad.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          Log.i(_tag, 'onUserEarnedReward: ${reward.amount} ${reward.type}');
          onEarned();
        },
      );
    } else if (ad is RewardedInterstitialAd) {
      ad.fullScreenContentCallback =
          FullScreenContentCallback<RewardedInterstitialAd>(
        onAdShowedFullScreenContent: (ad) {
          Log.d(_tag, 'onAdShowedFullScreenContent (interstitial)');
        },
        onAdDismissedFullScreenContent: (ad) {
          Log.d(_tag, 'onAdDismissedFullScreenContent (interstitial)');
          _clearAd();
          onDismissed();
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          Log.e(_tag, 'onAdFailedToShow (interstitial): ${err.message}',
              null, null);
          _clearAd();
          onError?.call(err.message);
          onDismissed();
        },
      );
      ad.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          Log.i(_tag,
              'onUserEarnedReward (interstitial): ${reward.amount} ${reward.type}');
          onEarned();
        },
      );
    } else {
      Log.e(_tag, 'show: unknown ad type: ${ad.runtimeType}', null, null);
      onError?.call('Unknown ad type');
      _clearAd();
      onDismissed();
    }
  }

  /// Dispose the current ad if any. Call when the host screen is disposed.
  void dispose() {
    _clearAd();
  }

  void _clearAd() {
    final ad = _ad;
    if (ad is Ad) {
      ad.dispose();
    }
    _ad = null;
    _adType = null;
    _loading = false;
  }
}
