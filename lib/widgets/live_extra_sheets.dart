import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../constants/const.dart';
import '../models/room_runtime_models.dart';
import '../services/host_features_service.dart';
import '../services/session_manager.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';
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
    builder:
        (_) => _PkVoteSheet(
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
      decoration: BoxDecoration(
        color: AppTheme.themed(context, 0xFF1A1A2E, 0xFFF8F7FE),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Vote',
              style: TextStyle(
                color: AppTheme.fg(context),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _vote(context, 'host1'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E3FF2),
                    ),
                    child: Text(host1Name),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _vote(context, 'host2'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
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
          decoration: BoxDecoration(
            color: AppTheme.themed(context, 0xFF1A1A2E, 0xFFF8F7FE),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Stats',
                  style: TextStyle(
                    color: AppTheme.fg(context),
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
        color: AppTheme.themed(context, 0x4D000000, 0xFFF1F1FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF7E3FF2), size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: AppTheme.fg(context, 0.7), fontSize: 14),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.fg(context),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
