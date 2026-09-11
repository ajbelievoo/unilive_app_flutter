/// CP Detail screen — full couple profile (Bigo-style premium redesign).
///
/// Tabs: Bond | Tasks | Milestones | Anniversaries.
/// Either partner can edit the couple title/bio/cover and break up.
library cp_detail;
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../utils/media_utils.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../constants/const.dart';
import '../../models/cp_models.dart';
import '../../providers/cp_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../utils/log.dart';
import '../../widgets/cp_widgets.dart';
import '../../widgets/premium_ui.dart';
import 'package:belive/widgets/preloader.dart';

class CPDetailScreen extends StatefulWidget {
  const CPDetailScreen({super.key, required this.cpId});
  final String cpId;

  @override
  State<CPDetailScreen> createState() => _CPDetailScreenState();
}

class _CPDetailScreenState extends State<CPDetailScreen> with SingleTickerProviderStateMixin {
  static const String _tag = 'CPDetail';
  late final TabController _tabCtrl = TabController(length: 4, vsync: this);
  CPItem? _cp;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cpProv = context.read<CpProvider>();
    final session = context.read<SessionManager>();
    setState(() => _loading = true);
    try {
      await cpProv.loadCPDetail(widget.cpId);
      _cp = cpProv.cpDetail;
      await Future.wait([
        cpProv.loadTasks(widget.cpId, userId: session.userId),
        cpProv.loadMilestones(widget.cpId),
        cpProv.loadAnniversaries(widget.cpId),
      ]);
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    // refresh myCP too (in case of edits)
    cpProv.loadMyCP(session.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cpDarkBg,
      body: _loading
          ? const PremiumLoading()
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 320,
                  flexibleSpace: FlexibleSpaceBar(
                    background: _CoverHeader(cp: _cp),
                  ),
                  iconTheme: const IconThemeData(color: Colors.white),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit',
                      onPressed: _cp == null ? null : () => _showEditSheet(_cp!),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (v) {
                        if (v == 'breakup') _confirmBreakup();
                        if (v == 'share') _share();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'share', child: Text('Share couple')),
                        const PopupMenuItem(value: 'breakup', child: Text('Break up', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  ],
                  bottom: TabBar(
                    controller: _tabCtrl,
                    indicatorColor: Colors.white,
                    indicatorSize: TabBarIndicatorSize.label,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    tabs: const [Tab(text: 'Bond'), Tab(text: 'Tasks'), Tab(text: 'Milestones'), Tab(text: 'Anniversaries')],
                  ),
                ),
                SliverFillRemaining(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _BondTab(cp: _cp),
                      _TasksTab(cpId: widget.cpId),
                      _MilestonesTab(),
                      _AnniversariesTab(cpId: widget.cpId),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _showEditSheet(CPItem cp) {
    final titleCtrl = TextEditingController(text: cp.title ?? '');
    final bioCtrl = TextEditingController(text: cp.bio ?? '');
    File? cover;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cpDarkCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Edit Couple', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
                  if (p != null) setSt(() => cover = File(p.path));
                },
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: cover != null
                        ? DecorationImage(image: FileImage(cover!), fit: BoxFit.cover)
                        : (VideoUtil.getFullImageUrl(cp.coverImage).isNotEmpty
                            ? DecorationImage(image: CachedNetworkImageProvider(VideoUtil.getFullImageUrl(cp.coverImage)), fit: BoxFit.cover)
                            : null),
                    gradient: cover == null && VideoUtil.getFullImageUrl(cp.coverImage).isEmpty ? AppTheme.pinkGradient : null,
                    color: cover == null && cp.coverImage == null ? null : AppTheme.cpDarkSurfaceLight,
                  ),
                  child: const Center(child: Icon(Icons.camera_alt, color: Colors.white70, size: 32)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Couple title', hintText: 'e.g. Romeo & Juliet'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bioCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Bio', hintText: 'Your love story...'),
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Save',
                icon: Icons.check,
                onPressed: () async {
                  final session = context.read<SessionManager>();
                  final ok = await context.read<CpProvider>().updateCP(
                        cpId: widget.cpId,
                        userId: session.userId,
                        title: titleCtrl.text.trim(),
                        bio: bioCtrl.text.trim(),
                        coverFile: cover,
                      );
                  if (ok) {
                    Fluttertoast.showToast(msg: 'Updated');
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  } else {
                    Fluttertoast.showToast(msg: 'Update failed');
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmBreakup() {
    // Fetch breakup status (penalty + cooldown) before showing the dialog.
    ApiService.getCPBreakupStatus().then((res) {
      final status = res.data;
      if (status != null && status.inCooldown) {
        // User is in cooldown — show the cooldown info instead.
        if (!mounted) return;
        final remaining = status.remainingCooldownSeconds;
        final hours = remaining ~/ 3600;
        final minutes = (remaining % 3600) ~/ 60;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cooldown Active'),
            content: Text(
              'You are in a breakup cooldown. You can break up again in '
              '$hours h $minutes m.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      final penalty = status?.penaltyCoins ?? 0;
      _showBreakupDialog(penalty);
    }).catchError((_) {
      // Endpoint not available — fall back to the simple dialog.
      _showBreakupDialog(0);
    });
  }

  void _showBreakupDialog(int penaltyCoins) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Break up?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will end your CP relationship. Your bond level and intimacy will be archived in your CP history. This cannot be undone.',
            ),
            if (penaltyCoins > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Breaking up will cost $penaltyCoins Diamonds and start a 24h cooldown.',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final session = context.read<SessionManager>();
              final ok = await context.read<CpProvider>().breakUp(cpId: widget.cpId, userId: session.userId);
              if (ok) {
                Fluttertoast.showToast(msg: 'CP ended');
                if (mounted) context.goNamed(AppRoutes.cp);
              } else {
                Fluttertoast.showToast(msg: 'Failed');
              }
            },
            child: const Text('Break up'),
          ),
        ],
      ),
    );
  }

  void _share() {
    Share.share('Check out our CP profile on Belive! Join us at ${Const.baseUrl}');
  }
}

// ===========================================================================
// Cover header — Bigo-style with gradient overlay, decorative hearts,
// couple avatar pair, names, level badge, days together
// ===========================================================================
class _CoverHeader extends StatelessWidget {
  const _CoverHeader({required this.cp});
  final CPItem? cp;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image or gradient
        Container(
          decoration: BoxDecoration(
            gradient: AppTheme.cpHeaderGradient,
            image: VideoUtil.getFullImageUrl(cp?.coverImage).isNotEmpty
                ? DecorationImage(image: CachedNetworkImageProvider(VideoUtil.getFullImageUrl(cp?.coverImage)), fit: BoxFit.cover)
                : null,
          ),
        ),
        // Dark gradient overlay for readability
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.15),
                Colors.black.withValues(alpha: 0.35),
                Colors.black.withValues(alpha: 0.65),
              ],
            ),
          ),
        ),
        // Romantic heart with wings, centered behind avatars
        Positioned.fill(
          child: Align(
            alignment: const Alignment(0, 0.2),
            child: Opacity(
              opacity: 0.3,
              child: Image.asset(
                'assets/cp_friend/heart_tow.webp',
                width: 240,
                height: 150,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        // Decorative couple heart ornaments
        Positioned(
          top: 16,
          left: 16,
          child: Image.asset(
            'assets/cp_friend/cuppul1.webp',
            width: 60,
            height: 60,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
        Positioned(
          bottom: 90,
          right: 16,
          child: Image.asset(
            'assets/cp_friend/cuppul2.webp',
            width: 60,
            height: 60,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
        // Bottom content — avatars, names, level
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 60, left: 20, right: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Soft glow behind avatars
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.cpAccent.withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: CoupleAvatarPair(
                    user1: cp?.user1,
                    user2: cp?.user2,
                    size: 84,
                    overlap: 30,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  cp?.title ?? '${cp?.user1?.name ?? ''} & ${cp?.user2?.name ?? ''}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CPLevelBadge(level: cp?.level ?? 1, size: 22),
                      const SizedBox(width: 6),
                      Text('Bond Lv.${cp?.level ?? 1}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(width: 12),
                      Container(width: 1, height: 14, color: Colors.white30),
                      const SizedBox(width: 12),
                      const Icon(Icons.calendar_today, size: 13, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text('${cp?.daysTogether ?? 0} days', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Bond tab — gradient hero card with bond progress + stats + partners + bio
// ===========================================================================
class _BondTab extends StatelessWidget {
  const _BondTab({required this.cp});
  final CPItem? cp;

  @override
  Widget build(BuildContext context) {
    if (cp == null) {
      return const EmptyState(icon: Icons.error_outline, title: 'Couple not found');
    }
    final levels = context.watch<CpProvider>().levels;
    final nextLevel = levels.where((l) => l.level == cp!.level + 1).firstOrNull;
    final nextTarget = nextLevel?.requiredIntimacy ?? (cp!.level * 500) + 500;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero bond card with gradient
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: AppTheme.cpCardGradient,
            boxShadow: AppTheme.cpGlowShadow,
            border: Border.all(
              color: AppTheme.cpAccent.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/cp_friend/heart_tow.webp',
                    width: 28,
                    height: 18,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 8),
                  const Text('Bond Progress',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: AppTheme.pinkGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Lv.${cp!.level}',
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              BondProgressBar(current: cp!.intimacy, target: nextTarget),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: CPStatTile(icon: Icons.card_giftcard, value: formatCount(cp!.totalGift), label: 'Gifts', color: AppTheme.cpAccent)),
                  const SizedBox(width: 10),
                  Expanded(child: CPStatTile(icon: Icons.call, value: formatCount(cp!.totalCall), label: 'Calls', color: AppTheme.secondary)),
                  const SizedBox(width: 10),
                  Expanded(child: CPStatTile(icon: Icons.live_tv, value: formatCount(cp!.totalLive), label: 'Lives', color: AppTheme.primary)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: CPStatTile(icon: Icons.star, value: formatCount(cp!.charm), label: 'Charm', color: AppTheme.yellow)),
                  const SizedBox(width: 10),
                  Expanded(child: CPStatTile(icon: Icons.favorite, value: formatCount(cp!.intimacy), label: 'Intimacy', color: AppTheme.cpAccent)),
                  const SizedBox(width: 10),
                  Expanded(child: CPStatTile(icon: Icons.calendar_today, value: '${cp!.daysTogether}', label: 'Days', color: AppTheme.green)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _PartnersCard(cp: cp!),
        const SizedBox(height: 16),
        if (cp!.bio != null && cp!.bio!.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.cpDarkCard,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppTheme.cardShadow,
              border: Border.all(
                color: AppTheme.cpAccent.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/cp_friend/heart_tow.webp',
                      width: 24,
                      height: 16,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.book, size: 18, color: AppTheme.cpAccent),
                    ),
                    const SizedBox(width: 8),
                    const Text('Our Story', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(cp!.bio!, style: const TextStyle(fontSize: 14, color: AppTheme.cpDarkTextSecondary, height: 1.6)),
              ],
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ===========================================================================
// Partners card — two avatars with heart in middle
// ===========================================================================
class _PartnersCard extends StatelessWidget {
  const _PartnersCard({required this.cp});
  final CPItem cp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cpDarkCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(
          color: AppTheme.cpDarkSurfaceLight,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _person(cp.user1, 'Partner 1', const Color(0xFF6A5AE0))),
          // Heart in the middle
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppTheme.pinkGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.cpAccent.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.favorite, color: Colors.white, size: 18),
          ),
          Expanded(child: _person(cp.user2, 'Partner 2', const Color(0xFF4F8DFD))),
        ],
      ),
    );
  }

  Widget _person(CPUser? u, String fallback, Color ring) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [ring, ring.withValues(alpha: 0.6)],
            ),
            boxShadow: [
              BoxShadow(
                color: ring.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(2.5),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: AppTheme.cpDarkSurfaceLight,
              backgroundImage: (u?.image != null && u!.image!.isNotEmpty) ? CachedNetworkImageProvider(u.image!) : null,
              child: (u?.image == null) ? const Icon(Icons.person, color: Colors.white) : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(u?.name ?? fallback, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text('Lv.${u?.level ?? 1}', style: const TextStyle(fontSize: 12, color: AppTheme.cpDarkTextSecondary)),
      ],
    );
  }
}

// ===========================================================================
// Anniversaries tab — time-based claimable rewards
// ===========================================================================
class _AnniversariesTab extends StatelessWidget {
  const _AnniversariesTab({required this.cpId});
  final String cpId;

  @override
  Widget build(BuildContext context) {
    final cpProv = context.watch<CpProvider>();
    final anniversaries = cpProv.anniversaries;

    if (anniversaries.isEmpty) {
      return const EmptyState(
        icon: Icons.card_giftcard_outlined,
        title: 'No Anniversaries Yet',
        subtitle: 'Celebrate 7, 30, 100 and 365 days together for rewards!',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: anniversaries.length,
      itemBuilder: (_, i) {
        final a = anniversaries[i];
        final isLast = i == anniversaries.length - 1;
        return _AnniversaryTile(anniversary: a, cpId: cpId, isLast: isLast);
      },
    );
  }
}

class _AnniversaryTile extends StatefulWidget {
  const _AnniversaryTile({
    required this.anniversary,
    required this.cpId,
    required this.isLast,
  });
  final CPMilestone anniversary;
  final String cpId;
  final bool isLast;

  @override
  State<_AnniversaryTile> createState() => _AnniversaryTileState();
}

class _AnniversaryTileState extends State<_AnniversaryTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.anniversary;
    final canClaim = a.isUnlocked && !a.isClaimed;
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
                    gradient: a.isUnlocked ? AppTheme.pinkGradient : null,
                    color: a.isUnlocked ? null : AppTheme.cpDarkSurfaceLight,
                    shape: BoxShape.circle,
                    boxShadow: a.isUnlocked
                        ? [BoxShadow(color: AppTheme.cpAccent.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))]
                        : null,
                    border: a.isUnlocked
                        ? Border.all(color: AppTheme.cpAccent.withValues(alpha: 0.3), width: 2)
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
                            a.isUnlocked ? AppTheme.cpAccent : AppTheme.cpDarkSurfaceLight,
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
                    ? Border.all(color: AppTheme.cpAccent.withValues(alpha: 0.3), width: 1.2)
                    : Border.all(color: AppTheme.cpDarkSurfaceLight, width: 1),
                boxShadow: a.isUnlocked ? AppTheme.cardShadow : null,
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 12, color: AppTheme.green),
                              SizedBox(width: 3),
                              Text('Claimed', style: TextStyle(fontSize: 10, color: AppTheme.green, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )
                      else if (a.isUnlocked)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.yellow.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.card_giftcard, size: 12, color: AppTheme.yellow),
                              SizedBox(width: 3),
                              Text('Ready', style: TextStyle(fontSize: 10, color: AppTheme.yellow, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (a.description != null) ...[
                    const SizedBox(height: 4),
                    Text(a.description!, style: const TextStyle(fontSize: 12, color: AppTheme.cpDarkTextSecondary)),
                  ],
                  if (rewardText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.diamond, size: 12, color: AppTheme.cpAccent),
                        const SizedBox(width: 4),
                        Text(
                          rewardText.join(' + '),
                          style: const TextStyle(fontSize: 12, color: AppTheme.cpAccent, fontWeight: FontWeight.w600),
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
                                backgroundColor: AppTheme.cpAccent,
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

  Future<void> _claim() async {
    setState(() => _busy = true);
    final session = context.read<SessionManager>();
    final cp = context.read<CpProvider>();
    final res = await cp.claimAnniversary(
      cpId: widget.cpId,
      anniversaryId: widget.anniversary.id ?? '',
      userId: session.userId,
    );
    if (mounted) {
      Fluttertoast.showToast(
        msg: res
            ? 'Reward claimed!'
            : 'Failed to claim anniversary reward',
      );
      setState(() => _busy = false);
    }
  }
}

// ===========================================================================
// Tasks tab — daily/weekly/anniversary tasks with progress + claim
// ===========================================================================
class _TasksTab extends StatelessWidget {
  const _TasksTab({required this.cpId});
  final String cpId;

  @override
  Widget build(BuildContext context) {
    final cpProv = context.watch<CpProvider>();
    final session = context.read<SessionManager>();
    final tasks = cpProv.tasks;
    if (tasks.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const EmptyState(icon: Icons.task_outlined, title: 'No Tasks', subtitle: 'Couple tasks refresh daily. Come back soon!'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => cpProv.loadTasks(cpId, userId: session.userId),
            child: const Text('Refresh Tasks'),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (_, i) => _TaskCard(task: tasks[i], cpId: cpId, userId: session.userId),
    );
  }
}

class _TaskCard extends StatefulWidget {
  const _TaskCard({required this.task, required this.cpId, required this.userId});
  final CPTask task;
  final String cpId;
  final String userId;

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final typeColor = _typeColor(t.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cpDarkCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(
          color: typeColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [typeColor, typeColor.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: typeColor.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(t.type.toUpperCase(),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(t.title ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(gradient: AppTheme.goldGradient, borderRadius: BorderRadius.circular(10)),
                child: Text('+${t.reward} ${t.rewardType}',
                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (t.description != null && t.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(t.description!, style: const TextStyle(fontSize: 13, color: AppTheme.cpDarkTextSecondary)),
          ],
          const SizedBox(height: 14),
          BondProgressBar(current: t.progress, target: t.target, label: 'Combined progress'),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('You: ${t.myProgress}  •  Partner: ${t.partnerProgress}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.cpDarkTextTertiary)),
              if (t.isCompleted && !t.isClaimed)
                _busy
                    ? const SizedBox(width: 20, height: 20, child: Preloader(strokeWidth: 2))
                    : GestureDetector(
                        onTap: () async {
                          setState(() => _busy = true);
                          final ok = await context.read<CpProvider>().claimTask(cpId: widget.cpId, taskId: t.id ?? '', userId: widget.userId);
                          if (ok) Fluttertoast.showToast(msg: 'Reward claimed!');
                          if (mounted) setState(() => _busy = false);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: AppTheme.goldGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.yellow.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Text('Claim',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      )
              else if (t.isClaimed)
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.green, size: 18),
                    SizedBox(width: 4),
                    Text('Claimed', style: TextStyle(fontSize: 12, color: AppTheme.green, fontWeight: FontWeight.w600)),
                  ],
                )
              else
                Text('${t.progress}/${t.target}', style: const TextStyle(fontSize: 12, color: AppTheme.cpDarkTextSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'daily':
        return AppTheme.primary;
      case 'weekly':
        return AppTheme.secondary;
      case 'anniversary':
        return AppTheme.cpAccent;
      default:
        return AppTheme.yellow;
    }
  }
}

// ===========================================================================
// Milestones tab — timeline-style cards with locked/unlocked states
// ===========================================================================
class _MilestonesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cpProv = context.watch<CpProvider>();
    final ms = cpProv.milestones;
    if (ms.isEmpty) {
      return const EmptyState(
          icon: Icons.celebration_outlined,
          title: 'No Milestones Yet',
          subtitle: 'Celebrate your 7-day, 30-day, 100-day and 1-year anniversaries together!');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: ms.length,
      itemBuilder: (_, i) {
        final m = ms[i];
        final isLast = i == ms.length - 1;
        return _MilestoneTile(milestone: m, isLast: isLast);
      },
    );
  }
}

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({required this.milestone, required this.isLast});
  final CPMilestone milestone;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column
          SizedBox(
            width: 50,
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: milestone.isUnlocked ? AppTheme.pinkGradient : null,
                    color: milestone.isUnlocked ? null : AppTheme.cpDarkSurfaceLight,
                    shape: BoxShape.circle,
                    boxShadow: milestone.isUnlocked
                        ? [BoxShadow(color: AppTheme.cpAccent.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))]
                        : null,
                    border: milestone.isUnlocked
                        ? Border.all(color: AppTheme.cpAccent.withValues(alpha: 0.3), width: 2)
                        : null,
                  ),
                  child: Icon(milestone.isUnlocked ? Icons.celebration : Icons.lock_outline,
                      color: milestone.isUnlocked ? Colors.white : AppTheme.cpDarkTextTertiary, size: 22),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            milestone.isUnlocked ? AppTheme.cpAccent : AppTheme.cpDarkSurfaceLight,
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
          // Content card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cpDarkCard,
                borderRadius: BorderRadius.circular(18),
                border: milestone.isUnlocked
                    ? Border.all(color: AppTheme.cpAccent.withValues(alpha: 0.3), width: 1.2)
                    : Border.all(color: AppTheme.cpDarkSurfaceLight, width: 1),
                boxShadow: milestone.isUnlocked ? AppTheme.cardShadow : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(milestone.title ?? 'Milestone',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                      if (milestone.isUnlocked)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 12, color: AppTheme.green),
                              SizedBox(width: 3),
                              Text('Unlocked', style: TextStyle(fontSize: 10, color: AppTheme.green, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (milestone.description != null) ...[
                    const SizedBox(height: 4),
                    Text(milestone.description!, style: const TextStyle(fontSize: 12, color: AppTheme.cpDarkTextSecondary)),
                  ],
                  if (milestone.date != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 11, color: AppTheme.cpDarkTextTertiary),
                        const SizedBox(width: 4),
                        Text(milestone.date!, style: const TextStyle(fontSize: 11, color: AppTheme.cpDarkTextTertiary)),
                      ],
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
}
