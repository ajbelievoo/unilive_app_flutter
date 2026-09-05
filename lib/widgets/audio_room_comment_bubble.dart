/// Audio room comment bubble — renders a single chat comment in the
/// audio room with Bigo-style decorations (VIP frames, gift bubbles,
/// system messages, seat requests, etc.).
library audio_room_comment_bubble;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../utils/media_utils.dart';
import '../utils/vip_privilege_helper.dart';
import 'svga_player_widget.dart';
import 'user_avatar.dart';

/// Immutable data model for a single audio room comment.
class AudioRoomComment {
  const AudioRoomComment({
    this.name,
    this.text,
    this.isMine = false,
    this.isVIP = false,
    this.isGift = false,
    this.isSystem = false,
    this.isAdmin = false,
    this.isHost = false,
    this.isAgency = false,
    this.isBd = false,
    this.imageUrl,
    this.userImage,
    this.frameUrl,
    this.giftImage,
    this.giftReceiverName,
    this.giftReceiverImage,
    this.giftCoin,
    this.giftCount,
    this.isLuckyWin = false,
    this.luckyCoins,
    this.vipStyle,
    this.vipLevel,
    this.chatBubbleId,
    this.levelName,
    this.country,
    this.countryFlagImage,
    this.familyName,
    this.familyBadgeUrl,
    this.userId,
    this.isCard = false,
    this.cardImage,
    this.cardCta,
    this.cardAction,
    this.mentionedUserId,
    this.mentionedUserName,
    this.relationshipType,
    this.cpLevel,
    this.friendLevel,
    this.badgeUrls = const [],
    this.tagLabels = const [],
    this.levelImageUrl,
    this.vipBadgeUrl,
    this.isSeatRequest = false,
    this.seatRequestUserId,
    this.seatRequestPosition,
  });

  final String? name;
  final String? text;
  final bool isMine;
  final bool isVIP;
  final bool isGift;
  final bool isSystem;
  final bool isAdmin;
  final bool isHost;
  final bool isAgency;
  final bool isBd;
  final String? imageUrl;
  final String? userImage;
  final String? frameUrl;
  final String? giftImage;
  final String? giftReceiverName;
  final String? giftReceiverImage;
  final int? giftCoin;
  final int? giftCount;
  final bool isLuckyWin;
  final int? luckyCoins;
  final VipChatStyle? vipStyle;
  final int? vipLevel;
  final int? chatBubbleId;
  final String? levelName;
  final String? country;
  final String? countryFlagImage;
  final String? familyName;
  final String? familyBadgeUrl;
  final String? userId;
  final bool isCard;
  final String? cardImage;
  final String? cardCta;
  final String? cardAction;
  final String? mentionedUserId;
  final String? mentionedUserName;
  final String? relationshipType;
  final int? cpLevel;
  final int? friendLevel;
  final List<String> badgeUrls;
  final List<String> tagLabels;
  final String? levelImageUrl;
  final String? vipBadgeUrl;
  final bool isSeatRequest;
  final String? seatRequestUserId;
  final int? seatRequestPosition;
}

/// Renders a single [AudioRoomComment] as a Bigo-style chat bubble.
class AudioRoomCommentBubble extends StatelessWidget {
  const AudioRoomCommentBubble({
    super.key,
    required this.comment,
    required this.myUserId,
    this.isHost = false,
    this.iAmAdmin = false,
    this.onTapUser,
    this.onAcceptSeatRequest,
    this.onCopy,
    this.onLongPressName,
  });

  final AudioRoomComment comment;
  final String myUserId;
  final bool isHost;
  final bool iAmAdmin;
  final VoidCallback? onTapUser;
  final VoidCallback? onAcceptSeatRequest;
  final VoidCallback? onCopy;
  final VoidCallback? onLongPressName;

  @override
  Widget build(BuildContext context) {
    final c = comment;

    // System / card messages
    if (c.isCard) {
      return _cardBubble(c);
    }
    if (c.isLuckyWin) {
      return _luckyBagBubble(c);
    }
    if (c.isGift) {
      return _giftBubble(c);
    }
    if (c.isSeatRequest) {
      return _seatRequestBubble(c);
    }
    if (c.isSystem) {
      return _systemBubble(c);
    }
    return _normalBubble(c);
  }

  // -------------------------------------------------------------------------
  // Normal chat bubble
  // -------------------------------------------------------------------------
  Widget _normalBubble(AudioRoomComment c) {
    return GestureDetector(
      onLongPress: onCopy,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(c),
            const SizedBox(width: 7),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Identity (name + owner) OUTSIDE and ABOVE the bubble.
                  _identityHeader(c),
                  if (_hasImageBadges(c)) ...[
                    const SizedBox(height: 3),
                    _imageBadges(c),
                  ],
                  if (c.text?.isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    _chatBubbleSurface(
                      c,
                      child: Text(
                        c.text!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Gift bubble — green/gold capsule pill (Bigo/Masti style)
  // -------------------------------------------------------------------------
  Widget _luckyBagBubble(AudioRoomComment c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(c),
          const SizedBox(width: 7),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _identityHeader(c),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF071A38), Color(0xFF0D47A1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF40C4FF).withValues(alpha: 0.65),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/lucky/lucky_bag.png',
                        width: 38,
                        height: 38,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          c.text ?? 'Lucky Bag',
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _giftBubble(AudioRoomComment c) {
    final receiverName = c.giftReceiverName?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar(c),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _identityHeader(c),
                    if (_hasImageBadges(c)) ...[
                      const SizedBox(height: 3),
                      _imageBadges(c),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 39, top: 5),
            child: Container(
              constraints: const BoxConstraints(minWidth: 185, maxWidth: 255),
              padding: const EdgeInsets.fromLTRB(11, 8, 11, 9),
              decoration: BoxDecoration(
                color: const Color(0xFF27232E).withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 0.7,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Sent to\n',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        TextSpan(
                          text:
                              receiverName.isEmpty ? 'Room Host' : receiverName,
                          style: const TextStyle(
                            color: Color(0xFF52E0D0),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (c.giftReceiverImage?.isNotEmpty == true) ...[
                        UserAvatar(imageUrl: c.giftReceiverImage, size: 28),
                        const SizedBox(width: 7),
                      ],
                      if (c.giftImage?.isNotEmpty == true)
                        _giftAsset(c.giftImage!, 52)
                      else
                        const ImageIcon(const AssetImage("assets/gift/official_gift.png"), color: Color(0xFFFFD700), size: 45),
                      const SizedBox(width: 8),
                      Text(
                        'x${c.giftCount ?? 1}',
                        style: const TextStyle(
                          color: Color(0xFFFFD740),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if ((c.giftCoin ?? 0) > 0) ...[
                        const SizedBox(width: 7),
                        Text(
                          '${c.giftCoin}💎',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // System bubble
  // -------------------------------------------------------------------------
  Widget _systemBubble(AudioRoomComment c) {
    final hasUser =
        c.userId?.isNotEmpty == true ||
        c.userImage?.isNotEmpty == true ||
        (c.name?.isNotEmpty == true &&
            c.name != 'System' &&
            c.name != 'Announcement');
    if (!hasUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              c.text ?? '',
              style: const TextStyle(color: Colors.white60, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(c),
          const SizedBox(width: 7),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _identityHeader(c),
                if (_hasImageBadges(c)) ...[
                  const SizedBox(height: 3),
                  _imageBadges(c),
                ],
                if (c.text?.isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 80,
                      minHeight: 36,
                      maxWidth: 240,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF17141F).withValues(alpha: 0.76),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 0.7,
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        c.text!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Card bubble (rich system message with image/CTA)
  // -------------------------------------------------------------------------
  Widget _cardBubble(AudioRoomComment c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            if (c.cardImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: c.cardImage!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorWidget:
                      (_, __, ___) => const Icon(
                        Icons.image,
                        size: 40,
                        color: Colors.white30,
                      ),
                ),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                c.text ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            if (c.cardCta != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6A5AE0), Color(0xFF4F8DFD)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  c.cardCta!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Seat request bubble
  // -------------------------------------------------------------------------
  Widget _seatRequestBubble(AudioRoomComment c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(c),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _identityHeader(c),
                if (_hasImageBadges(c)) ...[
                  const SizedBox(height: 3),
                  _imageBadges(c),
                ],
                const SizedBox(height: 3),
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 80,
                    minHeight: 36,
                    maxWidth: 240,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF17141F).withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Flexible(
                        child: Text(
                          'requested a seat',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                      if (isHost && onAcceptSeatRequest != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onAcceptSeatRequest,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF34C759), Color(0xFF30D158)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Accept',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Built-in VIP chat bubble styles (1-12)
  // -------------------------------------------------------------------------
  Widget _chatBubbleSurface(AudioRoomComment c, {required Widget child}) {
    // Resolve VIP bubble ID: explicit chatBubbleId > vipStyle.chatBubbleId >
    // vipLevel > fallback to 1 if user is VIP (so VIP users always get a
    // styled bubble even if the backend didn't send a level/bubble id).
    int vipId = c.chatBubbleId ?? c.vipStyle?.chatBubbleId ?? c.vipLevel ?? 0;
    if (vipId <= 0 && (c.isVIP || c.vipStyle?.isVip == true)) {
      vipId = 1; // Default VIP bubble for VIP users without a level.
    }
    vipId = vipId.clamp(0, 12);

    const constraints = BoxConstraints(
      minWidth: 80,
      minHeight: 36,
      maxWidth: 240,
    );
    const padding = EdgeInsets.symmetric(horizontal: 14, vertical: 8);

    if (vipId >= 1 && vipId <= 12) {
      return _AnimatedVipBubble(
        id: vipId,
        constraints: constraints,
        padding: padding,
        child: child,
      );
    }

    // Default non-VIP translucent bubble.
    return Container(
      constraints: constraints,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF17141F).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.7,
        ),
      ),
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }

  Widget _identityHeader(AudioRoomComment c) {
    final nameColor =
        c.vipStyle?.effectiveNameColor ??
        (c.isAdmin ? const Color(0xFFFF8A80) : Colors.white);
    final name = c.name?.isNotEmpty == true ? c.name! : 'User';
    return GestureDetector(
      onTap: onTapUser,
      onLongPress: onLongPressName,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: nameColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
          if (c.isHost) ...[
            const SizedBox(width: 5),
            _badgePill('Owner', const [Color(0xFF7E57C2), Color(0xFF9575CD)]),
          ] else if (c.isAdmin) ...[
            const SizedBox(width: 5),
            _badgePill('Admin', const [Color(0xFF1565C0), Color(0xFF42A5F5)]),
          ],
        ],
      ),
    );
  }

  bool _hasImageBadges(AudioRoomComment c) {
    return c.countryFlagImage?.isNotEmpty == true ||
        c.familyBadgeUrl?.isNotEmpty == true ||
        c.badgeUrls.where((u) => u.trim().isNotEmpty).isNotEmpty;
  }

  /// Image badge row: level/vip/medal images from badgeUrls, then country
  /// and family flags. Preserves the backend order for badgeUrls.
  Widget _imageBadges(AudioRoomComment c) {
    final urls =
        <String>[
          ...c.badgeUrls.where((u) => u.trim().isNotEmpty),
          if (c.countryFlagImage?.isNotEmpty == true) c.countryFlagImage!,
          if (c.familyBadgeUrl?.isNotEmpty == true) c.familyBadgeUrl!,
        ].take(10).toList();
    if (urls.isEmpty) return const SizedBox.shrink();

    final images = urls.map((u) => _imageBadge(u)).toList();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 24),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (_, i) => images[i],
      ),
    );
  }

  Widget _badgePill(String label, List<Color> gradientColors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 7.5,
          fontWeight: FontWeight.w700,
          height: 1.05,
        ),
      ),
    );
  }

  Widget _imageBadge(String rawUrl) {
    final isSvga = SvgaHelper.isSvgaUrl(rawUrl);
    final url =
        isSvga
            ? VideoUtil.getFullSvgaUrl(rawUrl)
            : VideoUtil.getFullImageUrl(rawUrl);
    if (url.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: 24,
      height: 24,
      child:
          isSvga
              ? SvgaPlayer(
                url: url,
                width: 24,
                height: 24,
                allowAnimation: true,
                repeat: true,
              )
              : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
    );
  }

  Widget _avatar(AudioRoomComment c) {
    return GestureDetector(
      onTap: onTapUser,
      onLongPress: onLongPressName,
      child: UserAvatar(
        imageUrl: c.userImage,
        frameUrl: c.frameUrl,
        size: 32,
        isVIP: c.isVIP,
        vipBadgeUrl: c.vipBadgeUrl,
      ),
    );
  }

  Widget _giftAsset(String rawUrl, double size) {
    final isSvga = SvgaHelper.isSvgaUrl(rawUrl);
    final url =
        isSvga
            ? VideoUtil.getFullSvgaUrl(rawUrl)
            : VideoUtil.getFullImageUrl(rawUrl);
    if (url.isEmpty) {
      return ImageIcon(const AssetImage("assets/gift/official_gift.png"), color: const Color(0xFFFFD700), size: size);
    }
    return SizedBox(
      width: size,
      height: size,
      child:
          isSvga
              ? SvgaPlayer(
                url: url,
                width: size,
                height: size,
                fit: BoxFit.contain,
                // Show first frame only (no animation) in comments —
                // shows the gift's theme without the GPU cost of running
                // many SVGA decoders in the comment list.
                allowAnimation: false,
                repeat: false,
              )
              : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                errorWidget:
                    (_, __, ___) => const ImageIcon(const AssetImage("assets/gift/official_gift.png"), color: Color(0xFFFFD700), size: 40),
              ),
    );
  }
}

// ---------------------------------------------------------------------------
// 12 built-in VIP chat bubble styles with animation
// ---------------------------------------------------------------------------

/// Animated VIP chat bubble with shimmer / glow / pulse effects.
class _AnimatedVipBubble extends StatefulWidget {
  const _AnimatedVipBubble({
    required this.id,
    required this.constraints,
    required this.padding,
    required this.child,
  });

  final int id;
  final BoxConstraints constraints;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  State<_AnimatedVipBubble> createState() => _AnimatedVipBubbleState();
}

class _AnimatedVipBubbleState extends State<_AnimatedVipBubble>
    with TickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final AnimationController _glowCtrl;
  late final Animation<double> _shimmer;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _shimmer = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));
    _glow = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = _VipBubbleStyles.byId(widget.id);
    return AnimatedBuilder(
      animation: Listenable.merge([_shimmer, _glow]),
      builder: (context, _) {
        return Container(
          constraints: widget.constraints,
          padding: widget.padding,
          decoration: _buildDecoration(style),
          child: Stack(
            children: [
              // Shimmer sweep overlay
              if (style.hasShimmer)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: _ShimmerSweep(progress: _shimmer.value),
                  ),
                ),
              // Text content
              Align(
                alignment: Alignment.centerLeft,
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: style.textColor,
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: style.textWeight,
                    shadows: style.textShadow,
                  ),
                  child: widget.child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  BoxDecoration _buildDecoration(_VipBubbleStyle style) {
    // Animated glow: pulse the box shadow alpha.
    final glowVal = _glow.value;
    final baseShadow = style.glowShadow;
    final animatedShadow =
        baseShadow == null
            ? null
            : <BoxShadow>[
              BoxShadow(
                color: baseShadow.color.withValues(
                  alpha: baseShadow.color.a * glowVal,
                ),
                blurRadius: baseShadow.blurRadius * (0.7 + glowVal * 0.5),
                spreadRadius: baseShadow.spreadRadius,
              ),
            ];

    return style.decoration.copyWith(boxShadow: animatedShadow);
  }
}

/// Horizontal shimmer sweep — a translucent white gradient that sweeps
/// across the bubble from left to right.
class _ShimmerSweep extends StatelessWidget {
  const _ShimmerSweep({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _ShimmerPainter(progress: progress),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  _ShimmerPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final sweepW = w * 0.35;
    final x = progress * w;

    final shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.topRight,
      colors: [
        Colors.white.withValues(alpha: 0.0),
        Colors.white.withValues(alpha: 0.15),
        Colors.white.withValues(alpha: 0.35),
        Colors.white.withValues(alpha: 0.15),
        Colors.white.withValues(alpha: 0.0),
      ],
      stops: [0.0, 0.35, 0.5, 0.65, 1.0],
    ).createShader(Rect.fromLTWH(x - sweepW, 0, sweepW * 2, h));

    final paint = Paint()..shader = shader;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.progress != progress;
}

class _VipBubbleStyles {
  static _VipBubbleStyle byId(int id) {
    switch (id) {
      case 1:
        // VIP 1: Emerald Green Glass
        return _VipBubbleStyle(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
              colors: [Color(0xFF00E676), Color(0xFF00C853), Color(0xFF1B5E20)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFFB9F6CA).withValues(alpha: 0.7),
              width: 1,
            ),
          ),
          glowShadow: const BoxShadow(
            color: Color(0xFF00E676),
            blurRadius: 10,
            spreadRadius: 1,
          ),
          textColor: Colors.white,
          hasShimmer: true,
        );
      case 2:
        // VIP 2: Metallic Golden Empire
        return _VipBubbleStyle(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF8E1), Color(0xFFFFC107), Color(0xFF8D6E63)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFFFFE082), width: 1.2),
          ),
          glowShadow: const BoxShadow(
            color: Color(0xFFFFECB3),
            blurRadius: 10,
            spreadRadius: 1,
          ),
          textColor: const Color(0xFF4E342E),
          hasShimmer: true,
        );
      case 3:
        // VIP 3: Royal Amethyst Purple
        return _VipBubbleStyle(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
              colors: [Color(0xFF8E24AA), Color(0xFF4A148C), Color(0xFF311B92)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFFEA80FC).withValues(alpha: 0.7),
              width: 1,
            ),
          ),
          glowShadow: const BoxShadow(
            color: Color(0xFFE040FB),
            blurRadius: 10,
            spreadRadius: 1,
          ),
          textColor: Colors.white,
          hasShimmer: true,
        );
      case 4:
        // VIP 4: Crimson Flame
        return _VipBubbleStyle(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
              colors: [Color(0xFFFF1744), Color(0xFFD50000), Color(0xFF880E4F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFFFF8A80).withValues(alpha: 0.7),
              width: 1,
            ),
          ),
          glowShadow: const BoxShadow(
            color: Color(0xFFFF5252),
            blurRadius: 10,
            spreadRadius: 1,
          ),
          textColor: Colors.white,
          hasShimmer: true,
        );
      case 5:
        // VIP 5: Emerald Jade
        return _VipBubbleStyle(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
              colors: [Color(0xFF00E676), Color(0xFF00897B), Color(0xFF004D40)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFFB9F6CA).withValues(alpha: 0.7),
              width: 1,
            ),
          ),
          glowShadow: const BoxShadow(
            color: Color(0xFF69F0AE),
            blurRadius: 10,
            spreadRadius: 1,
          ),
          textColor: Colors.white,
          hasShimmer: true,
        );
      case 6:
        // VIP 6: Ocean Aqua Wave
        return _VipBubbleStyle(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
              colors: [Color(0xFF00B0FF), Color(0xFF0091EA), Color(0xFF01579B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFF40C4FF).withValues(alpha: 0.7),
              width: 1,
            ),
          ),
          glowShadow: const BoxShadow(
            color: Color(0xFF80D8FF),
            blurRadius: 10,
            spreadRadius: 1,
          ),
          textColor: Colors.white,
          hasShimmer: true,
        );
      case 7:
        // VIP 7: Sakura Pink
        return _VipBubbleStyle(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
              colors: [Color(0xFFFF80AB), Color(0xFFF06292), Color(0xFFC2185B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFFFFCDD2).withValues(alpha: 0.7),
              width: 1,
            ),
          ),
          glowShadow: const BoxShadow(
            color: Color(0xFFF8BBD0),
            blurRadius: 10,
            spreadRadius: 1,
          ),
          textColor: Colors.white,
          hasShimmer: true,
        );
      case 8:
        // VIP 8: Cyberpunk Neon
        return _VipBubbleStyle(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
              colors: [Color(0xFF00E5FF), Color(0xFF651FFF), Color(0xFF212121)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFF7C4DFF).withValues(alpha: 0.8),
              width: 1.2,
            ),
          ),
          glowShadow: const BoxShadow(
            color: Color(0xFF18FFFF),
            blurRadius: 12,
            spreadRadius: 1,
          ),
          textColor: Colors.white,
          textShadow: const [Shadow(color: Color(0xFF00E5FF), blurRadius: 4)],
          hasShimmer: true,
        );
      case 9:
        // VIP 9: Solar Gold Flare
        return _VipBubbleStyle(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFEA00), Color(0xFFFFD600), Color(0xFFFF6F00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFFFFFF8D), width: 1.2),
          ),
          glowShadow: const BoxShadow(
            color: Color(0xFFFFF59D),
            blurRadius: 12,
            spreadRadius: 1,
          ),
          textColor: const Color(0xFF3E2723),
          hasShimmer: true,
        );
      case 10:
        // VIP 10: Platinum Chrome
        return _VipBubbleStyle(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
              colors: [Color(0xFFE0E0E0), Color(0xFFBDBDBD), Color(0xFF757575)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFFFFFFFF).withValues(alpha: 0.8),
              width: 1.2,
            ),
          ),
          glowShadow: const BoxShadow(
            color: Color(0xFFFFFFFF),
            blurRadius: 12,
            spreadRadius: 1,
          ),
          textColor: const Color(0xFF212121),
          hasShimmer: true,
        );
      case 11:
        // VIP 11: Rainbow Border
        return _VipBubbleStyle(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFF1744),
                Color(0xFFFF9100),
                Color(0xFFFFEA00),
                Color(0xFF00E676),
                Color(0xFF00B0FF),
                Color(0xFF651FFF),
                Color(0xFFD500F9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 1.2,
            ),
          ),
          glowShadow: const BoxShadow(
            color: Color(0xFFFFFFFF),
            blurRadius: 10,
            spreadRadius: 1,
          ),
          textColor: Colors.white,
          textShadow: const [Shadow(color: Colors.black54, blurRadius: 3)],
          hasShimmer: true,
        );
      case 12:
        // VIP 12: Ultimate Cosmic Galaxy
        return _VipBubbleStyle(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1A237E),
                Color(0xFF311B92),
                Color(0xFF6200EA),
                Color(0xFF00BCD4),
                Color(0xFF18FFFF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFF80D8FF).withValues(alpha: 0.8),
              width: 1.2,
            ),
          ),
          glowShadow: const BoxShadow(
            color: Color(0xFF18FFFF),
            blurRadius: 14,
            spreadRadius: 1,
          ),
          textColor: Colors.white,
          textShadow: const [Shadow(color: Color(0xFF18FFFF), blurRadius: 4)],
          hasShimmer: true,
        );
      default:
        return _VipBubbleStyle(
          decoration: BoxDecoration(
            color: const Color(0xFF17141F).withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(11),
          ),
          textColor: Colors.white,
        );
    }
  }
}

class _VipBubbleStyle {
  const _VipBubbleStyle({
    required this.decoration,
    required this.textColor,
    this.textShadow = const [],
    this.textWeight = FontWeight.w600,
    this.glowShadow,
    this.hasShimmer = false,
  });

  final BoxDecoration decoration;
  final Color textColor;
  final List<Shadow> textShadow;
  final FontWeight textWeight;
  final BoxShadow? glowShadow;
  final bool hasShimmer;
}
