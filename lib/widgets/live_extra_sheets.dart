import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../constants/const.dart';
import '../models/room_runtime_models.dart';
import '../services/host_features_service.dart';
import '../services/session_manager.dart';
import '../services/socket_service.dart';
import '../utils/format_utils.dart' show diamondsToBeans;
import '../utils/log.dart';
import 'package:belive/widgets/preloader.dart';
import 'package:provider/provider.dart';

/// Vote for one of two PK sides.
void showPkVoteSheet(
  BuildContext context, {
  required String liveStreamingId,
  required String userId,
  String host1Name = 'Host',
  String host2Name = 'Opponent',
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PkVoteSheet(
      liveStreamingId: liveStreamingId,
      userId: userId,
      host1Name: host1Name,
      host2Name: host2Name,
    ),
  );
}

class _PkVoteSheet extends StatelessWidget {
  const _PkVoteSheet({
    required this.liveStreamingId,
    required this.userId,
    required this.host1Name,
    required this.host2Name,
  });

  final String liveStreamingId;
  final String userId;
  final String host1Name;
  final String host2Name;

  void _vote(BuildContext context, String side) {
    SocketService.instance.emit(Const.eventPkVote, {
      'userId': userId,
      'hostSide': side,
      'liveStreamingId': liveStreamingId,
    });
    Fluttertoast.showToast(msg: 'Vote sent for $side');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Vote', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _vote(context, 'host1'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7E3FF2)),
                    child: Text(host1Name),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _vote(context, 'host2'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    child: Text(host2Name),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Host lucky menu: draw or send a lucky bag.
void showHostLuckySheet(
  BuildContext context, {
  required String liveStreamingId,
  required String userId,
  required List<String> viewerNames,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _HostLuckySheet(
      liveStreamingId: liveStreamingId,
      userId: userId,
      viewerNames: viewerNames,
    ),
  );
}

class _HostLuckySheet extends StatefulWidget {
  const _HostLuckySheet({
    required this.liveStreamingId,
    required this.userId,
    required this.viewerNames,
  });

  final String liveStreamingId;
  final String userId;
  final List<String> viewerNames;

  @override
  State<_HostLuckySheet> createState() => _HostLuckySheetState();
}

class _HostLuckySheetState extends State<_HostLuckySheet> {
  final _coinsCtrl = TextEditingController();
  final _countCtrl = TextEditingController(text: '5');
  String? _drawResult;
  bool _drawing = false;

  @override
  void dispose() {
    _coinsCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  void _spin() {
    if (widget.viewerNames.isEmpty) {
      Fluttertoast.showToast(msg: 'No viewers to draw');
      return;
    }
    setState(() => _drawing = true);
    final names = [...widget.viewerNames];
    var ticks = 0;
    Timer.periodic(const Duration(milliseconds: 120), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _drawResult = names[Random().nextInt(names.length)]);
      ticks++;
      if (ticks > 20) {
        timer.cancel();
        final winner = names[Random().nextInt(names.length)];
        final diamonds = Random().nextInt(91) + 10;
        setState(() {
          _drawResult = '$winner won $diamonds diamonds!';
          _drawing = false;
        });
        SocketService.instance.emit(Const.luckyGift, {
          'liveStreamingId': widget.liveStreamingId,
          'userId': widget.userId,
          'winner': winner,
          'diamonds': diamonds,
        });
      }
    });
  }

  void _sendLuckyBag() {
    final coins = int.tryParse(_coinsCtrl.text.trim()) ?? 0;
    final count = int.tryParse(_countCtrl.text.trim()) ?? 0;
    if (coins <= 0 || count <= 0) {
      Fluttertoast.showToast(msg: 'Enter valid diamonds and count');
      return;
    }
    SocketService.instance.emit(Const.eventLuckyBagCreate, {
      'liveStreamingId': widget.liveStreamingId,
      'userId': widget.userId,
      'totalCoins': coins,
      'bagCount': count,
    });
    Fluttertoast.showToast(msg: 'Lucky bag sent!');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Lucky', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const TabBar(
                indicatorColor: Color(0xFF7E3FF2),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [Tab(text: 'Draw'), Tab(text: 'Lucky Bag')],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 260,
                child: TabBarView(
                  children: [
                    // Draw tab
                    Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: _drawing
                                ? const Preloader()
                                : Text(
                                    _drawResult ?? 'Tap Spin to pick a lucky viewer',
                                    style: const TextStyle(color: Colors.white, fontSize: 16),
                                    textAlign: TextAlign.center,
                                  ),
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _drawing ? null : _spin,
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7E3FF2)),
                            child: const Text('Spin'),
                          ),
                        ),
                      ],
                    ),
                    // Lucky Bag tab
                    Column(
                      children: [
                        TextField(
                          controller: _coinsCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Total Diamonds',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          ),
                        ),
                        TextField(
                          controller: _countCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Number of Bags',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _sendLuckyBag,
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7E3FF2)),
                            child: const Text('Send Lucky Bag'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Audience lucky bag claim.
void showLuckyBagClaimSheet(
  BuildContext context, {
  required String liveStreamingId,
    required String userId,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LuckyBagClaimSheet(
      liveStreamingId: liveStreamingId,
      userId: userId,
    ),
  );
}

class _LuckyBagClaimSheet extends StatefulWidget {
  const _LuckyBagClaimSheet({required this.liveStreamingId, required this.userId});

  final String liveStreamingId;
  final String userId;

  @override
  State<_LuckyBagClaimSheet> createState() => _LuckyBagClaimSheetState();
}

class _LuckyBagClaimSheetState extends State<_LuckyBagClaimSheet> {
  Function? _cancel;
  bool _available = false;
  bool _claimed = false;

  @override
  void initState() {
    super.initState();
    _cancel = SocketService.instance.on(Const.eventLuckyBagCreate, (data) {
      if (data is Map && (data['liveStreamingId']?.toString() == widget.liveStreamingId)) {
        setState(() => _available = true);
      }
    });
    // No initial query — wait for socket event from host.
  }

  @override
  void dispose() {
    _cancel?.call();
    super.dispose();
  }

  void _claim() {
    SocketService.instance.emit(Const.eventLuckyBagClaim, {
      'liveStreamingId': widget.liveStreamingId,
      'userId': widget.userId,
    });
    setState(() => _claimed = true);
    Fluttertoast.showToast(msg: 'Claimed!');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Lucky Bag', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            if (!_available && !_claimed)
              const Text('No lucky bag active right now', style: TextStyle(color: Colors.white70))
            else if (_claimed)
              const Icon(Icons.check_circle, color: Colors.green, size: 64)
            else
            ...[
              const ImageIcon(const AssetImage("assets/gift/official_gift.png"), color: Color(0xFF7E3FF2), size: 64),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _claim,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7E3FF2)),
                  child: const Text('Open Lucky Bag'),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Audio room live stats + host earnings dashboard.
// ---------------------------------------------------------------------------
void showAudioRoomLiveStatsSheet(
  BuildContext context, {
  required String userId,
  required int viewerCount,
  required int watchSeconds,
  required int sessionCoins,
  ValueListenable<LiveRoomAnalytics?>? liveAnalytics,
  ValueListenable<int>? watchSecondsNotifier,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:
        (_) => _AudioRoomLiveStatsSheet(
          userId: userId,
          viewerCount: viewerCount,
          watchSeconds: watchSeconds,
          sessionCoins: sessionCoins,
          liveAnalytics: liveAnalytics,
          watchSecondsNotifier: watchSecondsNotifier,
        ),
  );
}

class _AudioRoomLiveStatsSheet extends StatefulWidget {
  const _AudioRoomLiveStatsSheet({
    required this.userId,
    required this.viewerCount,
    required this.watchSeconds,
    required this.sessionCoins,
    this.liveAnalytics,
    this.watchSecondsNotifier,
  });

  final String userId;
  final int viewerCount;
  final int watchSeconds;
  final int sessionCoins;
  final ValueListenable<LiveRoomAnalytics?>? liveAnalytics;
  final ValueListenable<int>? watchSecondsNotifier;

  @override
  State<_AudioRoomLiveStatsSheet> createState() =>
      _AudioRoomLiveStatsSheetState();
}

class _AudioRoomLiveStatsSheetState extends State<_AudioRoomLiveStatsSheet> {
  HostEarnings? _earnings;
  final ValueNotifier<HostEarnings?> _earningsNotifier = ValueNotifier(null);
  bool _loading = true;
  Timer? _earningsRefreshTimer;

  List<Listenable> get _rebuildSignals => [
    _earningsNotifier,
    if (widget.liveAnalytics != null) widget.liveAnalytics!,
    if (widget.watchSecondsNotifier != null) widget.watchSecondsNotifier!,
  ];

  @override
  void initState() {
    super.initState();
    _load().then((_) {
      if (!mounted) return;
      _earningsRefreshTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _load(),
      );
    });
  }

  @override
  void dispose() {
    _earningsRefreshTimer?.cancel();
    _earningsNotifier.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final earnings = await HostFeaturesService.getEarnings(widget.userId);
      if (!mounted) return;
      _earnings = earnings;
      _earningsNotifier.value = earnings;
      setState(() => _loading = false);
    } catch (e, s) {
      Log.e('LiveStats', 'getEarnings failed', e, s);
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(_rebuildSignals),
      builder: (context, _) {
        final analytics = widget.liveAnalytics?.value;
        final currentViewers = analytics?.viewerCount ?? widget.viewerCount;
        final currentWatchSeconds =
            widget.watchSecondsNotifier?.value ?? widget.watchSeconds;
        final currentSessionCoins =
            (analytics != null && analytics.receivedCoins > 0)
                ? diamondsToBeans(
                  analytics.receivedCoins,
                  context.read<SessionManager>().getSetting(),
                )
                : widget.sessionCoins;
        final e = _earningsNotifier.value ?? _earnings;

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live Stats',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildCard(
                  icon: Icons.visibility,
                  label: 'Current Viewers',
                  value: '$currentViewers',
                ),
                const SizedBox(height: 10),
                _buildCard(
                  icon: Icons.timer,
                  label: 'Watch Time',
                  value: _formatTime(currentWatchSeconds),
                ),
                const SizedBox(height: 10),
                _buildCard(
                  icon: Icons.card_giftcard,
                  label: 'Beans This Session',
                  value: '$currentSessionCoins',
                ),
                const SizedBox(height: 10),
                if (_loading)
                  const SizedBox(
                    height: 80,
                    child: Center(
                      child: Preloader(
                        color: Color(0xFF7E3FF2),
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else if (e != null) ...[
                  _buildCard(
                    icon: Icons.account_balance_wallet,
                    label: "Today's Earnings",
                    value: '${e.todayCoins}',
                  ),
                  const SizedBox(height: 10),
                  _buildCard(
                    icon: Icons.diamond,
                    label: 'Total Earnings',
                    value: '${e.totalCoins}',
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF7E3FF2), size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
