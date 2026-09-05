/// Comment & Like list screen â€” shows comments or likes for a post/reel.
///
/// Ports native `CommentLikeListActivity.java`.
library comment_like_list;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../models/comment_models.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

enum CommentLikeViewType { comments, likes }

const String _tag = 'CommentLikeList';

class CommentLikeListScreen extends StatefulWidget {
  const CommentLikeListScreen({
    super.key,
    required this.postId,
    required this.type, // 'post' | 'video'
    required this.viewType,
  });

  final String postId;
  final String type;
  final CommentLikeViewType viewType;

  @override
  State<CommentLikeListScreen> createState() => _CommentLikeListScreenState();
}

class _CommentLikeListScreenState extends State<CommentLikeListScreen> {
  final _items = <CommentItem>[];
  final _commentCtrl = TextEditingController();
  bool _loading = true;
  bool _loadingMore = false;
  int _start = 0;
  bool _hasMore = true;
  bool _sending = false;
  late final String _userId;

  bool get _isComments => widget.viewType == CommentLikeViewType.comments;

  @override
  void initState() {
    super.initState();
    _userId = context.read<SessionManager>().userId;
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loadingMore || !_hasMore) return;
    if (_start == 0) {
      setState(() => _loading = true);
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      if (_isComments) {
        final res = await ApiService.getComments(
          postId: widget.postId,
          start: _start,
          limit: 30,
        );
        _items.addAll(res.data);
        _hasMore = res.data.length >= 30;
      } else {
        final res = await ApiService.getLikeList(
          postId: widget.postId,
          type: widget.type,
          start: _start,
          limit: 30,
        );
        _items.addAll(res.data);
        _hasMore = res.data.length >= 30;
      }
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

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final res = await ApiService.addComment(
        userId: _userId,
        postId: widget.postId,
        comment: text,
      );
      if (res.status) {
        _commentCtrl.clear();
        _start = 0;
        _items.clear();
        _hasMore = true;
        _load();
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Failed to comment');
      }
    } catch (e, s) {
      Log.e(_tag, 'comment failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to comment');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComment(CommentItem item) async {
    try {
      final res = await ApiService.deleteComment(item.id ?? '');
      if (res.status) {
        setState(() => _items.remove(item));
        Fluttertoast.showToast(msg: 'Comment deleted');
      }
    } catch (e, s) {
      Log.e(_tag, 'delete failed', e, s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(_isComments ? 'Comments' : 'Likes')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: Preloader())
                : _items.isEmpty
                    ? Center(
                        child: Text(
                          _isComments ? 'No comments yet' : 'No likes yet',
                          style: TextStyle(color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary),
                        ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n is ScrollEndNotification && n.metrics.pixels >= n.metrics.maxScrollExtent - 100) {
                            _load();
                          }
                          return false;
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _items.length + (_loadingMore ? 1 : 0),
                          separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? AppTheme.surfaceLight : AppTheme.lightBg),
                          itemBuilder: (_, i) {
                            if (i >= _items.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: Preloader(strokeWidth: 2)),
                              );
                            }
                            return _itemTile(isDark, _items[i]);
                          },
                        ),
                      ),
          ),
          if (_isComments) _commentInput(isDark),
        ],
      ),
    );
  }

  Widget _itemTile(bool isDark, CommentItem item) {
    return ListTile(
      onLongPress: () => _confirmDelete(item),
      leading: ClipOval(
        child: CachedNetworkImage(
          imageUrl: item.image ?? '',
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(
            width: 44,
            height: 44,
            color: isDark ? AppTheme.surfaceLight : AppTheme.lightBg,
            child: const Icon(Icons.person, size: 22),
          ),
        ),
      ),
      title: Row(
        children: [
          Text(
            item.name ?? 'Unknown',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
            ),
          ),
          if (item.isVIP) ...[
            const SizedBox(width: 4),
            const Icon(Icons.verified, color: Color(0xFFFFB800), size: 14),
          ],
        ],
      ),
      subtitle: _isComments
          ? Text(
              item.comment ?? '',
              style: TextStyle(color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary),
            )
          : Text(
              item.username ?? '',
              style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary),
            ),
      trailing: Text(
        _formatTime(item.time),
        style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary),
      ),
    );
  }

  Widget _commentInput(bool isDark) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surface : AppTheme.lightSurface,
          border: Border(top: BorderSide(color: isDark ? AppTheme.surfaceLight : AppTheme.lightBg)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentCtrl,
                style: TextStyle(color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary),
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: TextStyle(color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary),
                  filled: true,
                  fillColor: isDark ? AppTheme.surfaceLight : AppTheme.lightBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _sending ? null : _sendComment,
              icon: _sending
                  ? const SizedBox(width: 20, height: 20, child: Preloader(strokeWidth: 2))
                  : const Icon(Icons.send, color: AppTheme.primary),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(CommentItem item) {
    if (item.userId != _userId) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Comment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteComment(item);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '';
    try {
      final dt = DateTime.parse(time);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inHours < 1) return '${diff.inMinutes}m';
      if (diff.inDays == 0) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return time;
    }
  }
}

