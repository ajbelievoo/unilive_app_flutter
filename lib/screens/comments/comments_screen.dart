import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../models/comment_models.dart';
import '../../models/follow_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../utils/log.dart';
import '../../widgets/user_avatar.dart';
import 'package:belive/widgets/preloader.dart';

/// Ported from native `CommentLikeListActivity.java`.
///
/// Phase 4 implementation: paginated comments list with send field.
/// Also supports likes list (read-only) when [viewType] is `likes`.
class CommentsScreen extends StatefulWidget {
  const CommentsScreen({
    super.key,
    required this.postId,
    this.type = 'post',
    this.viewType = CommentViewType.comments,
  });

  final String postId;
  final String type; // 'post' | 'video'
  final CommentViewType viewType;

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

enum CommentViewType { comments, likes }

class _CommentsScreenState extends State<CommentsScreen> {
  static const String _tag = 'Comments';

  static CommentItem _followUserToCommentItem(FollowUser u) => CommentItem(
        id: u.id,
        userId: u.id,
        name: u.name,
        username: u.username,
        image: u.image,
        avatarFrameImage: u.avatarFrameImage,
        isVIP: u.isVIP,
      );

  static CommentItem _commentItemFromPostComment(CommentItem c) => c;

  final _items = <CommentItem>[];
  final _ctrl = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  int _start = 0;
  static const int _limit = 30;
  bool _hasMore = true;

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
    _ctrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (widget.viewType == CommentViewType.comments) {
        if (widget.type == 'reel') {
          final session = context.read<SessionManager>();
          final res = await ApiService.getReelComments(userId: session.userId, videoId: widget.postId);
          _items
            ..clear()
            ..addAll(res.data);
        } else {
          final res = await ApiService.getComments(postId: widget.postId);
          _items
            ..clear()
            ..addAll(res.data);
        }
      } else {
        if (widget.type == 'reel') {
          final session = context.read<SessionManager>();
          final res = await ApiService.getReelLikes(userId: session.userId, videoId: widget.postId);
          _items
            ..clear()
            ..addAll(res.data.map(_commentItemFromPostComment));
        } else {
          final res = await ApiService.getLikes(postId: widget.postId);
          _items
            ..clear()
            ..addAll(res.users.map(_followUserToCommentItem));
        }
      }
      _start = _items.length;
      _hasMore = _items.length >= _limit;
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      List<CommentItem> newItems;
      if (widget.viewType == CommentViewType.comments) {
        if (widget.type == 'reel') {
          final session = context.read<SessionManager>();
          final res = await ApiService.getReelComments(userId: session.userId, videoId: widget.postId, start: _start);
          newItems = res.data;
        } else {
          final res = await ApiService.getComments(postId: widget.postId, start: _start);
          newItems = res.data;
        }
      } else {
        if (widget.type == 'reel') {
          final session = context.read<SessionManager>();
          final res = await ApiService.getReelLikes(userId: session.userId, videoId: widget.postId, start: _start);
          newItems = res.data.map(_commentItemFromPostComment).toList();
        } else {
          final res = await ApiService.getLikes(postId: widget.postId, start: _start);
          newItems = res.users.map(_followUserToCommentItem).toList();
        }
      }
      _items.addAll(newItems);
      _start = _items.length;
      _hasMore = newItems.length >= _limit;
    } catch (e, s) {
      Log.e(_tag, 'loadMore failed', e, s);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    setState(() => _sending = true);
    final session = context.read<SessionManager>();
    final user = context.read<AuthProvider>().user;
    // Optimistic add.
    final temp = CommentItem(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      userId: session.userId,
      name: user?.name,
      image: user?.image,
      avatarFrameImage: user?.avatarFrameImage,
      comment: text,
      time: 'now',
      isVIP: user?.isVIP ?? false,
    );
    setState(() {
      _items.add(temp);
      _sending = false;
    });
    _scrollToBottom();
    try {
      final res = await ApiService.addComment(userId: session.userId, postId: widget.postId, comment: text);
      Log.d(_tag, 'addComment response: status=${res.status} msg=${res.message}');
      if (!res.status) {
        if (mounted) {
          setState(() => _items.remove(temp));
          Fluttertoast.showToast(msg: res.message ?? 'Failed to send comment');
        }
      }
    } catch (e, s) {
      Log.e(_tag, 'send failed', e, s);
      if (mounted) {
        setState(() => _items.remove(temp));
        Fluttertoast.showToast(msg: 'Failed to send comment');
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isComments = widget.viewType == CommentViewType.comments;
    return Scaffold(
      appBar: AppBar(
        title: Text(isComments ? 'Comments (${_items.length})' : 'Likes (${_items.length})'),
      ),
      body: Column(children: [
        Expanded(child: _buildList()),
        if (isComments) _buildInputBar(),
      ]),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: Preloader());
    if (_items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(widget.viewType == CommentViewType.comments ? Icons.chat_bubble_outline : Icons.favorite_border,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(widget.viewType == CommentViewType.comments ? 'No comments yet' : 'No likes yet',
              style: TextStyle(color: Colors.grey.shade600)),
        ]),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _items.length + (_loadingMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= _items.length) {
          return const Padding(padding: EdgeInsets.all(16), child: Center(child: Preloader(strokeWidth: 2)));
        }
        final c = _items[i];
        return ListTile(
          leading: UserAvatar(imageUrl: c.image, frameUrl: c.avatarFrameImage, size: 36, isVIP: c.isVIP),
          title: Text(c.name ?? 'User', style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: c.isVIP ? const Color(0xFFFFD54F) : null,
          )),
          subtitle: c.comment == null
              ? null
              : Text(c.comment!, style: const TextStyle(fontSize: 13)),
          trailing: Text(c.time ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendComment(),
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          CircleAvatar(
            backgroundColor: const Color(0xFF7E3FF2),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              onPressed: _sending ? null : _sendComment,
            ),
          ),
        ]),
      ),
    );
  }
}
