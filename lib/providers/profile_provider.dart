import 'package:flutter/foundation.dart';

import '../models/user_root.dart';
import '../models/guest_profile_root.dart';
import '../models/level_summary_models.dart';
import '../models/fans_ranking_root.dart';
import '../models/follow_models.dart';
import '../services/api_service.dart';
import '../utils/log.dart';

class ProfileProvider extends ChangeNotifier {
  static const String _tag = 'ProfileProvider';

  User? _user;
  User? get user => _user;

  GuestProfileRoot? _guestProfile;
  GuestProfileRoot? get guestProfile => _guestProfile;

  LevelSummaryRoot? _levelSummary;
  LevelSummaryRoot? get levelSummary => _levelSummary;

  final List<FansRankingGroup> _fansRanking = [];
  List<FansRankingGroup> get fansRanking => _fansRanking;

  final List<FollowUser> _followers = [];
  List<FollowUser> get followers => _followers;

  final List<FollowUser> _following = [];
  List<FollowUser> get following => _following;

  final List<FollowUser> _blockedUsers = [];
  List<FollowUser> get blockedUsers => _blockedUsers;

  bool _loading = false;
  bool get loading => _loading;

  void setUser(User? user) {
    _user = user;
    notifyListeners();
  }

  Future<User?> refreshUser(String userId) async {
    try {
      final res = await ApiService.getUser({'userId': userId});
      if (res.status && res.user != null) {
        _user = res.user;
        notifyListeners();
        return res.user;
      }
    } catch (e, s) {
      Log.e(_tag, 'refreshUser failed', e, s);
    }
    return null;
  }

  Future<void> loadGuestProfile(String userId) async {
    _loading = true;
    notifyListeners();
    try {
      _guestProfile = await ApiService.getGuestProfile(userId);
    } catch (e, s) {
      Log.e(_tag, 'loadGuestProfile failed', e, s);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadGuestProfileByUsername(String username) async {
    _loading = true;
    notifyListeners();
    try {
      _guestProfile = await ApiService.getGuestProfileByUsername(username);
    } catch (e, s) {
      Log.e(_tag, 'loadGuestProfileByUsername failed', e, s);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadLevelSummary(String userId) async {
    try {
      _levelSummary = await ApiService.getLevelSummary(userId);
    } catch (e, s) {
      Log.e(_tag, 'loadLevelSummary failed', e, s);
    }
    notifyListeners();
  }

  Future<void> loadFansRanking(String userId, {String type = 'all'}) async {
    try {
      final res = await ApiService.getFansRanking(userId: userId, type: type, limit: 50);
      _fansRanking
        ..clear()
        ..addAll(res.data);
    } catch (e, s) {
      Log.e(_tag, 'loadFansRanking failed', e, s);
    }
    notifyListeners();
  }

  Future<void> loadFollowers(String userId) async {
    try {
      final res = await ApiService.followerList(userId: userId, limit: 50);
      _followers
        ..clear()
        ..addAll(res.users);
    } catch (e, s) {
      Log.e(_tag, 'loadFollowers failed', e, s);
    }
    notifyListeners();
  }

  Future<void> loadFollowing(String userId) async {
    try {
      final res = await ApiService.followingList(userId: userId, limit: 50);
      _following
        ..clear()
        ..addAll(res.users);
    } catch (e, s) {
      Log.e(_tag, 'loadFollowing failed', e, s);
    }
    notifyListeners();
  }

  Future<void> loadBlockedUsers(String userId) async {
    try {
      final res = await ApiService.getBlockedUsers(userId: userId, limit: 50);
      _blockedUsers
        ..clear()
        ..addAll(res.users);
    } catch (e, s) {
      Log.e(_tag, 'loadBlockedUsers failed', e, s);
    }
    notifyListeners();
  }

  Future<bool> followUnfollow({
    required String userId,
    required String toUserId,
  }) async {
    try {
      final res = await ApiService.followUnfollow({
        'userId': userId,
        'toUserId': toUserId,
      });
      return res.status;
    } catch (e, s) {
      Log.e(_tag, 'followUnfollow failed', e, s);
      return false;
    }
  }

  Future<bool> blockUnblock({
    required String userId,
    required String blockUserId,
  }) async {
    try {
      final res = await ApiService.blockUnblock(
        userId: userId,
        blockUserId: blockUserId,
      );
      if (res.status) {
        await loadBlockedUsers(userId);
        notifyListeners();
      }
      return res.status;
    } catch (e, s) {
      Log.e(_tag, 'blockUnblock failed', e, s);
      return false;
    }
  }
}
