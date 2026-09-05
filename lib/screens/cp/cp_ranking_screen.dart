/// CP Ranking screen — full couple leaderboard with period selector.
library cp_ranking;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/cp_models.dart';
import '../../providers/cp_provider.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../widgets/cp_widgets.dart';
import '../../widgets/premium_ui.dart';

class CPRankingScreen extends StatefulWidget {
  const CPRankingScreen({super.key});

  @override
  State<CPRankingScreen> createState() => _CPRankingScreenState();
}

class _CPRankingScreenState extends State<CPRankingScreen> {
  String _period = 'weekly';

  @override
  void initState() {
    super.initState();
    context.read<CpProvider>().loadRanking(period: _period);
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CpProvider>();
    final ranking = cp.ranking;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/cp_friend/bg_rank_cp.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              AppTheme.background.withValues(alpha: 0.8),
              BlendMode.srcOver,
            ),
          ),
        ),
        child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('Couple Ranking', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppTheme.pinkGradient)),
            iconTheme: const IconThemeData(color: Colors.white),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _chip('daily', 'Daily'),
                    const SizedBox(width: 8),
                    _chip('weekly', 'Weekly'),
                    const SizedBox(width: 8),
                    _chip('monthly', 'Monthly'),
                    const SizedBox(width: 8),
                    _chip('total', 'All Time'),
                  ],
                ),
              ),
            ),
          ),
          if (ranking.isEmpty)
            const SliverFillRemaining(child: EmptyState(icon: Icons.emoji_events_outlined, title: 'No Rankings Yet', subtitle: 'Couples will appear here once the leaderboard is live.'))
          else ...[
            if (ranking.length >= 3)
              SliverToBoxAdapter(child: _Podium(top3: ranking.take(3).toList())),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final idx = ranking.length >= 3 ? i + 3 : i;
                  if (idx >= ranking.length) return null;
                  final item = ranking[idx];
                  return _RankRow(item: item, onTap: () {
                    final cpId = item.cp?.id;
                    if (cpId != null) context.pushNamed(AppRoutes.cpDetail, extra: {'cpId': cpId});
                  });
                },
                childCount: ranking.length >= 3 ? ranking.length - 3 : ranking.length,
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  Widget _chip(String value, String label) {
    final selected = _period == value;
    return GestureDetector(
      onTap: () {
        setState(() => _period = value);
        context.read<CpProvider>().loadRanking(period: value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.pinkGradient : null,
          color: selected ? null : Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.top3});
  final List<CPRankItem> top3;

  @override
  Widget build(BuildContext context) {
    // Order: 2nd, 1st, 3rd
    final order = [top3[1], top3[0], top3[2]];
    final heights = [120.0, 150.0, 100.0];
    final colors = [const Color(0xFFC0C0C0), const Color(0xFFFFD700), const Color(0xFFCD7F32)];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (i) {
          final item = order[i];
          final rank = item.rank;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                final cpId = item.cp?.id;
                if (cpId != null) context.pushNamed(AppRoutes.cpDetail, extra: {'cpId': cpId});
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (i == 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Image.asset(
                          'assets/cp_friend/top1cp.png',
                          width: 36,
                          height: 36,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    CoupleAvatarPair(user1: item.cp?.user1, user2: item.cp?.user2, size: i == 1 ? 64 : 52, overlap: i == 1 ? 22 : 18),
                    const SizedBox(height: 8),
                    Text(item.cp?.title ?? '${item.cp?.user1?.name ?? ''} & ${item.cp?.user2?.name ?? ''}',
                        textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.favorite, size: 12, color: Color(0xFFE84B8A)),
                        const SizedBox(width: 3),
                        Text(formatCount(item.intimacy), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: heights[i],
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [colors[i].withValues(alpha: 0.9), colors[i].withValues(alpha: 0.3)]),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/cp_friend/tag_cp_top$rank.png',
                          width: 44,
                          height: 44,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Text('#$rank', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.9))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.item, required this.onTap});
  final CPRankItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rank = item.rank;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.cardShadow),
        child: Row(
          children: [
            SizedBox(width: 32, child: Text('#$rank', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary))),
            const SizedBox(width: 8),
            CoupleAvatarPair(user1: item.cp?.user1, user2: item.cp?.user2, size: 44, overlap: 16, showHeart: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.cp?.title ?? '${item.cp?.user1?.name ?? ''} & ${item.cp?.user2?.name ?? ''}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    CPLevelBadge(level: item.cp?.level ?? 1, size: 18),
                    const SizedBox(width: 6),
                    Text('Lv.${item.cp?.level ?? 1}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ]),
                ],
              ),
            ),
            Row(
              children: [
                const Icon(Icons.favorite, size: 14, color: Color(0xFFE84B8A)),
                const SizedBox(width: 4),
                Text(formatCount(item.intimacy), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
