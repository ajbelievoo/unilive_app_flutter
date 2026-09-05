/// Feed grid screen â€” shows user's posts in a grid layout.
///
/// Ports native `FeedGridActivity.java`.
library feed_grid;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../models/post_root.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

const String _tag = 'FeedGrid';

class FeedGridScreen extends StatefulWidget {
  const FeedGridScreen({super.key, this.userId});

  /// If null, uses the logged-in user's ID.
  final String? userId;

  @override
  State<FeedGridScreen> createState() => _FeedGridScreenState();
}

class _FeedGridScreenState extends State<FeedGridScreen> {
  final _posts = <PostItem>[];
  bool _loading = true;
  bool _loadingMore = false;
  int _start = 0;
  bool _hasMore = true;
  late final String _userId;

  @override
  void initState() {
    super.initState();
    _userId = widget.userId ?? context.read<SessionManager>().userId;
    _load();
  }

  Future<void> _load() async {
    if (_loadingMore || !_hasMore) return;
    if (_start == 0) {
      setState(() => _loading = true);
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final res = await ApiService.getUserPosts(
        userId: _userId,
        start: _start,
        limit: 30,
      );
      _posts.addAll(res.post);
      _hasMore = res.post.length >= 30;
      _start += 30;
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _delete(PostItem post) async {
    try {
      final res = await ApiService.deletePost(post.id ?? '');
      if (res.status) {
        setState(() => _posts.remove(post));
        Fluttertoast.showToast(msg: 'Post deleted');
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Failed to delete');
      }
    } catch (e, s) {
      Log.e(_tag, 'delete failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to delete');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('My Posts')),
      body:
          _loading
              ? const Center(child: Preloader())
              : _posts.isEmpty
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.grid_view_outlined,
                      size: 48,
                      color:
                          isDark ? AppTheme.textTertiary : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No posts yet',
                      style: TextStyle(
                        color:
                            isDark
                                ? AppTheme.textSecondary
                                : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              )
              : NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n is ScrollEndNotification &&
                      n.metrics.pixels >= n.metrics.maxScrollExtent - 100) {
                    _load();
                  }
                  return false;
                },
                child: GridView.builder(
                  padding: const EdgeInsets.all(4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  itemCount: _posts.length + (_loadingMore ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i >= _posts.length) {
                      return const Center(child: Preloader(strokeWidth: 2));
                    }
                    final p = _posts[i];
                    return GestureDetector(
                      onLongPress: () => _confirmDelete(p),
                      child: Stack(
                        alignment: Alignment.topLeft,
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: p.post ?? '',
                            fit: BoxFit.cover,
                            errorWidget:
                                (_, __, ___) => Container(
                                  color:
                                      isDark
                                          ? AppTheme.surfaceLight
                                          : AppTheme.lightBg,
                                  child: const Icon(Icons.image, size: 24),
                                ),
                          ),
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.favorite,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${p.like}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
    );
  }

  void _confirmDelete(PostItem post) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Post?'),
            content: const Text('Are you sure you want to delete this post?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _delete(post);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }
}
