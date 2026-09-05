/// Live room gift stats overlay — top gifters panel + host earnings + gift wall.
///
/// Tracks gifts in real-time from socket events and displays:
/// 1. Top 3 gifters panel on the right side (with avatars + coins sent)
/// 2. Host earnings counter badge (total diamonds received this stream)
/// 3. Gift wall bottom sheet (recent gifts list) on tap
///
/// Ports native `topGifterLayout` from `HostPKLiveActivity.java`.
library live_gift_stats_overlay;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/session_manager.dart';
import '../utils/format_utils.dart' show diamondsToBeans;
import '../utils/log.dart';
import '../utils/media_utils.dart';
import 'gift_overlay.dart';
import 'svga_player_widget.dart';

/// A single gifter entry tracked in real-time.
class GifterEntry {
  final String userId;
  final String name;
  final String image;
  int totalCoins;

  GifterEntry({
    required this.userId,
    required this.name,
    required this.image,
    this.totalCoins = 0,
  });
}

/// A single gift history entry for the gift wall.
class GiftWallEntry {
  final String senderName;
  final String senderImage;
  final String giftName;
  final String giftImage;
  final int coins;
  final int count;
  final DateTime time;

  GiftWallEntry({
    required this.senderName,
    required this.senderImage,
    required this.giftName,
    required this.giftImage,
    required this.coins,
    required this.count,
    required this.time,
  });
}

/// Controller that tracks gift stats and feeds them to the overlay.
class LiveGiftStatsController {
  final _gifters = <String, GifterEntry>{}; // keyed by userId
  final _giftWall = <GiftWallEntry>[];
  int _hostEarnings = 0;
  int _totalGiftCount = 0;
  void Function()? _onUpdate;

  void attach(void Function() onUpdate) => _onUpdate = onUpdate;
  void detach() => _onUpdate = null;

  /// Record a gift event — called from socket listeners.
  void recordGift(GiftEvent event) {
    Log.d('LiveGiftStats', 'recordGift: ${event.senderName} id=${event.senderId} coins=${event.coin * event.count}');
    // Track gifter by sender ID; fallback to sender name for older backends.
    final senderId = event.senderId.isNotEmpty ? event.senderId : event.senderName;
    if (senderId.isNotEmpty) {
      final entry = _gifters[senderId] ?? GifterEntry(
        userId: senderId,
        name: event.senderName,
        image: event.senderImage,
      );
      entry.totalCoins += event.coin * event.count;
      _gifters[senderId] = entry;
    }

    // Track host earnings and total gift count.
    _hostEarnings += event.coin * event.count;
    _totalGiftCount += event.count;

    // Add to gift wall (keep last 50).
    _giftWall.insert(0, GiftWallEntry(
      senderName: event.senderName,
      senderImage: event.senderImage,
      giftName: event.giftName,
      giftImage: event.giftImage,
      coins: event.coin * event.count,
      count: event.count,
      time: DateTime.now(),
    ));
    if (_giftWall.length > 50) _giftWall.removeLast();

    _onUpdate?.call();
  }

  List<GifterEntry> get topGifters {
    final list = _gifters.values.toList()
      ..sort((a, b) => b.totalCoins.compareTo(a.totalCoins));
    return list.take(3).toList();
  }

  int get hostEarnings => _hostEarnings;
  int get totalGiftCount => _totalGiftCount;
  List<GiftWallEntry> get giftWall => List.unmodifiable(_giftWall);

  /// Set authoritative host earnings (e.g. from backend hostEarningUpdate).
  void setHostEarnings(int totalCoins) {
    _hostEarnings = totalCoins;
    _onUpdate?.call();
  }

  /// Add to host earnings (used by local tracking).
  void addHostEarnings(int coins) {
    _hostEarnings += coins;
    _onUpdate?.call();
  }

  /// Replace local top gifters with server-authoritative list.
  void setTopGifters(List<GifterEntry> gifters) {
    _gifters.clear();
    for (final g in gifters) {
      _gifters[g.userId] = g;
    }
    _onUpdate?.call();
  }
}

/// Top gifters panel + host earnings badge overlay.
class LiveGiftStatsOverlay extends StatefulWidget {
  const LiveGiftStatsOverlay({super.key, required this.controller, this.isHost = false});

  final LiveGiftStatsController controller;
  final bool isHost;

  @override
  State<LiveGiftStatsOverlay> createState() => _LiveGiftStatsOverlayState();
}

class _LiveGiftStatsOverlayState extends State<LiveGiftStatsOverlay> {
  @override
  void initState() {
    super.initState();
    widget.controller.attach(_onUpdate);
  }

  @override
  void dispose() {
    widget.controller.detach();
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  void _openGiftWall() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _GiftWallSheet(
        giftWall: widget.controller.giftWall,
        topGifters: widget.controller.topGifters,
        // Convert host earnings (diamonds) to beans using backend config.
        hostEarnings: diamondsToBeans(
            widget.controller.hostEarnings,
            context.read<SessionManager>().getSetting()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).viewPadding.top;
    final topGifters = widget.controller.topGifters;
    // Show beans (backend credits `diamondToRcoin` beans per diamond).
    final earnings = diamondsToBeans(
        widget.controller.hostEarnings,
        context.read<SessionManager>().getSetting());

    return Positioned(
      top: (topPad == 0 ? 12 : topPad + 6) + 130,
      right: 8,
      child: GestureDetector(
        onTap: _openGiftWall,
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with trophy icon + host earnings.
              Row(
                children: [
                  const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _formatCoins(earnings),
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Top gifters list.
              if (topGifters.isEmpty)
                const SizedBox.shrink()
              else
                for (int i = 0; i < topGifters.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Text(
                          '#${i + 1}',
                          style: TextStyle(
                            color: i == 0
                                ? const Color(0xFFFFD700)
                                : (i == 1 ? Colors.grey : const Color(0xFFFFA000)),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        ClipOval(
                          child: topGifters[i].image.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: VideoUtil.getFullImageUrl(topGifters[i].image),
                                  width: 16,
                                  height: 16,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 32,
                                  memCacheHeight: 32,
                                  errorWidget: (_, __, ___) => _avatarPlaceholder(16),
                                )
                              : _avatarPlaceholder(16),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            topGifters[i].name,
                            style: const TextStyle(color: Colors.white, fontSize: 9),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
              if (topGifters.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Tap for gift wall',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 8),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.white24,
      child: Icon(Icons.person, color: Colors.white54, size: size * 0.6),
    );
  }

  static String _formatCoins(int coins) {
    if (coins >= 1000000) return '${(coins / 1000000).toStringAsFixed(1)}M';
    if (coins >= 1000) return '${(coins / 1000).toStringAsFixed(1)}K';
    return '$coins';
  }
}

/// Gift wall bottom sheet — shows recent gifts + top gifters + host earnings.
class _GiftWallSheet extends StatelessWidget {
  const _GiftWallSheet({
    required this.giftWall,
    required this.topGifters,
    required this.hostEarnings,
  });

  final List<GiftWallEntry> giftWall;
  final List<GifterEntry> topGifters;
  final int hostEarnings;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header.
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 24),
              const SizedBox(width: 8),
              const Text(
                'Gift Wall',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF6B00)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.diamond, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      _formatCoins(hostEarnings),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Top gifters section.
          if (topGifters.isNotEmpty) ...[
            const Text(
              'Top Gifters',
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: topGifters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) {
                  final gifter = topGifters[i];
                  final rankColor = i == 0
                      ? const Color(0xFFFFD700)
                      : (i == 1 ? Colors.grey : const Color(0xFFFFA000));
                  return Column(
                    children: [
                      Stack(
                        alignment: Alignment.topLeft,
                        children: [
                          ClipOval(
                            child: gifter.image.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: VideoUtil.getFullImageUrl(gifter.image),
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 80,
                                    memCacheHeight: 80,
                                    errorWidget: (_, __, ___) => Container(
                                      width: 40,
                                      height: 40,
                                      color: Colors.white24,
                                      child: const Icon(Icons.person, color: Colors.white54),
                                    ),
                                  )
                                : Container(
                                    width: 40,
                                    height: 40,
                                    color: Colors.white24,
                                    child: const Icon(Icons.person, color: Colors.white54),
                                  ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: rankColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '#${i + 1}',
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatCoins(gifter.totalCoins),
                        style: TextStyle(color: rankColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Recent gifts list.
          const Text(
            'Recent Gifts',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: giftWall.isEmpty
                ? const Center(
                    child: Text('Gift wall is empty', style: TextStyle(color: Colors.white54, fontSize: 14)),
                  )
                : ListView.separated(
                    itemCount: giftWall.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
                    itemBuilder: (ctx, i) {
                      final gift = giftWall[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            // Sender avatar.
                            ClipOval(
                              child: gift.senderImage.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: VideoUtil.getFullImageUrl(gift.senderImage),
                                      width: 32,
                                      height: 32,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 64,
                                      memCacheHeight: 64,
                                      errorWidget: (_, __, ___) => Container(
                                        width: 32,
                                        height: 32,
                                        color: Colors.white24,
                                        child: const Icon(Icons.person, color: Colors.white54, size: 16),
                                      ),
                                    )
                                  : Container(
                                      width: 32,
                                      height: 32,
                                      color: Colors.white24,
                                      child: const Icon(Icons.person, color: Colors.white54, size: 16),
                                    ),
                            ),
                            const SizedBox(width: 8),
                            // Sender name + gift name.
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    gift.senderName,
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'sent ${gift.giftName}${gift.count > 1 ? ' x${gift.count}' : ''}',
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            // Gift image.
                            if (gift.giftImage.isNotEmpty)
                              Builder(builder: (_) {
                                final img = VideoUtil.getFullImageUrl(gift.giftImage);
                                final isSvga = img.toLowerCase().contains('.svga') || img.toLowerCase().contains('/svga');
                                if (isSvga) {
                                  return SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: SvgaPlayer(
                                      url: img,
                                      allowAnimation: false,
                                      playEmbeddedAudio: false,
                                      width: 28,
                                      height: 28,
                                      fit: BoxFit.contain,
                                    ),
                                  );
                                }
                                return CachedNetworkImage(
                                  imageUrl: img,
                                  width: 28,
                                  height: 28,
                                  fit: BoxFit.contain,
                                  memCacheWidth: 56,
                                  memCacheHeight: 56,
                                  errorWidget: (_, __, ___) => const ImageIcon(const AssetImage("assets/gift/official_gift.png"), color: Colors.white54, size: 20),
                                );
                              }),
                            const SizedBox(width: 8),
                            // Beans received for this gift (backend converts
                            // diamonds → beans using `diamondToRcoin` config).
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.diamond, color: Color(0xFFFFB800), size: 14),
                                const SizedBox(width: 2),
                                Text(
                                  _formatCoins(diamondsToBeans(
                                      gift.coins,
                                      context.read<SessionManager>().getSetting())),
                                  style: const TextStyle(color: Color(0xFFFFB800), fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static String _formatCoins(int coins) {
    if (coins >= 1000000) return '${(coins / 1000000).toStringAsFixed(1)}M';
    if (coins >= 1000) return '${(coins / 1000).toStringAsFixed(1)}K';
    return '$coins';
  }
}
