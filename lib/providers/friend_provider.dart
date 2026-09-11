import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/cp_models.dart';
import '../models/friend_models.dart';
import '../models/json_annotation_helper.dart';
import '../services/api_service.dart';
import '../services/socket_handlers.dart';
import '../utils/log.dart';

/// State management for the Friend system.
///
/// Mirrors [CpProvider] but for platonic friend relationships (max 9).
class FriendProvider extends ChangeNotifier {
  static const String _tag = 'FriendProvider';
  static const int maxFriends = 9;

  StreamSubscription? _friendRequestSub;
  StreamSubscription? _friendLevelUpSub;
  StreamSubscription? _friendIntimacySub;

  final _intimacyFlyController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get intimacyFlyStream => _intimacyFlyController.stream;

  final List<FriendItem> _friends = [];
  List<FriendItem> get friends => _friends;

  final List<FriendRequest> _incomingRequests = [];
  List<FriendRequest> get incomingRequests => _incomingRequests;

  final List<FriendRequest> _outgoingRequests = [];
  List<FriendRequest> get outgoingRequests => _outgoingRequests;

  final List<FriendLevel> _levels = [];
  List<FriendLevel> get levels => _levels;

  final List<FriendRankItem> _ranking = [];
  List<FriendRankItem> get ranking => _ranking;

  final List<FriendHistoryItem> _history = [];
  List<FriendHistoryItem> get history => _history;

  final List<FriendPrivilege> _privileges = [];
  List<FriendPrivilege> get privileges => _privileges;

  final List<FriendRing> _rings = [];
  List<FriendRing> get rings => _rings;

  final List<FriendRequest> _discover = [];
  List<FriendRequest> get discover => _discover;

  // ---- Friend tasks + anniversaries (Bigo-style engagement) -------------
  final List<CPTask> _tasks = [];
  List<CPTask> get tasks => _tasks;

  final List<CPMilestone> _anniversaries = [];
  List<CPMilestone> get anniversaries => _anniversaries;

  bool _loading = false;
  bool get loading => _loading;

  int get friendCount => _friends.length;
  int get availableSlots => maxFriends - _friends.length;
  bool get canAddMore => _friends.length < maxFriends;

  int get pendingCount =>
      _incomingRequests.where((r) => r.status == 'pending').length;

  /// Highest friend bond level the current user has (for global UI like
  /// privileges / level table). Defaults to 1 when the user has no friends.
  int get maxFriendLevel {
    if (_friends.isEmpty) return 1;
    return _friends.map((f) => f.level).reduce((a, b) => a > b ? a : b);
  }

  /// Highest intimacy among all friends (for global progress UI).
  int get maxFriendIntimacy {
    if (_friends.isEmpty) return 0;
    return _friends.map((f) => f.intimacy).reduce((a, b) => a > b ? a : b);
  }

  /// Returns relationship info if the given user is one of our friends.
  Map<String, dynamic>? getRelationshipWith(String otherUserId) {
    for (final f in _friends) {
      if (f.user1?.id == otherUserId || f.user2?.id == otherUserId) {
        return {
          'type': 'friend',
          'level': f.level,
        };
      }
    }
    return null;
  }

  /// Subscribe to real-time socket events for Friend.
  void initSocketListeners(String userId) {
    _friendRequestSub?.cancel();
    _friendLevelUpSub?.cancel();
    _friendIntimacySub?.cancel();
    try {
      final socket = SocketHandlers.instance;
      _friendRequestSub = socket.friendRequestStream.listen((_) {
        loadRequests(userId);
        notifyListeners();
      });
      _friendLevelUpSub = socket.friendLevelUpStream.listen((data) {
        final friendshipId = data['friendshipId'] as String?;
        if (friendshipId != null) {
          loadFriends(userId);
        }
        notifyListeners();
      });
      _friendIntimacySub = socket.friendIntimacyStream.listen((data) {
        final friendshipId = data['friendshipId'] as String?;
        if (friendshipId != null) {
          final intimacy = parseInt(data['intimacy'], 0);
          final delta = parseInt(data['delta'], 0);
          if (intimacy > 0) {
            final idx = _friends.indexWhere((f) => f.id == friendshipId);
            if (idx >= 0) {
              _friends[idx] = _friends[idx].copyWith(intimacy: intimacy);
            }
          }
          if (delta > 0) {
            _intimacyFlyController.add(data);
          }
          notifyListeners();
        }
      });
    } catch (e) {
      Log.e(_tag, 'initSocketListeners failed', e);
    }
  }

  @override
  void dispose() {
    _friendRequestSub?.cancel();
    _friendLevelUpSub?.cancel();
    _friendIntimacySub?.cancel();
    _intimacyFlyController.close();
    super.dispose();
  }

  Future<void> loadFriends(String userId) async {
    try {
      final res = await ApiService.getMyFriends(userId);
      _friends
        ..clear()
        ..addAll(res.data);
    } catch (e, s) {
      Log.e(_tag, 'loadFriends failed', e, s);
    }
    notifyListeners();
  }

  Future<void> loadRequests(String userId) async {
    try {
      final incoming = await ApiService.getFriendRequests(userId: userId, type: 'incoming');
      final outgoing = await ApiService.getFriendRequests(userId: userId, type: 'outgoing');
      _incomingRequests
        ..clear()
        ..addAll(incoming.requests);
      _outgoingRequests
        ..clear()
        ..addAll(outgoing.requests);
    } catch (e, s) {
      Log.e(_tag, 'loadRequests failed', e, s);
    }
    notifyListeners();
  }

  Future<void> loadLevels() async {
    try {
      final res = await ApiService.getFriendLevels();
      Log.i(_tag, 'Friend levels loaded: ${res.levels.length} | status=${res.status} | msg=${res.message}');
      _levels
        ..clear()
        ..addAll(res.levels);
    } catch (e, s) {
      Log.e(_tag, 'loadLevels failed', e, s);
    }
    notifyListeners();
  }

  Future<void> loadRanking({String period = 'weekly'}) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.getFriendRanking(period: period);
      _ranking
        ..clear()
        ..addAll(res.friends);
    } catch (e, s) {
      Log.e(_tag, 'loadRanking failed', e, s);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadHistory(String userId) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.getFriendHistory(userId: userId);
      _history
        ..clear()
        ..addAll(res.history);
    } catch (e, s) {
      Log.e(_tag, 'loadHistory failed', e, s);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadDiscover(String userId, {
    String? gender,
    String? region,
    bool? onlineOnly,
    int? minLevel,
  }) async {
    try {
      final res = await ApiService.getFriendDiscover(
        userId: userId,
        gender: gender,
        region: region,
        onlineOnly: onlineOnly,
        minLevel: minLevel,
      );
      _discover
        ..clear()
        ..addAll(res.requests);
    } catch (e, s) {
      Log.e(_tag, 'loadDiscover failed', e, s);
    }
    notifyListeners();
  }

  /// Load friend tasks with progress for a friendship.
  /// See `docs/CP_FRIEND_BACKEND_REMAINING.md` §4.
  Future<void> loadTasks(String friendshipId, {String userId = ''}) async {
    try {
      final res = await ApiService.getFriendTasks(
        friendshipId: friendshipId,
        userId: userId,
      );
      _tasks
        ..clear()
        ..addAll(res.tasks);
    } catch (e, s) {
      Log.e(_tag, 'loadTasks failed', e, s);
    }
    notifyListeners();
  }

  /// Claim a completed friend task reward.
  Future<bool> claimTask({
    required String friendshipId,
    required String taskId,
    required String userId,
  }) async {
    try {
      final res = await ApiService.claimFriendTask(
        friendshipId: friendshipId,
        taskId: taskId,
        userId: userId,
      );
      if (res.status) {
        await loadTasks(friendshipId, userId: userId);
      }
      return res.status;
    } catch (e, s) {
      Log.e(_tag, 'claimTask failed', e, s);
      return false;
    }
  }

  /// Load friend anniversaries (claimable + claimed).
  /// See `docs/CP_FRIEND_BACKEND_REMAINING.md` §5.
  Future<void> loadAnniversaries(String friendshipId) async {
    try {
      final res = await ApiService.getFriendAnniversaries(friendshipId);
      _anniversaries
        ..clear()
        ..addAll(res.milestones);
    } catch (e, s) {
      Log.e(_tag, 'loadAnniversaries failed', e, s);
    }
    notifyListeners();
  }

  /// Claim a friend anniversary reward.
  Future<bool> claimAnniversary({
    required String friendshipId,
    required String anniversaryId,
    required String userId,
  }) async {
    try {
      final res = await ApiService.claimFriendAnniversary(
        friendshipId: friendshipId,
        anniversaryId: anniversaryId,
        userId: userId,
      );
      if (res.status) {
        await loadAnniversaries(friendshipId);
      }
      return res.status;
    } catch (e, s) {
      Log.e(_tag, 'claimAnniversary failed', e, s);
      return false;
    }
  }

  Future<({bool ok, String? message})> sendRequest({
    required String fromUserId,
    required String toUserId,
    String message = '',
  }) async {
    try {
      final res = await ApiService.sendFriendRequest(
        fromUserId: fromUserId,
        toUserId: toUserId,
        message: message,
      );
      if (res.status) {
        _outgoingRequests.insert(
          0,
          FriendRequest(
            status: 'pending',
            toUser: FriendUser(id: toUserId),
            message: message,
          ),
        );
        notifyListeners();
        // Refresh from server to get the real request id.
        await loadRequests(fromUserId);
      }
      return (ok: res.status, message: res.message);
    } catch (e, s) {
      Log.e(_tag, 'sendRequest failed', e, s);
      return (ok: false, message: 'Network error');
    }
  }

  Future<({bool ok, String? message})> acceptRequest({
    required String requestId,
    required String userId,
  }) async {
    try {
      final res = await ApiService.acceptFriendRequest(
        requestId: requestId,
        userId: userId,
      );
      if (res.status && res.data.isNotEmpty) {
        _friends.addAll(res.data);
        _incomingRequests.removeWhere((r) => r.id == requestId);
        notifyListeners();
      }
      return (ok: res.status, message: res.message);
    } catch (e, s) {
      Log.e(_tag, 'acceptRequest failed', e, s);
      return (ok: false, message: 'Network error');
    }
  }

  Future<bool> rejectRequest({
    required String requestId,
    required String userId,
  }) async {
    try {
      final res = await ApiService.rejectFriendRequest(
        requestId: requestId,
        userId: userId,
      );
      if (res.status) {
        _incomingRequests.removeWhere((r) => r.id == requestId);
        notifyListeners();
      }
      return res.status;
    } catch (e, s) {
      Log.e(_tag, 'rejectRequest failed', e, s);
      return false;
    }
  }

  Future<bool> cancelRequest({
    required String requestId,
    required String userId,
  }) async {
    try {
      final res = await ApiService.cancelFriendRequest(
        requestId: requestId,
        userId: userId,
      );
      if (res.status) {
        _outgoingRequests.removeWhere((r) => r.id == requestId);
        notifyListeners();
      }
      return res.status;
    } catch (e, s) {
      Log.e(_tag, 'cancelRequest failed', e, s);
      return false;
    }
  }

  Future<bool> removeFriend({
    required String friendshipId,
    required String userId,
  }) async {
    try {
      final res = await ApiService.removeFriend(
        friendshipId: friendshipId,
        userId: userId,
      );
      if (res.status) {
        _friends.removeWhere((f) => f.id == friendshipId);
        notifyListeners();
      }
      return res.status;
    } catch (e, s) {
      Log.e(_tag, 'removeFriend failed', e, s);
      return false;
    }
  }

  Future<void> loadPrivileges(String friendshipId, {String userId = ''}) async {
    try {
      final res = await ApiService.getFriendPrivileges(friendshipId, userId: userId);
      _privileges
        ..clear()
        ..addAll(res.privileges);
    } catch (e, s) {
      Log.e(_tag, 'loadPrivileges failed', e, s);
    }
    notifyListeners();
  }

  Future<void> loadRings(String friendshipId) async {
    try {
      final res = await ApiService.getFriendRings(friendshipId);
      _rings
        ..clear()
        ..addAll(res.rings);
    } catch (e, s) {
      Log.e(_tag, 'loadRings failed', e, s);
    }
    notifyListeners();
  }

  Future<bool> equipRing({
    required String friendshipId,
    required String ringId,
    required String userId,
  }) async {
    try {
      final res = await ApiService.equipFriendRing(
        friendshipId: friendshipId,
        ringId: ringId,
        userId: userId,
      );
      if (res.status) {
        for (var i = 0; i < _rings.length; i++) {
          _rings[i] = FriendRing(
            id: _rings[i].id,
            name: _rings[i].name,
            image: _rings[i].image,
            unlockLevel: _rings[i].unlockLevel,
            isUnlocked: _rings[i].isUnlocked,
            isEquipped: _rings[i].id == ringId,
            price: _rings[i].price,
            description: _rings[i].description,
          );
        }
        notifyListeners();
      }
      return res.status;
    } catch (e, s) {
      Log.e(_tag, 'equipRing failed', e, s);
      return false;
    }
  }
}
