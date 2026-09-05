import 'dart:async';
import 'package:flutter/foundation.dart';

import '../constants/const.dart';
import '../models/live_stream_root.dart';
import '../models/live_user_root.dart' as live_user;
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../utils/log.dart';

class LiveProvider extends ChangeNotifier {
  static const String _tag = 'LiveProvider';

  final SocketService _socket = SocketService.instance;

  LiveUser? _liveUser;
  LiveUser? get liveUser => _liveUser;

  final List<live_user.LiveUser> _liveUsers = [];
  List<live_user.LiveUser> get liveUsers => _liveUsers;

  int _viewerCount = 0;
  int get viewerCount => _viewerCount;

  int _totalCoins = 0;
  int get totalCoins => _totalCoins;

  bool _isLive = false;
  bool get isLive => _isLive;

  bool _loading = false;
  bool get loading => _loading;

  String _filterType = 'All';
  String get filterType => _filterType;

  final List<Map<String, dynamic>> _comments = [];
  List<Map<String, dynamic>> get comments => _comments;

  final List<Map<String, dynamic>> _gifts = [];
  List<Map<String, dynamic>> get gifts => _gifts;

  final List<live_user.LiveUser> _coHosts = [];
  List<live_user.LiveUser> get coHosts => _coHosts;

  final List<String> _bannedUserIds = [];
  List<String> get bannedUserIds => _bannedUserIds;

  final List<String> _adminIds = [];
  List<String> get adminIds => _adminIds;

  final List<Map<String, dynamic>> _joinRequests = [];
  List<Map<String, dynamic>> get joinRequests => _joinRequests;

  final _commentController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get commentStream => _commentController.stream;

  final _giftController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get giftStream => _giftController.stream;

  final _viewerController = StreamController<int>.broadcast();
  Stream<int> get viewerStream => _viewerController.stream;

  final List<void Function()> _unsubscribers = [];

  void setLiveUser(LiveUser? user) {
    _liveUser = user;
    _isLive = user != null;
    _viewerCount = user?.view ?? 0;
    _totalCoins = user?.coin ?? 0;
    notifyListeners();
  }

  Future<void> loadLiveUsers({
    required String userId,
    String type = 'All',
    String country = 'All',
    bool refresh = false,
  }) async {
    if (_loading && !refresh) return;
    _filterType = type;
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.getLiveUsers(
        userId: userId,
        type: type,
        country: country,
        start: 0,
        limit: 50,
      );
      _liveUsers
        ..clear()
        ..addAll(res.users);
    } catch (e, s) {
      Log.e(_tag, 'loadLiveUsers failed', e, s);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void subscribeSocketEvents() {
    _unsubscribers.add(_socket.on(Const.eventComment, (data) {
      _comments.insert(0, data as Map<String, dynamic>);
      _commentController.add(data);
      notifyListeners();
    }));

    _unsubscribers.add(_socket.on(Const.eventGift, (data) {
      final giftData = data as Map<String, dynamic>;
      _gifts.insert(0, giftData);
      _giftController.add(giftData);
      final coins = giftData['coin'] ?? giftData['diamond'];
      if (coins != null) {
        _totalCoins += (coins as num).toInt();
      }
      notifyListeners();
    }));

    _unsubscribers.add(_socket.on(Const.eventAddView, (data) {
      _viewerCount++;
      _viewerController.add(_viewerCount);
      notifyListeners();
    }));

    _unsubscribers.add(_socket.on(Const.eventLessView, (data) {
      if (_viewerCount > 0) _viewerCount--;
      _viewerController.add(_viewerCount);
      notifyListeners();
    }));

    _unsubscribers.add(_socket.on(Const.eventEndLive, (data) {
      _isLive = false;
      _liveUser = null;
      notifyListeners();
    }));

    _unsubscribers.add(_socket.on(Const.eventMakeAdmin, (data) {
      final adminId = (data as Map?)?['userId'] as String?;
      if (adminId != null && !_adminIds.contains(adminId)) {
        _adminIds.add(adminId);
        notifyListeners();
      }
    }));

    _unsubscribers.add(_socket.on(Const.eventUserBlock, (data) {
      final blockedId = (data as Map?)?['userId'] as String?;
      if (blockedId != null && !_bannedUserIds.contains(blockedId)) {
        _bannedUserIds.add(blockedId);
        notifyListeners();
      }
    }));

    _unsubscribers.add(_socket.on(Const.eventAddRequestedCallJoin, (data) {
      final req = data as Map<String, dynamic>? ?? {};
      _joinRequests.add(req);
      notifyListeners();
    }));

    _unsubscribers.add(_socket.on(Const.eventLessParticipatesCallJoin, (data) {
      final userId = (data as Map?)?['userId'] as String?;
      if (userId != null) {
        _coHosts.removeWhere((u) => u.id == userId);
        notifyListeners();
      }
    }));
  }

  void addComment(Map<String, dynamic> comment) {
    _comments.insert(0, comment);
    _commentController.add(comment);
    notifyListeners();
  }

  void addCoHost(live_user.LiveUser user) {
    _coHosts.add(user);
    notifyListeners();
  }

  void removeCoHost(String userId) {
    _coHosts.removeWhere((u) => u.id == userId);
    notifyListeners();
  }

  void banUser(String userId) {
    if (!_bannedUserIds.contains(userId)) {
      _bannedUserIds.add(userId);
      notifyListeners();
    }
  }

  void unbanUser(String userId) {
    _bannedUserIds.remove(userId);
    notifyListeners();
  }

  void addAdmin(String userId) {
    if (!_adminIds.contains(userId)) {
      _adminIds.add(userId);
      notifyListeners();
    }
  }

  void removeAdmin(String userId) {
    _adminIds.remove(userId);
    notifyListeners();
  }

  void acceptJoinRequest(String userId) {
    _joinRequests.removeWhere((r) => r['userId'] == userId);
    notifyListeners();
  }

  void rejectJoinRequest(String userId) {
    _joinRequests.removeWhere((r) => r['userId'] == userId);
    notifyListeners();
  }

  void clearLiveRoom() {
    _liveUser = null;
    _isLive = false;
    _viewerCount = 0;
    _totalCoins = 0;
    _comments.clear();
    _gifts.clear();
    _coHosts.clear();
    _bannedUserIds.clear();
    _adminIds.clear();
    _joinRequests.clear();
    for (final unsub in _unsubscribers) {
      try {
        unsub();
      } catch (_) {}
    }
    _unsubscribers.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    clearLiveRoom();
    _commentController.close();
    _giftController.close();
    _viewerController.close();
    super.dispose();
  }
}
