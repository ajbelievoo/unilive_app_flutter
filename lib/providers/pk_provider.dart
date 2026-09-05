import 'dart:async';
import 'package:flutter/foundation.dart';

import '../constants/const.dart';
import '../models/pk_call_models.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../utils/log.dart';

class PkProvider extends ChangeNotifier {
  static const String _tag = 'PkProvider';

  final SocketService _socket = SocketService.instance;

  // Scores (Host1 perspective from backend)
  int _host1Score = 0;
  int get host1Score => _host1Score;

  int _host2Score = 0;
  int get host2Score => _host2Score;

  int _secondsRemaining = 0;
  int get secondsRemaining => _secondsRemaining;

  bool _isPunishmentRound = false;
  bool get isPunishmentRound => _isPunishmentRound;

  int _pkRoundCount = 0;
  int get pkRoundCount => _pkRoundCount;

  bool _canRematch = false;
  bool get canRematch => _canRematch;

  bool _pkAutoStartBlocked = false;
  bool get pkAutoStartBlocked => _pkAutoStartBlocked;

  String? _pkId;
  String? get pkId => _pkId;

  String? _punishmentTask;
  String? get punishmentTask => _punishmentTask;

  int _pkVoteHost1 = 0;
  int get pkVoteHost1 => _pkVoteHost1;

  int _pkVoteHost2 = 0;
  int get pkVoteHost2 => _pkVoteHost2;

  final List<PkGifter> _topGifters = [];
  List<PkGifter> get topGifters => _topGifters;

  final List<PkRoundResult> _roundHistory = [];
  List<PkRoundResult> get roundHistory => _roundHistory;

  Timer? _countdownTimer;
  int _battleDuration = 300;
  int _punishmentDuration = 0;

  int get battleDuration => _battleDuration;
  int get punishmentDuration => _punishmentDuration;

  final List<void Function()> _unsubscribers = [];

  String? _hostId;
  String? _guestId;

  void subscribePkEvents() {
    _unsubscribers.add(_socket.on(Const.eventPkScoreUpdate, (data) {
      final d = data is Map ? Map<String, dynamic>.from(data) : null;
      if (d == null) return;
      final h1Score = (d['host1Score'] as num?)?.toInt();
      final h2Score = (d['host2Score'] as num?)?.toInt();
      if (h1Score != null) _host1Score = h1Score;
      if (h2Score != null) _host2Score = h2Score;
      notifyListeners();
    }));

    _unsubscribers.add(_socket.on(Const.eventPkPunishmentRound, (data) {
      final d = data is Map ? Map<String, dynamic>.from(data) : null;
      if (d == null) return;
      final showStartButton = d['showStartButton'] == true;
      if (showStartButton) {
        _isPunishmentRound = false;
        _punishmentTask = null;
        notifyListeners();
        return;
      }
      final isPunishment = d['isPKPunishment'] == true || d['isPunishmentActive'] == true;
      final punishmentDuration = (d['pkPunishmentDuration'] as num?)?.toInt() ?? 0;
      if (isPunishment && punishmentDuration > 0) {
        _isPunishmentRound = true;
        _punishmentDuration = punishmentDuration;
        _punishmentTask = PkPunishmentTasks.getTaskForRound(_pkRoundCount);
        _secondsRemaining = punishmentDuration;
        _startCountdown();
      } else {
        _isPunishmentRound = false;
      }
      notifyListeners();
    }));

    _unsubscribers.add(_socket.on(Const.eventPkEnd, (data) {
      _countdownTimer?.cancel();
      final d = data is Map ? Map<String, dynamic>.from(data) : null;
      if (d == null) return;

      // Check disconnect
      final isDisconnect = d['isDisconnect'] == true || d['disconnect'] == true;
      if (isDisconnect) {
        _pkAutoStartBlocked = true;
        _isPunishmentRound = false;
        _host1Score = 0;
        _host2Score = 0;
        _pkRoundCount = 0;
        notifyListeners();
        return;
      }

      final winner = (d['isWinner'] as num?)?.toInt() ??
          (d['winner'] as num?)?.toInt() ?? 0;
      final canRematch = d['canRematch'] == true;
      final h1Score = (d['host1Score'] as num?)?.toInt() ?? _host1Score;
      final h2Score = (d['host2Score'] as num?)?.toInt() ?? _host2Score;

      // Record round result
      _roundHistory.add(PkRoundResult(
        roundNumber: _pkRoundCount,
        host1Score: h1Score,
        host2Score: h2Score,
        winner: winner,
      ));

      _host1Score = h1Score;
      _host2Score = h2Score;
      _canRematch = canRematch;
      _pkAutoStartBlocked = true;
      _isPunishmentRound = false;
      notifyListeners();
    }));

    _unsubscribers.add(_socket.on(Const.eventPkStart, (data) {
      final d = data is Map ? Map<String, dynamic>.from(data) : null;
      final duration = (d?['durationSeconds'] as num?)?.toInt() ??
          (d?['duration'] as num?)?.toInt();
      if (duration != null && duration > 0) {
        _battleDuration = duration;
        _secondsRemaining = duration;
        _isPunishmentRound = false;
        _startCountdown();
      }
      notifyListeners();
    }));

    _unsubscribers.add(_socket.on(Const.eventPkRematch, (data) {
      _reset();
      notifyListeners();
    }));

    _unsubscribers.add(_socket.on(Const.eventPkVote, (data) {
      final d = data is Map ? Map<String, dynamic>.from(data) : null;
      if (d == null) return;
      final v1 = (d['pkVoteHost1'] as num?)?.toInt();
      final v2 = (d['pkVoteHost2'] as num?)?.toInt();
      if (v1 != null) _pkVoteHost1 = v1;
      if (v2 != null) _pkVoteHost2 = v2;
      notifyListeners();
    }));
  }

  void initPk({
    required String pkId,
    required String hostId,
    required String guestId,
    int durationSeconds = 300,
    int roundCount = 0,
  }) {
    _pkId = pkId;
    _hostId = hostId;
    _guestId = guestId;
    _battleDuration = durationSeconds;
    _secondsRemaining = durationSeconds;
    _pkRoundCount = roundCount;
    _host1Score = 0;
    _host2Score = 0;
    _isPunishmentRound = false;
    _canRematch = false;
    _pkAutoStartBlocked = false;
    _punishmentTask = null;
    _pkVoteHost1 = 0;
    _pkVoteHost2 = 0;
    _topGifters.clear();
    _roundHistory.clear();
    _startCountdown();
    subscribePkEvents();
    notifyListeners();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsRemaining > 0) {
        _secondsRemaining--;
        notifyListeners();
      } else {
        _countdownTimer?.cancel();
      }
    });
  }

  void updateRoundCount(int count) {
    _pkRoundCount = count;
    notifyListeners();
  }

  /// Get local score from Host1 perspective.
  /// If current user is Host1, local = host1Score, remote = host2Score.
  /// If current user is Host2, local = host2Score, remote = host1Score.
  int getLocalScore(String myUserId) {
    if (_hostId == myUserId) return _host1Score;
    if (_guestId == myUserId) return _host2Score;
    return _host1Score;
  }

  int getRemoteScore(String myUserId) {
    if (_hostId == myUserId) return _host2Score;
    if (_guestId == myUserId) return _host1Score;
    return _host2Score;
  }

  Future<void> updateScore({
    required String userId,
    required int score,
  }) async {
    if (_pkId == null) return;
    try {
      await ApiService.updatePkScore(pkId: _pkId!, userId: userId, score: score);
    } catch (e, s) {
      Log.e(_tag, 'updateScore failed', e, s);
    }
  }

  Future<void> endPk(String winnerId) async {
    if (_pkId == null) return;
    try {
      await ApiService.endPkCall(pkId: _pkId!, winnerId: winnerId);
      _countdownTimer?.cancel();
      _canRematch = true;
      _pkAutoStartBlocked = true;
      notifyListeners();
    } catch (e, s) {
      Log.e(_tag, 'endPk failed', e, s);
    }
  }

  void requestRematch() {
    if (_canRematch) {
      _socket.emit(Const.eventPkRematch, {'pkId': _pkId});
      _reset();
      notifyListeners();
    }
  }

  void _reset() {
    _host1Score = 0;
    _host2Score = 0;
    _isPunishmentRound = false;
    _punishmentTask = null;
    _canRematch = false;
    _pkAutoStartBlocked = false;
    _pkVoteHost1 = 0;
    _pkVoteHost2 = 0;
    _topGifters.clear();
  }

  void clearPk() {
    _countdownTimer?.cancel();
    for (final unsub in _unsubscribers) {
      try {
        unsub();
      } catch (_) {}
    }
    _unsubscribers.clear();
    _pkId = null;
    _hostId = null;
    _guestId = null;
    _reset();
    _roundHistory.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    clearPk();
    super.dispose();
  }
}
