/// Gift fly-to-seats animation overlay for audio room.
///
/// Ports native Java methods from HostLiveAudioActivity.java:
/// - `moveGiftToMultipleSeats()` — gift enters from bottom, zooms to center
/// - `animateToAllSeats()` — gift clones fly to each receiver's seat
/// - `animateGiftWithArcAndRotation()` — spiral/arc motion with rotation
///
/// Animation flow:
/// 1. A stacked "Sent to [name]" banner appears on the left side for every
///    receiver.
/// 2. A gift clone flies from that banner to the receiver's seat with arc
///    and rotation.
/// 3. The clone shrinks and fades as it reaches the seat so it appears to
///    "go into" the seat.
/// 4. The banner disappears when the flight completes.
///
/// For big full-screen gifts the caller is responsible for playing the big
/// overlay first, then calling [flyGiftToSeats] afterwards.
library gift_fly_overlay;
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../utils/log.dart';
import '../utils/media_utils.dart';
import 'svga_player_widget.dart';

/// Gift fly-to-seats animation overlay.
///
/// Embed in a Stack. Call `flyGiftToSeats()` when a gift is sent to seat users.
class GiftFlyOverlay extends StatefulWidget {
  const GiftFlyOverlay({super.key});

  @override
  State<GiftFlyOverlay> createState() => GiftFlyOverlayState();
}

class GiftFlyOverlayState extends State<GiftFlyOverlay>
    with TickerProviderStateMixin {
  final _activeSessions = <_GiftFlySession>[];
  final _seatPositions = <int, Rect>{};
  int _sessionCounter = 0;
  int _nextSessionId = 0;

  void setSeatPositions(Map<int, Rect> positions) {
    _seatPositions.clear();
    _seatPositions.addAll(positions);
  }

  /// Fly gift to multiple seats with a per-receiver "Sent to" banner on the
  /// left side. Each banner has its own gift clone that flies to the target
  /// seat.
  ///
  /// [receiverNames] and [receiverImages] may be supplied to show the correct
  /// receiver for every seat in [seatPositions]. If they are shorter than
  /// [seatPositions], the single [receiverName]/[receiverImage] is repeated.
  void flyGiftToSeats({
    required String giftImageUrl,
    required String senderName,
    String senderImage = '',      // NEW: sender avatar for Bigo-style banner
    String receiverName = '',
    String receiverImage = '',
    List<String>? receiverNames,
    List<String>? receiverImages,
    int count = 1,
    required List<int> seatPositions,
  }) {
    if (seatPositions.isEmpty) return;

    final fullUrl = VideoUtil.getFullImageUrl(giftImageUrl);
    final fullSenderImage = VideoUtil.getFullImageUrl(senderImage);
    final names = receiverNames ?? <String>[];
    final images = receiverImages ?? <String>[];

    for (int i = 0; i < seatPositions.length; i++) {
      final rName = i < names.length ? names[i] : receiverName;
      final rImage = i < images.length ? images[i] : receiverImage;
      final sessionId = _nextSessionId++;

      final session = _GiftFlySession(
        id: sessionId,
        index: _sessionCounter + i,
        senderName: senderName,
        senderImage: fullSenderImage,
        receiverName: rName.isNotEmpty ? rName : 'Host',
        receiverImage: rImage,
        seatPosition: seatPositions[i],
        giftImageUrl: fullUrl,
        count: count,
        controller: AnimationController(
          duration: const Duration(milliseconds: 1600),
          vsync: this,
        ),
        onComplete: () => _removeSession(sessionId),
      );

      // Stagger start so banners + flights cascade down the left side.
      Future.delayed(Duration(milliseconds: i * 120), () {
        if (mounted) _startSession(session);
      });
    }

    _sessionCounter += seatPositions.length;
  }

  void _startSession(_GiftFlySession session) {
    if (!mounted) return;

    final mq = MediaQuery.of(context);
    final safeTop = mq.padding.top;
    const bannerLeft = 12.0;
    const bannerTopBase = 120.0;
    const bannerSpacing = 52.0;
    const bannerWidth = 170.0;
    const bannerHeight = 38.0;

    final bannerTop = safeTop + bannerTopBase + session.index * bannerSpacing;
    session.startX = bannerLeft + bannerWidth / 2;
    session.startY = bannerTop + bannerHeight / 2;

    final seatRect = _seatPositions[session.seatPosition];
    if (seatRect != null) {
      session.endX = seatRect.center.dx;
      session.endY = seatRect.center.dy;
    } else {
      // Seat rect not measured yet — abort this clone. The next frame update
      // from the room should include it; the caller can retry if needed.
      Log.w('GiftFly', 'No seat rect for position ${session.seatPosition}');
      session.controller.dispose();
      return;
    }

    setState(() => _activeSessions.add(session));

    session.controller.forward().then((_) => session.onComplete());
  }

  void _removeSession(int id) {
    if (!mounted) return;
    setState(() => _activeSessions.removeWhere((s) => s.id == id));
  }

  @override
  void dispose() {
    for (final s in _activeSessions) {
      s.controller.dispose();
    }
    _activeSessions.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    const bannerLeft = 12.0;
    const bannerTopBase = 120.0;
    const bannerSpacing = 52.0;

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          alignment: Alignment.topLeft,
          children: [
            // Per-receiver "Sent to" banners stacked on the left.
            for (int i = 0; i < _activeSessions.length; i++)
              Positioned(
                left: bannerLeft,
                top: safeTop + bannerTopBase + _activeSessions[i].index * bannerSpacing,
                child: _buildBanner(_activeSessions[i]),
              ),

            // Flying gift clones.
            ..._activeSessions.map((s) => _buildFlyingGift(s)),
          ],
        ),
      ),
    );
  }

  /// Bigo/Chamet style capsule banner:
  /// [Sender Avatar] → "Sent to" → [Receiver Avatar] [Receiver Name] [Gift] x{count}
  Widget _buildBanner(_GiftFlySession session) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xDD1B5E20), Color(0xDD2E7D32)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sender avatar (left)
          _avatarCircle(session.senderImage, 22),
          const SizedBox(width: 5),
          // "Sent to" text
          const Text(
            'Sent to',
            style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 5),
          // Receiver avatar
          _avatarCircle(session.receiverImage, 22),
          const SizedBox(width: 5),
          // Receiver name
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 72),
            child: Text(
              session.receiverName,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          // Gift image
          if (session.giftImageUrl.isNotEmpty) ...[
            _buildGiftImage(session.giftImageUrl, 26),
            const SizedBox(width: 3),
          ],
          // Count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: session.count > 1 ? const Color(0xFFFFD700) : Colors.white24,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'x${session.count}',
              style: TextStyle(
                color: session.count > 1 ? Colors.black : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarCircle(String imageUrl, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white38, width: 1),
      ),
      child: ClipOval(
        child: imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.white24),
                errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.white54, size: 14),
              )
            : const Icon(Icons.person, color: Colors.white54, size: 14),
      ),
    );
  }

  Widget _buildGiftImage(String imageUrl, double size) {
    final lower = imageUrl.toLowerCase();
    final isSvga = lower.contains('.svga') || lower.contains('/svga');
    final isVideo = lower.contains('.mp4') || lower.contains('.mov') || lower.contains('.webm');

    Widget inner;
    if (isSvga) {
      inner = SvgaPlayer(
        url: imageUrl,
        allowAnimation: false,
        playEmbeddedAudio: false,
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    } else if (isVideo) {
      inner = Container(
        color: const Color(0x66FFD700),
        child: const Icon(Icons.card_giftcard, color: Colors.white, size: 20),
      );
    } else {
      inner = CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.contain,
        memCacheWidth: 120,
        memCacheHeight: 120,
        placeholder: (_, __) => const SizedBox.shrink(),
        errorWidget: (_, __, ___) => Container(
          color: const Color(0x66FFD700),
          child: const Icon(Icons.card_giftcard, color: Colors.white, size: 20),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: inner,
      ),
    );
  }

  Widget _buildFlyingGift(_GiftFlySession session) {
    return AnimatedBuilder(
      animation: session.controller,
      builder: (_, child) {
        final t = session.controller.value;
        final deltaX = session.endX - session.startX;
        final deltaY = session.endY - session.startY;
        final currentX = session.startX + t * deltaX;
        // Small arc for left-to-seat travel.
        final sineOffset = sin(t * pi * 2) * 30;
        final currentY = session.startY + t * deltaY - sineOffset;
        final rotation = t * 4 * pi;
        // Start visible, shrink as it lands in the seat.
        final scale = 0.7 - (t * 0.35);
        final fade = t < 0.9 ? 1.0 : (1.0 - (t - 0.9) / 0.1);

        return Positioned(
          left: currentX - 18,
          top: currentY - 18,
          child: Transform.rotate(
            angle: rotation,
            child: Transform.scale(
              scale: scale.clamp(0.2, 0.7),
              child: Opacity(
                opacity: fade.clamp(0.0, 1.0),
                child: child,
              ),
            ),
          ),
        );
      },
      child: _buildGiftImage(session.giftImageUrl, 36),
    );
  }
}

class _GiftFlySession {
  final int id;
  final int index;
  final String senderName;
  final String senderImage;
  final String receiverName;
  final String receiverImage;
  final int seatPosition;
  final String giftImageUrl;
  final int count;
  final AnimationController controller;
  final VoidCallback onComplete;
  double startX = 0;
  double startY = 0;
  double endX = 0;
  double endY = 0;

  _GiftFlySession({
    required this.id,
    required this.index,
    this.senderName = '',
    this.senderImage = '',
    required this.receiverName,
    required this.receiverImage,
    required this.seatPosition,
    required this.giftImageUrl,
    required this.count,
    required this.controller,
    required this.onComplete,
  });
}
