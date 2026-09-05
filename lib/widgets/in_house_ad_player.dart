/// Full-screen in-house ad player for the Free Diamonds ad engine.
///
/// Shows an admin-created ad (image or video) with a countdown timer. The
/// "Claim Reward" button is enabled after the required watch duration has
/// elapsed — matching the backend's anti-fraud duration check. If the ad has
/// a `targetUrl`, a "Visit Link" button is shown so the user can open the
/// advertiser's page.
///
/// The actual reward credit happens via [onClaim], which should call
/// `ApiService.claimAdReward` with the server-issued `watchToken` and the
/// elapsed seconds. The dialog also auto-claims once the timer reaches zero
/// and claims with the elapsed time if the user closes the player early.
library in_house_ad_player;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/ad_reward_models.dart';
import '../theme/app_theme.dart';
import 'package:belive/widgets/preloader.dart';

/// Signature for the in-house ad claim callback.
///
/// [durationSec] is the number of seconds the user actually watched before
/// this claim. The backend uses this for reporting; it may mark the watch as
/// `skipped` if [durationSec] is less than the ad's required duration.
typedef InHouseAdClaim = Future<bool> Function({required int durationSec});

/// Shows the in-house ad player as a full-screen modal route.
///
/// [watchToken] is the server-issued session token from `startAdWatch`.
/// [onClaim] is invoked when the user taps "Claim" after the duration, or
/// automatically when the countdown finishes, or when the player is closed
/// early. It must return `true` if the backend accepted the claim. The dialog
/// auto-closes on a successful claim.
Future<void> showInHouseAdPlayer({
  required BuildContext context,
  required InHouseAd ad,
  required String watchToken,
  required InHouseAdClaim onClaim,
  VoidCallback? onOpenLink,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => _InHouseAdPlayer(
        ad: ad,
        watchToken: watchToken,
        onClaim: onClaim,
        onOpenLink: onOpenLink,
      ),
    ),
  );
}

class _InHouseAdPlayer extends StatefulWidget {
  const _InHouseAdPlayer({
    required this.ad,
    required this.watchToken,
    required this.onClaim,
    this.onOpenLink,
  });

  final InHouseAd ad;
  final String watchToken;
  final InHouseAdClaim onClaim;
  final VoidCallback? onOpenLink;

  @override
  State<_InHouseAdPlayer> createState() => _InHouseAdPlayerState();
}

class _InHouseAdPlayerState extends State<_InHouseAdPlayer> {
  late int _remaining;
  Timer? _timer;
  bool _claiming = false;
  bool _claimed = false;
  bool _autoClaimed = false;
  bool _closed = false;
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;

  int get _elapsed => (widget.ad.durationSec - _remaining).clamp(0, widget.ad.durationSec);

  @override
  void initState() {
    super.initState();
    _remaining = widget.ad.durationSec > 0 ? widget.ad.durationSec : 0;
    _initMedia();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _videoCtrl?.dispose();
    super.dispose();
  }

  void _initMedia() {
    if (widget.ad.isVideo && widget.ad.mediaUrl != null) {
      _videoCtrl = VideoPlayerController.networkUrl(
        Uri.parse(widget.ad.mediaUrl!),
      )..initialize().then((_) {
          if (mounted) {
            _videoCtrl!.setLooping(true);
            _videoCtrl!.play();
            setState(() => _videoReady = true);
          }
        }).catchError((e) {
          // Video failed to load — the countdown still runs so the user can
          // claim after the required duration (backend validates server-side).
        });
    }
  }

  void _startCountdown() {
    if (widget.ad.durationSec <= 0) {
      setState(() => _remaining = 0);
      _autoClaimIfPossible();
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _remaining = _remaining - 1);
      if (_remaining <= 0) {
        t.cancel();
        HapticFeedback.lightImpact();
        _autoClaimIfPossible();
      }
    });
  }

  Future<void> _autoClaimIfPossible() async {
    if (_claiming || _claimed || _autoClaimed || !mounted) return;
    _autoClaimed = true;
    await _doClaim(elapsedSec: widget.ad.durationSec, popOnSuccess: true);
  }

  bool get _canClaim => !_claiming && !_claimed && !_closed;

  Future<void> _onClaim() async {
    if (!_canClaim) return;
    await _doClaim(elapsedSec: _elapsed, popOnSuccess: true);
  }

  /// Claims the reward and optionally pops the player on success.
  Future<void> _doClaim({
    required int elapsedSec,
    required bool popOnSuccess,
  }) async {
    if (_claiming || _claimed || _closed) return;
    setState(() => _claiming = true);
    try {
      final ok = await widget.onClaim(durationSec: elapsedSec);
      if (mounted) {
        setState(() {
          _claimed = ok;
          _claiming = false;
        });
        if (ok) {
          HapticFeedback.heavyImpact();
          if (popOnSuccess) {
            Future.delayed(const Duration(milliseconds: 900), () {
              if (mounted) Navigator.of(context).maybePop();
            });
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _claiming = false);
    }
  }

  Future<void> _onClose() async {
    _closed = true;
    _timer?.cancel();
    // If the user closes early, try to claim with the elapsed time so the
    // backend can mark the watch as `skipped` if needed.
    if (!_claimed && !_claiming && mounted) {
      await _doClaim(elapsedSec: _elapsed, popOnSuccess: false);
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: close + countdown chip
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _onClose,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _remaining > 0
                          ? Colors.white.withValues(alpha: 0.12)
                          : const Color(0xFF34C759).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _remaining > 0 ? Icons.timer : Icons.check_circle,
                          color: _remaining > 0
                              ? Colors.white
                              : const Color(0xFF34C759),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _remaining > 0
                              ? 'Reward in ${_remaining}s'
                              : 'Reward ready',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Ad media
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.topLeft,
                    children: [
                      _buildMedia(),
                      if (ad.title != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black87],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  ad.title!,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800),
                                ),
                                if (ad.description != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    ad.description!,
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [
                  if (ad.hasLink)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Visit Link'),
                        onPressed: () => widget.onOpenLink?.call(),
                      ),
                    ),
                  if (ad.hasLink) const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: _canClaim && _remaining <= 0
                            ? AppTheme.goldGradient
                            : null,
                        color: _canClaim && _remaining <= 0
                            ? null
                            : Colors.white12,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _canClaim && _remaining <= 0
                            ? _onClaim
                            : null,
                        child: _claimBody(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedia() {
    final ad = widget.ad;
    if (ad.isVideo) {
      if (_videoCtrl != null && _videoReady) {
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoCtrl!.value.size.width,
            height: _videoCtrl!.value.size.height,
            child: VideoPlayer(_videoCtrl!),
          ),
        );
      }
      return Container(
        color: Colors.black12,
        child: const Center(
          child: Preloader(color: Colors.white70),
        ),
      );
    }
    return Image.network(
      ad.mediaUrl ?? '',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFF1A1A2E),
        child: const Center(
          child: Icon(Icons.image, color: Colors.white24, size: 64),
        ),
      ),
    );
  }

  Widget _claimBody() {
    if (_claiming) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Preloader(strokeWidth: 2, color: Colors.black),
          ),
          SizedBox(width: 10),
          Text('Claiming...',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
        ],
      );
    }
    if (_claimed) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: Colors.black, size: 22),
          SizedBox(width: 8),
          Text('Reward Claimed!',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
        ],
      );
    }
    if (_remaining > 0) {
      return Text(
        'Watch to claim (+${widget.ad.rewardCoins})',
        style: const TextStyle(
            color: Colors.white54, fontWeight: FontWeight.w700, fontSize: 15),
      );
    }
    return Text(
      'Claim +${widget.ad.rewardCoins} Diamonds',
      style: const TextStyle(
          color: Colors.black, fontWeight: FontWeight.w800, fontSize: 16),
    );
  }
}
