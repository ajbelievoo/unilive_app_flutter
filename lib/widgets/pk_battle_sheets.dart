/// PK Battle enhancement bottom sheets.
///
/// Ports native:
/// - `BottomSheetPkRoundHistory` â€” round-by-round PK results
/// - `BottomsheetRanking` â€” fans leaderboard with daily/weekly/monthly/lifetime tabs
library pk_battle_sheets;

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shimmer/shimmer.dart';

import '../models/audio_room_root.dart';
import '../models/fans_ranking_root.dart';
import '../models/pk_call_models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../utils/log.dart';
import 'top_contributor_banner.dart';
import 'user_avatar.dart';
import 'package:belive/widgets/preloader.dart';

const String _tag = 'PKSheets';

// ---------------------------------------------------------------------------
// PK Round History sheet
// ---------------------------------------------------------------------------
void showPkRoundHistorySheet(
  BuildContext context, {
  required List<PkRoundResult> history,
  required String host1Name,
  required String host2Name,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:
        (_) => _PkRoundHistorySheet(
          history: history,
          host1Name: host1Name,
          host2Name: host2Name,
        ),
  );
}

class _PkRoundHistorySheet extends StatelessWidget {
  const _PkRoundHistorySheet({
    required this.history,
    required this.host1Name,
    required this.host2Name,
  });

  final List<PkRoundResult> history;
  final String host1Name;
  final String host2Name;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.surface : AppTheme.lightSurface;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [_header(context, isDark), Flexible(child: _list(isDark))],
      ),
    );
  }

  Widget _header(BuildContext context, bool isDark) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                gradient: AppTheme.pinkGradient,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.history,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PK Round History',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color:
                              isDark
                                  ? AppTheme.textPrimary
                                  : AppTheme.lightTextPrimary,
                        ),
                      ),
                      Text(
                        '${history.length} round${history.length == 1 ? '' : 's'} played',
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              isDark
                                  ? AppTheme.textSecondary
                                  : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color:
                        isDark
                            ? AppTheme.textSecondary
                            : AppTheme.lightTextSecondary,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(bool isDark) {
    if (history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports_kabaddi,
              size: 48,
              color: isDark ? AppTheme.textTertiary : Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'No rounds played yet',
              style: TextStyle(
                color:
                    isDark
                        ? AppTheme.textSecondary
                        : AppTheme.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: history.length,
      itemBuilder:
          (_, i) => _RoundCard(
            result: history[i],
            host1Name: host1Name,
            host2Name: host2Name,
            isDark: isDark,
          ),
    );
  }
}

class _RoundCard extends StatelessWidget {
  const _RoundCard({
    required this.result,
    required this.host1Name,
    required this.host2Name,
    required this.isDark,
  });

  final PkRoundResult result;
  final String host1Name;
  final String host2Name;
  final bool isDark;

  String get _winnerLabel {
    switch (result.winner) {
      case 1:
        return '$host2Name won';
      case 2:
        return '$host1Name won';
      default:
        return 'Tie';
    }
  }

  Gradient get _winnerGradient {
    switch (result.winner) {
      case 1:
        return AppTheme.blueGradient;
      case 2:
        return AppTheme.pinkGradient;
      default:
        return AppTheme.goldGradient;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceLight : AppTheme.lightBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: _winnerGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Round ${result.roundNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _winnerLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark
                          ? AppTheme.textSecondary
                          : AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ScoreSide(
                  name: host1Name,
                  score: result.host1Score,
                  isWinner: result.winner == 2,
                  gradient: AppTheme.pinkGradient,
                  isDark: isDark,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'VS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color:
                        isDark ? AppTheme.textTertiary : Colors.grey.shade400,
                  ),
                ),
              ),
              Expanded(
                child: _ScoreSide(
                  name: host2Name,
                  score: result.host2Score,
                  isWinner: result.winner == 1,
                  gradient: AppTheme.blueGradient,
                  isDark: isDark,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreSide extends StatelessWidget {
  const _ScoreSide({
    required this.name,
    required this.score,
    required this.isWinner,
    required this.gradient,
    required this.isDark,
    this.alignEnd = false,
  });

  final String name;
  final int score;
  final bool isWinner;
  final Gradient gradient;
  final bool isDark;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
          ),
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isWinner) ...[
              const Icon(Icons.emoji_events, size: 14, color: AppTheme.yellow),
              const SizedBox(width: 4),
            ],
            Text(
              formatCount(score),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                foreground:
                    Paint()
                      ..shader = gradient.createShader(
                        const Rect.fromLTWH(0, 0, 100, 20),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Fans Ranking sheet (PK fans leaderboard)
// ---------------------------------------------------------------------------
void showFansRankingSheet(
  BuildContext context, {
  required String hostUserId,
  List<Contributor>? localContributors,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:
        (_) => _FansRankingSheet(
          hostUserId: hostUserId,
          localContributors: localContributors ?? [],
        ),
  );
}

class _FansRankingSheet extends StatefulWidget {
  const _FansRankingSheet({
    required this.hostUserId,
    this.localContributors = const [],
  });

  final String hostUserId;
  final List<Contributor> localContributors;

  @override
  State<_FansRankingSheet> createState() => _FansRankingSheetState();
}

class _FansRankingSheetState extends State<_FansRankingSheet>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;
  final _types = ['daily', 'weekly', 'monthly', 'lifetime'];
  final _labels = ['Today', '7 Days', '30 Days', 'All Time'];

  final _data = <String, List<FansRankingEntry>>{};
  final _loading = <String, bool>{};
  final _totalDiamonds = <String, int>{};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) _load(_types[_tabCtrl.index]);
    });
    _load('daily');
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load(String type) async {
    if (_loading[type] == true) return;
    setState(() => _loading[type] = true);
    try {
      final res = await ApiService.getFansRanking(
        userId: widget.hostUserId,
        type: type,
      );
      final entries = <FansRankingEntry>[];
      int total = 0;
      for (final g in res.data) {
        entries.addAll(g.data);
        total += g.totalDiamond;
      }
      // Merge local contributors (from this session's gifts) — Bigo style.
      // This ensures the ranking shows data even when the backend hasn't
      // aggregated yet, and merges real-time gift data.
      for (final lc in widget.localContributors) {
        final existing =
            entries.where((e) => e.userId == lc.userId).firstOrNull;
        if (existing != null) {
          // Already in backend list — skip (backend data takes priority).
        } else {
          entries.add(
            FansRankingEntry(
              userId: lc.userId,
              name: lc.name,
              image: lc.avatar,
              totalSpentDiamond: lc.totalCoins,
            ),
          );
          total += lc.totalCoins;
        }
      }
      entries.sort(
        (a, b) => b.totalSpentDiamond.compareTo(a.totalSpentDiamond),
      );
      if (mounted) {
        setState(() {
          _data[type] = entries;
          _totalDiamonds[type] = total;
          _loading[type] = false;
        });
      }
    } catch (e, s) {
      Log.e(_tag, 'fansRanking $type failed', e, s);
      // Fallback: show local contributors only if backend fails.
      if (widget.localContributors.isNotEmpty) {
        final entries = <FansRankingEntry>[];
        int total = 0;
        for (final lc in widget.localContributors) {
          entries.add(
            FansRankingEntry(
              userId: lc.userId,
              name: lc.name,
              image: lc.avatar,
              totalSpentDiamond: lc.totalCoins,
            ),
          );
          total += lc.totalCoins;
        }
        entries.sort(
          (a, b) => b.totalSpentDiamond.compareTo(a.totalSpentDiamond),
        );
        if (mounted) {
          setState(() {
            _data[type] = entries;
            _totalDiamonds[type] = total;
            _loading[type] = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading[type] = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.surface : AppTheme.lightSurface;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          children: [
            _header(isDark),
            TabBar(
              controller: _tabCtrl,
              labelColor: AppTheme.primary,
              unselectedLabelColor:
                  isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary,
              indicatorColor: AppTheme.primary,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: _labels.map((l) => Tab(text: l)).toList(),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: _types.map((t) => _body(isDark, t)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(bool isDark) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Fans Ranking',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color:
                          isDark
                              ? AppTheme.textPrimary
                              : AppTheme.lightTextPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color:
                        isDark
                            ? AppTheme.textSecondary
                            : AppTheme.lightTextSecondary,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(bool isDark, String type) {
    if (_loading[type] == true) {
      return _shimmerList(isDark);
    }
    final entries = _data[type] ?? [];
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: isDark ? AppTheme.textTertiary : Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'No fans data',
              style: TextStyle(
                color:
                    isDark
                        ? AppTheme.textSecondary
                        : AppTheme.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }
    final total = _totalDiamonds[type] ?? 0;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.diamond, size: 16, color: AppTheme.yellow),
              const SizedBox(width: 6),
              Text(
                'Total: ${formatCount(total)} diamonds',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark
                          ? AppTheme.textSecondary
                          : AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
            itemCount: entries.length,
            itemBuilder:
                (_, i) =>
                    _FanTile(entry: entries[i], rank: i + 1, isDark: isDark),
          ),
        ),
      ],
    );
  }

  Widget _shimmerList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder:
          (_, __) => Shimmer.fromColors(
            baseColor: isDark ? AppTheme.surfaceLight : Colors.grey.shade200,
            highlightColor:
                isDark ? AppTheme.surfaceVariant : Colors.grey.shade100,
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              title: Container(
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              subtitle: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
    );
  }
}

class _FanTile extends StatelessWidget {
  const _FanTile({
    required this.entry,
    required this.rank,
    required this.isDark,
  });

  final FansRankingEntry entry;
  final int rank;
  final bool isDark;

  Gradient get _rankGradient {
    if (rank == 1) return AppTheme.goldGradient;
    if (rank == 2)
      return const LinearGradient(
        colors: [Color(0xFFC0C0C0), Color(0xFF8E8E8E)],
      );
    if (rank == 3)
      return const LinearGradient(
        colors: [Color(0xFFCD7F32), Color(0xFF8B4513)],
      );
    return AppTheme.purpleGradient;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: _rankGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          UserAvatar(imageUrl: entry.image, size: 40, isVIP: false),
        ],
      ),
      title: Text(
        entry.name ?? 'Fan',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
        ),
      ),
      subtitle: Text(
        '@${entry.uniqueId ?? ''}',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.diamond, size: 14, color: AppTheme.yellow),
          const SizedBox(width: 4),
          Text(
            formatCount(entry.totalSpentDiamond),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PK Waiting For Response sheet (host waiting for opponent to accept)
// Ported from native `PkWaitingForResponseBottomSheet`
// ---------------------------------------------------------------------------
Future<void> showPkWaitingSheet(
  BuildContext context, {
  required String hostName,
  required String? hostImage,
  required VoidCallback onCancel,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    backgroundColor: Colors.transparent,
    builder:
        (ctx) => _PkWaitingSheet(
          hostName: hostName,
          hostImage: hostImage,
          onCancel: () {
            Navigator.pop(ctx);
            onCancel();
          },
        ),
  );
}

class _PkWaitingSheet extends StatefulWidget {
  const _PkWaitingSheet({
    required this.hostName,
    required this.hostImage,
    required this.onCancel,
  });

  final String hostName;
  final String? hostImage;
  final VoidCallback onCancel;

  @override
  State<_PkWaitingSheet> createState() => _PkWaitingSheetState();
}

class _PkWaitingSheetState extends State<_PkWaitingSheet>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: const BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          ScaleTransition(
            scale: Tween(begin: 1.0, end: 1.1).animate(
              CurvedAnimation(
                parent: _pulseController,
                curve: Curves.easeInOut,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary, width: 2),
              ),
              child: UserAvatar(imageUrl: widget.hostImage, size: 80),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.hostName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Waiting for response...',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          const SizedBox(
            width: 24,
            height: 24,
            child: Preloader(strokeWidth: 2, color: AppTheme.primary),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: widget.onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PK Result sheet — ported from native `PkResultBottomSheet`
// ---------------------------------------------------------------------------
void showPkResultSheet(
  BuildContext context, {
  required int winner,
  required bool isHost1,
  required int host1Score,
  required int host2Score,
  required String? host1Name,
  required String? host2Name,
  required bool canRematch,
  required VoidCallback onDone,
  required VoidCallback onRematch,
}) {
  String title;
  String emoji;
  if (winner == 2) {
    // Host1 wins
    title = isHost1 ? 'You Win!' : 'You Lose!';
    emoji = isHost1 ? '\u{1F389}' : '\u{1F622}';
  } else if (winner == 1) {
    // Host2 wins
    title = isHost1 ? 'You Lose!' : 'You Win!';
    emoji = isHost1 ? '\u{1F622}' : '\u{1F389}';
  } else {
    title = 'Tie!';
    emoji = '\u{1F91D}';
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    backgroundColor: Colors.transparent,
    builder:
        (ctx) => Container(
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Text(emoji, style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _buildScoreColumn(
                      host1Name ?? 'Host 1',
                      host1Score,
                      winner == 2,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'VS',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildScoreColumn(
                      host2Name ?? 'Host 2',
                      host2Score,
                      winner == 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onDone();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
              if (canRematch) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onRematch();
                    },
                    icon: const Icon(Icons.replay),
                    label: const Text('Rematch'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
  );
}

Widget _buildScoreColumn(String name, int score, bool isWinner) {
  return Column(
    children: [
      Text(
        name,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 6),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isWinner) ...[
            const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
            const SizedBox(width: 4),
          ],
          Text(
            '$score',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isWinner ? Colors.amber : Colors.white,
            ),
          ),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Audio room PK opponent selection sheet
// ---------------------------------------------------------------------------
void showAudioRoomPkOpponentSheet(
  BuildContext context, {
  required String currentRoomId,
  required String currentHostId,
  required void Function(AudioRoomUser opponent) onSelected,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:
        (_) => _AudioRoomPkOpponentSheet(
          currentRoomId: currentRoomId,
          currentHostId: currentHostId,
          onSelected: onSelected,
        ),
  );
}

class _AudioRoomPkOpponentSheet extends StatefulWidget {
  const _AudioRoomPkOpponentSheet({
    required this.currentRoomId,
    required this.currentHostId,
    required this.onSelected,
  });

  final String currentRoomId;
  final String currentHostId;
  final void Function(AudioRoomUser opponent) onSelected;

  @override
  State<_AudioRoomPkOpponentSheet> createState() =>
      _AudioRoomPkOpponentSheetState();
}

class _AudioRoomPkOpponentSheetState extends State<_AudioRoomPkOpponentSheet> {
  static const String _tag = 'AudioRoomPkOpponent';
  late Future<AudioRoomRoot> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadRooms();
  }

  Future<AudioRoomRoot> _loadRooms() async {
    try {
      return await ApiService.getAudioRooms(type: 'All', start: 0, limit: 50);
    } catch (e, s) {
      Log.e(_tag, 'Failed to load audio rooms', e, s);
      return AudioRoomRoot(status: false, rooms: const []);
    }
  }

  void _pickRandom(List<AudioRoomUser> rooms) {
    final eligible =
        rooms
            .where(
              (r) =>
                  r.liveStreamingId != widget.currentRoomId &&
                  r.liveUserId != widget.currentHostId &&
                  (r.liveStreamingId ?? '').isNotEmpty,
            )
            .toList();
    if (eligible.isEmpty) {
      Fluttertoast.showToast(msg: 'No available opponent right now');
      return;
    }
    final index = DateTime.now().millisecond % eligible.length;
    Navigator.pop(context);
    widget.onSelected(eligible[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'PK Battle — Select Opponent',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _future = _loadRooms());
                  },
                  icon: const Icon(
                    Icons.refresh,
                    color: Colors.white70,
                    size: 18,
                  ),
                  label: const Text(
                    'Refresh',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12),
          FutureBuilder<AudioRoomRoot>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: Preloader(color: AppTheme.primary)),
                );
              }
              final rooms =
                  (snap.data?.rooms ?? [])
                      .where(
                        (r) =>
                            r.liveStreamingId != widget.currentRoomId &&
                            r.liveUserId != widget.currentHostId &&
                            (r.liveStreamingId ?? '').isNotEmpty,
                      )
                      .toList();
              if (rooms.isEmpty) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                    child: Text(
                      'No active audio rooms',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                );
              }
              return SizedBox(
                height: 320,
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: rooms.length,
                  itemBuilder: (_, i) {
                    final room = rooms[i];
                    return ListTile(
                      leading: UserAvatar(
                        imageUrl: room.image,
                        size: 44,
                        isVIP: room.isVIP,
                      ),
                      title: Text(
                        room.name ?? 'Host',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '${room.view} watching · ${room.roomName ?? 'Audio Room'}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (i == 0)
                            IconButton(
                              icon: const Icon(
                                Icons.shuffle,
                                color: AppTheme.primary,
                                size: 22,
                              ),
                              onPressed: () => _pickRandom(rooms),
                              tooltip: 'Random',
                            ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onSelected(room);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7E3FF2),
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: const Text('Invite'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
