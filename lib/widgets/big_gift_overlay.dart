/// Full-screen big gift animation overlay.
///
/// Ports the native "big gift" / "premium gift" animation from
/// `HostPKLiveActivity.java` and `WatchAudioLiveActivity.java`.
///
/// When an expensive gift (coin >= [BigGiftController.defaultThreshold] or
/// giftType == 2/3) is sent/received, this overlay takes over the full screen
/// with a dramatic SVGA / video / image animation + sender/receiver names.
///
/// Animation flow:
/// 1. Transparent background keeps the live feed visible.
/// 2. Gift animation scales up from center with bounce (600ms)
/// 3. Holds for the animation duration (SVGA uses the decoded file length)
/// 4. Everything fades out (400ms)
library big_gift_overlay;

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/gift_sound_service.dart';
import '../utils/log.dart';
import '../utils/media_utils.dart';
import 'gift_count_badge.dart';
import 'gift_overlay.dart';
import 'svga_player_widget.dart';
import 'package:belive/widgets/preloader.dart';

/// Controller that feeds big gift events into the overlay.
///
/// Embed [BigGiftOverlay] in a Stack and call [showBigGift] when an expensive
/// gift arrives. The overlay handles its own lifecycle and auto-dismisses.
class BigGiftController {
  void Function(GiftEvent)? _callback;
  int threshold;

  /// Backend-provided big-gift threshold (from `GiftRoot.bigGiftThreshold`).
  /// Synced by [setBackendThreshold] when gifts are loaded. Defaults to 500
  /// for Bigo/Chamet parity — even moderate gifts get full-screen treatment.
  static int backendThreshold = 500;

  /// Update the global backend threshold. Call after fetching gifts
  /// (`ApiService.getGifts` → `GiftRoot.bigGiftThreshold`).
  static void setBackendThreshold(int value) {
    if (value > 0) backendThreshold = value;
  }

  BigGiftController({int? threshold})
    : threshold = threshold ?? backendThreshold;

  void attach(void Function(GiftEvent) callback) => _callback = callback;
  void detach() => _callback = null;

  /// Show a big gift full-screen animation.
  void showBigGift(GiftEvent event) => _callback?.call(event);

  /// Returns true if [event] qualifies as a "big gift" (should trigger
  /// full-screen animation). Uses backend `isBigGift` flag OR coin threshold
  /// OR gift type (SVGA/video). Bigo/Chamet parity: SVGA/video ALWAYS
  /// full-screen, image gifts >= 100 coins also full-screen.
  bool isBigGift(GiftEvent event) {
    // Backend explicitly flags big gifts — highest priority.
    if (event.isBigGift) return true;
    // SVGA (type 2) and video (type 3) gifts ALWAYS full-screen (Bigo style).
    if (event.giftType == 2 || event.giftType == 3) return true;
    // Image gifts: full-screen if coin*count >= threshold.
    final effectiveThreshold =
        threshold > backendThreshold ? threshold : backendThreshold;
    if (event.coin * event.count >= effectiveThreshold) return true;
    // Any gift with coin >= 100 per unit is "big" (Bigo parity).
    if (event.coin >= 100) return true;
    return false;
  }

  /// Returns true if [event] should trigger a screen shake. Stricter than
  /// [isBigGift] — only genuinely expensive gifts shake the screen, NOT
  /// every SVGA/video gift (which are common and would shake constantly).
  /// Fires on: backend `isBigGift` flag OR coin*count >= backend threshold.
  bool shouldShake(GiftEvent event) {
    if (event.isBigGift) return true;
    final effectiveThreshold =
        threshold > backendThreshold ? threshold : backendThreshold;
    if (event.coin * event.count >= effectiveThreshold) return true;
    return false;
  }
}

/// Full-screen big gift animation overlay.
///
/// Place inside a Stack (above all other overlays). The overlay is
/// invisible (SizedBox.shrink) when no big gift is playing.
class BigGiftOverlay extends StatefulWidget {
  const BigGiftOverlay({super.key, required this.controller});

  final BigGiftController controller;

  @override
  State<BigGiftOverlay> createState() => BigGiftOverlayState();
}

class BigGiftOverlayState extends State<BigGiftOverlay>
    with TickerProviderStateMixin {
  static const String _tag = 'BigGiftOverlay';

  GiftEvent? _currentGift;
  bool _visible = false;
  bool _imageHideTimerStarted = false;
  Timer? _svgaMaxTimer;

  late AnimationController _scrimController; // dark background fade
  late AnimationController _scaleController; // gift scale-in with bounce
  late AnimationController _fadeOutController; // everything fade-out

  Timer? _hideTimer;

  // Display durations per gift type (Bigo/Chamet parity — longer display).
  static const int _imageDuration = 4000;
  static const int _svgaDuration = 8000;
  static const int _videoDuration = 8000;
  // Absolute max time an SVGA overlay can remain visible while loading/failing.
  static const int _svgaMaxDuration = 15000;

  @override
  void initState() {
    super.initState();
    _scrimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    widget.controller.attach(_onBigGift);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _svgaMaxTimer?.cancel();
    _scrimController.dispose();
    _scaleController.dispose();
    _fadeOutController.dispose();
    widget.controller.detach();
    super.dispose();
  }

  void _onBigGift(GiftEvent event) {
    Log.d(
      _tag,
      'Big gift received: ${event.giftName} coin=${event.coin}x${event.count} type=${event.giftType}',
    );
    if (!mounted) return;
    // Play gift chime for image/SVGA gifts. Video gifts have their own
    // audio track — playing the default chime over it causes sound issues.
    if (event.giftType != 3 &&
        !GiftQueueController.isVideo(event.giftImage) &&
        !GiftQueueController.isVideo(event.svgaImage)) {
      GiftSoundService.instance.playDefault();
    }

    // If a big gift is already playing, queue this one by replacing
    // (simpler than queue — native also replaces for big gifts).
    _hideTimer?.cancel();
    _fadeOutController.stop();

    setState(() {
      _currentGift = event;
      _visible = true;
    });

    // Start entrance animations.
    _scrimController.forward(from: 0);
    _scaleController.forward(from: 0);

    _imageHideTimerStarted = false;
    // For image gifts, wait until the image has loaded before starting the
    // hide timer. Otherwise the overlay can disappear before the image is
    // visible, making it look like "gift screen par nahi chala".
    if (_shouldDelayHideTimer(event)) {
      // Timer will be started by the imageBuilder/errorBuilder.
    } else if (event.giftType == 2) {
      _svgaMaxTimer?.cancel();
      _svgaMaxTimer = Timer(
        const Duration(milliseconds: _svgaMaxDuration),
        _hideOverlay,
      );
    } else {
      _startHideTimer();
    }
  }

  /// Returns true for plain image gifts where we should wait for the image
  /// to load before starting the auto-hide timer.
  bool _shouldDelayHideTimer(GiftEvent gift) {
    if (gift.giftType == 2 || gift.giftType == 3) return false;
    return gift.giftImage.isNotEmpty &&
        !GiftQueueController.isSvga(gift.giftImage) &&
        !GiftQueueController.isSvga(gift.svgaImage) &&
        !GiftQueueController.isVideo(gift.giftImage) &&
        !GiftQueueController.isVideo(gift.svgaImage);
  }

  void _maybeStartImageHideTimer() {
    if (_imageHideTimerStarted) return;
    _imageHideTimerStarted = true;
    _startHideTimer();
  }

  void _startHideTimer() {
    final type = _currentGift?.giftType ?? 1;
    final duration =
        type == 2
            ? _svgaDuration
            : type == 3
            ? _videoDuration
            : _imageDuration;
    _hideTimer = Timer(Duration(milliseconds: duration), () {
      if (!mounted) return;
      GiftSoundService.instance.stopSvgaAudio();
      _fadeOutController.forward(from: 0).then((_) {
        if (mounted) {
          setState(() {
            _visible = false;
          });
          _scrimController.reset();
          _scaleController.reset();
          _fadeOutController.reset();
        }
      });
    });
  }

  void _startSvgaHideTimer(int durationMs) {
    _svgaMaxTimer?.cancel();
    _hideTimer?.cancel();
    _hideTimer = Timer(
      Duration(milliseconds: durationMs + 500),
      _hideOverlay,
    );
  }

  void _hideOverlay() {
    if (!mounted) return;
    // Stop any SVGA embedded audio so it doesn't keep playing after the
    // overlay is gone (fixes "music repeats after gift plays" bug).
    GiftSoundService.instance.stopSvgaAudio();
    _fadeOutController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _visible = false;
        });
        _scrimController.reset();
        _scaleController.reset();
        _fadeOutController.reset();
      }
    });
  }

  void _onSvgaLoaded(int durationMs) {
    Log.d(_tag, 'SVGA loaded: durationMs=$durationMs');
    // Cancel the safety max timer — the SVGA is now actually playing, so
    // we only need the duration-based hide timer. This prevents the max
    // timer from cutting the animation short if loading took a while.
    _svgaMaxTimer?.cancel();
    _svgaMaxTimer = null;
    _startSvgaHideTimer(durationMs);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || _currentGift == null) return const SizedBox.shrink();
    final gift = _currentGift!;

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _fadeOutController,
          builder: (_, child) {
            return Opacity(
              opacity: 1.0 - _fadeOutController.value,
              child: child,
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Transparent background so the live video/host feed remains
              // fully visible behind transparent SVGA / video gifts. The
              // animation itself provides any non-transparent areas.
              AnimatedBuilder(
                animation: _scrimController,
                builder: (_, __) {
                  return Container(
                    color: Colors.black.withValues(
                      alpha: 0.0 * _scrimController.value,
                    ),
                  );
                },
              ),
              // Gift animation center (full screen scale).
              Center(
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _scaleController,
                      curve: Curves.elasticOut,
                    ),
                  ),
                  child: _buildGiftAnimation(gift),
                ),
              ),
              // Styled gift count badge (bottom center) — ports native imgGiftCount.
              if (gift.count > 1)
                Positioned(
                  bottom: MediaQuery.of(context).padding.top + 120,
                  left: 0,
                  right: 0,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(
                        parent: _scaleController,
                        curve: Curves.elasticOut,
                      ),
                    ),
                    child: Center(
                      child: GiftCountBadge(
                        count: gift.count,
                        size: 64,
                        burning: gift.count >= 50,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the main gift animation — SVGA, video, or image (FULL SCREEN).
  Widget _buildGiftAnimation(GiftEvent gift) {
    final screenSize = MediaQuery.of(context).size;
    final staticUrl = _bestStaticImageUrl(gift);
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // Resolve SVGA before checking the numeric gift type. Some backend gift
    // records use giftType=3 for SVGA; treating type 3 as video first sends
    // the protobuf file to video_player and produces a blank overlay.
    final svgaUrl = _resolveSvgaUrl(gift);
    final hasExplicitSvga =
        GiftQueueController.isSvga(gift.svgaImage) ||
        GiftQueueController.isSvga(gift.giftImage) ||
        (gift.svgaImage?.isNotEmpty == true &&
            !GiftQueueController.isVideo(gift.svgaImage)) ||
        gift.giftType == 2;
    Log.d(
      _tag,
      'Build gift animation: giftType=${gift.giftType}, svgaImage=${gift.svgaImage}, '
      'giftImage=${gift.giftImage}, hasExplicitSvga=$hasExplicitSvga, svgaUrl=$svgaUrl',
    );
    if (hasExplicitSvga && svgaUrl.isNotEmpty) {
      // Pass the static URL as fallbackImage — but SvgaPlayer only shows
      // it on ERROR (not during loading). During loading, a transparent
      // placeholder is shown so the user doesn't see a static thumbnail
      // before the SVGA plays. If the SVGA fails to load/decode, the
      // static image is shown so the user sees SOMETHING instead of
      // "empty" (broken image icon).
      return SizedBox(
        width: screenWidth,
        height: screenHeight,
        child: SvgaPlayer(
          url: svgaUrl,
          allowAnimation: true,
          playEmbeddedAudio: true,
          fallbackImage: staticUrl.isNotEmpty ? staticUrl : null,
          width: screenWidth,
          height: screenHeight,
          fit: BoxFit.contain,
          onLoaded: _onSvgaLoaded,
        ),
      );
    }

    // Video gift (type 3 or video extension), only after excluding SVGA.
    final isVideo =
        GiftQueueController.isVideo(gift.giftImage) ||
        GiftQueueController.isVideo(gift.svgaImage) ||
        (gift.giftType == 3 && !hasExplicitSvga);
    if (isVideo) {
      final videoUrl =
          GiftQueueController.isVideo(gift.svgaImage)
              ? gift.svgaImage!
              : (GiftQueueController.isVideo(gift.giftImage)
                  ? gift.giftImage
                  : (gift.svgaImage ?? gift.giftImage));
      final url = VideoUtil.getFullImageUrl(videoUrl);
      if (url.isNotEmpty) {
        // Cancel the fixed-duration hide timer — the video will call
        // onCompleted when it finishes, which hides the overlay at the
        // exact right time (no fixed 8000ms cutoff).
        _hideTimer?.cancel();
        return SizedBox(
          width: screenWidth,
          height: screenHeight,
          child: _BigGiftVideo(
            url: url,
            fallbackImage: staticUrl,
            onCompleted: _hideOverlay,
          ),
        );
      }
    }

    // Image gift — show full screen cover image.
    if (_isNonSvgaUrl(gift.giftImage)) {
      return SizedBox(
        width: screenWidth,
        height: screenHeight,
        child: CachedNetworkImage(
          imageUrl: VideoUtil.getFullImageUrl(gift.giftImage),
          width: screenWidth,
          height: screenHeight,
          fit: BoxFit.cover,
          placeholder: (_, __) => const Preloader(color: Colors.white54),
          imageBuilder: (_, imageProvider) {
            _maybeStartImageHideTimer();
            return Image(
              image: imageProvider,
              width: screenWidth,
              height: screenHeight,
              fit: BoxFit.cover,
            );
          },
          errorWidget: (_, __, ___) {
            _maybeStartImageHideTimer();
            return _buildFallbackIcon(screenWidth * 0.5);
          },
        ),
      );
    }

    // Fallback.
    return _buildFallbackIcon(screenWidth * 0.5);
  }

  Widget _buildFallbackIcon(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
        ),
      ),
      child: ImageIcon(const AssetImage("assets/gift/official_gift.png"), color: Colors.white, size: size * 0.4),
    );
  }

  /// Resolve the actual SVGA URL from the gift event.
  ///
  /// Prefer the explicit `svgaImage` field, then `giftImage` if it looks like
  /// an SVGA file. When the backend explicitly marks the gift as `giftType == 2`
  /// and one of the URLs is non-empty, we also try that URL as SVGA even if it
  /// lacks a `.svga` extension (some CDNs use hashed paths). In that case the
  /// SVGA decoder may fail, but the overlay falls back to the static image.
  String _resolveSvgaUrl(GiftEvent gift) {
    // Prefer svgaImage if it looks like SVGA.
    if (_isSvgaUrl(gift.svgaImage)) {
      return VideoUtil.getFullSvgaUrl(gift.svgaImage!);
    }
    // Then try giftImage if it looks like SVGA.
    if (_isSvgaUrl(gift.giftImage)) {
      return VideoUtil.getFullSvgaUrl(gift.giftImage);
    }
    // A non-video asset supplied in the dedicated svgaImage field is SVGA,
    // even when the CDN URL is hashed and has no file extension.
    if (gift.svgaImage?.isNotEmpty == true &&
        !GiftQueueController.isVideo(gift.svgaImage)) {
      return VideoUtil.getFullSvgaUrl(gift.svgaImage!);
    }
    // Backend explicitly says this is an SVGA gift — try giftImage even when
    // the URL has no `.svga` extension.
    if (gift.giftType == 2 && gift.giftImage.isNotEmpty) {
      return VideoUtil.getFullSvgaUrl(gift.giftImage);
    }
    return '';
  }

  bool _isSvgaUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.contains('.svga') || lower.contains('/svga');
  }

  bool _isNonSvgaUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return !_isSvgaUrl(url);
  }

  /// Return the best static image URL (usually a .png thumbnail) for a gift
  /// that may have an .svga / .mp4 / .mov / .webm asset URL. This is used as
  /// the loading / error fallback while the big video/SVGA initializes.
  String _bestStaticImageUrl(GiftEvent gift) {
    final candidates = [gift.giftImage, gift.svgaImage];

    // 1. Use a candidate that is already a static image.
    for (final c in candidates) {
      if (c == null || c.isEmpty) continue;
      final clean = c.split('?').first.toLowerCase();
      if (!clean.endsWith('.svga') &&
          !clean.endsWith('.mp4') &&
          !clean.endsWith('.mov') &&
          !clean.endsWith('.webm') &&
          !clean.contains('/svga/')) {
        final full = VideoUtil.getFullImageUrl(c);
        if (full.isNotEmpty) return full;
      }
    }

    // 2. Derive a .png sibling from the animation/video URL.
    for (final c in candidates) {
      if (c == null || c.isEmpty) continue;
      final clean = c.split('?').first.toLowerCase();
      if (clean.endsWith('.svga') ||
          clean.endsWith('.mp4') ||
          clean.endsWith('.mov') ||
          clean.endsWith('.webm')) {
        final png = c.replaceAll(
          RegExp(r'\.(svga|mp4|mov|webm)$', caseSensitive: false),
          '.png',
        );
        if (png != c) {
          final full = VideoUtil.getFullImageUrl(png);
          if (full.isNotEmpty) return full;
        }
      }
    }

    // 3. Derive a _thumb.jpg for video assets.
    for (final c in candidates) {
      if (c == null || c.isEmpty) continue;
      final clean = c.split('?').first.toLowerCase();
      if (clean.endsWith('.mp4') ||
          clean.endsWith('.mov') ||
          clean.endsWith('.webm')) {
        final thumb = VideoUtil.getThumbnailUrl(c);
        if (thumb.isNotEmpty && thumb != c) {
          final full = VideoUtil.getFullImageUrl(thumb);
          if (full.isNotEmpty) return full;
        }
      }
    }

    // 4. Final fallback: return the original URL if nothing better is found.
    for (final c in candidates) {
      if (c != null && c.isNotEmpty) {
        final full = VideoUtil.getFullImageUrl(c);
        if (full.isNotEmpty) return full;
      }
    }
    return '';
  }
}

/// Global semaphore that limits concurrent hardware video decoder
/// instances. Android devices typically have 2-4 hardware decoder slots;
/// creating more simultaneously causes `OMX.qcom.video.decoder.avc` to fail
/// with `NO_MEMORY` (error 0xfffffff4). This guard ensures only ONE video
/// gift player is initializing/playing at any time.
class _VideoDecoderGuard {
  static final _VideoDecoderGuard _instance = _VideoDecoderGuard._();
  static _VideoDecoderGuard get instance => _instance;
  _VideoDecoderGuard._();

  bool _busy = false;
  final _waiters = <Completer<void>>[];

  /// Acquire the decoder slot. Returns immediately if free, otherwise waits
  /// for the current holder to release.
  Future<void> acquire() {
    if (!_busy) {
      _busy = true;
      return Future.value();
    }
    final c = Completer<void>();
    _waiters.add(c);
    return c.future;
  }

  /// Release the decoder slot and wake the next waiter (if any).
  void release() {
    if (_waiters.isNotEmpty) {
      final next = _waiters.removeAt(0);
      next.complete();
    } else {
      _busy = false;
    }
  }
}

/// Full-screen video player for video-type big gifts.
class _BigGiftVideo extends StatefulWidget {
  const _BigGiftVideo({required this.url, this.fallbackImage, this.onCompleted});
  final String url;
  final String? fallbackImage;
  /// Called when the video finishes playing (one-shot, no loop).
  /// The BigGiftOverlay uses this to hide the overlay at the right time
  /// instead of using a fixed 8000ms timer.
  final VoidCallback? onCompleted;

  @override
  State<_BigGiftVideo> createState() => _BigGiftVideoState();
}

class _BigGiftVideoState extends State<_BigGiftVideo> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _disposed = false;
  bool _acquired = false;
  bool _completedFired = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // Acquire the global decoder slot — only one video gift init at a time
      // to avoid OMX NO_MEMORY crashes on devices with limited decoder slots.
      await _VideoDecoderGuard.instance.acquire();
      _acquired = true;
      if (_disposed) {
        _VideoDecoderGuard.instance.release();
        _acquired = false;
        return;
      }
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _controller!.addListener(_onVideoUpdate);
      await _controller!.initialize();
      if (_disposed) {
        _controller?.dispose();
        _controller = null;
        _VideoDecoderGuard.instance.release();
        _acquired = false;
        return;
      }
      await _controller!.setVolume(1.0);
      // One-shot playback — gift videos must NOT loop (user complaint:
      // "music repeats after the animation ends").
      _controller!.setLooping(false);
      _controller!.play();
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      Log.e('BigGiftVideo', 'init failed', e);
      if (mounted) setState(() => _hasError = true);
    } finally {
      // Release the decoder slot after init — the hardware decoder is now
      // running and we don't need to block new inits anymore. The slot is
      // only needed during the init/allocate phase.
      if (_acquired) {
        _VideoDecoderGuard.instance.release();
        _acquired = false;
      }
    }
  }

  void _onVideoUpdate() {
    if (_controller == null) return;
    if (_controller!.value.hasError && !_hasError) {
      Log.e(
        'BigGiftVideo',
        'playback error: ${_controller!.value.errorDescription}',
      );
      if (mounted) setState(() => _hasError = true);
      return;
    }
    // Fire onCompleted once when the video reaches the end (one-shot mode).
    if (_initialized &&
        !_completedFired &&
        _controller!.value.isInitialized &&
        _controller!.value.position >= _controller!.value.duration &&
        !_controller!.value.isPlaying) {
      _completedFired = true;
      widget.onCompleted?.call();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    _controller = null;
    if (_acquired) {
      _VideoDecoderGuard.instance.release();
      _acquired = false;
    }
    super.dispose();
  }

  Widget _fallback() {
    final fallback = widget.fallbackImage;
    if (fallback == null || fallback.isEmpty) {
      return const SizedBox.expand();
    }
    return SizedBox.expand(
      child: CachedNetworkImage(
        imageUrl: fallback,
        fit: BoxFit.cover,
        placeholder: (_, __) => const SizedBox.expand(),
        errorWidget: (_, __, ___) => const SizedBox.expand(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) return _fallback();
    if (!_initialized || _controller == null) return _fallback();
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}
