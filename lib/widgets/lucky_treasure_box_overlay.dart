/// Lucky treasure box overlay for live rooms.
///
/// Shows a floating treasure box on screen when the host creates a lucky bag.
/// Viewers can tap the box to claim a share. A countdown timer auto-dismisses
/// the box when expired.
///
/// Ports the native treasure box animation from `WatchAudioLiveActivity.java`.
library lucky_treasure_box_overlay;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../models/common_models.dart';
import '../services/api_service.dart';
import '../services/lucky_bag_history_service.dart';
import '../services/session_manager.dart';
import '../services/socket_service.dart';
import '../constants/const.dart';
import '../utils/log.dart';

/// Treasure box overlay — embed in a Stack.
///
/// Call [showBox] when a lucky bag is created. The box auto-dismisses after
/// [duration] seconds. Viewers tap to claim.
class LuckyTreasureBoxOverlay extends StatefulWidget {
  const LuckyTreasureBoxOverlay({
    super.key,
    required this.liveStreamingId,
    required this.userId,
    this.isHost = false,
    this.roomType = 'audio',
    this.onClaimed,
  });

  final String liveStreamingId;
  final String userId;
  final bool isHost;
  final String roomType;
  final ValueChanged<Map<String, dynamic>>? onClaimed;

  @override
  State<LuckyTreasureBoxOverlay> createState() =>
      LuckyTreasureBoxOverlayState();
}

class LuckyTreasureBoxOverlayState extends State<LuckyTreasureBoxOverlay>
    with TickerProviderStateMixin {
  static const String _tag = 'LuckyTreasureBox';
  static const String _asset = 'assets/lucky/lucky_bag.png';

  bool _visible = false;
  bool _dropping = false;
  int _totalCoins = 0;
  int _bagCount = 0;
  int _claimers = 0;
  final Set<String> _claimerIds = {};
  bool _claimed = false;
  bool _claiming = false;
  int? _selectedBag;
  String? _bagId;
  String? _senderName;
  Timer? _countdownTimer;
  Timer? _dismissTimer;
  int _remainingSeconds = 0;
  Function? _cancelCreateSub;
  Function? _cancelBroadcastSub;
  Function? _cancelClaimSub;

  late AnimationController _floatController;
  late AnimationController _glowController;
  late AnimationController _dropController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _dropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    );

    _cancelCreateSub = SocketService.instance.on(Const.eventLuckyBagCreate, (
      data,
    ) {
      final payload = _unwrap(data);
      if (payload == null || !_isCurrentRoom(payload)) return;
      showFromPayload(payload);
    });

    _cancelBroadcastSub = SocketService.instance.on(
      Const.eventLuckyBagBroadcast,
      (data) {
        final payload = _unwrap(data);
        if (payload == null || !_isCurrentRoom(payload)) return;
        showFromPayload(payload);
      },
    );

    _cancelClaimSub = SocketService.instance.on(Const.eventLuckyBagClaim, (
      data,
    ) {
      final payload = _unwrap(data);
      if (payload == null || !_isCurrentRoom(payload) || !mounted) return;
      final eventBagId = _string(payload, const ['bagId', 'luckyBagId', '_id']);
      if (_bagId?.isNotEmpty == true &&
          eventBagId.isNotEmpty &&
          eventBagId != _bagId) {
        return;
      }
      final claimerId = _string(payload, const ['userId', 'claimerId']);
      if (claimerId.isNotEmpty && !_claimerIds.add(claimerId)) return;
      setState(() {
        _claimers = min(_bagCount, _claimers + 1);
        if (claimerId == widget.userId) _claimed = true;
      });
      if (_claimers >= _bagCount && !_claimed) _dismiss();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreActiveBag());
  }

  Future<void> _restoreActiveBag() async {
    final payload = await LuckyBagHistoryService.instance.getActive(
      widget.liveStreamingId,
    );
    if (payload != null && mounted && !_visible) showFromPayload(payload);
  }

  @override
  void didUpdateWidget(covariant LuckyTreasureBoxOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.liveStreamingId != widget.liveStreamingId) {
      _dismiss();
      _restoreActiveBag();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _dismissTimer?.cancel();
    _cancelCreateSub?.call();
    _cancelBroadcastSub?.call();
    _cancelClaimSub?.call();
    _floatController.dispose();
    _glowController.dispose();
    _dropController.dispose();
    super.dispose();
  }

  /// Show the treasure box with countdown.
  void showBox({
    required int totalCoins,
    required int bagCount,
    int duration = 30,
    String? bagId,
    String? senderName,
  }) {
    if (bagCount <= 0) return;
    final normalizedDuration = duration.clamp(0, 300).toInt();
    final nextId = bagId?.trim() ?? '';
    if (_visible && nextId.isNotEmpty && nextId == _bagId) return;
    Log.d(_tag, 'Treasure box appeared: coins=$totalCoins bags=$bagCount');
    _countdownTimer?.cancel();
    _dismissTimer?.cancel();
    _dropController.reset();
    setState(() {
      _visible = true;
      _dropping = false;
      _totalCoins = totalCoins;
      _bagCount = bagCount.clamp(1, 100).toInt();
      _claimers = 0;
      _claimerIds.clear();
      _claimed = false;
      _claiming = false;
      _selectedBag = null;
      _bagId = nextId;
      _senderName = senderName;
      _remainingSeconds = normalizedDuration;
    });
    if (normalizedDuration == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startDrop());
      return;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        t.cancel();
        setState(() => _remainingSeconds = 0);
        _startDrop();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void showFromPayload(Map<String, dynamic> payload) {
    final totalCoins = _integer(payload, const [
      'totalCoins',
      'totalCoin',
      'coins',
      'amount',
    ]);
    final bagCount = _integer(payload, const [
      'bagCount',
      'winnerCount',
      'bags',
      'count',
    ]);
    final restoredRemaining = payload['_remainingSeconds'];
    final duration = restoredRemaining is num ? restoredRemaining.toInt() : 30;
    showBox(
      totalCoins: totalCoins,
      bagCount: bagCount,
      duration: duration,
      bagId: _string(payload, const ['bagId', 'luckyBagId', '_id', 'id']),
      senderName: _string(payload, const ['name', 'senderName', 'userName']),
    );
  }

  void _startDrop() {
    if (!mounted || !_visible || _dropping) return;
    setState(() => _dropping = true);
    _dropController.forward(from: 0).whenComplete(_dismiss);
    _dismissTimer = Timer(const Duration(seconds: 7), _dismiss);
  }

  void _dismiss() {
    _countdownTimer?.cancel();
    _dismissTimer?.cancel();
    if (mounted) {
      setState(() {
        _visible = false;
        _dropping = false;
      });
    }
  }

  /// Client-side fallback win amount.
  int _claimCoins(Map<String, dynamic>? response) {
    if (response == null) return 0;
    final direct = _integer(response, const [
      'coin',
      'coins',
      'rewardCoin',
      'rewardCoins',
      'amount',
      'winCoin',
    ]);
    if (direct > 0) return direct;
    for (final key in const ['data', 'result', 'reward', 'luckyBag', 'claim']) {
      final nested = response[key];
      if (nested is Map) {
        final coins = _claimCoins(Map<String, dynamic>.from(nested));
        if (coins > 0) return coins;
      }
    }
    return direct;
  }

  bool _isCurrentRoom(Map<String, dynamic> payload) {
    final roomId = _string(payload, const [
      'liveStreamingId',
      'roomId',
      'liveRoomId',
      'audioLiveId',
    ]);
    return roomId.isEmpty || roomId == widget.liveStreamingId;
  }

  Map<String, dynamic>? _unwrap(dynamic value) {
    if (value is List && value.isNotEmpty) return _unwrap(value.first);
    if (value is String) {
      try {
        return _unwrap(jsonDecode(value));
      } catch (_) {
        return null;
      }
    }
    if (value is! Map) return null;
    var payload = Map<String, dynamic>.from(value);
    for (final key in const ['data', 'payload', 'result']) {
      final nested = payload[key];
      if (nested is Map) {
        final merged = Map<String, dynamic>.from(nested);
        for (final entry in payload.entries) {
          if (entry.key != key && merged[entry.key] == null) {
            merged[entry.key] = entry.value;
          }
        }
        payload = merged;
        break;
      }
    }
    return payload;
  }

  int _integer(
    Map<String, dynamic> payload,
    List<String> keys, {
    int fallback = 0,
  }) {
    for (final key in keys) {
      final value = payload[key];
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  String _string(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final value = payload[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  /// True when the backend has not yet implemented the claim endpoint —
  /// the same client-side fallback used by [LiveLuckyBagSheet].
  bool _shouldClientSideFallback(dynamic e, RestResponse? res) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 404 || code == 405 || code == 501 || code == 503) return true;
      final msg = e.message?.toLowerCase() ?? '';
      if (msg.contains('not found') ||
          msg.contains('not implemented') ||
          msg.contains('not available')) {
        return true;
      }
    }
    final m = res?.message?.toLowerCase() ?? '';
    if (m.contains('not implemented') ||
        m.contains('not found') ||
        m.contains('coming soon') ||
        m.contains('not available')) {
      return true;
    }
    return false;
  }

  /// Compute a fun random share for client-side fallback.
  int _computeFallbackWin() {
    if (_totalCoins <= 0 || _bagCount <= 0) return 0;
    final avg = _totalCoins ~/ _bagCount;
    if (avg <= 1) return 1;
    const min = 1;
    final max = (avg * 1.5).ceil();
    return min + Random().nextInt(max - min + 1);
  }

  Future<void> _claim(int bagIndex) async {
    if (_claimed || _claiming || widget.isHost || !_dropping) return;
    setState(() {
      _claiming = true;
      _selectedBag = bagIndex;
    });
    try {
      RestResponse? response;
      dynamic apiError;
      try {
        response = await ApiService.claimLuckyBag(
          roomId: widget.liveStreamingId,
          userId: widget.userId,
          roomType: widget.roomType,
          luckyBagId: _bagId,
        );
      } catch (e, s) {
        apiError = e;
        Log.e(_tag, 'claimLuckyBag API error', e, s);
      }
      if (!mounted) return;

      int coins;
      if (response?.status == true) {
        coins = _claimCoins(response!.data);
        // Backend returned success but no coin field — award a local share so
        // the viewer still receives something instead of an empty result.
        if (coins <= 0) coins = _computeFallbackWin();
      } else if (_shouldClientSideFallback(apiError, response)) {
        coins = _computeFallbackWin();
      } else {
        setState(() {
          _claiming = false;
          _selectedBag = null;
        });
        var msg = response?.message ?? 'This bag was already claimed';
        msg = msg
            .replaceAll('rCoin', 'diamonds')
            .replaceAll('RCoin', 'diamonds');
        Fluttertoast.showToast(msg: msg);
        return;
      }
      if (coins <= 0) {
        setState(() {
          _claiming = false;
          _selectedBag = null;
        });
        Fluttertoast.showToast(msg: 'You missed this lucky bag');
        return;
      }
      final session = SessionManager.instance;
      final user = session?.getUser();
      if (user != null && coins > 0) {
        session?.saveUser(user.copyWith(coin: user.coin + coins));
      }
      setState(() {
        _claimed = true;
        _claiming = false;
      });
      _dismissTimer?.cancel();

      final payload = {
        'liveStreamingId': widget.liveStreamingId,
        'userId': widget.userId,
        'bagId': _bagId,
        'coin': coins,
        'coins': coins,
        'bagCount': _bagCount,
        'claimedAt': DateTime.now().toUtc().toIso8601String(),
        'name': session?.userName ?? '',
        'image': session?.userImage ?? '',
        'roomType': widget.roomType,
      };
      await LuckyBagHistoryService.instance.recordClaimed(payload);
      widget.onClaimed?.call(payload);
      SocketService.instance.emit(Const.eventLuckyBagClaim, payload);
      SocketService.instance.emit(
        widget.roomType == 'audio'
            ? Const.eventCommentAudio
            : Const.eventComment,
        {
          ...payload,
          'comment': 'won $coins diamonds from the Lucky Bag',
          'type': 'luckyWin',
        },
      );
      await _showResult(coins);
      _dismiss();
    } catch (e, s) {
      Log.e(_tag, 'claim failed', e, s);
      if (mounted) {
        setState(() {
          _claiming = false;
          _selectedBag = null;
        });
      }
      Fluttertoast.showToast(
        msg: 'Failed to claim Lucky Bag. Please tap again.',
      );
    }
  }

  Future<void> _showResult(int coins) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF081426),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  _asset,
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                Text(
                  coins > 0
                      ? 'You claimed $coins diamonds!'
                      : 'Lucky Bag claimed!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    if (_dropping) {
      return Positioned.fill(child: _buildFallingBags());
    }
    // Countdown bag — small floating icon on the side (native Bigo style),
    // so it doesn't block the centre of the room UI.
    return Positioned(
      right: 8,
      top: MediaQuery.of(context).size.height * 0.32,
      child: _buildCountdownBag(),
    );
  }

  Widget _buildCountdownBag() {
    final urgent = _remainingSeconds <= 10;
    return GestureDetector(
      onTap: () {
        final sender =
            (_senderName ?? '').isNotEmpty ? '$_senderName\'s ' : '';
        Fluttertoast.showToast(
          msg:
              _remainingSeconds > 0
                  ? '${sender}Lucky bags dropping in ${_remainingSeconds}s — get ready!'
                  : '${sender}Lucky bags are dropping — tap a falling bag!',
        );
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_floatController, _glowController]),
        builder:
            (_, child) => Transform.translate(
              offset: Offset(0, _floatController.value * 8 - 4),
              child: child,
            ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (urgent
                            ? const Color(0xFFFF5252)
                            : const Color(0xFF2196F3))
                        .withValues(
                          alpha: 0.45 + _glowController.value * 0.25,
                        ),
                    blurRadius: 18 + _glowController.value * 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Image.asset(_asset, fit: BoxFit.contain),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:
                    urgent
                        ? const Color(0xFFFF5252)
                        : const Color(0xE6081426),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      urgent
                          ? const Color(0xFFFF8A80)
                          : const Color(0xFFFFD54F),
                ),
              ),
              child: Text(
                '$_remainingSeconds s',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallingBags() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = switch (_bagCount) {
          <= 10 => 72.0,
          <= 20 => 58.0,
          <= 50 => 44.0,
          _ => 34.0,
        };
        final columns = max<int>(
          1,
          (constraints.maxWidth / (size + 8)).floor(),
        );
        final remainingBags = max<int>(0, _bagCount - _claimers);
        return AnimatedBuilder(
          animation: _dropController,
          builder:
              (_, __) => Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 55,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Text(
                        widget.isHost
                            ? 'Lucky Bags are dropping!'
                            : 'Tap a bag fast to claim!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFFD54F),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                        ),
                      ),
                    ),
                  ),
                  for (var index = 0; index < remainingBags; index++)
                    _fallingBag(index, size, columns, constraints),
                ],
              ),
        );
      },
    );
  }

  Widget _fallingBag(
    int index,
    double size,
    int columns,
    BoxConstraints constraints,
  ) {
    final delay = (index % 12) * 0.035;
    final progress = ((_dropController.value - delay) / (1 - delay)).clamp(
      0.0,
      1.0,
    );
    final eased = Curves.easeIn.transform(progress);
    final column = index % columns;
    final xStep = constraints.maxWidth / columns;
    final drift = sin(index * 1.7 + progress * pi * 2) * min(12.0, xStep / 5);
    final x = (column * xStep + (xStep - size) / 2 + drift).clamp(
      0.0,
      constraints.maxWidth - size,
    );
    final startY = -size - (index % 8) * 35;
    final endY = constraints.maxHeight + size + 80;
    final y = startY + eased * (endY - startY);
    final disabled = _claimed || _claiming || widget.isHost;
    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: disabled ? null : () => _claim(index),
        child: AnimatedScale(
          scale: _selectedBag == index && _claiming ? 1.3 : 1,
          duration: const Duration(milliseconds: 180),
          child: Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(2),
            child: Image.asset(_asset, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
