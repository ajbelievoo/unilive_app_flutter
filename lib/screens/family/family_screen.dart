/// Family list screen — Bigo Live-style.
///
/// Three tabs: All Families | Ranking | My Family.
/// Search bar, family cards with rank/level/members/join, create button.
library family;
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/family_models.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../utils/log.dart';
import '../../widgets/premium_ui.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen>
    with SingleTickerProviderStateMixin {
  static const String _tag = 'Family';

  late final TabController _tabCtrl = TabController(length: 3, vsync: this);

  final _families = <FamilyItem>[];
  bool _loadingList = true;
  final _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _searchDebounce;

  final _ranking = <FamilyRankItem>[];
  bool _loadingRank = true;

  FamilyItem? _myFamily;
  bool _loadingMine = true;

  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _loadFamilies();
    _loadRanking();
    _loadMyFamily();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFamilies() async {
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.getFamilies(
        userId: session.userId,
        start: 0,
        limit: 100,
      );
      if (res.status) {
        _families
          ..clear()
          ..addAll(res.data);
      }
    } catch (e, s) {
      Log.e(_tag, 'loadFamilies failed', e, s);
    } finally {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  Future<void> _loadRanking() async {
    try {
      final res = await ApiService.getFamilyRanking(limit: 50);
      if (res.status) {
        _ranking
          ..clear()
          ..addAll(res.families);
      }
    } catch (e, s) {
      Log.e(_tag, 'loadRanking failed', e, s);
    } finally {
      if (mounted) setState(() => _loadingRank = false);
    }
  }

  Future<void> _loadMyFamily() async {
    try {
      final session = context.read<SessionManager>();
      if (session.userId.isEmpty) return;
      final res = await ApiService.getUserFamily(session.userId);
      if (res.status && res.data.isNotEmpty) {
        _myFamily = res.data.first;
      }
    } catch (e, s) {
      Log.e(_tag, 'loadMyFamily failed', e, s);
    } finally {
      if (mounted) setState(() => _loadingMine = false);
    }
  }

  void _onSearch(String q) {
    _query = q.trim();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (_query.isEmpty) {
        _loadFamilies();
      } else {
        _doSearch();
      }
    });
  }

  Future<void> _doSearch() async {
    if (!mounted) return;
    setState(() => _loadingList = true);
    try {
      final res = await ApiService.searchFamilies(query: _query);
      _families
        ..clear()
        ..addAll(res.data);
    } catch (e, s) {
      Log.e(_tag, 'search failed', e, s);
    } finally {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  Future<void> _joinFamily(FamilyItem item) async {
    if (_joining) return;

    if (!item.isPublic) {
      final code = await showDialog<String>(
        context: context,
        builder: (_) => const _JoinCodeDialog(),
      );
      if (code == null || code.isEmpty) return;
      _doJoin(item, joinCode: code);
    } else {
      _doJoin(item);
    }
  }

  Future<void> _doJoin(FamilyItem item, {String joinCode = ''}) async {
    setState(() => _joining = true);
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.joinFamily(
        userId: session.userId,
        familyId: item.id ?? '',
        joinCode: joinCode,
      );
      Fluttertoast.showToast(
          msg: res.status ? 'Joined family' : (res.message ?? 'Failed to join'));
      if (res.status) {
        _loadFamilies();
        _loadMyFamily();
      }
    } catch (e, s) {
      Log.e(_tag, 'joinFamily failed', e, s);
      Fluttertoast.showToast(msg: 'Network error');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  void _openDetail(FamilyItem item) {
    context.pushNamed(AppRoutes.familyDetail, extra: {'familyId': item.id ?? ''});
  }

  void _openRankDetail(FamilyRankItem item) {
    context.pushNamed(AppRoutes.familyDetail, extra: {'familyId': item.id ?? ''});
  }

  Future<void> _confirmLeave(FamilyItem f) async {
    final session = context.read<SessionManager>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Family?'),
        content: Text('Are you sure you want to leave ${f.name ?? 'your family'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Leave', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final res = await ApiService.leaveFamily(session.userId, familyId: f.id ?? '');
      if (!mounted) return;
      Fluttertoast.showToast(msg: res.status ? 'Left family' : (res.message ?? 'Failed'));
      if (res.status) {
        _loadFamilies();
        _loadMyFamily();
      }
    } catch (e, s) {
      Log.e(_tag, 'leaveFamily failed', e, s);
      if (mounted) Fluttertoast.showToast(msg: 'Failed to leave family');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Family'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Family Rules',
            onPressed: () => context.pushNamed(AppRoutes.familyRules),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Family',
            onPressed: () => context.pushNamed(AppRoutes.familyCreate),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Ranking'),
            Tab(text: 'My Family'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _allTab(),
          _rankingTab(),
          _myFamilyTab(),
        ],
      ),
    );
  }

  // ---- All families tab ---------------------------------------------------
  Widget _allTab() {
    return Column(children: [
      if (_ranking.isNotEmpty) _buildGlobalChampionBanner(),
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _searchCtrl,
          onChanged: _onSearch,
          decoration: InputDecoration(
            hintText: 'Search family...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchCtrl.clear();
                _onSearch('');
              },
            ),
            filled: true,
            fillColor: AppTheme.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          ),
        ),
      ),
      Expanded(
        child: _loadingList
            ? const Center(child: PremiumLoading())
            : _families.isEmpty
            ? EmptyState(
          icon: Icons.group,
          title: 'No families found',
          actionLabel: 'Create one',
          onAction: () => context.pushNamed(AppRoutes.familyCreate),
        )
            : RefreshIndicator(
          onRefresh: _loadFamilies,
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: _families.length,
            itemBuilder: (_, i) => _familyCard(_families[i]),
          ),
        ),
      ),
    ]);
  }

  Widget _buildGlobalChampionBanner() {
    final top1 = _ranking.first;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF210A49), Color(0xFF3F1682)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha:0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.amber, width: 2)),
            child: ClipOval(child: top1.image != null ? CachedNetworkImage(imageUrl: top1.image!, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.group, color: Colors.white)) : const Icon(Icons.group, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.emoji_events, color: Colors.amber, size: 12),
                    SizedBox(width: 4),
                    Text('WEEKLY CHAMPION', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
                Text(top1.name ?? 'Family', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => context.pushNamed(AppRoutes.familyHonor),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.amber,
              side: const BorderSide(color: Colors.amber),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Honor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _familyCard(FamilyItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetail(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.purpleGradient,
              ),
              child: ClipOval(
                child: item.image != null && item.image!.isNotEmpty
                    ? CachedNetworkImage(imageUrl: item.image!, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.group, color: Colors.white))
                    : const Icon(Icons.group, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(item.name ?? 'Family',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 6),
                  PremiumBadge(text: 'Lv ${item.level}', gradient: AppTheme.goldGradient),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.people, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text('${item.memberCount}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(width: 10),
                  const Icon(Icons.diamond, size: 14, color: AppTheme.yellow),
                  const SizedBox(width: 4),
                  Text('${item.totalCoin}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ]),
                if (item.description != null && item.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(item.description!,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                ],
              ]),
            ),
            const SizedBox(width: 8),
            item.isMember
                ? OutlinedButton(
              onPressed: () => _openDetail(item),
              child: const Text('View'),
            )
                : GradientButton(
              label: 'Join',
              onPressed: () => _joinFamily(item),
              width: 80,
              height: 36,
              borderRadius: 18,
            ),
          ]),
        ),
      ),
    );
  }

  // ---- Ranking tab --------------------------------------------------------
  Widget _rankingTab() {
    if (_loadingRank) {
      return const Center(child: PremiumLoading());
    }
    if (_ranking.isEmpty) {
      return const EmptyState(icon: Icons.leaderboard, title: 'No ranking data');
    }
    final top3 = _ranking.take(3).toList();
    final rest = _ranking.length > 3 ? _ranking.sublist(3) : <FamilyRankItem>[];
    return RefreshIndicator(
      onRefresh: _loadRanking,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _rewardBanner(),
          const SizedBox(height: 16),
          if (top3.isNotEmpty) _podium(top3),
          const SizedBox(height: 16),
          ...List.generate(rest.length, (i) => _rankCard(rest[i], rank: i + 4)),
        ],
      ),
    );
  }

  Widget _rewardBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: AppTheme.darkGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Family Ranking Reward',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            SizedBox(height: 4),
            Text('Exquisite gifts are waiting for you!',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
        Text('🏆', style: TextStyle(fontSize: 28)),
      ]),
    );
  }

  Widget _podium(List<FamilyRankItem> top3) {
    FamilyRankItem? at(int i) => i < top3.length ? top3[i] : null;
    final first = at(0);
    final second = at(1);
    final third = at(2);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (second != null) Expanded(child: _podiumItem(second, 2, 120)) else const Spacer(),
        if (first != null) Expanded(child: _podiumItem(first, 1, 150)) else const Spacer(),
        if (third != null) Expanded(child: _podiumItem(third, 3, 110)) else const Spacer(),
      ],
    );
  }

  Widget _podiumItem(FamilyRankItem item, int place, double height) {
    final gradient = switch (place) {
      1 => AppTheme.goldGradient,
      2 => const LinearGradient(colors: [Color(0xFF90A4AE), Color(0xFF546E7A)]),
      _ => const LinearGradient(colors: [Color(0xFFD7A26E), Color(0xFF8D5524)]),
    };
    return GestureDetector(
      onTap: () => _openRankDetail(item),
      child: Column(children: [
        PremiumBadge(text: 'TOP$place', gradient: gradient, icon: Icons.emoji_events),
        const SizedBox(height: 8),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: gradient,
            boxShadow: place == 1
                ? [BoxShadow(color: AppTheme.yellow.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 2)]
                : null,
          ),
          padding: const EdgeInsets.all(2.5),
          child: ClipOval(
            child: item.image != null && item.image!.isNotEmpty
                ? CachedNetworkImage(imageUrl: item.image!, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: AppTheme.surfaceLight, child: const Icon(Icons.group, color: AppTheme.primary)))
                : Container(color: AppTheme.surfaceLight, child: const Icon(Icons.group, color: AppTheme.primary)),
          ),
        ),
        const SizedBox(height: 8),
        Text(item.name ?? 'Family',
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
            maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('🔥', style: TextStyle(fontSize: 11)),
          const SizedBox(width: 2),
          Text(formatCount(item.totalCoin),
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        ClipPath(
          clipper: _ShieldClipper(),
          child: Container(height: height * 0.35, decoration: BoxDecoration(gradient: gradient)),
        ),
      ]),
    );
  }

  Widget _rankCard(FamilyRankItem item, {required int rank}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openRankDetail(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            SizedBox(
              width: 32,
              child: Text('$rank',
                  style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(width: 10),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.purpleGradient),
              child: ClipOval(
                child: item.image != null && item.image!.isNotEmpty
                    ? CachedNetworkImage(imageUrl: item.image!, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.group, color: Colors.white, size: 20))
                    : const Icon(Icons.group, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name ?? 'Family',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.people, size: 12, color: AppTheme.textSecondary),
                  const SizedBox(width: 3),
                  Text('${item.memberCount}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  const SizedBox(width: 8),
                  PremiumBadge(text: 'Lv ${item.level}', gradient: AppTheme.goldGradient),
                ]),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(formatCount(item.totalCoin),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary)),
              const Text('diamonds', style: TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
            ]),
          ]),
        ),
      ),
    );
  }

  // ---- My family tab ------------------------------------------------------
  Widget _myFamilyTab() {
    if (_loadingMine) return const Center(child: PremiumLoading());
    if (_myFamily == null) {
      return EmptyState(
        icon: Icons.family_restroom,
        title: 'You are not in a family',
        subtitle: 'Join or create a family to get started',
        actionLabel: 'Create Family',
        onAction: () => context.pushNamed(AppRoutes.familyCreate),
      );
    }
    final f = _myFamily!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Cover header
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: AppTheme.darkGradient,
            boxShadow: AppTheme.cardShadow,
          ),
          child: Stack(children: [
            if (f.coverImage != null && f.coverImage!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CachedNetworkImage(
                  imageUrl: f.coverImage!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox(height: 160),
                ),
              )
            else
              const SizedBox(height: 160),
            Container(
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                ),
              ),
            ),
            Positioned(
              left: 16, bottom: 12,
              child: Row(children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.purpleGradient,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipOval(
                    child: f.image != null && f.image!.isNotEmpty
                        ? CachedNetworkImage(imageUrl: f.image!, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.group, color: Colors.white))
                        : const Icon(Icons.group, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.name ?? 'Family',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(children: [
                    PremiumBadge(text: 'Lv ${f.level}', gradient: AppTheme.goldGradient),
                    const SizedBox(width: 8),
                    Text('${f.memberCount} members',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ]),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        // Stats
        Row(children: [
          Expanded(child: _miniStat('Diamonds', formatCount(f.totalCoin), Icons.diamond, AppTheme.greenGradient)),
        ]),
        const SizedBox(height: 16),
        // Welcome message
        if (f.welcomeMessage != null && f.welcomeMessage!.isNotEmpty) ...[
          const SectionHeader(title: 'Welcome'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
            ),
            child: Text(f.welcomeMessage!, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
          ),
          const SizedBox(height: 16),
        ],
        // Action buttons
        GradientButton(
          label: 'Open Family',
          icon: Icons.arrow_forward,
          onPressed: () => _openDetail(f),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                final code = f.joinCode ?? '';
                final msg = code.isNotEmpty
                    ? 'Join my family ${f.name ?? ''} on Belive! Code: $code'
                    : 'Join my family ${f.name ?? ''} on Belive!';
                Share.share(msg);
              },
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _confirmLeave(f),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Leave', style: TextStyle(color: Colors.red)),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        // Members preview
        if (f.members.isNotEmpty) ...[
          const SectionHeader(title: 'Members'),
          const SizedBox(height: 8),
          ...f.members.take(5).map((m) => _memberRow(m)),
          if (f.members.length > 5)
            TextButton(
              onPressed: () => _openDetail(f),
              child: Text('View all ${f.members.length} members'),
            ),
        ],
      ],
    );
  }

  Widget _miniStat(String label, String value, IconData icon, Gradient g) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(gradient: g, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
      ]),
    );
  }

  Widget _memberRow(FamilyMember m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        ClipOval(
          child: SizedBox(
            width: 36,
            height: 36,
            child: m.image != null && m.image!.isNotEmpty
                ? CachedNetworkImage(imageUrl: m.image!, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: AppTheme.surface, child: const Icon(Icons.person, color: Colors.white54, size: 18)))
                : Container(color: AppTheme.surface, child: const Icon(Icons.person, color: Colors.white54, size: 18)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(m.name ?? '—', style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        if (m.role == 'leader')
          const PremiumBadge(text: 'Leader', gradient: AppTheme.goldGradient, icon: Icons.star)
        else if (m.role == 'co-leader')
          const PremiumBadge(text: 'Co-Leader', gradient: AppTheme.purpleGradient, icon: Icons.shield)
        else
          const Text('Member', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
      ]),
    );
  }
}

// ---- Join Code Dialog ----------------------------------------------------
class _JoinCodeDialog extends StatefulWidget {
  const _JoinCodeDialog();

  @override
  State<_JoinCodeDialog> createState() => _JoinCodeDialogState();
}

class _JoinCodeDialogState extends State<_JoinCodeDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter Join Code'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Join code'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, _ctrl.text.trim()), child: const Text('Join')),
      ],
    );
  }
}

// ---- Shield ribbon shape used under podium avatars ------------------------
class _ShieldClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height * 0.6);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(0, size.height * 0.6);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
