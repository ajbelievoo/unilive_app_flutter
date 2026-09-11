/// Host Center — native replacement for the web-based host panel.
///
/// Features:
/// - Host dashboard with earnings, live stats, task progress
/// - Live history (monthly breakdown)
/// - Settlement/payout history
/// - Daily tasks with rewards
/// - Top creators ranking
library centers;

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/json_annotation_helper.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/host_features_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart' show formatCount;
import '../../utils/log.dart';
import '../../widgets/premium_ui.dart';
import '../../widgets/user_avatar.dart';

class HostCenterScreen extends StatefulWidget {
  const HostCenterScreen({super.key});

  @override
  State<HostCenterScreen> createState() => _HostCenterScreenState();
}

class _HostCenterScreenState extends State<HostCenterScreen>
    with SingleTickerProviderStateMixin {
  static const String _tag = 'HostCenter';

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _settlement;
  Map<String, dynamic>? _tasks;
  Map<String, dynamic>? _taskRewardHistory;
  Map<String, dynamic>? _liveHistory;
  Map<String, dynamic>? _todayLive;
  bool _loading = true;
  bool _isHost = true;
  String? _error;

  /// Tasks tab can show either current active tasks or reward history.
  bool _showTaskHistory = false;

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final session = context.read<SessionManager>();
    final hostId = session.userId;
    final month = DateTime.now().toIso8601String().substring(0, 7);

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getHostProfile(hostId),
        ApiService.getHostSettlement(hostId),
        ApiService.getHostTasks(hostId),
        ApiService.getHostLiveHistory(hostId: hostId, month: month),
        ApiService.getHostLiveHistoryToday(hostId),
      ]);
      _profile = results[0];
      _settlement = results[1];
      _tasks = results[2];
      _liveHistory = results[3];
      _todayLive = results[4];

      // Task reward history is non-critical: load it separately so the rest
      // of the Host Center still works if this endpoint is unavailable.
      try {
        _taskRewardHistory = await ApiService.getHostTaskRewardHistory(hostId);
      } catch (e) {
        Log.e(_tag, 'task reward history failed', e);
        _taskRewardHistory = {};
      }

      await _normalizeHostData(hostId);
      // Check if user is a host
      final data = _profile?['data'] as Map<String, dynamic>? ?? _profile;
      _isHost = data != null && parseBool(data['isHost']);
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Normalize `data` fields that may arrive as a Map or a List, and fall back
  /// to the local on-device cache when the backend endpoints are empty.
  Future<void> _normalizeHostData(String hostId) async {
    // Make sure today history has a List `data` entry.
    _todayLive ??= {};
    final todayRaw = _todayLive!['data'];
    if (todayRaw is Map) {
      _todayLive!['data'] = [todayRaw];
    }
    final todayList = _todayLive!['data'] as List? ?? [];
    final first = todayList.isNotEmpty ? todayList.first as Map<String, dynamic>? : null;
    final cacheFallback = first == null ||
        ((first['audioDuration'] ?? 0) == 0 &&
            (first['videoDuration'] ?? 0) == 0 &&
            (first['todayEarning'] ?? 0) == 0);
    if (cacheFallback) {
      try {
        final cache = await HostLiveCache.getTodayProgress(hostId);
        _todayLive!['data'] = [
          if (first != null) {...first, ...cache} else cache,
        ];
      } catch (e) {
        Log.e(_tag, 'today cache fallback failed', e);
      }
    }

    // Same for monthly live history — keep it as a List.
    _liveHistory ??= {};
    final historyRaw = _liveHistory!['data'];
    if (historyRaw is Map) {
      _liveHistory!['data'] = [historyRaw];
    } else if (historyRaw == null) {
      _liveHistory!['data'] = [];
    }

    // Normalize task reward history the same way.
    _taskRewardHistory ??= {};
    final taskHistoryRaw = _taskRewardHistory!['data'];
    if (taskHistoryRaw is Map) {
      _taskRewardHistory!['data'] = [taskHistoryRaw];
    } else if (taskHistoryRaw == null) {
      _taskRewardHistory!['data'] = [];
    }

    // If live history is empty but the cache has data, show a synthetic session.
    final historyList = _liveHistory!['data'] as List? ?? [];
    if (historyList.isEmpty) {
      try {
        final cache = await HostLiveCache.getTodayProgress(hostId);
        final hasProgress = (cache['audioDuration'] ?? 0) > 0 ||
            (cache['videoDuration'] ?? 0) > 0 ||
            (cache['todayEarning'] ?? 0) > 0;
        if (hasProgress) {
          _liveHistory!['data'] = [{
            'type': (cache['videoDuration'] ?? 0) > (cache['audioDuration'] ?? 0) ? 'video' : 'audio',
            'totalMinutes': cache['totalMinutes'],
            'duration': cache['totalMinutes'],
            'coin': cache['todayEarning'],
            'rCoin': cache['todayEarning'],
            'date': DateTime.now().toIso8601String(),
          }];
        }
      } catch (e) {
        Log.e(_tag, 'history cache fallback failed', e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: Column(children: [
            _buildHeader(),
            if (_loading)
              const Expanded(child: Center(child: PremiumLoading()))
            else if (_error != null)
              Expanded(
                child: EmptyState(
                  icon: Icons.error_outline,
                  title: 'Failed to load',
                  subtitle: _error!,
                  actionLabel: 'Retry',
                  onAction: _loadAll,
                ),
              )
            else if (!_isHost)
              Expanded(
                child: EmptyState(
                  icon: Icons.star_outline,
                  title: 'You are not a Host',
                  subtitle: 'Send a host request to an agency to become a host',
                  actionLabel: 'Send Host Request',
                  onAction: () => context.pushNamed(AppRoutes.hostRequest),
                ),
              )
            else ...[
              _buildStatsRow(),
              const SizedBox(height: 12),
              _buildTabBar(),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildDashboardTab(),
                    _buildLiveHistoryTab(),
                    _buildSettlementTab(),
                    _buildTasksTab(),
                  ],
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final user = context.read<SessionManager>().getUser();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        UserAvatar(
          imageUrl: user?.image,
          size: 40,
          isVIP: user?.isVIP ?? false,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.name ?? user?.username ?? 'Host',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'Host Center',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white70),
          onPressed: _loadAll,
        ),
      ]),
    );
  }

  Widget _buildStatsRow() {
    final data = _profile?['data'] as Map<String, dynamic>? ?? {};
    // hostLevel can be a string ID or an object — handle both
    String hostLevelText;
    final hl = data['hostLevel'];
    if (hl is Map<String, dynamic>) {
      hostLevelText = hl['name']?.toString() ?? 'Lv. ${hl['level'] ?? 0}';
    } else if (hl is String && hl.isNotEmpty) {
      hostLevelText = 'Active';
    } else {
      hostLevelText = 'N/A';
    }
    final rCoin = parseInt(data['rCoin'] ?? 0);
    final todayData = _todayLive?['data'] as List? ?? [];
    final todayMinutes = todayData.fold<int>(0, (sum, item) {
      final d = item as Map<String, dynamic>;
      return sum + parseInt(d['totalMinutes'] ?? d['duration'] ?? 0);
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        _statCard('Beans', formatCount(rCoin),
            Icons.grain, const [Color(0xFFFFB800), Color(0xFFFF9500)]),
        const SizedBox(width: 12),
        _statCard('Today Live', '${todayMinutes}m',
            Icons.schedule, const [Color(0xFF4F8DFD), Color(0xFF3B7BFF)]),
        const SizedBox(width: 12),
        _statCard(
            'Host Level',
            hostLevelText,
            Icons.star,
            const [Color(0xFFE0A800), Color(0xFFC88800)],
            onTap: () => context.pushNamed(AppRoutes.hostLevelList)),
      ]),
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon,
    List<Color> gradient, {
    VoidCallback? onTap,
  }) {
    Widget card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: gradient[0].withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
        ],
      ),
    );
    if (onTap != null) {
      card = GestureDetector(onTap: onTap, child: card);
    }
    return Expanded(child: card);
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabCtrl,
      indicatorColor: AppTheme.primary,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white54,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      tabs: const [
        Tab(text: 'Dashboard'),
        Tab(text: 'Live History'),
        Tab(text: 'Payouts'),
        Tab(text: 'Tasks'),
      ],
    );
  }

  Widget _buildDashboardTab() {
    final data = _profile?['data'] as Map<String, dynamic>? ?? {};
    final liveData = _liveHistory?['data'] as List? ?? [];
    final totalAudioDays = parseInt(_liveHistory?['totalAudioValidDays'] ?? 0);
    final totalVideoDays = parseInt(_liveHistory?['totalVideoValidDays'] ?? 0);
    final rCoin = parseInt(data['rCoin'] ?? 0);
    final earnCoin = parseInt(data['earnCoin'] ?? 0);
    final currentCoin = parseInt(data['currentCoin'] ?? 0);
    final spentCoin = parseInt(data['spentCoin'] ?? 0);
    final hostAgency = data['hostAgency'] as Map<String, dynamic>?;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Earnings card
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Earnings', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _infoRow('Beans', formatCount(rCoin), Icons.grain),
                _infoRow('Total Earned', formatCount(earnCoin), Icons.trending_up),
                _infoRow('Current Diamonds', formatCount(currentCoin), Icons.diamond),
                _infoRow('Diamonds Spent', formatCount(spentCoin), Icons.shopping_cart),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Agency info
        if (hostAgency != null)
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('My Agency', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _infoRow('Agency', hostAgency['name']?.toString() ?? 'N/A', Icons.business),
                  _infoRow('Agency ID', hostAgency['uniqueId']?.toString() ?? 'N/A', Icons.code),
                ],
              ),
            ),
          ),
        if (hostAgency != null) const SizedBox(height: 16),
        // Monthly summary
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Monthly Summary', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _infoRow('Audio Valid Days', '$totalAudioDays', Icons.mic),
                _infoRow('Video Valid Days', '$totalVideoDays', Icons.videocam),
                _infoRow('Total Sessions', '${liveData.length}', Icons.history),
                _infoRow('Bio', data['bio']?.toString() ?? 'N/A', Icons.person),
                _infoRow('Country', data['country']?.toString() ?? 'N/A', Icons.public),
                _infoRow('Bank Details', data['bankDetails']?.toString() ?? 'N/A', Icons.account_balance),
                _infoRow('Can Live', data['enableToLive'] == true ? 'Yes' : 'No', Icons.live_tv),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (liveData.isNotEmpty) ...[
          const Text('Recent Sessions', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...liveData.take(5).map((item) {
            final d = item as Map<String, dynamic>;
            return _sessionTile(d);
          }),
        ],
      ],
    );
  }

  Widget _buildLiveHistoryTab() {
    final liveData = _liveHistory?['data'] as List? ?? [];
    if (liveData.isEmpty) {
      return const Center(child: EmptyState(icon: Icons.history, title: 'No Live History', subtitle: 'Your live sessions will appear here'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: liveData.length,
      itemBuilder: (_, i) {
        final d = liveData[i] as Map<String, dynamic>;
        return _sessionTile(d);
      },
    );
  }

  Widget _buildSettlementTab() {
    final history = _settlement?['history'] as List? ?? [];
    final total = parseInt(_settlement?['total'] ?? 0);
    if (history.isEmpty && total == 0) {
      return const Center(child: EmptyState(icon: Icons.account_balance_wallet, title: 'No Payouts Yet', subtitle: 'Your settlement history will appear here'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Settled', style: TextStyle(color: Colors.white70, fontSize: 14)),
                Text(formatCount(total), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...history.map((item) {
          final d = item as Map<String, dynamic>;
          return _settlementTile(d);
        }),
      ],
    );
  }

  Widget _buildTasksTab() {
    final tasks = _tasks?['data'] as List? ?? [];
    final history = _taskRewardHistory?['data'] as List? ?? [];

    return Column(
      children: [
        _buildTaskModeSwitch(),
        Expanded(
          child: _showTaskHistory
              ? _buildTaskHistoryList(history)
              : _buildCurrentTaskList(tasks),
        ),
      ],
    );
  }

  Widget _buildTaskModeSwitch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildModeButton('Current Tasks', !_showTaskHistory, () {
                if (_showTaskHistory) setState(() => _showTaskHistory = false);
              }),
            ),
            Expanded(
              child: _buildModeButton('Task History', _showTaskHistory, () {
                if (!_showTaskHistory) setState(() => _showTaskHistory = true);
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF6A5AE0) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTaskList(List tasks) {
    if (tasks.isEmpty) {
      return const Center(child: EmptyState(icon: Icons.task_alt, title: 'No Tasks', subtitle: 'Daily tasks will appear here'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (_, i) {
        final t = tasks[i] as Map<String, dynamic>;
        return _taskTile(t);
      },
    );
  }

  Widget _buildTaskHistoryList(List history) {
    if (history.isEmpty) {
      return const Center(child: EmptyState(icon: Icons.history, title: 'No Task History', subtitle: 'Claimed and completed tasks will appear here'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (_, i) {
        final h = history[i] as Map<String, dynamic>;
        return _taskHistoryTile(h);
      },
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
        const Spacer(),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _sessionTile(Map<String, dynamic> d) {
    final type = d['type']?.toString() ?? 'video';
    final minutes = parseInt(d['totalMinutes'] ?? d['duration'] ?? 0);
    final coins = parseInt(d['coin'] ?? d['rCoin'] ?? 0);
    final date = d['date']?.toString() ?? d['createdAt']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (type == 'audio' ? const Color(0xFF6A5AE0) : const Color(0xFFFF6B9D)).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(type == 'audio' ? Icons.mic : Icons.videocam, color: type == 'audio' ? const Color(0xFF6A5AE0) : const Color(0xFFFF6B9D), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(type == 'audio' ? 'Audio Live' : 'Video Live', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              if (date.isNotEmpty)
                Text(date.split('T').first, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${minutes}m', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Text(formatCount(coins), style: const TextStyle(color: Color(0xFFFFB800), fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ]),
    );
  }

  Widget _settlementTile(Map<String, dynamic> d) {
    final amount = parseInt(d['coin'] ?? d['amount'] ?? 0);
    final status = d['status']?.toString() ?? 'pending';
    final date = d['date']?.toString() ?? d['createdAt']?.toString() ?? '';
    final Color statusColor = status == 'approved' || status == 'completed'
        ? Colors.green
        : status == 'rejected'
            ? Colors.red
            : Colors.orange;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.account_balance_wallet, color: statusColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formatCount(amount), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              if (date.isNotEmpty)
                Text(date.split('T').first, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  Widget _taskTile(Map<String, dynamic> t) {
    final type = t['type']?.toString() ?? 'video';
    final targetType = t['targetType']?.toString() ?? '';
    final timeRequired = _firstInt(t, const [
      'timeRequired',
      'timeRequirement',
      'timeTarget',
      'targetTime',
      'target',
      'requiredTime',
      'required',
      'duration',
      'minutes',
      'time',
    ]);
    final coinRequired = _firstInt(t, const [
      'coinRequired',
      'coinRequirement',
      'rCoinRequired',
      'earningRequired',
      'earnRequired',
      'earningTarget',
      'targetEarning',
      'targetAmount',
      'beansRequired',
      'amount',
      'target',
    ]);
    final coinsRewarded = _firstInt(t, const [
      'coinsRewarded',
      'rewardCoins',
      'reward',
      'coin',
    ]);
    final isClaimed = _parseClaimed(t);
    final taskId = t['_id']?.toString() ?? t['id']?.toString() ?? t['taskId']?.toString() ?? '';

    // Get today's progress from _todayLive
    final todayData = _todayLive?['data'] as List? ?? [];
    final today = todayData.isNotEmpty ? todayData[0] as Map<String, dynamic> : <String, dynamic>{};
    final completedTime = _firstInt(today, type == 'audio'
        ? const ['audioDuration', 'audioMinutes', 'audioTime', 'duration', 'totalMinutes', 'minutes']
        : const ['videoDuration', 'videoMinutes', 'videoTime', 'duration', 'totalMinutes', 'minutes']);
    final todayEarning = _firstInt(today, const [
      'todayEarning',
      'todayEarnings',
      'earning',
      'earnings',
      'coin',
      'coins',
      'rCoin',
      'todayRcoin',
      'todayRCoin',
      'totalEarning',
      'totalEarnings',
    ]);

    // Prefer the backend's completion flag when provided. When the backend
    // doesn't yet mark the task complete, still let the user try to claim —
    // the server may accept it once it sees the live duration update. This
    // matches the native UnilivePro behaviour where the claim button appears
    // as soon as the local progress bar reaches 100%.
    final backendCompleted = t.containsKey('completed') ? parseBool(t['completed']) : null;
    final timeDone = completedTime >= timeRequired;
    final coinDone = todayEarning >= coinRequired;
    final canClaim = (backendCompleted == true || (timeDone && coinDone)) && !isClaimed;

    // Progress percentage
    final timeProgress = timeRequired > 0 ? (completedTime / timeRequired).clamp(0.0, 1.0) : 1.0;
    final coinProgress = coinRequired > 0 ? (todayEarning / coinRequired).clamp(0.0, 1.0) : 1.0;
    final overallProgress = (timeProgress + coinProgress) / 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isClaimed
              ? [Colors.grey.withValues(alpha: 0.1), Colors.grey.withValues(alpha: 0.05)]
              : [const Color(0xFF6A5AE0).withValues(alpha: 0.15), const Color(0xFF4A3FB8).withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isClaimed ? Colors.grey.withValues(alpha: 0.2) : const Color(0xFF6A5AE0).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: type + reward badge
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (type == 'audio' ? const Color(0xFF6A5AE0) : const Color(0xFFFF6B9D)).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(type == 'audio' ? Icons.mic : Icons.videocam,
                  color: type == 'audio' ? const Color(0xFF6A5AE0) : const Color(0xFFFF6B9D), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('${type == 'audio' ? 'Audio' : 'Video'} Live Task',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.diamond, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(formatCount(coinsRewarded),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          // Time progress
          _taskProgressRow('Time', '$completedTime / $timeRequired min', timeProgress,
              timeDone ? Colors.green : const Color(0xFF6A5AE0)),
          const SizedBox(height: 10),
          // Coin progress (only if coinRequired > 0)
          if (coinRequired > 0) ...[
            _taskProgressRow('Earning', '${formatCount(todayEarning)} / ${formatCount(coinRequired)}', coinProgress,
                coinDone ? Colors.green : Colors.orange),
            const SizedBox(height: 10),
          ],
          // Status / Claim button
          if (isClaimed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 18),
                  SizedBox(width: 6),
                  Text('Already Claimed', style: TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold)),
                ]),
              ),
            )
          else if (canClaim)
            _claimButton(taskId)
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Center(
                child: Text(
                  'In Progress ${(overallProgress * 100).toInt()}%',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _taskHistoryTile(Map<String, dynamic> h) {
    final legacyType = h['type']?.toString() ?? 'video';
    final title = h['title']?.toString() ?? '${legacyType == 'audio' ? 'Audio' : 'Video'} Live Task';
    final description = h['description']?.toString() ?? '';
    final timeTarget = parseInt(h['timeRequired'] ?? h['target'] ?? h['duration'] ?? 0);
    final coinTarget = parseInt(h['coinRequired'] ?? 0);
    final coinsRewarded = parseInt(h['coinsRewarded'] ?? h['rewardCoins'] ?? h['coin'] ?? 0);
    final isClaimed = parseBool(h['isClaimed'] ?? h['claimed']);
    final completedAt = h['claimedAt']?.toString() ??
        h['completedAt']?.toString() ??
        h['createdAt']?.toString() ??
        h['updatedAt']?.toString() ??
        h['date']?.toString() ??
        '';

    String subtitle;
    if (description.isNotEmpty) {
      subtitle = description;
    } else if (timeTarget > 0) {
      subtitle = '$timeTarget min completed';
    } else if (coinTarget > 0) {
      subtitle = '${formatCount(coinTarget)} earning target';
    } else {
      subtitle = 'Task completed';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (legacyType == 'audio' ? const Color(0xFF6A5AE0) : const Color(0xFFFF6B9D)).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(legacyType == 'audio' ? Icons.mic : Icons.videocam,
              color: legacyType == 'audio' ? const Color(0xFF6A5AE0) : const Color(0xFFFF6B9D), size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
              ),
              if (completedAt.isNotEmpty)
                Text(
                  completedAt.split('T').first,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.diamond, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(formatCount(coinsRewarded),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isClaimed ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isClaimed ? 'Claimed' : 'Completed',
                style: TextStyle(
                  color: isClaimed ? Colors.green : Colors.orange,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ]),
    );
  }

  Widget _taskProgressRow(String label, String value, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
          const Spacer(),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _claimButton(String taskId) {
    return Builder(builder: (context) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _claimTask(taskId),
          icon: const ImageIcon(const AssetImage("assets/gift/official_gift.png"), size: 18),
          label: const Text('Claim Reward', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6A5AE0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
      );
    });
  }

  Future<void> _syncLiveHistoryBeforeClaim(String hostId) async {
    final ids = <String>{};
    for (final source in [_todayLive?['data'], _liveHistory?['data']]) {
      final entries = source is List ? source : (source is Map ? [source] : const []);
      for (final entry in entries.take(10)) {
        if (entry is! Map) continue;
        final id =
            parseString(
              entry['liveStreamingId'] ??
                  entry['liveId'] ??
                  entry['streamId'] ??
                  entry['_id'],
              '',
            ) ??
            '';
        if (id.isNotEmpty) ids.add(id);
      }
    }
    await Future.wait(
      ids.map((id) async {
        try {
          await ApiService.updateLiveTime(hostId, id);
        } catch (_) {}
      }),
    );
  }

  Future<void> _claimTask(String taskId) async {
    final session = context.read<SessionManager>();
    try {
      await _syncLiveHistoryBeforeClaim(session.userId);
      final today = _todayLive?['data'] is List
          ? (_todayLive!['data'] as List).isNotEmpty
              ? _todayLive!['data'][0] as Map<String, dynamic>
              : <String, dynamic>{}
          : <String, dynamic>{};
      final videoDuration = parseInt(today['videoDuration'] ?? today['videoMinutes'] ?? today['videoTime'] ?? 0);
      final audioDuration = parseInt(today['audioDuration'] ?? today['audioMinutes'] ?? today['audioTime'] ?? 0);
      final earning = parseInt(today['todayEarning'] ?? today['earning'] ?? today['coin'] ?? today['rCoin'] ?? 0);
      final liveId = parseString(today['liveStreamingId'] ?? today['liveId'] ?? today['streamId'] ?? today['_id']);
      final res = await ApiService.claimTaskReward(
        hostId: session.userId,
        taskId: taskId,
        liveStreamingId: liveId,
        videoDuration: videoDuration > 0 ? videoDuration : null,
        audioDuration: audioDuration > 0 ? audioDuration : null,
        rCoin: earning > 0 ? earning : null,
        coin: earning > 0 ? earning : null,
      );
      final data = res['data'] is Map ? Map<String, dynamic>.from(res['data'] as Map) : res;
      final ok = parseBool(res['status']) ||
          parseBool(res['success']) ||
          parseBool(data['status']) ||
          parseBool(data['success']);
      if (ok) {
        Fluttertoast.showToast(
          msg: res['message']?.toString() ?? data['message']?.toString() ?? 'Reward claimed!',
        );
        // Refresh the session user so the new balance shows everywhere.
        try {
          final userRes = await ApiService.getUser({'userId': session.userId});
          final fresh = userRes.user;
          if (fresh != null) session.saveUser(fresh);
        } catch (e) {
          Log.w(_tag, 'user refresh after claim failed: $e');
        }
        _loadAll();
      } else {
        final msg = res['message']?.toString() ?? data['message']?.toString() ?? 'Failed to claim';
        Log.e(_tag, 'claimTask failed: $msg res=$res');
        Fluttertoast.showToast(msg: msg);
      }
    } catch (e, s) {
      Log.e(_tag, 'claimTask exception', e, s);
      Fluttertoast.showToast(msg: 'Failed to claim reward');
    }
  }

  /// Parse a claimed flag from common backend keys.
  bool _parseClaimed(Map<String, dynamic> t) {
    const keys = ['isClaimed', 'claimed', 'isRewardClaimed', 'rewardClaimed'];
    for (final key in keys) {
      final value = t[key];
      if (value != null) return parseBool(value);
    }
    return false;
  }

  /// Read the first non-null numeric value from a list of keys.
  int _firstInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return 0;
  }
}
