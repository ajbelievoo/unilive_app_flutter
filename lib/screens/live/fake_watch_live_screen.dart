/// Fake Watch Live screen — plays a pre-recorded video URL as if it were a
/// live stream. Ports native `FakeWatchLiveActivity.java`.
///
/// Used when a live-list entry has `isFake == true` and a `link` field
/// pointing to a video file. The video loops continuously (like a live
/// stream), with host info, comments overlay, gift button, and share.
library fake_watch_live;

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../constants/const.dart';
import '../../models/live_user_root.dart' as live_user;
import '../../routes/app_routes.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import '../../utils/media_utils.dart';
import '../../widgets/gift_bottom_sheet.dart';
import '../../widgets/gift_overlay.dart';
import '../../widgets/user_avatar.dart';
import 'package:belive/widgets/preloader.dart';

/// Pre-recorded video played as a fake live stream.
class FakeWatchLiveScreen extends StatefulWidget {
  const FakeWatchLiveScreen({super.key, required this.host});

  /// The fake host entry from the live list (must have `link` set).
  final live_user.LiveUser host;

  @override
  State<FakeWatchLiveScreen> createState() => _FakeWatchLiveScreenState();
}

class _FakeWatchLiveScreenState extends State<FakeWatchLiveScreen> {
  static const String _tag = 'FakeWatch';

  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _playerReady = false;
  bool _playerError = false;

  // Comments
  final _comments = <_FakeComment>[];
  final _scrollController = ScrollController();
  final _commentCtrl = TextEditingController();
  Timer? _demoCommentTimer;

  // Gift overlay
  final _giftController = GiftQueueController();

  // Viewer count (fake, increments slowly)
  int _viewCount = 0;
  Timer? _viewTimer;

  @override
  void initState() {
    super.initState();
    _viewCount = widget.host.view > 0 ? widget.host.view : 100;
    _initPlayer();
    _startDemoComments();
    _startViewCounter();
  }

  Future<void> _initPlayer() async {
    final url = widget.host.link ?? '';
    if (url.isEmpty) {
      Log.e(_tag, 'No video link for fake host ${widget.host.id}');
      if (mounted) setState(() => _playerError = true);
      return;
    }

    Log.d(_tag, 'Initializing fake watch video: $url');
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url));

    try {
      await _videoController.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: true, // Repeat forever like a live stream
        showControls: false, // No seek bar — it's "live"
        aspectRatio: _videoController.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        },
      );
      if (mounted) setState(() => _playerReady = true);
    } catch (e, s) {
      Log.e(_tag, 'Video init failed', e, s);
      if (mounted) setState(() => _playerError = true);
    }
  }

  void _startDemoComments() {
    // Simulate live comments appearing periodically.
    const demoNames = [
      'User123', 'Aisha', 'Rahul', 'Sara', 'Mike',
      'Priya', 'John', 'Fatima', 'Li Wei', 'David',
    ];
    const demoTexts = [
      'Nice stream!', 'Hello from India', 'Wow amazing',
      'Where are you from?', 'Hi', 'So cool', 'Love this',
      'Send gift!', '👍👍👍', 'Hello everyone',
    ];
    _demoCommentTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final i = DateTime.now().millisecondsSinceEpoch ~/ 4000;
      setState(() {
        _comments.insert(0, _FakeComment(
          name: demoNames[i % demoNames.length],
          text: demoTexts[i % demoTexts.length],
        ));
        if (_comments.length > 50) _comments.removeLast();
      });
    });
  }

  void _startViewCounter() {
    _viewTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      setState(() => _viewCount += 1 + DateTime.now().millisecond % 3);
    });
  }

  void _sendComment() {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final session = context.read<SessionManager>();
    setState(() {
      _comments.insert(0, _FakeComment(
        name: session.userName,
        text: text,
        isMe: true,
        imageUrl: session.userImage,
      ));
      if (_comments.length > 50) _comments.removeLast();
    });
    _commentCtrl.clear();
  }

  void _openGifts() {
    GiftBottomSheet.show(
      context,
      receiverId: widget.host.id,
      liveStreamingId: widget.host.liveStreamingId,
      type: 'live',
      onGiftSent: ({
        required String giftId,
        required String giftName,
        required String giftImage,
        String? svgaImage,
        int giftType = 1,
        required int count,
        required int totalCoins,
        bool isLucky = false,
      }) {
        // Show gift animation overlay locally.
        final session = context.read<SessionManager>();
        final event = GiftEvent(
          giftId: giftId,
          giftName: giftName,
          giftImage: giftImage,
          svgaImage: svgaImage,
          giftType: giftType,
          coin: totalCoins,
          senderName: session.userName,
          senderImage: session.userImage,
          receiverName: widget.host.name ?? 'Host',
          count: count,
        );
        _giftController.addGift(event);
      },
    );
  }

  void _shareLive() {
    final link = '${Const.baseUrl}live/${widget.host.liveStreamingId ?? widget.host.id}';
    Share.share('Watch ${widget.host.name ?? 'host'} live! $link');
  }

  void _exit() {
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _demoCommentTimer?.cancel();
    _viewTimer?.cancel();
    _scrollController.dispose();
    _commentCtrl.dispose();
    _chewieController?.dispose();
    _videoController.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // --- Video layer (fills entire screen) ---
          _buildVideoLayer(),

          // --- Demo banner ---
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 6,
                bottom: 6,
                left: 16,
                right: 16,
              ),
              color: Colors.orange.withValues(alpha: 0.85),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'DEMO — pre-recorded stream',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Top bar (host info + close) ---
          Positioned(
            top: MediaQuery.of(context).padding.top + 36,
            left: 12,
            right: 12,
            child: _buildTopBar(),
          ),

          // --- Comments overlay (left side, bottom) ---
          Positioned(
            left: 12,
            bottom: 80,
            child: _buildCommentsOverlay(),
          ),

          // --- Gift overlay ---
          Positioned.fill(
            child: GiftOverlay(controller: _giftController),
          ),

          // --- Bottom bar ---
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoLayer() {
    if (_playerError) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Stream link not available',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _exit,
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_playerReady || _chewieController == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Preloader(color: Colors.white54),
        ),
      );
    }

    // Use a BoxConstraints to force the video to fill the screen
    // (chewie normally respects aspect ratio; for "live" we want fill).
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _videoController.value.size.width,
          height: _videoController.value.size.height,
          child: Chewie(controller: _chewieController!),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        // Close button
        GestureDetector(
          onTap: _exit,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.black38,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 22),
          ),
        ),
        const SizedBox(width: 10),
        // Host avatar + name
        Expanded(
          child: GestureDetector(
            onTap: () {
              final hostId = widget.host.id ?? '';
              if (hostId.isNotEmpty) {
                context.pushNamed(AppRoutes.guestProfile, extra: {'userId': hostId});
              }
            },
            child: Row(
              children: [
                UserAvatar(
                  imageUrl: widget.host.image,
                  size: 38,
                  isVIP: widget.host.isVIP,
                  frameUrl: widget.host.avatarFrameImage,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.host.name ?? 'Demo Host',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.visibility, color: Colors.white70, size: 13),
                          const SizedBox(width: 3),
                          Text(
                            '$_viewCount',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Share button
        GestureDetector(
          onTap: _shareLive,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.black38,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.share, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsOverlay() {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.65,
      height: 220,
      child: ListView.builder(
        reverse: true,
        controller: _scrollController,
        padding: EdgeInsets.zero,
        itemCount: _comments.length,
        itemBuilder: (_, i) {
          final c = _comments[i];
          return _buildCommentBubble(c);
        },
      ),
    );
  }

  Widget _buildCommentBubble(_FakeComment c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c.imageUrl != null && c.imageUrl!.isNotEmpty)
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: VideoUtil.getFullImageUrl(c.imageUrl),
                width: 24,
                height: 24,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.grey.shade700),
                errorWidget: (_, __, ___) => Container(
                  width: 24, height: 24, color: Colors.grey.shade700,
                  child: const Icon(Icons.person, color: Colors.white38, size: 16),
                ),
              ),
            )
          else
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white38, size: 16),
            ),
          const SizedBox(width: 6),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${c.name}: ',
                      style: TextStyle(
                        color: c.isMe ? AppTheme.primary : Colors.orangeAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    TextSpan(
                      text: c.text,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: [
          // Comment input
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _commentCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Say something...',
                  hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white70, size: 20),
                    onPressed: _sendComment,
                  ),
                ),
                onSubmitted: (_) => _sendComment(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Gift button
          GestureDetector(
            onTap: _openGifts,
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: const ImageIcon(const AssetImage("assets/gift/official_gift.png"), color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

/// A simple comment model for the fake watch screen.
class _FakeComment {
  _FakeComment({
    required this.name,
    required this.text,
    this.isMe = false,
    this.imageUrl,
  });

  final String name;
  final String text;
  final bool isMe;
  final String? imageUrl;
}
