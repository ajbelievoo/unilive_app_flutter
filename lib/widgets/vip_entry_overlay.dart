import 'dart:async';

import '../../utils/media_utils.dart';
import 'svga_player_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Entry data for a user joining the room.
class VipEntryData {
  final String userId;
  final String userName;
  final String? userImage;
  final String? avatarFrame;
  final String? entrySvgaUrl;
  final String? vipNameUrl;
  final String? vipMedalUrl;
  final bool isVIP;
  final int? vipLevel;
  final String? levelName;
  final String? country;

  /// VIP privilege — controls whether the full-screen special entrance
  /// animation plays. When false, a VIP user still gets a simple corner entry.
  final bool isSpecialEntrance;

  /// Family display name — shown as a badge in the entrance card.
  final String? familyName;

  /// Family badge icon URL.
  final String? familyBadgeUrl;

  /// Family entrance SVGA URL — if the family has the "Entrance Effect" perk
  /// unlocked, this SVGA plays as the entry animation (overrides VIP entry
  /// SVGA when the user is not VIP).
  final String? familyEntranceSvgaUrl;

  /// Family profile frame URL — shown around the avatar in the entrance card.
  final String? familyFrameUrl;

  /// Vehicle / ride image/SVGA URL — shown before the entrance animation.
  final String? vehicleUrl;

  VipEntryData({
    required this.userId,
    required this.userName,
    this.userImage,
    this.avatarFrame,
    this.entrySvgaUrl,
    this.vipNameUrl,
    this.vipMedalUrl,
    this.isVIP = false,
    this.vipLevel,
    this.levelName,
    this.country,
    this.isSpecialEntrance = false,
    this.familyName,
    this.familyBadgeUrl,
    this.familyEntranceSvgaUrl,
    this.familyFrameUrl,
    this.vehicleUrl,
  });

  factory VipEntryData.fromSocketJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final vipDetails =
        json['vipDetails'] as Map<String, dynamic>? ??
        (user?['vipDetails'] as Map<String, dynamic>?) ??
        (user?['vip']?['tierId'] as Map<String, dynamic>?);

    final isVip =
        json['isVIP'] == true ||
        json['isVip'] == true ||
        user?['isVIP'] == true ||
        user?['isVip'] == true ||
        (vipDetails?['isActive'] == true);
    final hasSpecialEntrance =
        isVip || vipDetails?['isSpecialRoomEntranceAnimationEnabled'] == true;

    final entrySvga =
        json['entrySvga']?.toString() ??
        json['entrySvgaUrl']?.toString() ??
        json['entranceAnimationUrl']?.toString() ??
        json['entryEffectImage']?.toString() ??
        vipDetails?['entranceAnimationUrl']?.toString() ??
        vipDetails?['entryEffectImage']?.toString() ??
        user?['svgaImage']?.toString() ??
        user?['entranceAnimationUrl']?.toString() ??
        user?['entryEffectImage']?.toString() ??
        (user?['liveJoinSvga'] is Map
            ? user!['liveJoinSvga']['svgaImage']?.toString()
            : null) ??
        (json['familyDetails'] is Map
            ? json['familyDetails']['entranceSvgaUrl']?.toString()
            : null) ??
        json['familyEntranceSvga']?.toString() ??
        user?['familyEntranceSvga']?.toString();

    final vehicle =
        json['vehicleImage']?.toString() ??
        json['vehicle']?.toString() ??
        json['vehicleUrl']?.toString() ??
        json['rideImage']?.toString() ??
        json['ride']?.toString() ??
        user?['vehicleImage']?.toString() ??
        user?['vehicle']?.toString() ??
        user?['vehicleUrl']?.toString() ??
        user?['rideImage']?.toString() ??
        user?['ride']?.toString() ??
        vipDetails?['vehicleImage']?.toString() ??
        vipDetails?['vehicle']?.toString() ??
        vipDetails?['vehicleUrl']?.toString();

    return VipEntryData(
      userId:
          json['userId']?.toString() ??
          user?['_id']?.toString() ??
          user?['id']?.toString() ??
          '',
      userName:
          json['userName']?.toString() ??
          json['name']?.toString() ??
          user?['name']?.toString() ??
          '',
      userImage: json['image']?.toString() ?? user?['image']?.toString(),
      avatarFrame:
          json['avatarFrame']?.toString() ??
          user?['avatarFrameImage']?.toString() ??
          vipDetails?['profileFrameUrl']?.toString(),
      entrySvgaUrl: entrySvga,
      vipNameUrl:
          vipDetails?['nameUrl']?.toString() ??
          vipDetails?['roomCardUrl']?.toString() ??
          vipDetails?['profileCardUrl']?.toString(),
      vipMedalUrl:
          vipDetails?['levelBadgeUrl']?.toString() ??
          vipDetails?['iconUrl']?.toString() ??
          vipDetails?['badgeUrl']?.toString(),
      isVIP: isVip,
      vipLevel: _toInt(
        json['vipLevel'] ?? user?['vipLevel'] ?? vipDetails?['vipLevel'],
      ),
      levelName:
          user?['level']?['name']?.toString() ??
          user?['levelName']?.toString() ??
          json['levelName']?.toString() ??
          json['level']?.toString(),
      country: json['country']?.toString() ?? user?['country']?.toString(),
      isSpecialEntrance: hasSpecialEntrance,
      familyName:
          json['familyName']?.toString() ??
          user?['familyName']?.toString() ??
          user?['family']?.toString() ??
          json['family']?.toString(),
      familyBadgeUrl:
          json['familyBadgeUrl']?.toString() ??
          user?['familyBadgeUrl']?.toString(),
      familyEntranceSvgaUrl:
          json['familyEntranceSvga']?.toString() ??
          user?['familyEntranceSvga']?.toString() ??
          (json['familyDetails'] is Map
              ? json['familyDetails']['entranceSvgaUrl']?.toString()
              : null),
      familyFrameUrl:
          json['familyFrameUrl']?.toString() ??
          user?['familyFrameUrl']?.toString() ??
          (json['familyDetails'] is Map
              ? json['familyDetails']['frameUrl']?.toString()
              : null),
      vehicleUrl: vehicle,
    );
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString());
  }
}

/// Slide-out animation that can exit to either the left (-1) or the right (+1).
class _DirectionalSlideAnimation extends Animation<Offset> {
  _DirectionalSlideAnimation(this.parent, this.exitToRight);

  final Animation<double> parent;
  bool exitToRight;

  @override
  Offset get value => Offset(exitToRight ? parent.value : -parent.value, 0.0);

  @override
  void addListener(VoidCallback listener) => parent.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => parent.removeListener(listener);

  @override
  void addStatusListener(AnimationStatusListener listener) =>
      parent.addStatusListener(listener);

  @override
  void removeStatusListener(AnimationStatusListener listener) =>
      parent.removeStatusListener(listener);

  @override
  AnimationStatus get status => parent.status;
}

/// VIP / user entry overlay — sequential entrance effects.
///
/// Ported from native `triggerNextEntryEffect` / `showVipEntryEffect`.
/// Flow:
///   1. Entry (SVGA animation) plays fully.
///   2. Entrance card (profile avatar + frame + medal + name + country) appears.
///   3. After hold duration the whole overlay slides out and the next entry starts.
/// Multiple incoming entries are queued so they never overlap.
class VipEntryOverlay extends StatefulWidget {
  const VipEntryOverlay({super.key});

  @override
  State<VipEntryOverlay> createState() => VipEntryOverlayState();
}

enum _EntryPhase { none, vehicle, entry, card, exit }

class VipEntryOverlayState extends State<VipEntryOverlay>
    with TickerProviderStateMixin {
  final _entryQueue = <VipEntryData>[];
  bool _isPlaying = false;
  VipEntryData? _currentEntry;
  _EntryPhase _phase = _EntryPhase.none;

  Timer? _timeoutTimer;
  Timer? _phaseTimer;

  late AnimationController _inController;
  late AnimationController _outController;
  late AnimationController _vehicleController;
  late Animation<Offset> _slideIn;
  late Animation<double> _fadeIn;
  late Animation<double> _fadeOut;
  late Animation<double> _outCurve;
  late _DirectionalSlideAnimation _slideOut;
  late Animation<Offset> _normalVehicleSlide;
  bool _exitToRight = false;

  /// SVGA duration detected from the loaded entrance animation (ms).
  int _svgaDurationMs = 0;
  bool _svgaLoaded = false;
  bool _vehicleLoaded = false;

  @override
  void initState() {
    super.initState();
    _vehicleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _normalVehicleSlide = Tween<Offset>(
      begin: const Offset(1.2, 0.0),
      end: const Offset(0.2, 0.0),
    ).animate(
      CurvedAnimation(parent: _vehicleController, curve: Curves.easeOutCubic),
    );

    _inController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideIn = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _inController, curve: Curves.easeOutCubic),
    );
    _fadeIn = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _inController, curve: Curves.easeOut));

    _outController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _outCurve = CurvedAnimation(
      parent: _outController,
      curve: Curves.easeInCubic,
    );
    _slideOut = _DirectionalSlideAnimation(_outCurve, _exitToRight);
    _fadeOut = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _outController, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _phaseTimer?.cancel();
    _vehicleController.dispose();
    _inController.dispose();
    _outController.dispose();
    super.dispose();
  }

  void addEntry(VipEntryData entry) {
    // Some backend join payloads omit userId. Never dedupe empty IDs or one
    // malformed entry will suppress every later room entrance.
    final canDedupe = entry.userId.trim().isNotEmpty;
    final alreadyQueued =
        canDedupe &&
        (_entryQueue.any((e) => e.userId == entry.userId) ||
            _currentEntry?.userId == entry.userId);
    if (alreadyQueued) return;
    _entryQueue.add(entry);
    _triggerNext();
  }

  void _triggerNext() {
    if (_isPlaying || _entryQueue.isEmpty || !mounted) return;
    _isPlaying = true;
    _currentEntry = _entryQueue.removeAt(0);
    _svgaDurationMs = 0;
    _svgaLoaded = false;
    _vehicleLoaded = false;
    _phase = _EntryPhase.entry;

    _inController.reset();
    _outController.reset();
    _vehicleController.reset();

    // 25s safety timeout to force-reset stuck animations.
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 25), () => _finishAndNext());

    // Start slide-in. Once visible, the entry SVGA phase begins.
    _inController.forward(from: 0.0).then((_) {
      if (!mounted || !_isPlaying) return;
      _startEntryPhase();
    });

    setState(() {});
  }

  void _startEntryPhase() {
    if (!mounted || !_isPlaying) return;

    final entry = _currentEntry;
    if (entry == null) return;

    final special = entry.isSpecialEntrance;

    // If the user has an equipped vehicle, show it before the main entrance.
    final vehicleUrl = entry.vehicleUrl;
    if (vehicleUrl != null && vehicleUrl.isNotEmpty) {
      _phase = _EntryPhase.vehicle;
      if (!special) {
        _vehicleController.forward(from: 0.0);
      }
      setState(() {});
      _phaseTimer?.cancel();
      // Static vehicles need a short display; network SVGA vehicles get up to
      // 8 seconds to download before falling through to the main entrance.
      final wait =
          _isKnownStaticImage(VideoUtil.getFullImageUrl(vehicleUrl))
              ? const Duration(milliseconds: 2800)
              : const Duration(seconds: 8);
      _phaseTimer = Timer(wait, () {
        if (!mounted || !_isPlaying) return;
        _startMainEntry();
      });
      return;
    }

    _startMainEntry();
  }

  void _startMainEntry() {
    if (!mounted || !_isPlaying) return;
    _phase = _EntryPhase.entry;

    final entry = _currentEntry;
    if (entry == null) return;

    final hasSvga = SvgaHelper.isSvgaUrl(entry.entrySvgaUrl);
    if (!hasSvga) {
      _phaseTimer?.cancel();
      _phaseTimer = Timer(const Duration(milliseconds: 400), () {
        if (!mounted || !_isPlaying) return;
        _advanceToCard();
      });
      return;
    }

    // If the SVGA already loaded before we got here, start the hold timer
    // immediately using its real duration.
    if (_svgaLoaded && _svgaDurationMs > 0) {
      _phaseTimer?.cancel();
      _phaseTimer = Timer(Duration(milliseconds: _svgaDurationMs), () {
        if (!mounted || !_isPlaying) return;
        _advanceToCard();
      });
      return;
    }

    // Network SVGA files can be several MB. The previous 1.5-second fallback
    // removed the widget before downloads completed, so entries never showed.
    _phaseTimer?.cancel();
    _phaseTimer = Timer(const Duration(seconds: 20), () {
      if (!mounted || !_isPlaying || _svgaLoaded) return;
      _advanceToCard();
    });
  }

  void _onVehicleLoaded(int durationMs) {
    if (!mounted ||
        !_isPlaying ||
        _phase != _EntryPhase.vehicle ||
        _vehicleLoaded) {
      return;
    }
    _vehicleLoaded = true;
    _phaseTimer?.cancel();
    _phaseTimer = Timer(
      Duration(milliseconds: durationMs.clamp(1200, 6000).toInt()),
      () {
        if (!mounted || !_isPlaying) return;
        _startMainEntry();
      },
    );
  }

  void _onSvgaLoaded(int durationMs) {
    if (!mounted || !_isPlaying || _phase != _EntryPhase.entry) return;
    _svgaLoaded = true;
    _svgaDurationMs = durationMs;

    // Cancel any pending fallback and wait for the SVGA to finish one loop.
    _phaseTimer?.cancel();
    _phaseTimer = Timer(Duration(milliseconds: durationMs), () {
      if (!mounted || !_isPlaying) return;
      _advanceToCard();
    });
  }

  void _advanceToCard() {
    if (!mounted || !_isPlaying) return;
    _phase = _EntryPhase.card;
    setState(() {});

    // Hold the entrance card then slide out.
    final isVip = _currentEntry?.isVIP == true;
    final holdDuration =
        isVip
            ? const Duration(milliseconds: 3000)
            : const Duration(milliseconds: 2000);

    // VIP / special exits to the left; normal entries exit back to the right.
    final special = _currentEntry?.isSpecialEntrance == true;
    _exitToRight = !special;
    _slideOut.exitToRight = _exitToRight;

    _phaseTimer?.cancel();
    _phaseTimer = Timer(holdDuration, () {
      if (!mounted || !_isPlaying) return;
      _phase = _EntryPhase.exit;
      _outController.forward(from: 0.0).then((_) {
        _finishAndNext();
      });
    });
  }

  void _finishAndNext() {
    if (!mounted) return;
    _timeoutTimer?.cancel();
    _phaseTimer?.cancel();
    _timeoutTimer = null;
    _phaseTimer = null;
    setState(() {
      _isPlaying = false;
      _currentEntry = null;
      _phase = _EntryPhase.none;
    });
    _inController.reset();
    _outController.reset();
    _vehicleController.reset();
    _triggerNext();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPlaying || _currentEntry == null) return const SizedBox.shrink();

    final entry = _currentEntry!;
    // VIP / special: full-screen centered entrance. Normal: right-side fly-by.
    final showSpecial = entry.isSpecialEntrance;

    final bool showCard =
        _phase == _EntryPhase.card || _phase == _EntryPhase.exit;

    return Positioned.fill(
      child: IgnorePointer(
        child: SlideTransition(
          position: _outController.isAnimating ? _slideOut : _slideIn,
          child: FadeTransition(
            opacity: _outController.isAnimating ? _fadeOut : _fadeIn,
            child: Container(
              color: Colors.transparent,
              child: Stack(
                alignment: Alignment.topLeft,
                children: [
                  // Phase 0: Vehicle / ride.
                  if (_phase == _EntryPhase.vehicle)
                    _buildVehicleAnimation(entry, showSpecial),

                  // Phase 1: Entry (SVGA only).
                  if (_phase == _EntryPhase.entry)
                    _buildEntryAnimation(entry, showSpecial),

                  // Phase 2: Entrance card (profile + name + badges).
                  if (showCard) _buildEntranceCard(entry, showSpecial),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Vehicle / ride entry animation shown before the main entrance.
  Widget _buildVehicleAnimation(VipEntryData entry, bool showSpecial) {
    final screenSize = MediaQuery.of(context).size;
    final vehicleUrl = entry.vehicleUrl;
    if (vehicleUrl == null || vehicleUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    final fullUrl =
        SvgaHelper.isSvgaUrl(vehicleUrl)
            ? VideoUtil.getFullSvgaUrl(vehicleUrl)
            : VideoUtil.getFullImageUrl(vehicleUrl);
    if (fullUrl.isEmpty) return const SizedBox.shrink();

    if (showSpecial) {
      // VIP / special: full screen, centered, no clipping.
      final fullW = screenSize.width;
      final fullH = screenSize.height;
      return Positioned.fill(
        child: Center(
          child: SizedBox(
            width: fullW,
            height: fullH,
            child: _buildVehicleContent(fullUrl, fullW, fullH),
          ),
        ),
      );
    }

    // Normal (non-VIP): smaller, right-side fly-by.
    final normalW = screenSize.width * 0.55;
    final normalH = screenSize.height * 0.30;
    return Positioned.fill(
      child: Center(
        child: SlideTransition(
          position: _normalVehicleSlide,
          child: SizedBox(
            width: normalW,
            height: normalH,
            child: _buildVehicleContent(fullUrl, normalW, normalH),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleContent(String fullUrl, double width, double height) {
    if (_isKnownStaticImage(fullUrl)) {
      return CachedNetworkImage(
        imageUrl: fullUrl,
        width: width,
        height: height,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    if (SvgaHelper.isSvgaUrl(fullUrl)) {
      return SvgaPlayer(
        url: fullUrl,
        width: width,
        height: height,
        fit: BoxFit.contain,
        playEmbeddedAudio: true,
        onLoaded: _onVehicleLoaded,
      );
    }
    return CachedNetworkImage(
      imageUrl: fullUrl,
      width: width,
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      errorWidget: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  bool _isKnownStaticImage(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return path.endsWith('.png') ||
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.webp') ||
        path.endsWith('.gif');
  }

  /// The entry SVGA animation itself.
  /// For VIP / special: full screen, centered.
  /// For normal users: small, right-side, not full screen.
  Widget _buildEntryAnimation(VipEntryData entry, bool showSpecial) {
    final screenSize = MediaQuery.of(context).size;
    final hasSvga = SvgaHelper.isSvgaUrl(entry.entrySvgaUrl);
    if (!hasSvga) return const SizedBox.shrink();

    final url = VideoUtil.getFullSvgaUrl(entry.entrySvgaUrl);
    if (showSpecial) {
      final fullW = screenSize.width;
      final fullH = screenSize.height;
      return Positioned.fill(
        child: Center(
          child: SizedBox(
            width: fullW,
            height: fullH,
            child: SvgaPlayer(
              url: url,
              width: fullW,
              height: fullH,
              fit: BoxFit.contain,
              playEmbeddedAudio: true,
              onLoaded: _onSvgaLoaded,
            ),
          ),
        ),
      );
    }

    // Normal (non-VIP): play the SVGA on the right side, not full screen.
    final normalW = screenSize.width * 0.55;
    final normalH = screenSize.height * 0.30;
    return Positioned.fill(
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 20),
          child: SizedBox(
            width: normalW,
            height: normalH,
            child: SvgaPlayer(
              url: url,
              width: normalW,
              height: normalH,
              fit: BoxFit.contain,
              playEmbeddedAudio: true,
              onLoaded: _onSvgaLoaded,
            ),
          ),
        ),
      ),
    );
  }

  /// The entrance card shown after the entry SVGA finishes.
  /// Bigo/Chamet-style: only a long top banner with the user's name.
  Widget _buildEntranceCard(VipEntryData entry, bool showSpecial) {
    if (showSpecial) {
      // VIP full-screen entrance card — reduced to a long banner with name.
      return Positioned.fill(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildLongVipBanner(entry),
          ),
        ),
      );
    }

    // Non-special / normal entrance card (centered).
    return Positioned.fill(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors:
                  entry.isVIP
                      ? [const Color(0x66FFD700), const Color(0x66FFA000)]
                      : [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.black.withValues(alpha: 0.4),
                      ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  entry.isVIP
                      ? const Color(0xFFFFD700).withValues(alpha: 0.6)
                      : Colors.white24,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (entry.isVIP ? const Color(0xFFFFD700) : Colors.black)
                    .withValues(alpha: 0.3),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAvatarWithFrame(entry, size: 48),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (entry.vipLevel != null && entry.vipLevel! > 0)
                        _buildVipBadge(entry.vipLevel!),
                      if (entry.levelName != null &&
                          entry.levelName!.isNotEmpty)
                        _buildLevelBadge(entry.levelName!),
                      if (entry.familyName != null &&
                          entry.familyName!.isNotEmpty)
                        _buildFamilyBadge(
                          entry.familyName!,
                          entry.familyBadgeUrl,
                        ),
                      Flexible(
                        child: Text(
                          entry.userName,
                          style: TextStyle(
                            color:
                                entry.isVIP
                                    ? const Color(0xFFFFD700)
                                    : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (entry.country != null && entry.country!.isNotEmpty)
                        Text(
                          'from ${entry.country} ',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      Text(
                        entry.isVIP
                            ? 'VIP entered the room'
                            : 'entered the room',
                        style: TextStyle(
                          color:
                              entry.isVIP
                                  ? const Color(0xFFFFD700)
                                  : Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bigo/Chamet-style long VIP entrance banner.
  /// Uses the backend VIP room-card image as the banner if available,
  /// otherwise a transparent fallback, and overlays the user's name.
  Widget _buildLongVipBanner(VipEntryData entry) {
    final hasBanner = entry.vipNameUrl != null && entry.vipNameUrl!.isNotEmpty;
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: hasBanner ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (hasBanner)
              Positioned.fill(
                child:
                    SvgaHelper.isSvgaUrl(entry.vipNameUrl)
                        ? SvgaPlayer(
                          url: VideoUtil.getFullSvgaUrl(entry.vipNameUrl),
                          width: double.infinity,
                          height: 56,
                          fit: BoxFit.contain,
                          onLoaded: (_) {},
                        )
                        : CachedNetworkImage(
                          imageUrl: VideoUtil.getFullImageUrl(entry.vipNameUrl),
                          width: double.infinity,
                          height: 56,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const SizedBox.shrink(),
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                gradient:
                    hasBanner
                        ? LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.1),
                            Colors.black.withValues(alpha: 0.35),
                          ],
                        )
                        : null,
              ),
              child: Text(
                entry.userName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarWithFrame(VipEntryData entry, {required double size}) {
    // Family frame is used as a fallback when there's no VIP frame.
    final familyFrame =
        SvgaHelper.isSvgaUrl(entry.familyFrameUrl)
            ? VideoUtil.getFullSvgaUrl(entry.familyFrameUrl)
            : VideoUtil.getFullImageUrl(entry.familyFrameUrl);
    return Stack(
      alignment: Alignment.center,
      children: [
        // VIP frame takes priority; family frame is fallback.
        if (entry.avatarFrame != null && entry.avatarFrame!.isNotEmpty)
          SvgaHelper.isSvgaUrl(entry.avatarFrame)
              ? SvgaPlayer(
                url: VideoUtil.getFullSvgaUrl(entry.avatarFrame),
                width: size,
                height: size,
                repeat: true,
                onLoaded: (_) {},
              )
              : CachedNetworkImage(
                imageUrl: VideoUtil.getFullImageUrl(entry.avatarFrame),
                width: size,
                height: size,
                fit: BoxFit.contain,
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              )
        else if (familyFrame.isNotEmpty)
          SvgaHelper.isSvgaUrl(familyFrame)
              ? SvgaPlayer(
                url: familyFrame,
                width: size,
                height: size,
                repeat: true,
                onLoaded: (_) {},
              )
              : CachedNetworkImage(
                imageUrl: familyFrame,
                width: size,
                height: size,
                fit: BoxFit.contain,
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
        ClipOval(
          child: CachedNetworkImage(
            imageUrl: VideoUtil.getFullImageUrl(entry.userImage),
            width: size * 0.65,
            height: size * 0.65,
            fit: BoxFit.cover,
            placeholder:
                (_, __) => Container(
                  width: size * 0.65,
                  height: size * 0.65,
                  color: Colors.grey.shade800,
                ),
            errorWidget:
                (_, __, ___) => Container(
                  width: size * 0.65,
                  height: size * 0.65,
                  color: Colors.grey.shade800,
                  child: const Icon(
                    Icons.person,
                    color: Colors.white54,
                    size: 32,
                  ),
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildVipBadge(int level) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'VIP $level',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLevelBadge(String name) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5FF),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        name,
        style: const TextStyle(
          color: Color(0xFF1A1A2E),
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color isVipColor(int vipLevel) {
    if (vipLevel > 0) return const Color(0xFFFFD700);
    return Colors.white54;
  }

  /// Family badge for entrance card — shows family icon if available,
  /// otherwise a blue text chip with the family name.
  Widget _buildFamilyBadge(String name, String? badgeUrl) {
    if (badgeUrl != null && badgeUrl.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: CachedNetworkImage(
          imageUrl: VideoUtil.getFullImageUrl(badgeUrl),
          width: 18,
          height: 18,
          errorWidget: (_, __, ___) => _familyTextBadge(name),
        ),
      );
    }
    return _familyTextBadge(name);
  }

  Widget _familyTextBadge(String name) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)],
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
