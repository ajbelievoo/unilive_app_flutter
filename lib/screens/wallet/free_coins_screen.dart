/// Free Diamonds screen — watch-ad rewards + referral code redemption.
///
/// Ports native `FreeDimondsActivity.java` + `activity_free_dimonds.xml`:
/// - Dark gradient hero card with diamond balance.
/// - "How It Works" 3-step guide.
/// - Method 1 card: Watch the next available ad (Google rewarded,
///   Google rewarded interstitial, or admin-created in-house ad) → earn diamonds.
/// - Method 2 card: Refer & Earn — share code/link, redeem a friend's code.
/// - Referral stats row.
/// - "Why Earn With Us?" feature highlights.
/// - "Good to Know" terms section.
/// - Footer.
///
/// The ad engine is fully dynamic:
///   1. `GET /api/v1/ads/config` returns the next ad type, remaining Google
///      ads until an in-house ad, daily limits, and the ad unit IDs.
///   2. `POST /api/v1/ads/start` issues a `watchToken`.
///   3. The appropriate ad is shown (AdMob rewarded / rewarded interstitial,
///      or the in-house player). Google ads claim with `durationSec: 0`.
///   4. `POST /api/v1/ads/claim` credits the reward.
library free_coins;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/const.dart';
import '../../models/ad_reward_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../services/rewarded_ad_service.dart';
import '../../utils/format_utils.dart';
import '../../utils/log.dart';
import '../../widgets/currency_icon.dart';
import '../../widgets/in_house_ad_player.dart';
import 'package:belive/widgets/preloader.dart';

const String _tag = 'FreeCoins';

// ---- Colours matching the native dark theme ----------------------------------
const Color _bg = Color(0xFF0A0A1A);
const Color _cardBg = Color(0xFF15151F);
const Color _cardBg2 = Color(0xFF1A1A2E);
const Color _divider = Color(0xFF2A2A40);
const Color _textWhite = Colors.white;
const Color _textLavender = Color(0xFFB0B0D0);
const Color _textMuted = Color(0xFF8A8AA8);
const Color _gold = Color(0xFFFFD700);
const Color _goldDark = Color(0xFFFFB300);
const Color _purple = Color(0xFF6A4CFE);

class FreeCoinsScreen extends StatefulWidget {
  const FreeCoinsScreen({super.key});

  @override
  State<FreeCoinsScreen> createState() => _FreeCoinsScreenState();
}

/// Immutable plan for a single ad attempt used by the fallback chain.
class _AdPlan {
  const _AdPlan.google(this.googleType)
      : inHouseAd = null,
        isInHouse = false;
  const _AdPlan.inhouse(this.inHouseAd)
      : googleType = null,
        isInHouse = true;

  final bool isInHouse;
  final AdSourceType? googleType;
  final InHouseAd? inHouseAd;
}

class _FreeCoinsScreenState extends State<FreeCoinsScreen> {
  bool _claiming = false;
  bool _loadingAd = false;
  int _adWatched = 0;
  int _maxAd = 5;
  int _referralBonus = 200;
  int _googleAdReward = 50;
  int _interstitialAdReward = 50;
  String? _rewardAdUnitId;
  final TextEditingController _referralCtrl = TextEditingController();

  // ---- Dynamic ad engine state ---------------------------------------------
  AdRewardConfig? _adConfig;
  AdWatchHistoryRoot? _adHistory;
  bool _loadingHistory = false;
  AdSourceType? _lastGoogleAdType;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _referralCtrl.dispose();
    RewardedAdService.instance.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final session = context.read<SessionManager>();
      final setting = session.getSetting();
      final user = session.getUser();
      final adUnitId = setting?.advertisement?.reward;

      setState(() {
        _adWatched = user?.ad?.count ?? 0;
        _maxAd = (setting?.maxAdPerDay ?? 0) > 0 ? setting!.maxAdPerDay : 5;
        _referralBonus = (setting?.referralBonus ?? 0) > 0 ? setting!.referralBonus : 200;
        _rewardAdUnitId = (adUnitId != null && adUnitId.isNotEmpty) ? adUnitId : null;
      });

      // Pre-load a Google ad while we fetch config.
      _preloadFallbackGoogle();

      // Fetch the dynamic ad-reward config + history in parallel.
      _loadAdConfig();
      _loadAdHistory();
    } catch (e, s) {
      Log.e(_tag, 'loadSettings failed', e, s);
    }
  }

  Future<void> _loadAdConfig() async {
    try {
      final session = context.read<SessionManager>();
      final config = await ApiService.getAdRewardConfig(session.userId);
      if (mounted) {
        setState(() {
          _adConfig = config;
          // Prefer the dynamic config over the legacy setting defaults.
          if (config.googleAdReward > 0) _googleAdReward = config.googleAdReward;
          if (config.interstitialAdReward > 0) {
            _interstitialAdReward = config.interstitialAdReward;
          }

          // Single daily progress pool: total watched / Rewarded Ad daily limit.
          _adWatched = config.adsWatchedToday;
          _maxAd = config.googleAdDailyLimit > 0
              ? config.googleAdDailyLimit
              : _maxAd;
        });

        // Pre-load the next appropriate Google ad after config is known.
        _preloadNextGoogle();
      }
    } catch (e, s) {
      Log.e(_tag, 'loadAdConfig failed', e, s);
    }
  }

  Future<void> _loadAdHistory() async {
    if (_loadingHistory) return;
    setState(() => _loadingHistory = true);
    try {
      final session = context.read<SessionManager>();
      final history = await ApiService.getAdWatchHistory(
        userId: session.userId,
        limit: 30,
      );
      if (mounted) setState(() => _adHistory = history);
    } catch (e, s) {
      Log.e(_tag, 'loadAdHistory failed', e, s);
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  // ---- Ad selection helpers -------------------------------------------------

  /// Picks the next in-house ad that is not at its per-ad daily limit.
  InHouseAd? _nextInHouseAd(AdRewardConfig config) {
    if (config.inHouseAds.isEmpty) return null;
    for (final ad in config.inHouseAds) {
      if (!ad.isActive) continue;
      if (ad.isDailyLimitReached) continue;
      return ad;
    }
    return null;
  }

  /// Whether the global in-house daily limit has been reached.
  bool _inHouseGlobalLimitReached(AdRewardConfig config) {
    if (config.inHouseAdDailyLimit <= 0) return false;
    final inHouseWatched =
        (config.adsWatchedToday - config.totalGoogleAdsWatchedToday)
            .clamp(0, config.adsWatchedToday);
    return inHouseWatched >= config.inHouseAdDailyLimit;
  }

  /// Picks the next Google ad type to show.
  ///
  /// Alternates between rewarded and rewarded interstitial when both are
  /// configured and under their daily limits. Starts with rewarded.
  AdSourceType? _nextGoogleAdType(AdRewardConfig config) {
    final hasInterstitialUnit =
        config.rewardedInterstitialAdUnit?.isNotEmpty == true ||
            config.interstitialAdUnit?.isNotEmpty == true;

    // If the backend explicitly marks the interstitial limit reached, avoid it.
    if (config.googleLimitReached &&
        (!hasInterstitialUnit || config.interstitialLimitReached)) {
      return null;
    }

    // If last shown was rewarded, try interstitial next (if available).
    if (_lastGoogleAdType == AdSourceType.google &&
        hasInterstitialUnit &&
        !config.interstitialLimitReached) {
      return AdSourceType.interstitial;
    }

    // Prefer rewarded first or fall back to it if interstitial is unavailable.
    if (!config.googleLimitReached) return AdSourceType.google;

    // Rewarded exhausted — use interstitial if still available.
    if (hasInterstitialUnit && !config.interstitialLimitReached) {
      return AdSourceType.interstitial;
    }

    return null;
  }

  /// Reward amount the user will get for the *next* ad to be shown.
  ///
  /// Uses the in-house ad reward when an in-house ad is due, otherwise the
  /// current Google ad type's reward.
  int _nextAdReward(AdRewardConfig? config) {
    if (config == null) return _googleAdReward;

    if (config.nextAdType == 'inhouse' && config.inHouseAds.isNotEmpty) {
      final ad = _nextInHouseAd(config);
      if (ad != null) return ad.rewardCoins;
    }

    final nextType = _nextGoogleAdType(config);
    if (nextType == AdSourceType.interstitial) {
      return config.interstitialAdReward > 0
          ? config.interstitialAdReward
          : _interstitialAdReward;
    }
    return config.googleAdReward > 0 ? config.googleAdReward : _googleAdReward;
  }

  /// Returns the configured ad unit ID for the requested Google ad type.
  String? _adUnitIdForGoogleType(
    AdSourceType type,
    AdRewardConfig config,
  ) {
    if (type == AdSourceType.interstitial) {
      if (config.rewardedInterstitialAdUnit?.isNotEmpty == true) {
        return config.rewardedInterstitialAdUnit;
      }
      if (config.interstitialAdUnit?.isNotEmpty == true) {
        return config.interstitialAdUnit;
      }
      return null;
    }
    return config.rewardedAdUnit?.isNotEmpty == true
        ? config.rewardedAdUnit
        : _rewardAdUnitId;
  }

  /// Pre-load the next Google ad from the current config.
  Future<void> _preloadNextGoogle() async {
    final config = _adConfig;
    if (config == null) return;
    if (config.nextAdType == 'inhouse') return;

    final nextType = _nextGoogleAdType(config);
    if (nextType == null) return;

    final unitId = _adUnitIdForGoogleType(nextType, config);
    RewardedAdService.instance
        .load(adUnitId: unitId, adType: nextType)
        .catchError((e) {
      Log.e(_tag, 'preload ad failed', e);
    });
  }

  /// Pre-load the default rewarded ad before config is known.
  void _preloadFallbackGoogle() {
    RewardedAdService.instance
        .load(adUnitId: _rewardAdUnitId, adType: AdSourceType.google)
        .catchError((e) {
      Log.e(_tag, 'preload ad failed', e);
    });
  }

  /// Updates the cached user's diamond balance from a successful ad claim.
  ///
  /// Prefer the `balance` returned by the backend. If it's missing/0, fall back
  /// to adding the reward to the previous balance so the UI updates instantly.
  void _updateUserBalance(SessionManager session, int balance, int reward) {
    final user = session.getUser();
    if (user == null) return;
    final newCoin = balance > 0
        ? balance
        : user.coin.toInt() + reward;
    if (newCoin != user.coin) {
      session.saveUser(user.copyWith(coin: newCoin));
    }
  }

  // ---- Method 1: Watch Ads (Google + in-house, with fallback) ---------------

  Future<void> _onWatchAdTap() async {
    if (_claiming || _loadingAd) return;

    setState(() => _loadingAd = true);
    await _loadAdConfig();
    if (!mounted) {
      return;
    }

    final config = _adConfig;
    if (config == null) {
      setState(() => _loadingAd = false);
      Fluttertoast.showToast(msg: 'Ad config not available. Try again.');
      return;
    }

    final userId = context.read<SessionManager>().userId;

    // Build a fallback chain for the next ad attempt.
    final plans = <_AdPlan>[];

    // Primary: what the backend says is next.
    if (config.nextAdType == 'inhouse' && config.inHouseAds.isNotEmpty) {
      final ad = _nextInHouseAd(config);
      if (ad != null && !_inHouseGlobalLimitReached(config)) {
        plans.add(_AdPlan.inhouse(ad));
      }
    }

    // Google ads: primary + alternate.
    final primaryGoogle = _nextGoogleAdType(config);
    if (primaryGoogle != null) plans.add(_AdPlan.google(primaryGoogle));

    final hasInterstitialUnit =
        config.rewardedInterstitialAdUnit?.isNotEmpty == true ||
            config.interstitialAdUnit?.isNotEmpty == true;
    if (primaryGoogle == AdSourceType.interstitial &&
        !config.googleLimitReached) {
      plans.add(const _AdPlan.google(AdSourceType.google));
    } else if (primaryGoogle == AdSourceType.google &&
        hasInterstitialUnit &&
        !config.interstitialLimitReached) {
      plans.add(const _AdPlan.google(AdSourceType.interstitial));
    }

    // In-house fallback if not already the primary.
    if (config.nextAdType != 'inhouse' && config.inHouseAds.isNotEmpty) {
      final ad = _nextInHouseAd(config);
      if (ad != null && !_inHouseGlobalLimitReached(config)) {
        plans.add(_AdPlan.inhouse(ad));
      }
    }

    if (plans.isEmpty) {
      setState(() => _loadingAd = false);
      Fluttertoast.showToast(msg: 'You exceeded your Ad limit.');
      return;
    }

    for (int i = 0; i < plans.length; i++) {
      final plan = plans[i];

      if (plan.isInHouse) {
        setState(() => _loadingAd = false);
        _onInHouseAdTap(plan.inHouseAd!);
        return;
      }

      final adType = plan.googleType!;
      late AdWatchSession session;
      try {
        session = await ApiService.startAdWatch(
          userId: userId,
          adType: adType,
        );
      } catch (e, s) {
        Log.e(_tag, 'startAdWatch failed for ${adSourceTypeName(adType)}', e, s);
        continue;
      }

      // Backend forcing an in-house ad — insert it as the very next plan.
      if (!session.status || session.watchToken == null) {
        if (session.nextAdType == 'inhouse' &&
            session.recommendedAdId != null) {
          final forcedAd = _findInHouseAd(session.recommendedAdId!);
          if (forcedAd != null) {
            plans.insert(i + 1, _AdPlan.inhouse(forcedAd));
          }
        }
        continue;
      }

      // Success for this Google ad type.
      setState(() => _loadingAd = false);
      await _showGoogleAd(adType, session, config);
      return;
    }

    setState(() => _loadingAd = false);
    Fluttertoast.showToast(msg: 'Could not start ad. Try again.');
    _loadAdHistory();
  }

  Future<void> _showGoogleAd(
    AdSourceType adType,
    AdWatchSession session,
    AdRewardConfig config,
  ) async {
    final unitId = _adUnitIdForGoogleType(adType, config);

    if (!RewardedAdService.instance.isReady ||
        RewardedAdService.instance.loadedAdType != adType) {
      await RewardedAdService.instance
          .load(adUnitId: unitId, adType: adType)
          .timeout(const Duration(seconds: 10), onTimeout: () => null);
    }

    if (!mounted) {
      return;
    }

    if (!RewardedAdService.instance.isReady) {
      setState(() => _loadingAd = false);
      Fluttertoast.showToast(msg: 'Ad not available. Try again in a moment.');
      _loadAdConfig();
      _loadAdHistory();
      return;
    }

    setState(() => _loadingAd = false);

    final watchToken = session.watchToken!;

    RewardedAdService.instance.show(
      onEarned: () => _onAdEarned(watchToken, adType),
      onDismissed: () {
        if (!_claiming) {
          // Dismissed without earning (or before claim finished) — preload same
          // type again for the next attempt.
          RewardedAdService.instance
              .load(adUnitId: unitId, adType: adType)
              .catchError((e) => Log.e(_tag, 'reload ad failed', e));
        }
        _loadAdHistory();
      },
      onError: (msg) {
        Log.e(_tag, 'ad show error: $msg', null, null);
        _loadAdConfig();
        _loadAdHistory();
      },
    );
  }

  Future<void> _onAdEarned(String watchToken, AdSourceType adType) async {
    if (_claiming) return;
    setState(() => _claiming = true);
    final session = context.read<SessionManager>();
    try {
      final res = await ApiService.claimAdReward(
        userId: session.userId,
        watchToken: watchToken,
        adType: adType,
        durationSec: 0, // Backend no longer checks duration for Google ads.
      );
      if (res.status) {
        _lastGoogleAdType = adType;
        setState(() {
          // Update the single daily progress pool.
          _adWatched = res.adsWatchedToday > 0
              ? res.adsWatchedToday
              : _adWatched + 1;
          // Update wallet balance instantly.
          _updateUserBalance(session, res.balance, res.reward);
        });
        Fluttertoast.showToast(
          msg: res.reward > 0
              ? 'Earned ${res.reward} ${Const.coinName}!'
              : 'Ad watched',
        );
        // Refresh the user's diamond balance + ad config/history.
        if (mounted) await context.read<AuthProvider>().refreshUser();
        _loadAdConfig();
        _loadAdHistory();
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Reward not credited');
        _loadAdHistory();
      }
    } catch (e, s) {
      Log.e(_tag, 'ad reward failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to claim reward');
      _loadAdHistory();
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  // ---- In-house ad flow -----------------------------------------------------

  InHouseAd? _findInHouseAd(String adId) {
    final ads = _adConfig?.inHouseAds ?? [];
    for (final ad in ads) {
      if (ad.id == adId) return ad;
    }
    return ads.isNotEmpty ? ads.first : null;
  }

  Future<void> _onInHouseAdTap(InHouseAd ad) async {
    if (_claiming) return;
    final session = context.read<SessionManager>();
    AdWatchSession? adSession;
    try {
      adSession = await ApiService.startAdWatch(
        userId: session.userId,
        adType: AdSourceType.inhouse,
        adId: ad.id,
      );
      if (!adSession.status || adSession.watchToken == null) {
        Fluttertoast.showToast(msg: adSession.message ?? 'Could not start ad.');
        _loadAdHistory();
        return;
      }
    } catch (e, s) {
      Log.e(_tag, 'startAdWatch inhouse failed', e, s);
      Fluttertoast.showToast(msg: 'Could not start ad.');
      return;
    }

    final watchToken = adSession.watchToken!;

    if (!mounted) return;
    await showInHouseAdPlayer(
      context: context,
      ad: ad,
      watchToken: watchToken,
      onOpenLink: ad.hasLink ? () => _openUrl(ad.targetUrl!) : null,
      onClaim: ({required durationSec}) =>
          _claimInHouse(ad, watchToken, durationSec),
    );
    // After the player closes, refresh state.
    _loadAdConfig();
    _loadAdHistory();
  }

  Future<bool> _claimInHouse(
    InHouseAd ad,
    String watchToken,
    int durationSec,
  ) async {
    final session = context.read<SessionManager>();
    try {
      final res = await ApiService.claimAdReward(
        userId: session.userId,
        watchToken: watchToken,
        adType: AdSourceType.inhouse,
        adId: ad.id,
        durationSec: durationSec,
      );
      if (res.status) {
        if (mounted) {
          _updateUserBalance(session, res.balance, res.reward);
          setState(() {}); // refresh the wallet balance immediately.
        }
        if (mounted) await context.read<AuthProvider>().refreshUser();
        Fluttertoast.showToast(
          msg: res.reward > 0
              ? 'Earned ${res.reward} ${Const.coinName}!'
              : 'Ad watched',
        );
        _loadAdConfig();
        _loadAdHistory();
        return true;
      }
      Fluttertoast.showToast(msg: res.message ?? 'Reward not credited');
      return false;
    } catch (e, s) {
      Log.e(_tag, 'claim inhouse failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to claim reward');
      return false;
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      Log.e(_tag, 'openUrl failed', e, null);
    }
  }

  // ---- Referral flow ---------------------------------------------------------

  void _copyToClipboard(String text, String toastMsg) {
    if (text.isEmpty) {
      Fluttertoast.showToast(msg: 'Nothing to copy');
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    Fluttertoast.showToast(msg: toastMsg);
  }

  void _shareReferral(String code) {
    final link = 'https://play.google.com/store/apps/details?id=com.believoo.app'
        '&referrer=referralCode%3D$code';
    final msg = 'Hey! Join me on Belive using my referral link:\n\n'
        '$link\n\n'
        'Referral Code: ${code.toUpperCase()}';
    Share.share(msg, subject: 'Belive');
  }

  Future<void> _onSubmitReferral() async {
    final code = _referralCtrl.text.trim();
    if (code.isEmpty) {
      Fluttertoast.showToast(msg: 'Enter Referral Code');
      return;
    }
    final session = context.read<SessionManager>();
    try {
      final res = await ApiService.redeemReferralCode(
        userId: session.userId,
        referralCode: code,
      );
      if (res.status) {
        if (res.user != null) session.saveUser(res.user!);
        Fluttertoast.showToast(msg: 'Referred Successfully');
        _referralCtrl.clear();
        setState(() {}); // refresh UI
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Failed to redeem');
      }
    } catch (e, s) {
      Log.e(_tag, 'redeem referral failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to redeem referral code');
    }
  }

  // ---- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionManager>();
    final user = session.getUser();
    final referralCode = user?.referralCode ?? user?.id ?? '';
    final isReferral = user?.isReferral ?? false;
    final diamondBalance = (user?.coin ?? 0).toInt();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text('Free Diamonds', style: TextStyle(color: _textWhite)),
        iconTheme: const IconThemeData(color: _textWhite),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _balanceCard(diamondBalance),
              const SizedBox(height: 16),
              _howItWorksCard(),
              const SizedBox(height: 16),
              _method1AdCard(),
              const SizedBox(height: 16),
              _method2ReferCard(referralCode, isReferral),
              const SizedBox(height: 16),
              _referralStatsRow(user?.referralCount ?? 0),
              const SizedBox(height: 16),
              _adHistoryCard(),
              const SizedBox(height: 16),
              _whyChooseUsCard(),
              const SizedBox(height: 16),
              _termsCard(),
              const SizedBox(height: 20),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Balance hero card -----------------------------------------------------

  Widget _balanceCard(int balance) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B1240), Color(0xFF0A0A1A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3D2B79), width: 0.5),
      ),
      child: Column(
        children: [
          const Text(
            'Your Diamond Balance',
            style: TextStyle(color: _textLavender, fontSize: 11, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CurrencyIcon(CurrencyType.diamond, size: 22),
              const SizedBox(width: 6),
              Text(
                formatCount(balance),
                style: const TextStyle(
                  color: _gold,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 0.5, color: _divider),
          const SizedBox(height: 10),
          const Text(
            'Earn Free Diamonds',
            style: TextStyle(color: _textWhite, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Watch ads & invite friends to get rewarded',
            style: TextStyle(color: _textLavender, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ---- How It Works ----------------------------------------------------------

  Widget _howItWorksCard() {
    return _darkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How It Works', style: TextStyle(color: _textWhite, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          const Text('Simple steps to earn free diamonds', style: TextStyle(color: _textMuted, fontSize: 11)),
          const SizedBox(height: 14),
          _howItWorksStep('1', 'Watch Video Ads', 'Watch video ads to get instant diamonds'),
          const SizedBox(height: 10),
          _howItWorksStep('2', 'Share Your Code', 'Send your referral code to friends'),
          const SizedBox(height: 10),
          _howItWorksStep('3', 'Get Rewarded', 'Both you & your friend receive diamonds'),
        ],
      ),
    );
  }

  Widget _howItWorksStep(String num, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_gold, _goldDark]),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(num, style: const TextStyle(color: _bg, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: _textWhite, fontSize: 12, fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(color: _textMuted, fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }

  // ---- Method 1: Watch Ads (single unified card) ----------------------------

  Widget _method1AdCard() {
    final config = _adConfig;

    // Single daily progress pool: total watched / Rewarded Ad daily limit.
    final watched = config?.adsWatchedToday ?? _adWatched;
    final max = config != null && config.googleAdDailyLimit > 0
        ? config.googleAdDailyLimit
        : _maxAd;
    final reached = max > 0 && watched >= max;

    // If the next ad is in-house, show a preview inside the same card.
    InHouseAd? nextInHouse;
    if (config != null &&
        config.nextAdType == 'inhouse' &&
        config.inHouseAds.isNotEmpty) {
      nextInHouse = _nextInHouseAd(config);
      if (nextInHouse != null && _inHouseGlobalLimitReached(config)) {
        nextInHouse = null; // let fallback pick Google if in-house is capped.
      }
    }

    final reward = _nextAdReward(config);
    final adsUntilInHouse = config?.adsUntilInHouse ?? 0;

    return _method1Card(
      reward: reward,
      watched: watched,
      max: max,
      reached: reached,
      adsUntilInHouse: adsUntilInHouse,
      inHouseAd: nextInHouse,
    );
  }

  Widget _method1Card({
    required int reward,
    required int watched,
    required int max,
    required bool reached,
    required int adsUntilInHouse,
    InHouseAd? inHouseAd,
  }) {
    final progressText = max > 0
        ? '$watched / $max watched today'
        : '$watched watched today (unlimited)';

    return _darkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge + reward
          Row(
            children: [
              _methodBadge('Method 1'),
              const Spacer(),
              const CurrencyIcon(CurrencyType.diamond, size: 18),
              const SizedBox(width: 4),
              Text('+$reward',
                  style: const TextStyle(
                      color: _gold, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Watch Video Ads',
              style: TextStyle(
                  color: _textWhite, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Complete watching an ad and earn diamonds instantly',
              style: TextStyle(color: _textMuted, fontSize: 11)),
          const SizedBox(height: 14),
          // Progress
          Row(
            children: [
              Text(progressText,
                  style: const TextStyle(color: _textLavender, fontSize: 12)),
              const Spacer(),
              if (_claiming)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: Preloader(strokeWidth: 2, color: _gold))
              else if (reached)
                const Icon(Icons.check_circle, color: Color(0xFF34C759), size: 18)
              else
                const Icon(Icons.play_circle_fill, color: _gold, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: max > 0 ? (watched / max).clamp(0.0, 1.0) : 0,
              minHeight: 7,
              backgroundColor: _cardBg2,
              valueColor: const AlwaysStoppedAnimation(_gold),
            ),
          ),
          const SizedBox(height: 12),
          // In-house preview (embedded in the same card)
          if (inHouseAd != null) _inHousePreview(inHouseAd),
          const SizedBox(height: 14),
          // CTA
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: reached
                    ? null
                    : const LinearGradient(colors: [_purple, Color(0xFF4F8DFD)]),
                color: reached ? _cardBg2 : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton(
                onPressed: reached || _claiming || _loadingAd ? null : _onWatchAdTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _loadingAd
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                              width: 18,
                              height: 18,
                              child: Preloader(
                                  strokeWidth: 2, color: _textWhite)),
                          SizedBox(width: 10),
                          Text('Loading ad...',
                              style: TextStyle(color: _textWhite)),
                        ],
                      )
                    : Text(
                        reached ? 'Daily Limit Reached' : 'Watch & Earn +$reward',
                        style: TextStyle(
                          color: reached ? _textMuted : _textWhite,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
          if (adsUntilInHouse > 0 && !reached && inHouseAd == null) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Watch $adsUntilInHouse more ad${adsUntilInHouse == 1 ? '' : 's'} for in-house reward',
                style: const TextStyle(
                    color: _textLavender, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _inHousePreview(InHouseAd ad) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ad.thumbnailUrl != null || ad.mediaUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                ad.thumbnailUrl ?? ad.mediaUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: _cardBg2,
                  child: Center(
                    child: Icon(
                      ad.isVideo ? Icons.play_circle_fill : Icons.image,
                      color: _purple,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (ad.thumbnailUrl != null || ad.mediaUrl != null)
          const SizedBox(height: 10),
        Text(
          ad.title ?? 'Sponsored',
          style: const TextStyle(
              color: _textWhite, fontSize: 14, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          ad.description ?? 'Watch this ad to earn diamonds',
          style: const TextStyle(color: _textMuted, fontSize: 10),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              ad.isVideo ? Icons.videocam : Icons.image,
              color: _textLavender,
              size: 12,
            ),
            const SizedBox(width: 6),
            Text(
              '${ad.durationSec}s • ${ad.isUnlimited ? 'Unlimited' : '${ad.dailyLimit}/day'}',
              style: const TextStyle(color: _textLavender, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  // ---- Ad history (watched / earned / failed) --------------------------------

  Widget _adHistoryCard() {
    final history = _adHistory;
    final totalWatched = history?.totalWatched ?? 0;
    final totalEarned = history?.totalEarned ?? 0;
    final totalFailed = history?.totalFailed ?? 0;
    final items = history?.history ?? const <AdWatchHistoryItem>[];

    return _darkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: _purple, size: 18),
              const SizedBox(width: 8),
              const Text('Ad History',
                  style: TextStyle(
                      color: _textWhite,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_loadingHistory)
                const SizedBox(
                    width: 14,
                    height: 14,
                    child:
                        Preloader(strokeWidth: 2, color: _gold)),
            ],
          ),
          const SizedBox(height: 12),
          // Totals row
          Row(
            children: [
              _historyStat('Watched', totalWatched, _textLavender),
              _historyStat('Earned', totalEarned, _gold),
              _historyStat('Failed', totalFailed, const Color(0xFFE53935)),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('No ad history yet',
                    style: TextStyle(color: _textMuted, fontSize: 12)),
              ),
            )
          else
            ...items.take(8).map((item) => _historyItemRow(item)),
        ],
      ),
    );
  }

  Widget _historyStat(String label, int value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _cardBg2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text('$value',
                style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: _textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _historyItemRow(AdWatchHistoryItem item) {
    final isEarned = item.status == AdWatchStatus.earned;
    final isFailed = item.status == AdWatchStatus.failed;
    final color = isEarned
        ? const Color(0xFF34C759)
        : isFailed
            ? const Color(0xFFE53935)
            : _textMuted;
    final icon = isEarned
        ? Icons.check_circle
        : isFailed
            ? Icons.cancel
            : Icons.skip_next;
    final defaultTitle = item.adType == AdSourceType.inhouse
        ? 'Sponsored Ad'
        : item.adType == AdSourceType.interstitial
            ? 'Interstitial Ad'
            : 'Google Ad';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.adTitle ?? defaultTitle,
                  style: const TextStyle(
                      color: _textWhite, fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.reason ??
                      (isEarned
                          ? 'Earned ${item.reward} ${Const.coinName}'
                          : isFailed
                              ? 'No reward'
                              : 'Skipped'),
                  style: TextStyle(color: color, fontSize: 10),
                ),
              ],
            ),
          ),
          if (item.reward > 0)
            Row(
              children: [
                const CurrencyIcon(CurrencyType.diamond, size: 12),
                const SizedBox(width: 2),
                Text('${isEarned ? '+' : ''}${item.reward}',
                    style: TextStyle(
                        color: isEarned ? _gold : _textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
        ],
      ),
    );
  }

  // ---- Method 2: Refer & Earn ------------------------------------------------

  Widget _method2ReferCard(String referralCode, bool isReferral) {
    return _darkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _methodBadge('Method 2'),
              const Spacer(),
              const CurrencyIcon(CurrencyType.diamond, size: 18),
              const SizedBox(width: 4),
              Text('+$_referralBonus', style: const TextStyle(color: _gold, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Refer & Earn', style: TextStyle(color: _textWhite, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Invite friends and both of you get rewarded', style: TextStyle(color: _textMuted, fontSize: 11)),
          const SizedBox(height: 16),

          // Referral code
          const Text('Your Referral Code', style: TextStyle(color: _textLavender, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _glassRow(
            child: Text(
              referralCode.isEmpty ? 'Not set' : referralCode,
              style: const TextStyle(color: _gold, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.copy, color: _textLavender, size: 20),
              onPressed: referralCode.isEmpty ? null : () => _copyToClipboard(referralCode, 'Referral Code Copied!'),
            ),
          ),
          const SizedBox(height: 16),

          // Referral link
          const Text('Your Referral Link', style: TextStyle(color: _textLavender, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _glassRow(
            child: Expanded(
              child: Text(
                referralCode.isEmpty
                    ? 'Not available'
                    : 'https://play.google.com/store/apps/details?id=com.believoo.app&referrer=referralCode%3D$referralCode',
                style: const TextStyle(color: _gold, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.share, color: _textLavender, size: 20),
                  onPressed: referralCode.isEmpty ? null : () => _shareReferral(referralCode),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: _textLavender, size: 20),
                  onPressed: referralCode.isEmpty
                      ? null
                      : () => _copyToClipboard(
                            'https://play.google.com/store/apps/details?id=com.believoo.app&referrer=referralCode%3D$referralCode',
                            'Referral Link Copied!',
                          ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Info text
          Text(
            'Invite your Friends! For each payout of invited friends, you and your friend both will receive $_referralBonus Diamonds.',
            style: const TextStyle(color: Color(0xFFA0A0C0), fontSize: 11, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Redeem section
          if (isReferral) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _gold.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: _gold, size: 18),
                  SizedBox(width: 8),
                  Text('You Already Referred', style: TextStyle(color: _gold, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ] else ...[
            const Text('Have a Referral Code?', style: TextStyle(color: _textLavender, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _referralCtrl,
              style: const TextStyle(color: _textWhite, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Enter Referral code here',
                hintStyle: const TextStyle(color: Color(0xFF666688), fontSize: 13),
                filled: true,
                fillColor: _cardBg2,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _purple, width: 1),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_gold, _goldDark]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ElevatedButton(
                  onPressed: _onSubmitReferral,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Claim Reward',
                    style: TextStyle(color: _bg, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---- Referral stats row ----------------------------------------------------

  Widget _referralStatsRow(int count) {
    return _darkCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.group, color: _purple, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Referrals', style: TextStyle(color: _textWhite, fontSize: 14, fontWeight: FontWeight.bold)),
                Text('You have $count referrals', style: const TextStyle(color: _textMuted, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_gold, _goldDark]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('+$_referralBonus / Friend', style: const TextStyle(color: _bg, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ---- Why Choose Us ---------------------------------------------------------

  Widget _whyChooseUsCard() {
    return _darkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Why Earn With Us?', style: TextStyle(color: _textWhite, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          _featureItem(Icons.diamond, 'Instant Rewards', 'Diamonds credited immediately after watching ads'),
          const SizedBox(height: 12),
          _featureItem(Icons.share, 'Unlimited Referrals', 'Invite as many friends as you want, no limits'),
          const SizedBox(height: 12),
          _featureItem(Icons.verified, '100% Safe & Secure', 'All transactions are encrypted and protected'),
        ],
      ),
    );
  }

  Widget _featureItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _gold, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: _textWhite, fontSize: 12, fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(color: _textMuted, fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }

  // ---- Terms -----------------------------------------------------------------

  Widget _termsCard() {
    return _darkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Good to Know', style: TextStyle(color: _textWhite, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(height: 0.5, color: _divider),
          const SizedBox(height: 10),
          const Text(
            '• Diamond rewards are credited instantly to your wallet after completing each activity.\n\n'
            '• Referral rewards are given when your referred friend makes their first purchase.\n\n'
            '• Ad availability depends on regional ad inventory and daily limits.\n\n'
            '• Misuse or fraudulent activity may result in account suspension.\n\n'
            '• All rewards are subject to platform terms and conditions.',
            style: TextStyle(color: _textMuted, fontSize: 10, height: 1.6),
          ),
        ],
      ),
    );
  }

  // ---- Footer ----------------------------------------------------------------

  Widget _footer() {
    return const Column(
      children: [
        CurrencyIcon(CurrencyType.diamond, size: 28),
        SizedBox(height: 6),
        Text('Belive Rewards Program', style: TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
        SizedBox(height: 2),
        Text('Earn more, enjoy more', style: TextStyle(color: Color(0xFF4A4A60), fontSize: 10)),
      ],
    );
  }

  // ---- Reusable widgets ------------------------------------------------------

  Widget _darkCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider, width: 0.5),
      ),
      child: child,
    );
  }

  Widget _methodBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_gold, _goldDark]),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: const TextStyle(color: _bg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _glassRow({required Widget child, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _cardBg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _divider, width: 0.5),
      ),
      child: Row(
        children: [
          if (child is Expanded) child else Expanded(child: child),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
