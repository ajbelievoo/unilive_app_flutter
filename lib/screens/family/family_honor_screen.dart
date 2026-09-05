/// Family Honor screen — Bigo Live-style weekly family ranking.
///
/// Shows top family banner, This Week / Last Week / Reward tabs,
/// countdown timer and the full ranking list.
library family_honor;

import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/family_models.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../utils/log.dart';
import 'family_reward_screen.dart';
import 'package:belive/widgets/preloader.dart';

/// Fallback countdown when backend is unavailable.
/// Calculates next Monday 00:00 UTC from now.
Duration _fallbackCountdown() {
  final now = DateTime.now().toUtc();
  final nextMonday = now
      .add(const Duration(days: 7))
      .subtract(Duration(days: now.weekday - 1))
      .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
  return nextMonday.difference(now);
}

class FamilyHonorScreen extends StatefulWidget {
  const FamilyHonorScreen({super.key});

  @override
  State<FamilyHonorScreen> createState() => _FamilyHonorScreenState();
}

class _FamilyHonorScreenState extends State<FamilyHonorScreen>
    with TickerProviderStateMixin {
  static const String _tag = 'FamilyHonor';

  int _selectedTab = 0; // 0 = this week, 1 = last week, 2 = reward
  final List<FamilyRankItem> _thisWeek = [];
  final List<FamilyRankItem> _lastWeek = [];
  final List<String> _topMemberImages = [];
  bool _loading = true;
  String _searchQuery = '';
  String _myFamilyId = '';

  late final AnimationController _orbitCtrl;
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  Timer? _timer;
  Duration _countdown = _fallbackCountdown();
  bool _weekActive = true;
  String? _weekLabel;
  bool _configLoaded = false;

  @override
  void initState() {
    super.initState();
    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _loadMyFamily();
    _loadData();
    _loadWeekConfig();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _orbitCtrl.dispose();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_countdown.inSeconds > 0) {
          _countdown -= const Duration(seconds: 1);
        }
      });
    });
  }

  Future<void> _loadWeekConfig() async {
    try {
      final config = await ApiService.getFamilyWeekConfig();
      if (!mounted) return;
      Log.d(_tag, 'weekConfig received: isActive=${config.isActive}, weekEnd=${config.weekEnd}, label=${config.label}');
      setState(() {
        _configLoaded = true;
        _weekActive = config.isActive;
        _weekLabel = config.label;
        if (config.weekEnd != null) {
          final end = DateTime.tryParse(config.weekEnd!);
          if (end != null) {
            _countdown = end.difference(DateTime.now().toUtc());
            if (_countdown.isNegative) _countdown = const Duration();
          }
        } else if (config.nextReset != null) {
          final reset = DateTime.tryParse(config.nextReset!);
          if (reset != null) {
            _countdown = reset.difference(DateTime.now().toUtc());
            if (_countdown.isNegative) _countdown = const Duration();
          }
        } else {
          _countdown = _fallbackCountdown();
        }
      });
    } catch (e, s) {
      Log.e(_tag, 'loadWeekConfig failed, using fallback', e, s);
      if (mounted) {
        setState(() {
          _configLoaded = true;
          _countdown = _fallbackCountdown();
          _weekActive = true;
        });
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getFamilyRanking(limit: 50);
      if (res.status) {
        _thisWeek
          ..clear()
          ..addAll(res.families);
        _lastWeek
          ..clear()
          ..addAll(List.of(res.families.reversed));
        if (res.families.isNotEmpty) await _loadTopMembers(res.families.first);
      }
    } catch (e, s) {
      Log.e(_tag, 'loadData failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadTopMembers(FamilyRankItem top1) async {
    try {
      final detail = await ApiService.getFamilyMembers(top1.id ?? '');
      if (detail.status && detail.data.isNotEmpty) {
        final members = detail.data.first.members;
        if (mounted) {
          setState(() {
            _topMemberImages
              ..clear()
              ..addAll(members.map((m) => m.image ?? '').where((i) => i.isNotEmpty).take(5));
          });
        }
      }
    } catch (e, s) {
      Log.e(_tag, 'loadTopMembers failed', e, s);
    }
  }

  Future<void> _loadMyFamily() async {
    try {
      final sm = SessionManager.instance;
      if (sm == null) return;
      final userId = sm.userId;
      if (userId.isEmpty) return;
      final res = await ApiService.getUserFamily(userId);
      if (res.status && res.data.isNotEmpty) {
        if (mounted) setState(() => _myFamilyId = res.data.first.id ?? '');
      }
    } catch (e, s) {
      Log.e(_tag, 'loadMyFamily failed', e, s);
    }
  }

  List<FamilyRankItem> get _currentList => _selectedTab == 1 ? _lastWeek : _thisWeek;

  List<FamilyRankItem> get _filteredList {
    final list = _currentList;
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((f) => (f.name ?? '').toLowerCase().contains(q)).toList();
  }

  void _openCreate() => context.pushNamed(AppRoutes.familyCreate);

  void _openRules() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _FamilyRulesDialog(),
    );
  }

  void _shareRanking() {
    Share.share('Check out the family ranking on Belive! Download now.');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF050A23),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Neon header
              _buildHeader(),
              // Tabs + countdown
              _buildTabsAndCountdown(),
              // Search bar
              if (_selectedTab != 2) _buildSearchBar(),
              // Ranking / reward
              Expanded(
                child: _loading
                    ? _buildSkeletonList()
                    : _selectedTab == 2
                        ? const FamilyRewardScreen()
                        : _buildRankingList(),
              ),
              // Bottom create + share bar
              _buildCreateBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: const Color(0xFF050A23),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search family...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: const Icon(Icons.close, color: Colors.white54, size: 18),
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF0F1A4D),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: const Color(0xFF4F8DFD).withValues(alpha: 0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: const Color(0xFF4F8DFD).withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF4F8DFD), width: 1.5),
          ),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFF11183A),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Container(width: 44, height: 44, decoration: const BoxDecoration(color: Color(0xFF1A2456), shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Container(width: 50, height: 50, decoration: BoxDecoration(color: const Color(0xFF1A2456), borderRadius: BorderRadius.circular(8))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 120, height: 14, decoration: BoxDecoration(color: const Color(0xFF1A2456), borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 8),
                  Container(width: 80, height: 12, decoration: BoxDecoration(color: const Color(0xFF1A2456), borderRadius: BorderRadius.circular(4))),
                ],
              ),
            ),
            Container(width: 60, height: 16, decoration: BoxDecoration(color: const Color(0xFF1A2456), borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final top1 = _currentList.isNotEmpty ? _currentList.first : null;
    final members = _topMemberImages;

    return Container(
      height: 370,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0B6E), Color(0xFF050A23)],
        ),
      ),
      child: Stack(
        children: [
          // Decorative neon background with particles + sparkles
          Positioned.fill(
            child: CustomPaint(painter: _NeonBackgroundPainter()),
          ),
          // Radial glow behind pod
          const Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 260,
                height: 230,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x224F8DFD), Color(0x001A0B6E)],
                      radius: 0.7,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Back + share buttons
          Positioned(
            top: 4,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ),
          Positioned(
            top: 4,
            right: 8,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: _shareRanking,
                ),
                IconButton(
                  icon: const Icon(Icons.help_outline, color: Colors.white),
                  onPressed: _openRules,
                ),
              ],
            ),
          ),
          // Title
          const Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  Text(
                    'FAMILY',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFFE082),
                      shadows: [
                        Shadow(color: Color(0xFFFFD700), blurRadius: 12),
                        Shadow(color: Color(0xFFFF8C00), blurRadius: 24),
                      ],
                    ),
                  ),
                  Text(
                    'HONOR',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFFE082),
                      shadows: [
                        Shadow(color: Color(0xFFFFD700), blurRadius: 12),
                        Shadow(color: Color(0xFFFF8C00), blurRadius: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Top 1 family pod with orbiting members
          Positioned(
            top: 95,
            left: 0,
            right: 0,
            child: Center(child: _buildTopPod(top1, members)),
          ),
          // Banner below pod
          if (top1 != null)
            Positioned(
              top: 308,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2962FF), Color(0xFF7C4DFF)],
                      ),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF4F8DFD).withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 1),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.workspace_premium, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          _selectedTab == 1 ? 'LAST WEEK TOP1' : 'THIS WEEK TOP1',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Family name
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.black.withValues(alpha: 0.25),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          top1.name ?? 'Family Name',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: Color(0xFFFFD700), blurRadius: 10)],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.favorite, color: Color(0xFFFF4081), size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopPod(FamilyRankItem? top1, List<String> members) {
    const double radius = 72;
    final centerImage = top1?.image ?? '';

    return SizedBox(
      width: 260,
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hex glow behind center
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.25), blurRadius: 30, spreadRadius: 6)],
            ),
          ),
          // Orbit ring with glow
          Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF4F8DFD).withValues(alpha: 0.4), width: 2),
              boxShadow: [BoxShadow(color: const Color(0xFF4F8DFD).withValues(alpha: 0.2), blurRadius: 15)],
            ),
          ),
          // Animated orbiting avatars
          AnimatedBuilder(
            animation: _orbitCtrl,
            builder: (_, child) => Transform.rotate(angle: _orbitCtrl.value * 2 * math.pi, child: child),
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (int i = 0; i < 5; i++)
                  Transform.translate(
                    offset: Offset(radius * _xOffset(i, 5), radius * _yOffset(i, 5)),
                    child: _OrbitAvatar(image: i < members.length ? members[i] : ''),
                  ),
              ],
            ),
          ),
          // Center hex shield
          SizedBox(
            width: 90,
            height: 90,
            child: CustomPaint(
              painter: _HexagonPainter(color: const Color(0xFF00E5FF)),
              child: ClipPath(
                clipper: _HexagonClipper(),
                child: _FamilyImage(image: centerImage),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _xOffset(int index, int total) => math.cos(_angle(index, total));
  double _yOffset(int index, int total) => math.sin(_angle(index, total));

  double _angle(int index, int total) => index * 2 * math.pi / total - math.pi / 2;

  Widget _buildTabsAndCountdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: const Color(0xFF050A23),
      child: Column(
        children: [
          Row(
            children: [
              _tabButton(0, 'This Week\nRanking'),
              const SizedBox(width: 8),
              _tabButton(1, 'Last Week\nRanking'),
              const SizedBox(width: 8),
              _tabButton(2, 'Reward'),
            ],
          ),
          const SizedBox(height: 10),
          // Countdown or inactive status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1A4D),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _weekActive
                    ? const Color(0xFF4F8DFD).withValues(alpha: 0.3)
                    : const Color(0xFFFF5252).withValues(alpha: 0.4),
              ),
            ),
            child: !_configLoaded
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 14, height: 14, child: Preloader(strokeWidth: 2, color: Colors.white54)),
                      SizedBox(width: 10),
                      Text('Loading countdown...', style: TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  )
                : _weekActive
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_weekLabel != null) ...[
                        Text(_weekLabel!, style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                      ],
                      const Text('CountDown  ', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      _countBox(_countdown.inDays.toString().padLeft(2, '0')),
                      const Text('  Days |  ', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      _countBox(_countdown.inHours.remainder(24).toString().padLeft(2, '0')),
                      const Text('  :  ', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      _countBox(_countdown.inMinutes.remainder(60).toString().padLeft(2, '0')),
                      const Text('  :  ', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      _countBox(_countdown.inSeconds.remainder(60).toString().padLeft(2, '0')),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pause_circle, color: Color(0xFFFF5252), size: 18),
                      SizedBox(width: 8),
                      Text('Weekly ranking is currently paused', style: TextStyle(color: Color(0xFFFF5252), fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(int index, String label) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)])
                : const LinearGradient(colors: [Color(0xFF11183A), Color(0xFF11183A)]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? const Color(0xFF4F8DFD) : const Color(0xFF1A2456)),
            boxShadow: selected
                ? [BoxShadow(color: const Color(0xFF4F8DFD).withValues(alpha: 0.4), blurRadius: 8)]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _countBox(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _buildRankingList() {
    final list = _filteredList;
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? 'No families found' : 'No ranking data',
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: Colors.white,
      backgroundColor: const Color(0xFF1A0B6E),
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemCount: list.length,
        itemBuilder: (_, i) => _rankItem(list[i], i + 1),
      ),
    );
  }

  Widget _rankItem(FamilyRankItem item, int rank) {
    final isTop3 = rank <= 3;
    final isMyFamily = _myFamilyId.isNotEmpty && item.id == _myFamilyId;
    final gradient = rank == 1
        ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)])
        : rank == 2
            ? const LinearGradient(colors: [Color(0xFFC0C0C0), Color(0xFF78909C)])
            : rank == 3
                ? const LinearGradient(colors: [Color(0xFF00BFA5), Color(0xFF00695C)])
                : const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF0D47A1)]);

    return GestureDetector(
      onTap: () {
        if (item.id != null && item.id!.isNotEmpty) {
          context.pushNamed(AppRoutes.familyDetail, extra: {'familyId': item.id});
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          border: isMyFamily ? Border.all(color: const Color(0xFF00E5FF), width: 2) : null,
          boxShadow: isTop3
              ? [BoxShadow(color: gradient.colors.first.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 1)]
              : isMyFamily
                  ? [BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.3), blurRadius: 8)]
                  : null,
        ),
        child: Row(
          children: [
            // Rank badge
            if (isTop3)
              _topBadge(rank)
            else
              SizedBox(
                width: 40,
                child: Text('$rank', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ),
            const SizedBox(width: 10),
            // Family frame / avatar
            _FamilyFrame(rank: rank, image: item.image ?? ''),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.name ?? 'Family',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (isTop3)
                        const Icon(Icons.verified, color: Colors.white, size: 14),
                      if (isMyFamily) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: const Color(0xFF00E5FF), borderRadius: BorderRadius.circular(4)),
                          child: const Text('YOU', style: TextStyle(color: Color(0xFF050A23), fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Level + member count row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shield, color: Color(0xFF00E5FF), size: 10),
                            const SizedBox(width: 3),
                            Text('Lv.${item.level}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.group, color: Colors.white70, size: 10),
                          const SizedBox(width: 3),
                          Text('${item.memberCount}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _memberAvatars(item),
                ],
              ),
            ),
            // Coin value
            Row(
              children: [
                const Icon(Icons.diamond, color: Color(0xFFFFD700), size: 18),
                const SizedBox(width: 4),
                Text(
                  _formatBig(item.totalCoin),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBadge(int rank) {
    if (rank >= 1 && rank <= 3) {
      return Image.asset(
        'assets/family/tag_family_top$rank.png',
        width: 44,
        height: 44,
        fit: BoxFit.contain,
      );
    }
    return SizedBox(
      width: 44,
      child: Text(
        '$rank',
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _memberAvatars(FamilyRankItem item) {
    final images = item.members.map((m) => m.image ?? '').where((img) => img.isNotEmpty).take(5).toList();
    return SizedBox(
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(5, (i) {
          final hasImg = i < images.length;
          return Positioned(
            left: i * 18.0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.2),
                color: const Color(0xFF0F1A4D),
              ),
              child: hasImg
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: images[i],
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Icon(Icons.person, color: Colors.white24, size: 14),
                        errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.white24, size: 14),
                      ),
                    )
                  : const Center(child: Icon(Icons.person, color: Colors.white12, size: 14)),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCreateBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF050A23),
        boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 8)],
      ),
      child: GestureDetector(
        onTap: _openCreate,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFFD54F), Color(0xFFFF8C00)]),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [BoxShadow(color: const Color(0xFFFFD54F).withValues(alpha: 0.4), blurRadius: 12)],
          ),
          child: const Center(
            child: Text(
              'Create My Family',
              style: TextStyle(color: Color(0xFF3E2723), fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  String _formatBig(int n) {
    if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(n < 10000000000 ? 2 : 1)}B';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(n < 10000000 ? 2 : 1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ---- Family image helper ---------------------------------------------------
class _FamilyImage extends StatelessWidget {
  final String image;
  const _FamilyImage({required this.image});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: const Color(0xFF2A2A3E),
      child: const Center(child: Icon(Icons.group, color: Colors.white, size: 32)),
    );
    if (image.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: image,
      fit: BoxFit.cover,
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => fallback,
    );
  }
}

// ---- Orbit member avatar ---------------------------------------------------
class _OrbitAvatar extends StatelessWidget {
  final String image;
  const _OrbitAvatar({required this.image});

  @override
  Widget build(BuildContext context) {
    final hasImg = image.isNotEmpty;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.6), width: 2),
        color: const Color(0xFF0F1A4D),
        boxShadow: hasImg ? [BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.4), blurRadius: 8)] : null,
      ),
      child: ClipOval(
        child: hasImg
            ? _FamilyImage(image: image)
            : const Center(child: Icon(Icons.person, color: Colors.white10, size: 24)),
      ),
    );
  }
}

// ---- Family rank frame ----------------------------------------------------
class _FamilyFrame extends StatelessWidget {
  final int rank;
  final String image;
  const _FamilyFrame({required this.rank, required this.image});

  @override
  Widget build(BuildContext context) {
    final size = rank == 1 ? 60.0 : 50.0;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HexagonPainter(color: _frameColor()),
        child: ClipPath(
          clipper: _HexagonClipper(),
          child: _FamilyImage(image: image),
        ),
      ),
    );
  }

  Color _frameColor() {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFF00BFA5);
    return const Color(0xFF4F8DFD);
  }
}

// ---- Hexagon helpers -------------------------------------------------------
class _HexagonPainter extends CustomPainter {
  final Color color;
  final double strokeWidth = 3;
  _HexagonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final path = _hexagonPath(size);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _hexagonPath(size);

  @override
  bool shouldReclip(_) => false;
}

Path _hexagonPath(Size size) {
  final path = Path();
  final center = Offset(size.width / 2, size.height / 2);
  final radius = size.width / 2;
  for (int i = 0; i < 6; i++) {
    final angle = -math.pi / 2 + i * math.pi / 3;
    final x = center.dx + radius * math.cos(angle);
    final y = center.dy + radius * math.sin(angle);
    if (i == 0) path.moveTo(x, y);
    path.lineTo(x, y);
  }
  path.close();
  return path;
}

// ---- Neon background painter -----------------------------------------------
class _NeonBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Soft top glow
    final glow = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.6),
        radius: 0.8,
        colors: [Color(0x336200EA), Color(0x001A0B6E)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glow);

    final paint = Paint()
      ..color = const Color(0xFF4F8DFD).withValues(alpha: 0.15)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Left bolt
    _drawBolt(canvas, const Offset(20, 80), 40, paint);
    // Right bolt
    _drawBolt(canvas, Offset(size.width - 40, 60), 60, paint);

    // Floating particles
    final p = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    final rng = math.Random(size.width.round() + size.height.round());
    for (int i = 0; i < 12; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.6;
      final r = 1.0 + rng.nextDouble() * 2.5;
      canvas.drawCircle(Offset(x, y), r, p);
    }

    // Star sparkles
    final starFill = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    final starStroke = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int i = 0; i < 6; i++) {
      final x = rng.nextDouble() * size.width;
      final y = 20 + rng.nextDouble() * (size.height * 0.4);
      _drawStar(canvas, Offset(x, y), 4 + rng.nextDouble() * 4, starFill, starStroke);
    }

    // Perspective grid lines at bottom
    final grid = Paint()
      ..color = const Color(0xFF4F8DFD).withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (int i = 1; i <= 6; i++) {
      final y = size.height - i * 8.0;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  void _drawBolt(Canvas canvas, Offset start, double height, Paint paint) {
    final path = Path();
    path.moveTo(start.dx, start.dy);
    path.lineTo(start.dx + 12, start.dy + height * 0.35);
    path.lineTo(start.dx - 4, start.dy + height * 0.4);
    path.lineTo(start.dx + 18, start.dy + height);
    canvas.drawPath(path, paint);
  }

  void _drawStar(Canvas canvas, Offset c, double r, Paint fill, Paint stroke) {
    canvas.drawCircle(c, r * 0.25, fill);
    canvas.drawCircle(c, r, stroke);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ---- Rules dialog matching screenshot --------------------------------------
class _FamilyRulesDialog extends StatelessWidget {
  const _FamilyRulesDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF311B92), Color(0xFF4A148C)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(child: SizedBox()),
                const Text('Rules', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const Expanded(child: SizedBox()),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white70, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _ruleTitle('How to improve your family ranking?'),
            const SizedBox(height: 8),
            _ruleBody('The families will be ranked by the total contribution of all members weekly. The higher the contribution, the higher the ranking.'),
            const SizedBox(height: 12),
            _ruleBody('Tips: Once a member leaves the family, the individual rank and contribution will be cleared, but the total contribution of the family will not be deducted.'),
            const SizedBox(height: 20),
            _ruleTitle('How to get family contribution?'),
            const SizedBox(height: 8),
            _ruleBody('Gifting by family members.'),
            _ruleBody('1 diamond = 1 contribution'),
            _ruleBody('(Lucky gifts are calculated 20% of diamonds value.)'),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _ruleTitle(String text) {
    return Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold));
  }

  Widget _ruleBody(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
    );
  }
}
