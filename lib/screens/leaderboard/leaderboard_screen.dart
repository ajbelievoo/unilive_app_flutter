/// Leaderboard screen — ported from native `LeaderboardActivity.java`.
///
/// Three tabs: Users (spending), Hosts (receiving), Agencies.
/// Each tab supports daily/weekly/monthly filtering.
library leaderboard_screen;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/leaderboard_complain_models.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import '../../widgets/user_avatar.dart';
import 'package:belive/widgets/preloader.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  static const String _tag = 'Leaderboard';

  late TabController _tabController;
  String _period = 'daily';
  bool _loading = false;

  final _userList = <LeaderboardEntry>[];
  final _hostList = <LeaderboardEntry>[];
  final _agencyList = <LeaderboardEntry>[];

  final _tabs = const ['Users', 'Hosts', 'Agencies'];
  // Host tab is unified — one host owns both audio + video live, so
  // their ranking combines earnings from both (Bigo/Chamet parity).
  final _periods = const ['daily', 'weekly', 'monthly'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadData();
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final type = ['user', 'host', 'agency'][_tabController.index];
    setState(() => _loading = true);

    try {
      final userId = SessionManager.instance?.userId ?? '';
      final result = await ApiService.getLeaderboard(
        type: type,
        userId: userId,
        period: _period,
      );

      final root = LeaderboardRoot.fromJson(result);
      final list = root.leaderboard;

      if (type == 'user') {
        _userList
          ..clear()
          ..addAll(list);
      } else if (type == 'host') {
        _hostList
          ..clear()
          ..addAll(list);
      } else {
        _agencyList
          ..clear()
          ..addAll(list);
      }
    } catch (e, s) {
      Log.e(_tag, 'loadData failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<LeaderboardEntry> get _currentList {
    switch (_tabController.index) {
      case 0:
        return _userList;
      case 1:
        return _hostList;
      default:
        return _agencyList;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
        ),
      ),
      body: Column(
        children: [
          _buildPeriodSelector(),
          Expanded(
            child: _loading
                ? const Center(child: Preloader())
                : _currentList.isEmpty
                    ? const SizedBox.shrink()
                    : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: _periods.map((p) {
          final isSelected = p == _period;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(p[0].toUpperCase() + p.substring(1)),
                selected: isSelected,
                onSelected: (_) {
                  if (!isSelected) {
                    _period = p;
                    _loadData();
                  }
                },
                selectedColor: AppTheme.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildList() {
    final list = _currentList;
    final type = ['user', 'host', 'agency'][_tabController.index];
    // Bigo/Chamet-style: top-3 podium for host tab, unified across audio +
    // video live (one host owns both — ranking combines all earnings).
    final showPodium = list.length >= 3;
    return CustomScrollView(
      slivers: [
        if (showPodium)
          SliverToBoxAdapter(child: _buildPodium(list.take(3).toList(), type)),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final entry = list[index];
              final rank = index + 1;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: type == 'agency'
                      ? null
                      : () {
                          final userId = entry.userId ?? entry.id;
                          if (userId == null || userId.isEmpty) return;
                          context.pushNamed(AppRoutes.guestProfile, extra: {'userId': userId});
                        },
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: rank <= 3
                                ? [Colors.amber, Colors.grey, Colors.brown][rank - 1]
                                : AppTheme.textTertiary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      UserAvatar(
                        imageUrl: entry.displayImage,
                        frameUrl: entry.avatarFrameImage,
                        size: 40,
                        isVIP: entry.isVIP,
                        isVerified: entry.isVerified,
                        vipBadgeUrl: entry.vipBadgeUrl,
                      ),
                    ],
                  ),
                  title: Text(entry.displayName),
                  subtitle: Text('Level ${entry.level ?? '1'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        type == 'user' ? Icons.diamond : Icons.savings,
                        color: Colors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${entry.rankingValue(type)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              );
            },
            childCount: list.length,
          ),
        ),
      ],
    );
  }

  /// Bigo/Chamet-style top-3 podium — gold/silver/bronze pedestals.
  Widget _buildPodium(List<LeaderboardEntry> top3, String type) {
    final podiumOrder = [1, 0, 2]; // 2nd, 1st, 3rd (Bigo layout)
    final heights = [80.0, 110.0, 60.0];
    final colors = [
      const Color(0xFFC0C0C0), // Silver
      const Color(0xFFFFD700), // Gold
      const Color(0xFFCD7F32), // Bronze
    ];
    final labels = ['2nd', '1st', '3rd'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (i) {
          final entry = top3[podiumOrder[i]];
          final color = colors[i];
          final height = heights[i];
          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: i == 1 ? 8 : 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar with crown for #1
                  Stack(
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.none,
                    children: [
                      if (i == 1)
                        const Positioned(
                          top: -22,
                          child: Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 28),
                        ),
                      UserAvatar(
                        imageUrl: entry.displayImage,
                        frameUrl: entry.avatarFrameImage,
                        size: i == 1 ? 64 : 52,
                        isVIP: entry.isVIP,
                        isVerified: entry.isVerified,
                        vipBadgeUrl: entry.vipBadgeUrl,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    entry.displayName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  // Coins
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.diamond, color: color, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        '${entry.rankingValue(type)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Pedestal
                  Container(
                    width: double.infinity,
                    height: height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withValues(alpha: 0.8),
                          color.withValues(alpha: 0.3),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Center(
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

