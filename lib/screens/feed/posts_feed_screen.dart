/// Posts feed screen — shows a paginated list of posts in Facebook-style cards.
///
/// Ports native `FeedAdapter` — displays popular or following posts
/// with full post cards including user info, caption, like/comment/share actions.
library posts_feed;

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/post_root.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../utils/format_utils.dart';
import '../../utils/log.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user_avatar.dart';
import 'package:belive/widgets/preloader.dart';

/// One visual unit below the status bar ("1 sut" gap).
const double _kStatusBarUnitGap = 8.0;

/// Estimated height of the custom frosted bottom navigation bar.
const double _kBottomNavGap = 76.0;

/// Spacing between post cards and the screen edges.
const double _kCardGap = 12.0;

/// Uniform image height for all post cards.
const double _kPostImageHeight = 250.0;

const double _kCardRadius = 20.0;
const double _kImageRadius = 16.0;

const LinearGradient _kFeedBackgroundGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF8F7FF), Color(0xFFEDEBF9)],
);

/// Posts feed screen with [type] parameter (1 = popular, 2 = following).
class PostsFeedScreen extends StatefulWidget {
  const PostsFeedScreen({super.key, this.type = 1});

  /// 1 = popular posts, 2 = following posts.
  final int type;

  @override
  State<PostsFeedScreen> createState() => _PostsFeedScreenState();
}

class _PostsFeedScreenState extends State<PostsFeedScreen>
    with AutomaticKeepAliveClientMixin {
  static const String _tag = 'PostsFeed';

  final _posts = <PostItem>[];
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  int _start = 0;
  bool _hasMore = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _start = 0;
      _hasMore = true;
    });
    final session = context.read<SessionManager>();
    try {
      final res = await ApiService.getPosts(
        userId: session.userId,
        type: widget.type,
        start: 0,
        limit: 20,
      );
      _posts
        ..clear()
        ..addAll(res.post);
      _start = res.post.length;
      _hasMore = res.post.length >= 20;
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final session = context.read<SessionManager>();
    try {
      final res = await ApiService.getPosts(
        userId: session.userId,
        type: widget.type,
        start: _start,
        limit: 20,
      );
      _posts.addAll(res.post);
      _start += res.post.length;
      _hasMore = res.post.length >= 20;
    } catch (e, s) {
      Log.e(_tag, 'loadMore failed', e, s);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final Widget body;
    if (_loading) {
      body = const Center(child: Preloader());
    } else if (_posts.isEmpty) {
      body = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text('No posts yet', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          controller: _scrollController,
          padding: _feedPadding(context),
          itemCount: _posts.length + (_loadingMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: _kCardGap),
          itemBuilder: (_, i) {
            if (i >= _posts.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Preloader(strokeWidth: 2)),
              );
            }
            final post = _posts[i];
            return _postCard(post);
          },
        ),
      );
    }
    return Container(
      decoration: const BoxDecoration(gradient: _kFeedBackgroundGradient),
      child: body,
    );
  }

  /// Top / bottom padding that respects the status bar and the custom
  /// frosted bottom navigation bar, keeping the requested 1-unit gap
  /// below the status bar.
  EdgeInsets _feedPadding(BuildContext context) {
    final media = MediaQuery.of(context);
    final scaffold = Scaffold.maybeOf(context);
    final hasAppBar = scaffold?.widget.appBar != null;
    final hasBottomNav = scaffold?.widget.bottomNavigationBar != null;
    final top =
        hasAppBar ? _kStatusBarUnitGap : media.padding.top + _kStatusBarUnitGap;
    final bottom =
        hasBottomNav ? media.padding.bottom + _kBottomNavGap : _kCardGap;
    return EdgeInsets.fromLTRB(16, top, 16, bottom);
  }

  Widget _postCard(PostItem post) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_kCardRadius),
        boxShadow: [
          // Brand glow.
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.15),
            blurRadius: 18,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
          // Soft depth blur.
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kCardRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _postHeader(post),
                if (post.post != null && post.post!.isNotEmpty)
                  _postImage(post),
                if (post.caption != null && post.caption!.isNotEmpty)
                  _postCaption(post),
                _postStats(post),
                _postActions(post),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _postHeader(PostItem post) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          if (post.isVIP)
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.yellow.withValues(alpha: 0.55),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: UserAvatar(
                imageUrl: post.userImage,
                size: 40,
                frameUrl: post.avatarFrameImage,
              ),
            )
          else
            UserAvatar(
              imageUrl: post.userImage,
              size: 40,
              frameUrl: post.avatarFrameImage,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      post.name ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: post.isVIP ? const Color(0xFFFFD54F) : null,
                      ),
                    ),
                    if (post.isVIP) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified,
                        color: Color(0xFFFFB800),
                        size: 14,
                      ),
                    ],
                  ],
                ),
                Text(
                  post.time ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () => _showPostOptions(post),
          ),
        ],
      ),
    );
  }

  Widget _postImage(PostItem post) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GestureDetector(
        onTap: () => _openPostDetail(post),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kImageRadius),
            boxShadow: [
              // Glow + blur under the image.
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.22),
                blurRadius: 22,
                spreadRadius: -2,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_kImageRadius - 2),
              child: SizedBox(
                height: _kPostImageHeight,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: post.post!,
                  fit: BoxFit.cover,
                  placeholder:
                      (_, __) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(child: Preloader()),
                      ),
                  errorWidget:
                      (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                        ),
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _postCaption(PostItem post) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Text(
        post.caption!,
        style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _postStats(PostItem post) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          if (post.like > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.red, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    formatCount(post.like),
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ],
              ),
            ),
          const Spacer(),
          if (post.comment > 0)
            Text(
              '${formatCount(post.comment)} comments',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textTertiary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _postActions(PostItem post) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.9),
              Colors.white.withValues(alpha: 0.75),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.6),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _actionButton(
                icon:
                    post.isLike == true
                        ? Icons.favorite
                        : Icons.favorite_border,
                color:
                    post.isLike == true ? Colors.red : AppTheme.textSecondary,
                label: 'Like',
                onTap: () => _toggleLike(post),
              ),
              _actionButton(
                icon: Icons.chat_bubble_outline,
                color: AppTheme.textSecondary,
                label: 'Comment',
                onTap: () => _openComments(post),
              ),
              _actionButton(
                icon: Icons.share_outlined,
                color: AppTheme.textSecondary,
                label: 'Share',
                onTap: () => _sharePost(post),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLike(PostItem post) async {
    final session = context.read<SessionManager>();
    // Optimistic update
    final oldLike = post.isLike;
    final oldCount = post.like;
    setState(() {
      post.isLike = !post.isLike;
      post.like = post.like + (post.isLike ? 1 : -1);
    });
    try {
      final res = await ApiService.toggleLikePost(
        userId: session.userId,
        postId: post.id ?? '',
      );
      Log.d(
        _tag,
        'toggleLike response: status=${res.status} msg=${res.message}',
      );
      if (!res.status) {
        // Revert on failure
        if (mounted) {
          setState(() {
            post.isLike = oldLike;
            post.like = oldCount;
          });
          Fluttertoast.showToast(msg: res.message ?? 'Failed to like');
        }
      }
    } catch (e, s) {
      Log.e(_tag, 'toggleLike failed', e, s);
      // Revert on error
      if (mounted) {
        setState(() {
          post.isLike = oldLike;
          post.like = oldCount;
        });
        Fluttertoast.showToast(msg: 'Failed to like post');
      }
    }
  }

  void _openComments(PostItem post) {
    context
        .pushNamed(
          AppRoutes.comments,
          extra: {'postId': post.id ?? '', 'type': 'post'},
        )
        .then((_) {
          // Refresh comment count when returning from comments screen
          _refreshPost(post);
        });
  }

  Future<void> _refreshPost(PostItem post) async {
    final session = context.read<SessionManager>();
    try {
      final res = await ApiService.getPosts(
        userId: session.userId,
        type: widget.type,
        start: 0,
        limit: 20,
      );
      final updated = res.post.where((p) => p.id == post.id).firstOrNull;
      if (updated != null && mounted) {
        setState(() {
          post.comment = updated.comment;
          post.like = updated.like;
          post.isLike = updated.isLike;
        });
      }
    } catch (e) {
      // Silent fail — just refresh
    }
  }

  void _sharePost(PostItem post) {
    final url = post.post ?? '';
    final caption = post.caption ?? '';
    final name = post.name ?? 'Belive User';
    final shareText =
        StringBuffer()
          ..writeln('$name shared a post on Belive')
          ..writeln(caption);
    if (url.isNotEmpty) shareText.writeln(url);
    Share.share(shareText.toString(), subject: 'Belive Post by $name');
  }

  void _openPostDetail(PostItem post) {
    if (post.post != null && post.post!.isNotEmpty) {
      context.pushNamed(AppRoutes.imagePreview, extra: {'url': post.post!});
    }
  }

  void _showPostOptions(PostItem post) {
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.report_outlined),
                  title: const Text('Report'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _reportPost(post);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block),
                  title: const Text('Block User'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _blockUser(post);
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _reportPost(PostItem post) async {
    final session = context.read<SessionManager>();
    try {
      final res = await ApiService.reportThisUser({
        'reporterUserId': session.userId,
        'reportedUserId': post.userId ?? '',
        'reason': 'post_report',
        'postId': post.id ?? '',
      });
      Fluttertoast.showToast(
        msg:
            res.status
                ? 'Reported successfully'
                : res.message ?? 'Report failed',
      );
    } catch (e) {
      Log.e(_tag, 'report failed', e);
      Fluttertoast.showToast(msg: 'Report failed');
    }
  }

  Future<void> _blockUser(PostItem post) async {
    final session = context.read<SessionManager>();
    try {
      await ApiService.blockOrUnblockUser(session.userId, post.userId ?? '');
      Fluttertoast.showToast(msg: 'User blocked');
    } catch (e) {
      Log.e(_tag, 'block failed', e);
      Fluttertoast.showToast(msg: 'Block failed');
    }
  }
}
