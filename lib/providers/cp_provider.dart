import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/cp_models.dart';
import '../models/json_annotation_helper.dart';
import '../services/api_service.dart';
import '../services/socket_handlers.dart';
import '../utils/log.dart';

/// State management for the CP (Couple) feature.
///
/// Holds: the current user's active CP, incoming/outgoing requests, couple
/// tasks, ranking, bond-level table, milestones and history. Mirrors the
/// shape of [FamilyProvider].
class CpProvider extends ChangeNotifier {
  static const String _tag = 'CpProvider';

  StreamSubscription? _cpRequestSub;
  StreamSubscription? _cpLevelUpSub;
  StreamSubscription? _cpIntimacySub;

  final _intimacyFlyController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get intimacyFlyStream => _intimacyFlyController.stream;

  CPItem? _myCP;
  CPItem? get myCP => _myCP;

  CPItem? _cpDetail;
  CPItem? get cpDetail => _cpDetail;

  final List<CPRequest> _incomingRequests = [];
  List<CPRequest> get incomingRequests => _incomingRequests;

  final List<CPRequest> _outgoingRequests = [];
  List<CPRequest> get outgoingRequests => _outgoingRequests;

  final List<CPTask> _tasks = [];
  List<CPTask> get tasks => _tasks;

  final List<CPRankItem> _ranking = [];
  List<CPRankItem> get ranking => _ranking;

  final List<CPLevel> _levels = [];
  List<CPLevel> get levels => _levels;

  final List<CPMilestone> _milestones = [];
  List<CPMilestone> get milestones => _milestones;

  final List<CPPrivilege> _privileges = [];
  List<CPPrivilege> get privileges => _privileges;

  final List<CPRing> _rings = [];
  List<CPRing> get rings => _rings;

  final List<CPHistoryItem> _history = [];
  List<CPHistoryItem> get history => _history;

  final List<CPRequest> _discover = [];
  List<CPRequest> get discover => _discover;

  bool _loading = false;
  bool get loading => _loading;

  /// Number of pending incoming requests (for badge counts).
  int get pendingCount =>
      _incomingRequests.where((r) => r.status == 'pending').length;

  /// Returns relationship info if the given user is our CP partner.
  Map<String, dynamic>? getRelationshipWith(String otherUserId) {
    if (_myCP == null) return null;
    if (_myCP!.user1?.id == otherUserId || _myCP!.user2?.id == otherUserId) {
      return {
        'type': 'cp',
        'level': _myCP!.level,
      };
    }
    return null;
  }

  /// Subscribe to real-time socket events for CP.
  void initSocketListeners(String userId) {
    _cpRequestSub?.cancel();
    _cpLevelUpSub?.cancel();
    _cpIntimacySub?.cancel();
    try {
      final socket = SocketHandlers.instance;
      _cpRequestSub = socket.cpRequestStream.listen((_) {
        loadRequests(userId);
        notifyListeners();
      });
      _cpLevelUpSub = socket.cpLevelUpStream.listen((data) {
        final cpId = data['cpId'] as String?;
        if (cpId != null && _myCP?.id == cpId) {
          loadMyCP(userId);
        }
        notifyListeners();
      });
      _cpIntimacySub = socket.cpIntimacyStream.listen((data) {
        final cpId = data['cpId'] as String?;
        if (cpId != null && _myCP?.id == cpId) {
          final intimacy = parseInt(data['intimacy'], 0);
          final delta = parseInt(data['delta'], 0);
          if (intimacy > 0) {
            _myCP = _myCP?.copyWith(intimacy: intimacy);
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
    _cpRequestSub?.cancel();
    _cpLevelUpSub?.cancel();
    _cpIntimacySub?.cancel();
    _intimacyFlyController.close();
    super.dispose();
  }

  Future<void> loadMyCP(String userId) async {
    try {
      final res = await ApiService.getMyCP(userId);
      _myCP = res.data.isNotEmpty ? res.data.first : null;
    } catch (e, s) {
      Log.e(_tag, 'loadMyCP failed', e, s);
    }
    notifyListeners();
  }

  Future<void> loadCPDetail(String cpId) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.getCP(cpId);
      _cpDetail = res.data.isNotEmpty ? res.data.first : null;
    } catch (e, s) {
      Log.e(_tag, 'loadCPDetail failed', e, s);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadRequests(String userId) async {
    try {
      final incoming = await ApiService.getCPRequests(userId: userId, type: 'incoming');
      final outgoing = await ApiService.getCPRequests(userId: userId, type: 'outgoing');
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

  Future<void> loadTasks(String cpId, {String userId = ''}) async {
    try {
      final res = await ApiService.getCPTasks(cpId: cpId, userId: userId);
      _tasks
        ..clear()
        ..addAll(res.tasks);
    } catch (e, s) {
      Log.e(_tag, 'loadTasks failed', e, s);
    }
    notifyListeners();
  }

  Future<void> loadRanking({String period = 'weekly'}) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.getCPRanking(period: period);
      _ranking
        ..clear()
        ..addAll(res.couples);
    } catch (e, s) {
      Log.e(_tag, 'loadRanking failed', e, s);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadLevels() async {
    try {
      final res = await ApiService.getCPLevels();
      Log.i(_tag, 'CP levels loaded: ${res.levels.length} | status=${res.status} | msg=${res.message}');
      _levels
        ..clear()
        ..addAll(res.levels);
    } catch (e, s) {
      Log.e(_tag, 'loadLevels failed', e, s);
    }
    notifyListeners();
  }

  Future<void> loadMilestones(String cpId) async {
    try {
      final res = await ApiService.getCPMilestones(cpId);
      _milestones
        ..clear()
        ..addAll(res.milestones);
    } catch (e, s) {
      Log.e(_tag, 'loadMilestones failed', e, s);
    }
    notifyListeners();
  }

  /// Load CP anniversaries (claimable + claimed).
  /// See `docs/CP_FRIEND_BACKEND_REMAINING.md` §5.
  Future<void> loadAnniversaries(String cpId) async {
    try {
      final res = await ApiService.getCPAnniversaries(cpId);
      _milestones
        ..clear()
        ..addAll(res.milestones);
    } catch (e, s) {
      Log.e(_tag, 'loadAnniversaries failed', e, s);
    }
    notifyListeners();
  }

  /// Claim a CP anniversary reward.
  Future<bool> claimAnniversary({
    required String cpId,
    required String anniversaryId,
    required String userId,
  }) async {
    try {
      final res = await ApiService.claimCPAnniversary(
        cpId: cpId,
        anniversaryId: anniversaryId,
        userId: userId,
      );
      if (res.status) {
        await loadAnniversaries(cpId);
      }
      return res.status;
    } catch (e, s) {
      Log.e(_tag, 'claimAnniversary failed', e, s);
      return false;
    }
  }

  Future<void> loadHistory(String userId) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.getCPHistory(userId: userId);
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
      final res = await ApiService.getCPDiscover(
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

  Future<void> loadPrivileges(String cpId, {String userId = ''}) async {
    try {
      final res = await ApiService.getCPPrivileges(cpId, userId: userId);
      _privileges
        ..clear()
        ..addAll(res.privileges);
    } catch (e, s) {
      Log.e(_tag, 'loadPrivileges failed', e, s);
    }
    notifyListeners();
  }

  Future<void> loadRings(String cpId) async {
    try {
      final res = await ApiService.getCPRings(cpId);
      _rings
        ..clear()
        ..addAll(res.rings);
    } catch (e, s) {
      Log.e(_tag, 'loadRings failed', e, s);
    }
    notifyListeners();
  }

  Future<bool> equipRing({
    required String cpId,
    required String ringId,
    required String userId,
  }) async {
    try {
      final res = await ApiService.equipCPRing(
        cpId: cpId,
        ringId: ringId,
        userId: userId,
      );
      if (res.status) {
        // Update equipped state locally.
        for (var i = 0; i < _rings.length; i++) {
          _rings[i] = CPRing(
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

  Future<bool> sendRequest({
    required String fromUserId,
    required String toUserId,
    String message = '',
  }) async {
    try {
      final res = await ApiService.sendCPRequest(
        fromUserId: fromUserId,
        toUserId: toUserId,
        message: message,
      );
      if (res.status) {
        // Optimistically add to outgoing list.
        _outgoingRequests.insert(
          0,
          CPRequest(
            status: 'pending',
            toUser: CPUser(id: toUserId),
            message: message,
          ),
        );
        notifyListeners();
      }
      return res.status;
    } catch (e, s) {
      Log.e(_tag, 'sendRequest failed', e, s);
      return false;
    }
  }

  Future<bool> acceptRequest({
    required String requestId,
    required String userId,
  }) async {
    try {
      final res = await ApiService.acceptCPRequest(
        requestId: requestId,
        userId: userId,
      );
      if (res.status && res.data.isNotEmpty) {
        _myCP = res.data.first;
        _incomingRequests.removeWhere((r) => r.id == requestId);
        notifyListeners();
      }
      return res.status;
    } catch (e, s) {
      Log.e(_tag, 'acceptRequest failed', e, s);
      return false;
    }
  }

  Future<bool> rejectRequest({
    required String requestId,
    required String userId,
  }) async {
    try {
      final res = await ApiService.rejectCPRequest(
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
      final res = await ApiService.cancelCPRequest(
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

  Future<bool> breakUp({
    required String cpId,
    required String userId,
    String reason = 'by_me',
  }) async {
    try {
      final res = await ApiService.breakUpCP(
        cpId: cpId,
        userId: userId,
        reason: reason,
      );
      if (res.status) {
        _myCP = null;
        _cpDetail = null;
        _tasks.clear();
        _milestones.clear();
        notifyListeners();
      }
      return res.status;
    } catch (e, s) {
      Log.e(_tag, 'breakUp failed', e, s);
      return false;
    }
  }

  Future<bool> claimTask({
    required String cpId,
    required String taskId,
    required String userId,
  }) async {
    try {
      final res = await ApiService.claimCPTask(
        cpId: cpId,
        taskId: taskId,
        userId: userId,
      );
      if (res.status) {
        final idx = _tasks.indexWhere((t) => t.id == taskId);
        if (idx >= 0) {
          // Mark claimed locally (immutable list -> rebuild).
          _tasks[idx] = CPTask(
            id: _tasks[idx].id,
            title: _tasks[idx].title,
            description: _tasks[idx].description,
            type: _tasks[idx].type,
            reward: _tasks[idx].reward,
            rewardType: _tasks[idx].rewardType,
            target: _tasks[idx].target,
            progress: _tasks[idx].progress,
            myProgress: _tasks[idx].myProgress,
            partnerProgress: _tasks[idx].partnerProgress,
            isCompleted: true,
            isClaimed: true,
            expiresAt: _tasks[idx].expiresAt,
          );
          notifyListeners();
        }
      }
      return res.status;
    } catch (e, s) {
      Log.e(_tag, 'claimTask failed', e, s);
      return false;
    }
  }

  Future<bool> updateCP({
    required String cpId,
    required String userId,
    String? title,
    String? bio,
    File? coverFile,
  }) async {
    try {
      final res = await ApiService.updateCP(
        cpId: cpId,
        userId: userId,
        title: title,
        bio: bio,
        coverFile: coverFile,
      );
      if (res.status && res.data.isNotEmpty) {
        _myCP = res.data.first;
        notifyListeners();
      }
      return res.status;
    } catch (e, s) {
      Log.e(_tag, 'updateCP failed', e, s);
      return false;
    }
  }
}
