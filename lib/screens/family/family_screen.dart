/// Family hub screen — premium Bigo/Chamet-style UI.
///
/// Three tabs: Discover | Ranking | My Family.
/// Search, create, join, share, and weekly ranking with a polished,
/// modern dark/glass aesthetic.
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
      backgroundColor: const Color(0xFF0A0A18),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            floating: true,
            backgroundColor: const Color(0xFF0A0A18),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Family',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A1240), Color(0xFF0F0B22), Color(0xFF0A0A18)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -40,
                      top: -40,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.deepPurple.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -30,
                      bottom: 40,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.amber.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline, color: Colors.white70),
                tooltip: 'Family Rules',
                onPressed: () => context.pushNamed(AppRoutes.familyRules),
              ),
            ],
            bottom: TabBar(
              controller: _tabCtrl,
              indicator: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.amber, width: 3),
                ),
              ),
              labelColor: Colors.amber,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(text: 'Discover'),
                Tab(text: 'Ranking'),
                Tab(text: 'My Family'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _allTab(),
            _rankingTab(),
            _myFamilyTab(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(AppRoutes.familyCreate),
        backgroundColor: Colors.amber,
        icon: const Icon(Icons.add, color: Color(0xFF0A0A18)),
        label: const Text('Create', style: TextStyle(color: Color(0xFF0A0A18), fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ---- Discover tab --------------------------------------------------------
  Widget _allTab() {
    return RefreshIndicator(
      onRefresh: _loadFamilies,
      color: Colors.amber,
      backgroundColor: const Color(0xFF1A1240),
      child: CustomScrollView(
        slivers: [
          if (_ranking.isNotEmpty)
            SliverToBoxAdapter(child: _buildGlobalChampionBanner()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearch,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search family...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                    prefixIcon: const Icon(Icons.search, color: Colors.white60),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white60),
                            onPressed: () {
                              _searchCtrl.clear();
                              _onSearch('');
                            },
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              ),
            ),
          ),
          if (_loadingList)
            const SliverFillRemaining(child: Center(child: PremiumLoading()))
          else if (_families.isEmpty)
            SliverFillRemaining(
              child: EmptyState(
                icon: Icons.group,
                title: 'No families found',
                subtitle: 'Be the first to create a family',
                actionLabel: 'Create one',
                onAction: () => context.pushNamed(AppRoutes.familyCreate),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _familyCard(_families[i]),
                  childCount: _families.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGlobalChampionBanner() {
    final top1 = _ranking.first;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1E5C), Color(0xFF1A1240)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.amber.withValues(alpha: 0.1), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amber, width: 2),
              boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)],
            ),
            child: ClipOval(
              child: top1.image != null && top1.image!.isNotEmpty
                  ? CachedNetworkImage(imageUrl: top1.image!, fit: BoxFit.cover)
                  : const Icon(Icons.group, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    const Text('WEEKLY CHAMPION', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(top1.name ?? 'Family', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('${formatCount(top1.totalCoin)} diamonds · ${top1.memberCount} members',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
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
    return Hero(
      tag: 'family-${item.id}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF1E1B32), const Color(0xFF121026)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openDetail(item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.purpleGradient,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 2),
                    boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 10)],
                  ),
                  child: ClipOval(
                    child: item.image != null && item.image!.isNotEmpty
                        ? CachedNetworkImage(imageUrl: item.image!, fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(Icons.group, color: Colors.white))
                        : const Icon(Icons.group, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(item.name ?? 'Family',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: AppTheme.goldGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Lv ${item.level}',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.people, size: 14, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text('${item.memberCount} members',
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(width: 12),
                          const Icon(Icons.diamond, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text('${formatCount(item.totalCoin)}',
                              style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      if (item.description != null && item.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(item.description!,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                item.isMember
                    ? OutlinedButton(
                        onPressed: () => _openDetail(item),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.amber,
                          side: const BorderSide(color: Colors.amber),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        child: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.4), blurRadius: 10)],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _joinFamily(item),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              child: Text('Join', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Ranking tab ---------------------------------------------------------
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
      color: Colors.amber,
      backgroundColor: const Color(0xFF1A1240),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _rewardBanner(),
            ),
          ),
          if (top3.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _podium(top3),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _rankCard(rest[i], rank: i + 4),
                childCount: rest.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rewardBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1E5C), Color(0xFF1A1240)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Family Ranking Reward',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text('Exquisite gifts are waiting for you!',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
              ],
            ),
          ),
          const Text('🏆', style: TextStyle(fontSize: 32)),
        ],
      ),
    );
  }

  Widget _podium(List<FamilyRankItem> top3) {
    FamilyRankItem? at(int i) => i < top3.length ? top3[i] : null;
    final first = at(0);
    final second = at(1);
    final third = at(2);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1240), Color(0xFF0F0B22)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (second != null) Expanded(child: _podiumItem(second, 2, 120)) else const Spacer(),
          if (first != null) Expanded(child: _podiumItem(first, 1, 150)) else const Spacer(),
          if (third != null) Expanded(child: _podiumItem(third, 3, 110)) else const Spacer(),
        ],
      ),
    );
  }

  Widget _podiumItem(FamilyRankItem item, int place, double height) {
    final gradient = switch (place) {
      1 => AppTheme.goldGradient,
      2 => const LinearGradient(colors: [Color(0xFF90A4AE), Color(0xFF546E7A)]),
      _ => const LinearGradient(colors: [Color(0xFFD7A26E), Color(0xFF8D5524)]),
    };
    final placeColor = switch (place) {
      1 => Colors.amber,
      2 => const Color(0xFFCFD8DC),
      _ => const Color(0xFFD7A26E),
    };
    return GestureDetector(
      onTap: () => _openRankDetail(item),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: gradient,
                  boxShadow: place == 1
                      ? [BoxShadow(color: Colors.amber.withValues(alpha: 0.5), blurRadius: 16, spreadRadius: 3)]
                      : null,
                ),
                child: CircleAvatar(
                  radius: place == 1 ? 34 : 28,
                  backgroundColor: const Color(0xFF1A1240),
                  backgroundImage: item.image != null && item.image!.isNotEmpty
                      ? CachedNetworkImageProvider(item.image!)
                      : null,
                  child: item.image == null || item.image!.isEmpty
                      ? const Icon(Icons.group, color: Colors.white)
                      : null,
                ),
              ),
              Positioned(
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: placeColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('TOP$place',
                      style: const TextStyle(color: Color(0xFF0A0A18), fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.name ?? 'Family',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.diamond, size: 11, color: Colors.amber),
              const SizedBox(width: 2),
              Text(formatCount(item.totalCoin),
                  style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          ClipPath(
            clipper: _ShieldClipper(),
            child: Container(
              height: height * 0.35,
              width: 64,
              decoration: BoxDecoration(gradient: gradient),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankCard(FamilyRankItem item, {required int rank}) {
    final rankColor = rank == 4
        ? const Color(0xFFD7A26E)
        : rank == 5
            ? const Color(0xFF90A4AE)
            : Colors.white70;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF1E1B32), const Color(0xFF121026)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openRankDetail(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                alignment: Alignment.center,
                child: Text('$rank',
                    style: TextStyle(color: rankColor, fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.purpleGradient,
                ),
                child: ClipOval(
                  child: item.image != null && item.image!.isNotEmpty
                      ? CachedNetworkImage(imageUrl: item.image!, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(Icons.group, color: Colors.white, size: 20))
                      : const Icon(Icons.group, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name ?? 'Family',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.people, size: 12, color: Colors.white60),
                        const SizedBox(width: 4),
                        Text('${item.memberCount}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            gradient: AppTheme.goldGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Lv ${item.level}',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.diamond, size: 12, color: Colors.amber),
                      const SizedBox(width: 3),
                      Text(formatCount(item.totalCoin),
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.amber, fontSize: 13)),
                    ],
                  ),
                  Text('diamonds', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- My family tab -------------------------------------------------------
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
    return RefreshIndicator(
      onRefresh: _loadMyFamily,
      color: Colors.amber,
      backgroundColor: const Color(0xFF1A1240),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Cover header
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2A1E5C), Color(0xFF1A1240)],
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          if (f.coverImage != null && f.coverImage!.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: f.coverImage!,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const SizedBox(height: 180),
                            )
                          else
                            Container(
                              height: 180,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF7B61FF), Color(0xFF2A1E5C)],
                                ),
                              ),
                            ),
                          Container(
                            height: 180,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, const Color(0xFF0A0A18).withValues(alpha: 0.95)],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 18, bottom: 18, right: 18,
                            child: Row(
                              children: [
                                Container(
                                  width: 64, height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: AppTheme.purpleGradient,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                    boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.4), blurRadius: 12)],
                                  ),
                                  child: ClipOval(
                                    child: f.image != null && f.image!.isNotEmpty
                                        ? CachedNetworkImage(imageUrl: f.image!, fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) => const Icon(Icons.group, color: Colors.white))
                                        : const Icon(Icons.group, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(f.name ?? 'Family',
                                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              gradient: AppTheme.goldGradient,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text('Lv ${f.level}',
                                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                          const SizedBox(width: 10),
                                          Text('${f.memberCount} members',
                                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Stats
                  Row(
                    children: [
                      Expanded(child: _miniStat('Diamonds', formatCount(f.totalCoin), Icons.diamond, AppTheme.greenGradient)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.4), blurRadius: 12)],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _openDetail(f),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Text('Open Family', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final code = f.joinCode ?? '';
                            final msg = code.isNotEmpty
                                ? 'Join my family ${f.name ?? ''} on Belive! Code: $code'
                                : 'Join my family ${f.name ?? ''} on Belive!';
                            Share.share(msg);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('Share'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmLeave(f),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.logout, size: 18, color: Colors.redAccent),
                          label: const Text('Leave', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (f.members.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Members', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    ...f.members.take(5).map((m) => _memberRow(m)),
                    if (f.members.length > 5)
                      TextButton(
                        onPressed: () => _openDetail(f),
                        child: Text('View all ${f.members.length} members', style: const TextStyle(color: Colors.amber)),
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

  Widget _miniStat(String label, String value, IconData icon, Gradient g) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: g,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _memberRow(FamilyMember m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 40,
              height: 40,
              child: m.image != null && m.image!.isNotEmpty
                  ? CachedNetworkImage(imageUrl: m.image!, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: const Color(0xFF1E1B32), child: const Icon(Icons.person, color: Colors.white54, size: 20)))
                  : Container(color: const Color(0xFF1E1B32), child: const Icon(Icons.person, color: Colors.white54, size: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(m.name ?? '—', style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
          ),
          if (m.role == 'leader')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: Colors.white, size: 10),
                  SizedBox(width: 3),
                  Text('Leader', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else if (m.role == 'co-leader')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                gradient: AppTheme.purpleGradient,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield, color: Colors.white, size: 10),
                  SizedBox(width: 3),
                  Text('Co-Leader', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else
            const Text('Member', style: TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
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
