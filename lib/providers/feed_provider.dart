import 'package:flutter/foundation.dart';

import '../models/post_root.dart';
import '../models/reel_root.dart';
import '../services/api_service.dart';
import '../utils/log.dart';

class FeedProvider extends ChangeNotifier {
  static const String _tag = 'FeedProvider';

  final List<PostItem> _posts = [];
  List<PostItem> get posts => _posts;

  final List<ReelItem> _reels = [];
  List<ReelItem> get reels => _reels;

  bool _loading = false;
  bool get loading => _loading;

  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;

  bool _hasMorePosts = true;
  bool _hasMoreReels = true;
  int _postStart = 0;
  int _reelStart = 0;

  int _feedType = 1;

  Future<void> loadPosts({
    required String userId,
    int type = 1,
    bool refresh = false,
  }) async {
    _feedType = type;
    if (refresh) {
      _postStart = 0;
      _hasMorePosts = true;
    }
    if (_loading && !refresh) return;
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.getPosts(
        userId: userId,
        type: type,
        start: 0,
        limit: 20,
      );
      _posts
        ..clear()
        ..addAll(res.post);
      _postStart = res.post.length;
      _hasMorePosts = res.post.length >= 20;
    } catch (e, s) {
      Log.e(_tag, 'loadPosts failed', e, s);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMorePosts({required String userId}) async {
    if (_loadingMore || !_hasMorePosts) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final res = await ApiService.getPosts(
        userId: userId,
        type: _feedType,
        start: _postStart,
        limit: 20,
      );
      _posts.addAll(res.post);
      _postStart += res.post.length;
      _hasMorePosts = res.post.length >= 20;
    } catch (e, s) {
      Log.e(_tag, 'loadMorePosts failed', e, s);
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadReels({
    required String userId,
    String type = 'all',
    bool refresh = false,
  }) async {
    if (refresh) {
      _reelStart = 0;
      _hasMoreReels = true;
    }
    if (_loading && !refresh) return;
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.getReels(
        userId: userId,
        type: type,
        start: 0,
        limit: 20,
      );
      _reels
        ..clear()
        ..addAll(res.video);
      _reelStart = res.video.length;
      _hasMoreReels = res.video.length >= 20;
    } catch (e, s) {
      Log.e(_tag, 'loadReels failed', e, s);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreReels({required String userId}) async {
    if (_loadingMore || !_hasMoreReels) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final res = await ApiService.getReels(
        userId: userId,
        start: _reelStart,
        limit: 20,
      );
      _reels.addAll(res.video);
      _reelStart += res.video.length;
      _hasMoreReels = res.video.length >= 20;
    } catch (e, s) {
      Log.e(_tag, 'loadMoreReels failed', e, s);
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  void togglePostLike(String postId) {
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx >= 0) {
      final post = _posts[idx];
      _posts[idx] = PostItem(
        id: post.id,
        userId: post.userId,
        name: post.name,
        userImage: post.userImage,
        avatarFrameImage: post.avatarFrameImage,
        caption: post.caption,
        post: post.post,
        location: post.location,
        like: post.isLike ? post.like - 1 : post.like + 1,
        comment: post.comment,
        isLike: !post.isLike,
        isVIP: post.isVIP,
        allowComment: post.allowComment,
        createdAt: post.createdAt,
        time: post.time,
      );
      notifyListeners();
    }
  }

  void toggleReelLike(String reelId) {
    final idx = _reels.indexWhere((r) => r.id == reelId);
    if (idx >= 0) {
      final reel = _reels[idx];
      _reels[idx] = ReelItem(
        id: reel.id,
        userId: reel.userId,
        name: reel.name,
        userImage: reel.userImage,
        avatarFrameImage: reel.avatarFrameImage,
        caption: reel.caption,
        video: reel.video,
        thumbnail: reel.thumbnail,
        screenshot: reel.screenshot,
        location: reel.location,
        like: reel.isLike ? reel.like - 1 : reel.like + 1,
        comment: reel.comment,
        showVideo: reel.showVideo,
        isLike: !reel.isLike,
        isVIP: reel.isVIP,
        allowComment: reel.allowComment,
        isOriginalAudio: reel.isOriginalAudio,
        hashtag: reel.hashtag,
        mentionPeople: reel.mentionPeople,
        time: reel.time,
        song: reel.song,
      );
      notifyListeners();
    }
  }

  void removePost(String postId) {
    _posts.removeWhere((p) => p.id == postId);
    notifyListeners();
  }

  void removeReel(String reelId) {
    _reels.removeWhere((r) => r.id == reelId);
    notifyListeners();
  }
}
