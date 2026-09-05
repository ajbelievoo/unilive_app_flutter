/// VIP Leaderboard screen — top VIP point earners.
///
/// Bigo Live style — shows monthly and all-time VIP point rankings with
/// user avatars, VIP levels, and points.
library vip_leaderboard;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/vip_extended_models.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../utils/log.dart';
import '../../utils/media_utils.dart';
import 'package:belive/widgets/preloader.dart';

class VipLeaderboardScreen extends StatefulWidget {
  const VipLeaderboardScreen({super.key});

  @override
  State<VipLeaderboardScreen> createState() => _VipLeaderboardScreenState();
}

class _VipLeaderboardScreenState extends State<VipLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  static const String _tag = 'VipLeaderboard';
  late TabController _tab;
  final _monthly = <VipLeaderboardItem>[];
  final _allTime = <VipLeaderboardItem>[];
  bool _loadingMonthly = true;
  bool _loadingAllTime = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadMonthly();
    _loadAllTime();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadMonthly() async {
    setState(() => _loadingMonthly = true);
    try {
      final res = await ApiService.getVipLeaderboard(period: 'month');
      if (res.status) {
        _monthly.clear();
        _monthly.addAll(res.data);
      }
    } catch (e, s) {
      Log.e(_tag, 'loadMonthly failed', e, s);
    } finally {
      if (mounted) setState(() => _loadingMonthly = false);
    }
  }

  Future<void> _loadAllTime() async {
    setState(() => _loadingAllTime = true);
    try {
      final res = await ApiService.getVipLeaderboard(period: 'all');
      if (res.status) {
        _allTime.clear();
        _allTime.addAll(res.data);
      }
    } catch (e, s) {
      Log.e(_tag, 'loadAllTime failed', e, s);
    } finally {
      if (mounted) setState(() => _loadingAllTime = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _buildList(_monthly, _loadingMonthly, _loadMonthly, 'month'),
                    _buildList(_allTime, _loadingAllTime, _loadAllTime, 'all'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
          const Expanded(
            child: Center(
              child: Text('VIP Leaderboard', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tab,
        indicator: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: AppTheme.goldGradient),
        labelColor: Colors.black,
        unselectedLabelColor: Colors.white70,
        tabs: const [Tab(text: 'This Month'), Tab(text: 'All Time')],
      ),
    );
  }

  Widget _buildList(List<VipLeaderboardItem> items, bool loading, VoidCallback onRefresh, String period) {
    if (loading) return const Center(child: Preloader());
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.leaderboard_outlined, color: Colors.white38, size: 64),
            const SizedBox(height: 16),
            const Text('No data available', style: TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 12),
            TextButton(onPressed: onRefresh, child: const Text('Refresh')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async { onRefresh(); },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, i) => _buildRankCard(items[i], i, period),
      ),
    );
  }

  Widget _buildRankCard(VipLeaderboardItem item, int index, String period) {
    final rank = item.rank > 0 ? item.rank : index + 1;
    final points = period == 'month' ? item.monthlyPoints : item.totalPoints;
    final session = context.read<SessionManager>();
    final isMe = item.userId == session.userId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: isMe
            ? LinearGradient(colors: [AppTheme.primary.withValues(alpha: 0.2), Colors.transparent])
            : null,
        color: isMe ? null : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isMe ? AppTheme.primary.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          // Rank badge
          SizedBox(
            width: 40,
            child: _buildRankBadge(rank),
          ),
          const SizedBox(width: 12),
          // Avatar
          ClipOval(
            child: SizedBox(
              width: 44, height: 44,
              child: (item.image != null && item.image!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: VideoUtil.getFullImageUrl(item.image),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: Colors.grey.shade800, child: const Icon(Icons.person, color: Colors.white54)),
                    )
                  : Container(color: Colors.grey.shade800, child: const Icon(Icons.person, color: Colors.white54)),
            ),
          ),
          const SizedBox(width: 12),
          // Name + VIP level
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name ?? 'Unknown',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    decoration: isMe ? TextDecoration.underline : TextDecoration.none,
                  ),
                ),
                if (item.vipLevel > 0)
                  Row(
                    children: [
                      Icon(Icons.workspace_premium, size: 12, color: const Color(0xFFFFD700)),
                      const SizedBox(width: 2),
                      Text('VIP ${item.vipLevel}', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
              ],
            ),
          ),
          // Points
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatCount(points), style: const TextStyle(color: Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.w800)),
              const Text('points', style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    if (rank == 1) return const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 32);
    if (rank == 2) return const Icon(Icons.emoji_events, color: Color(0xFFC0C0C0), size: 28);
    if (rank == 3) return const Icon(Icons.emoji_events, color: Color(0xFFCD7F32), size: 26);
    return Text('$rank', style: const TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold));
  }
}
