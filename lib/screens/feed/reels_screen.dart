import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../models/reel_root.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../utils/format_utils.dart';
import '../../utils/log.dart';
import '../../widgets/user_avatar.dart';
import 'package:belive/widgets/preloader.dart';

/// Ported from native reels/video list.
///
/// Vertical paging reel list with video playback, like toggle,
/// comments navigation, and share.
class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  static const String _tag = 'Reels';
  final _reels = <ReelItem>[];
  bool _loading = true;
  bool _loadingMore = false;
  int _start = 0;
  static const int _limit = 10;
  bool _hasMore = true;
  final _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.getReels(
        userId: session.userId,
        start: 0,
        limit: _limit,
      );
      _reels
        ..clear()
        ..addAll(res.video);
      _start = _reels.length;
      _hasMore = res.video.length >= _limit;
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.getReels(
        userId: session.userId,
        start: _start,
        limit: _limit,
      );
      _reels.addAll(res.video);
      _start = _reels.length;
      _hasMore = res.video.length >= _limit;
    } catch (e, s) {
      Log.e(_tag, 'loadMore failed', e, s);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _toggleLike(int index) async {
    final reel = _reels[index];
    final session = context.read<SessionManager>();
    final wasLike = reel.isLike;
    setState(() {
      reel.isLike = !wasLike;
      reel.like += wasLike ? -1 : 1;
    });
    try {
      await ApiService.toggleLikeReel(
        userId: session.userId,
        reelId: reel.id ?? '',
      );
    } catch (e, s) {
      Log.e(_tag, 'toggleLike failed', e, s);
      if (mounted) {
        setState(() {
          reel.isLike = wasLike;
          reel.like += wasLike ? 1 : -1;
        });
      }
    }
  }

  Future<void> _deleteReel(int index) async {
    final reel = _reels[index];
    final session = context.read<SessionManager>();
    // Only allow deleting own reels
    if (reel.userId != session.userId) {
      Fluttertoast.showToast(msg: 'You can only delete your own reels');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Reel'),
            content: const Text('Are you sure you want to delete this reel?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.deleteReel(reel.id ?? '');
      if (mounted) {
        setState(() => _reels.removeAt(index));
        Fluttertoast.showToast(msg: 'Reel deleted');
      }
    } catch (e, s) {
      Log.e(_tag, 'deleteReel failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to delete reel');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: Preloader());
    if (_reels.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_library, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No reels yet', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: _reels.length + (_hasMore ? 1 : 0),
      onPageChanged: (i) {
        if (i >= _reels.length - 2 && _hasMore) _loadMore();
      },
      itemBuilder: (_, i) {
        if (i >= _reels.length) {
          return const Center(child: Preloader());
        }
        return _ReelView(
          reel: _reels[i],
          onLike: () => _toggleLike(i),
          onUserTap:
              () => context.pushNamed(
                AppRoutes.guestProfile,
                extra: {'userId': _reels[i].userId},
              ),
          onDelete: () => _deleteReel(i),
        );
      },
    );
  }
}

class _ReelView extends StatefulWidget {
  const _ReelView({
    required this.reel,
    required this.onLike,
    required this.onUserTap,
    this.onDelete,
  });
  final ReelItem reel;
  final VoidCallback onLike;
  final VoidCallback onUserTap;
  final VoidCallback? onDelete;

  @override
  State<_ReelView> createState() => _ReelViewState();
}

class _ReelViewState extends State<_ReelView>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isPlaying = false;
  bool _showHeart = false;
  late AnimationController _heartAnim;

  @override
  void initState() {
    super.initState();
    _heartAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _initVideo();
  }

  Future<void> _initVideo() async {
    final url = widget.reel.video;
    if (url == null || url.isEmpty) return;
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.play();
      if (mounted) {
        setState(() {
          _initialized = true;
          _isPlaying = true;
        });
      }
    } catch (e) {
      Log.e('ReelView', 'video init failed', e);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _heartAnim.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_controller == null || !_initialized) return;
    setState(() {
      if (_isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
    });
  }

  void _doubleTapLike() {
    if (!widget.reel.isLike) {
      widget.onLike();
    }
    setState(() => _showHeart = true);
    _heartAnim.forward(from: 0).then((_) {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  void _openComments() {
    context.pushNamed(
      AppRoutes.comments,
      extra: {'reelId': widget.reel.id, 'type': 'reel'},
    );
  }

  void _shareReel() {
    final reel = widget.reel;
    Share.share(
      'Check out this reel by @${reel.name} on Belive!',
      subject: 'Belive Reel',
    );
  }

  @override
  Widget build(BuildContext context) {
    final reel = widget.reel;
    return Stack(
      alignment: Alignment.topLeft,
      fit: StackFit.expand,
      children: [
        // Video or thumbnail with double-tap.
        if (_initialized && _controller != null)
          GestureDetector(
            onTap: _togglePlay,
            onDoubleTap: _doubleTapLike,
            onLongPress: widget.onDelete,
            child: Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),
          )
        else if ((reel.thumbnail ?? '').isNotEmpty)
          GestureDetector(
            onDoubleTap: _doubleTapLike,
            onLongPress: widget.onDelete,
            child: CachedNetworkImage(
              imageUrl: reel.thumbnail!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(color: Colors.black),
            ),
          )
        else
          GestureDetector(
            onLongPress: widget.onDelete,
            child: Container(color: Colors.black),
          ),

        // Gradient overlay
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black45],
              stops: [0.6, 1.0],
            ),
          ),
        ),

        // Double-tap heart animation.
        if (_showHeart)
          Center(
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.5, end: 1.5).animate(
                CurvedAnimation(parent: _heartAnim, curve: Curves.elasticOut),
              ),
              child: FadeTransition(
                opacity: Tween<double>(
                  begin: 1.0,
                  end: 0.0,
                ).animate(_heartAnim),
                child: const Icon(Icons.favorite, color: Colors.red, size: 100),
              ),
            ),
          ),

        // Play/pause indicator
        if (_initialized && !_isPlaying)
          const Center(
            child: Icon(Icons.play_arrow, size: 80, color: Colors.white70),
          ),

        // Right action bar
        Positioned(
          right: 12,
          bottom: 100,
          child: Column(
            children: [
              UserAvatar(imageUrl: reel.userImage, size: 44, isVIP: reel.isVIP),
              const SizedBox(height: 16),
              IconButton(
                icon: Icon(
                  reel.isLike ? Icons.favorite : Icons.favorite_border,
                  color: reel.isLike ? Colors.red : Colors.white,
                  size: 32,
                ),
                onPressed: widget.onLike,
              ),
              Text(
                formatCount(reel.like),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(height: 16),
              IconButton(
                icon: const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: _openComments,
              ),
              Text(
                formatCount(reel.comment),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(height: 16),
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white, size: 28),
                onPressed: _shareReel,
              ),
            ],
          ),
        ),

        // Bottom info
        Positioned(
          left: 16,
          right: 80,
          bottom: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: widget.onUserTap,
                child: Row(
                  children: [
                    Text(
                      '@${reel.name ?? ''}',
                      style: TextStyle(
                        color:
                            reel.isVIP ? const Color(0xFFFFD54F) : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (reel.isVIP)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.star,
                          color: Color(0xFFFFD54F),
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              if ((reel.caption ?? '').isNotEmpty)
                Text(
                  reel.caption!,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              if (reel.hashtag.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children:
                      reel.hashtag
                          .take(5)
                          .map(
                            (t) => GestureDetector(
                              onTap:
                                  () => context.pushNamed(
                                    AppRoutes.hashtagSearch,
                                  ),
                              child: Text(
                                '#$t',
                                style: const TextStyle(
                                  color: Color(0xFF7E3FF2),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ],
              if ((reel.song?.title ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.music_note,
                      color: Colors.white70,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${reel.song!.singer ?? ''} - ${reel.song!.title}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
