/// Full-screen Anniversaries screen for CP and Friend.
///
/// Shows time-based anniversaries (7, 30, 100, 365+ days) with
/// claimable rewards. Supports both `cpId` and `friendshipId`.
library anniversaries_screen;

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../models/cp_models.dart';
import '../../providers/cp_provider.dart';
import '../../providers/friend_provider.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../widgets/premium_ui.dart';
import 'package:belive/widgets/preloader.dart';

class AnniversariesScreen extends StatefulWidget {
  const AnniversariesScreen({
    super.key,
    this.cpId,
    this.friendshipId,
    this.isFriend = false,
  }) : assert(cpId != null || friendshipId != null);

  final String? cpId;
  final String? friendshipId;
  final bool isFriend;

  @override
  State<AnniversariesScreen> createState() => _AnniversariesScreenState();
}

class _AnniversariesScreenState extends State<AnniversariesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    if (widget.isFriend && widget.friendshipId != null) {
      await context.read<FriendProvider>().loadAnniversaries(widget.friendshipId!);
    } else if (widget.cpId != null) {
      await context.read<CpProvider>().loadAnniversaries(widget.cpId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final anniversaries = widget.isFriend
        ? context.watch<FriendProvider>().anniversaries
        : context.watch<CpProvider>().anniversaries;
    final loading = widget.isFriend
        ? context.watch<FriendProvider>().loading
        : context.watch<CpProvider>().loading;

    final claimed = anniversaries.where((a) => a.isClaimed).length;
    final ready = anniversaries.where((a) => a.isUnlocked && !a.isClaimed).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.isFriend ? 'Friend Anniversaries' : 'Couple Anniversaries',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: widget.isFriend ? AppTheme.friendHeaderGradient : AppTheme.cpHeaderGradient,
                ),
                child: const Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Opacity(
                      opacity: 0.35,
                      child: Image(
                        image: AssetImage('assets/cp_friend/heart_tow.png'),
                        width: 80,
                        height: 50,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat('Ready', '$ready', AppTheme.yellow),
                    Container(width: 1, height: 30, color: AppTheme.surfaceVariant),
                    _stat('Claimed', '$claimed', AppTheme.green),
                    Container(width: 1, height: 30, color: AppTheme.surfaceVariant),
                    _stat('Total', '${anniversaries.length}', AppTheme.primary),
                  ],
                ),
              ),
            ),
          ),
          if (loading && anniversaries.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Preloader()),
            )
          else if (anniversaries.isEmpty)
            const SliverFillRemaining(
              child: EmptyState(
                icon: Icons.card_giftcard_outlined,
                title: 'No Anniversaries Yet',
                subtitle: 'Celebrate 7, 30, 100 and 365 days together to earn rewards!',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final a = anniversaries[i];
                    final isLast = i == anniversaries.length - 1;
                    return _AnniversaryTile(
                      anniversary: a,
                      isLast: isLast,
                      isFriend: widget.isFriend,
                      relationId: widget.friendshipId ?? widget.cpId ?? '',
                    );
                  },
                  childCount: anniversaries.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
      ],
    );
  }
}

class _AnniversaryTile extends StatefulWidget {
  const _AnniversaryTile({
    required this.anniversary,
    required this.isLast,
    required this.isFriend,
    required this.relationId,
  });

  final CPMilestone anniversary;
  final bool isLast;
  final bool isFriend;
  final String relationId;

  @override
  State<_AnniversaryTile> createState() => _AnniversaryTileState();
}

class _AnniversaryTileState extends State<_AnniversaryTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.anniversary;
    final canClaim = a.isUnlocked && !a.isClaimed;
    final themeColor = widget.isFriend ? AppTheme.friendAccent : AppTheme.cpAccent;
    final gradient = widget.isFriend ? AppTheme.friendHeaderGradient : AppTheme.pinkGradient;

    final rewardText = <String>[];
    if (a.rewardCoin != null && a.rewardCoin! > 0) {
      rewardText.add('${formatCount(a.rewardCoin!)} Diamonds');
    }
    if (a.rewardIntimacy != null && a.rewardIntimacy! > 0) {
      rewardText.add('${formatCount(a.rewardIntimacy!)} Intimacy');
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: a.isUnlocked ? gradient : null,
                    color: a.isUnlocked ? null : AppTheme.cpDarkSurfaceLight,
                    shape: BoxShape.circle,
                    border: a.isUnlocked
                        ? Border.all(color: themeColor.withValues(alpha: 0.4), width: 2)
                        : null,
                  ),
                  child: Icon(
                    a.isClaimed ? Icons.check_circle : (a.isUnlocked ? Icons.card_giftcard : Icons.lock_outline),
                    color: a.isUnlocked ? Colors.white : AppTheme.cpDarkTextTertiary,
                    size: 22,
                  ),
                ),
                if (!widget.isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            a.isUnlocked ? themeColor : AppTheme.cpDarkSurfaceLight,
                            AppTheme.cpDarkSurfaceLight,
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cpDarkCard,
                borderRadius: BorderRadius.circular(18),
                border: a.isUnlocked
                    ? Border.all(color: themeColor.withValues(alpha: 0.3), width: 1.2)
                    : Border.all(color: AppTheme.cpDarkSurfaceLight, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          a.title ?? 'Anniversary',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (a.isClaimed)
                        _badge('Claimed', AppTheme.green)
                      else if (a.isUnlocked)
                        _badge('Ready', AppTheme.yellow),
                    ],
                  ),
                  if (a.days != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${a.days} days together',
                      style: const TextStyle(fontSize: 12, color: AppTheme.cpDarkTextTertiary),
                    ),
                  ],
                  if (a.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      a.description!,
                      style: const TextStyle(fontSize: 12, color: AppTheme.cpDarkTextSecondary),
                    ),
                  ],
                  if (rewardText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.diamond, size: 12, color: themeColor),
                        const SizedBox(width: 4),
                        Text(
                          rewardText.join(' + '),
                          style: TextStyle(fontSize: 12, color: themeColor, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                  if (canClaim) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _busy
                          ? const Center(child: Preloader(strokeWidth: 2))
                          : ElevatedButton(
                              onPressed: _claim,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Claim Reward', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            text == 'Claimed' ? Icons.check_circle : Icons.card_giftcard,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Future<void> _claim() async {
    setState(() => _busy = true);
    final session = context.read<SessionManager>();
    final a = widget.anniversary;

    bool ok;
    if (widget.isFriend) {
      ok = await context.read<FriendProvider>().claimAnniversary(
            friendshipId: widget.relationId,
            anniversaryId: a.id ?? '',
            userId: session.userId,
          );
    } else {
      ok = await context.read<CpProvider>().claimAnniversary(
            cpId: widget.relationId,
            anniversaryId: a.id ?? '',
            userId: session.userId,
          );
    }

    if (mounted) {
      Fluttertoast.showToast(
        msg: ok ? 'Reward claimed!' : 'Failed to claim anniversary reward',
      );
      setState(() => _busy = false);
    }
  }
}
