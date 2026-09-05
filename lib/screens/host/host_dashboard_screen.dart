/// Host dashboard screen — earnings, level/XP, achievements, tasks, analytics.
///
/// Ports native host features UI:
/// - Earnings summary (today, week, month, total)
/// - Level/XP progress bar
/// - Achievements grid
/// - Daily/weekly tasks list
/// - Analytics graph (viewer count, watch time)
library host_dashboard_screen;

import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../constants/const.dart';
import '../../providers/auth_provider.dart';
import '../../services/host_features_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../utils/log.dart';
import '../../widgets/currency_icon.dart';
import 'package:belive/widgets/preloader.dart';

class HostDashboardScreen extends StatefulWidget {
  const HostDashboardScreen({super.key});

  @override
  State<HostDashboardScreen> createState() => _HostDashboardScreenState();
}

class _HostDashboardScreenState extends State<HostDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _userId = '';
  HostEarnings? _earnings;
  HostLevel? _level;
  List<HostAchievement> _achievements = [];
  List<HostTask> _tasks = [];
  List<HostAnalyticsPoint> _analytics = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData().then((_) => _startRefreshTimer());
  }

  @override
  void dispose() {
    _stopRefreshTimer();
    _tabController.dispose();
    super.dispose();
  }

  /// Keep the dashboard fresh while the host is actively managing the room.
  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadData(silent: true),
    );
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _loadData({bool silent = false}) async {
    final userId =
        context.read<AuthProvider>().user?.id ??
        context.read<SessionManager>().userId;
    _userId = userId;
    if (userId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (!silent) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        HostFeaturesService.getEarnings(userId),
        HostFeaturesService.getLevel(userId),
        HostFeaturesService.getAchievements(userId),
        HostFeaturesService.getTasks(userId),
        HostFeaturesService.getAnalytics(userId, days: 7),
      ]);
      if (mounted) {
        setState(() {
          _earnings = results[0] as HostEarnings;
          _level = results[1] as HostLevel;
          _achievements = results[2] as List<HostAchievement>;
          _tasks = results[3] as List<HostTask>;
          _analytics = results[4] as List<HostAnalyticsPoint>;
          _isLoading = false;
        });
      }
    } catch (e) {
      Log.e('HostDashboard', 'load failed', e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Host Dashboard'),
        centerTitle: true,
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textTertiary,
          indicatorColor: AppTheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Earnings'),
            Tab(text: 'Level'),
            Tab(text: 'Achievements'),
            Tab(text: 'Tasks'),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: Preloader(color: AppTheme.primary))
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildEarningsTab(),
                  _buildLevelTab(),
                  _buildAchievementsTab(),
                  _buildTasksTab(),
                ],
              ),
    );
  }

  // ---- Earnings Tab ----
  Widget _buildEarningsTab() {
    final e = _earnings ?? HostEarnings();
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
        _buildTotalEarningsCard(e),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.mic,
                iconColor: AppTheme.primary,
                label: 'Total Sessions',
                value: formatCount(e.totalSessions),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.schedule,
                iconColor: AppTheme.secondary,
                label: 'Total Hours',
                value: '${e.totalHours}h',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Weekly Analytics',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildAnalyticsChart(),
        ],
      ),
    );
  }

  Widget _buildTotalEarningsCard(HostEarnings e) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.purpleGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.primaryShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Earnings',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCount(e.totalCoins),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CurrencyIcon(CurrencyType.bean, size: 14),
                    SizedBox(width: 4),
                    Text(
                      Const.rCoinName,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _StatChip(label: 'Today', value: formatCount(e.todayCoins)),
              const SizedBox(width: 16),
              _StatChip(label: 'This Week', value: formatCount(e.weekCoins)),
              const SizedBox(width: 16),
              _StatChip(label: 'This Month', value: formatCount(e.monthCoins)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsChart() {
    if (_analytics.isEmpty) {
      return Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
        ),
        child: const Center(
          child: Text(
            'No analytics data yet',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 14),
          ),
        ),
      );
    }
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots:
                  _analytics
                      .asMap()
                      .entries
                      .map(
                        (e) => FlSpot(
                          e.key.toDouble(),
                          e.value.viewers.toDouble(),
                        ),
                      )
                      .toList(),
              isCurved: true,
              color: AppTheme.primary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.primary.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Level Tab ----
  Widget _buildLevelTab() {
    final level = _level ?? HostLevel();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.purpleGradient,
                boxShadow: AppTheme.primaryShadow,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Lv ${level.level}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'LEVEL',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _levelTitle(level.title),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${level.currentXp} XP',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${level.nextLevelXp} XP',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: level.progress,
                      minHeight: 12,
                      backgroundColor: AppTheme.surfaceLight,
                      valueColor: const AlwaysStoppedAnimation(
                        AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(level.progress * 100).round()}% to Level ${level.level + 1}',
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Achievements Tab ----
  Widget _buildAchievementsTab() {
    if (_achievements.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        color: AppTheme.primary,
        backgroundColor: AppTheme.surface,
        child: const SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 300,
            child: Center(
              child: Text(
                'No achievements yet',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 14),
              ),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.0,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _achievements.length,
      itemBuilder: (_, i) {
        final a = _achievements[i];
        final (icon, color) = _achievementStyle(a.id);
        final fg = a.unlocked ? color : AppTheme.textTertiary;
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: a.unlocked ? color : AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  a.title,
                  style: TextStyle(
                    color:
                        a.unlocked
                            ? AppTheme.textPrimary
                            : AppTheme.textTertiary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  a.description,
                  style: TextStyle(
                    color:
                        a.unlocked
                            ? AppTheme.textSecondary
                            : AppTheme.textTertiary,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (a.target != null && !a.unlocked) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${a.progress ?? 0}/${a.target}',
                    style: TextStyle(
                      color: fg,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
  }

  String _levelTitle(String title) {
    if (title.isEmpty || _looksLikeObjectId(title)) return 'Rookie';
    return title;
  }

  static bool _looksLikeObjectId(String s) {
    if (s.length != 24) return false;
    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(s);
  }

  (IconData, Color) _achievementStyle(String id) {
    const map = <String, (IconData, Color)>{
      'first_stream': (Icons.mic, Color(0xFF7B61FF)),
      '100_viewers': (Icons.people_outline, Color(0xFF64B5F6)),
      '1000_hours': (Icons.access_time, Color(0xFFFF8A80)),
      '10000_coins': (Icons.account_balance_wallet, Color(0xFFFFD54F)),
      '50_sessions': (Icons.military_tech, Color(0xFFFFB74D)),
      '7_day_streak': (Icons.local_fire_department, Color(0xFFFF7043)),
    };
    return map[id] ?? (Icons.emoji_events, AppTheme.primary);
  }

  // ---- Tasks Tab ----
  Widget _buildTasksTab() {
    final daily = _tasks.where((t) => t.type == 'daily').toList();
    final weekly = _tasks.where((t) => t.type == 'weekly').toList();
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildSectionHeader('Daily Tasks'),
          const SizedBox(height: 12),
          ...daily.map(_buildTaskCard),
          const SizedBox(height: 24),
          _buildSectionHeader('Weekly Tasks'),
          const SizedBox(height: 12),
          ...weekly.map(_buildTaskCard),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: const BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(HostTask task) {
    final progress =
        task.target > 0 ? (task.progress / task.target).clamp(0.0, 1.0) : 0.0;
    final canClaim = task.completed && !task.claimed;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showTaskRules(task),
                      child: const Icon(
                        Icons.info_outline,
                        color: AppTheme.primary,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  task.description,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: AppTheme.surfaceLight,
                          valueColor: AlwaysStoppedAnimation(
                            task.completed ? AppTheme.green : AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${task.progress}/${task.target}',
                      style: const TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CurrencyIcon(CurrencyType.diamond, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '+${task.rewardCoins}',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: FilledButton(
                  onPressed:
                      canClaim
                          ? () async {
                            final ok =
                                await HostFeaturesService.claimTaskReward(
                                  userId: _userId,
                                  taskId: task.id,
                                );
                            if (ok) {
                              Fluttertoast.showToast(
                                msg:
                                    'Reward claimed: +${task.rewardCoins} ${Const.coinName}',
                              );
                              _loadData();
                            }
                          }
                          : null,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        task.claimed
                            ? AppTheme.green
                            : canClaim
                            ? AppTheme.primary
                            : AppTheme.surfaceVariant,
                    foregroundColor:
                        task.claimed || canClaim
                            ? Colors.white
                            : AppTheme.textTertiary,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    task.claimed
                        ? 'Claimed'
                        : canClaim
                        ? 'Claim'
                        : 'Claim',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTaskRules(HostTask task) {
    const defaultRules =
        '1. Mic must be ON while streaming.\n'
        '2. Rewards are only counted when the microphone is active.\n'
        '3. For "Stream 1 hour", only un-muted streaming time counts.\n'
        '4. Claims expire at midnight (task daily reset).\n'
        '5. Penalties apply if the room has no host/admin/moderator.';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Rules: ${task.title}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  task.rules.isNotEmpty ? task.rules : defaultRules,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }
}

// ---- Helper widgets ----
class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
