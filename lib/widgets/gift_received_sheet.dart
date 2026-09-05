/// Gift received sheet — shows gifts received during a live/audio room session.
///
/// Ports native `GiftReceiveAdapter` — a small panel showing the list of
/// gifts the host has received during the current live stream.
library gift_received_sheet;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../constants/const.dart';
import '../models/json_annotation_helper.dart';
import '../services/api_service.dart';
import '../utils/log.dart';
import '../utils/media_utils.dart';
import 'package:belive/widgets/preloader.dart';

const String _tag = 'GiftReceivedSheet';

/// Shows the gift received bottom sheet for a live room.
void showGiftReceivedSheet(
  BuildContext context, {
  required String liveStreamingId,
  required String hostUserId,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GiftReceivedSheet(
      liveStreamingId: liveStreamingId,
      hostUserId: hostUserId,
    ),
  );
}

class _GiftReceivedSheet extends StatefulWidget {
  const _GiftReceivedSheet({
    required this.liveStreamingId,
    required this.hostUserId,
  });

  final String liveStreamingId;
  final String hostUserId;

  @override
  State<_GiftReceivedSheet> createState() => _GiftReceivedSheetState();
}

class _GiftReceivedSheetState extends State<_GiftReceivedSheet> {
  List<_ReceivedGift> _gifts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchGifts();
  }

  Future<void> _fetchGifts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getReceivedGifts(widget.hostUserId);
      if (data['status'] == true) {
        final list = data['gift'] ?? data['data'] ?? data['history'];
        if (list is List) {
          setState(() {
            _gifts = list
                .map((e) => _ReceivedGift.fromJson(e is Map ? Map<String, dynamic>.from(e) : {}))
                .toList();
            _loading = false;
          });
          return;
        }
      }
      setState(() {
        _gifts = [];
        _loading = false;
      });
    } catch (e, s) {
      Log.e(_tag, 'fetch gifts failed', e, s);
      setState(() {
        _error = 'Failed to load gifts';
        _loading = false;
      });
    }
  }

  int get _totalCoins =>
      _gifts.fold(0, (sum, g) => sum + (g.coin * g.count).toInt());

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF7E3FF2), Color(0xFFE91E63)]),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF7E3FF2), Color(0xFFE91E63)]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const ImageIcon(const AssetImage("assets/gift/official_gift.png"), color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Gifts Received',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (_gifts.isNotEmpty)
                            Text(
                              '${_gifts.length} types • $_totalCoins ${Const.coinName}',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Body
          Expanded(
            child: _loading
                ? const Center(child: Preloader(color: Color(0xFF7E3FF2)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, style: const TextStyle(color: Colors.white54)),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _fetchGifts,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _gifts.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ImageIcon(const AssetImage("assets/gift/official_gift.png"), color: Colors.white24, size: 48),
                                SizedBox(height: 8),
                                Text('No gifts received yet', style: TextStyle(color: Colors.white54, fontSize: 14)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchGifts,
                            color: const Color(0xFF7E3FF2),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                              itemCount: _gifts.length,
                              itemBuilder: (_, i) => _GiftTile(gift: _gifts[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _GiftTile extends StatelessWidget {
  const _GiftTile({required this.gift});
  final _ReceivedGift gift;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _isSafeImageUrl(gift.image)
                ? CachedNetworkImage(
                    imageUrl: VideoUtil.getFullImageUrl(gift.image),
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => _giftIconPlaceholder(),
                    errorWidget: (_, __, ___) => _giftIconPlaceholder(),
                  )
                : _giftIconPlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gift.name ?? 'Gift',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'From ${gift.senderName ?? 'User'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'x${gift.count}',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Image.asset(Const.diamondIconAsset, width: 12, height: 12),
                  const SizedBox(width: 3),
                  Text(
                    '${(gift.coin * gift.count).toInt()}',
                    style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Returns true only for regular image URLs — never SVGA or video.
  /// Prevents Android ImageDecoder crashes when gift.image is actually an
  /// SVGA/MP4 URL (the backend sometimes stores the animation URL there).
  bool _isSafeImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final lower = url.toLowerCase();
    return !lower.contains('.svga') &&
        !lower.contains('/svga') &&
        !lower.endsWith('.mp4') &&
        !lower.endsWith('.mov') &&
        !lower.endsWith('.webm');
  }

  Widget _giftIconPlaceholder() {
    return Container(
      color: const Color(0xFF7E3FF2).withValues(alpha: 0.15),
      width: 48,
      height: 48,
      child: const ImageIcon(const AssetImage("assets/gift/official_gift.png"), color: Color(0xFF7E3FF2), size: 24),
    );
  }
}

class _ReceivedGift {
  const _ReceivedGift({
    this.name = '',
    this.image = '',
    this.count = 0,
    this.coin = 0,
    this.senderName = '',
  });

  final String? name;
  final String? image;
  final int count;
  final double coin;
  final String? senderName;

  factory _ReceivedGift.fromJson(Map<String, dynamic> json) => _ReceivedGift(
        name: parseString(json['name'] ?? json['giftName']),
        image: parseString(json['image'] ?? json['giftImage'] ?? json['icon']),
        count: parseInt(json['count'] ?? json['quantity'] ?? json['totalCount'], 0),
        coin: parseDouble(json['coin'] ?? json['price'] ?? json['giftCoin'], 0),
        senderName: parseString(json['senderName'] ?? json['userName'] ?? json['fromUserName']),
      );
}
