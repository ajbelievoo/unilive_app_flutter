library cp_star_event_screen;

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/cp_models.dart';
import '../../models/friend_models.dart';
import '../../providers/cp_provider.dart';
import '../../providers/friend_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart';

/// CP/Friend Star Event screen — opens from Home quick-action "CP" button.
/// Deep purple event leaderboard with gold accents (matching screenshots).
class CpStarEventScreen extends StatefulWidget {
  const CpStarEventScreen({super.key});

  @override
  State<CpStarEventScreen> createState() => _CpStarEventScreenState();
}

class _CpStarEventScreenState extends State<CpStarEventScreen> {
  bool _isFriendMode = false;
  int _tab = 0; // 0 Ranking, 1 Ranking Rewards, 2 Weekly Rewards

  /// Active star event (real backend event). Null when no event is active
  /// or the fetch failed — falls back to a mock countdown so the screen is
  /// still presentable. See `docs/CP_FRIEND_BACKEND_REMAINING.md` §3.
  CPStarEvent? _cpStarEvent;
  CPStarEvent? _friendStarEvent;

  DateTime? _eventEndTime;
  Timer? _timer;
  String _countdownText = 'Loading...';

  // ---- Exact colors from screenshot analysis ----
  static const Color _bgTop = Color(0xFF311288);
  static const Color _bgMid = Color(0xFF5F0C73);
  static const Color _bgBot = Color(0xFF5C03AA);
  static const Color _cardBg = Color(0xFF4B1180);
  static const Color _rowTopColor = Color(0xFF7A2BCB);
  static const Color _rowRestColor = Color(0xFF5421A9);
  static const Color _gold = Color(0xFFE1C363);
  static const Color _goldBright = Color(0xFFFFD85B);
  static const Color _goldInvite = Color(0xFFFFD13F);
  static const Color _scoreBlue = Color(0xFF9DE7FF);
  static const Color _headerGrad1 = Color(0xFF8A2BE2);
  static const Color _headerGrad2 = Color(0xFF6222C9);
  static const Color _tabSelGrad1 = Color(0xFFD034FF);
  static const Color _tabSelGrad2 = Color(0xFF7E21E8);
  static const Color _tabUnselGrad1 = Color(0xFF317BFF);
  static const Color _tabUnselGrad2 = Color(0xFF2152C6);
  static const Color _footerGrad1 = Color(0xFF9A2CFF);
  static const Color _footerGrad2 = Color(0xFF6E1FD3);
  static const Color _myRewardsBg = Color(0xFF7F35E7);

  @override
  void initState() {
    super.initState();
    // Fallback countdown in case the backend event endpoint is not live yet.
    _eventEndTime = DateTime.now().add(const Duration(days: 4, hours: 17, minutes: 43, seconds: 58));
    _startCountdown();
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _updateCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    if (_eventEndTime == null) return;
    final now = DateTime.now();
    final diff = _eventEndTime!.difference(now);
    if (diff.isNegative) {
      if (mounted) setState(() => _countdownText = 'Event Ended');
      _timer?.cancel();
    } else {
      final days = diff.inDays;
      final hours = diff.inHours % 24;
      final minutes = diff.inMinutes % 60;
      final seconds = diff.inSeconds % 60;
      if (mounted) {
        setState(() => _countdownText = 'CountDown   $days Days  ${hours.toString().padLeft(2, '0')} : ${minutes.toString().padLeft(2, '0')} : ${seconds.toString().padLeft(2, '0')}');
      }
    }
  }

  Future<void> _loadData() async {
    final cp = context.read<CpProvider>();
    final friend = context.read<FriendProvider>();
    // Fetch the real star event + ranking in parallel.
    final results = await Future.wait([
      ApiService.getActiveCPStarEvent(),
      ApiService.getActiveFriendStarEvent(),
      cp.loadRanking(period: 'weekly'),
      friend.loadRanking(period: 'weekly'),
    ]);
    final cpEvent = results[0] as CPStarEventRoot;
    final friendEvent = results[1] as CPStarEventRoot;
    if (!mounted) return;
    setState(() {
      _cpStarEvent = cpEvent.event;
      _friendStarEvent = friendEvent.event;
      // Use the real event end time for the countdown when available.
      final active = _isFriendMode ? _friendStarEvent : _cpStarEvent;
      if (active?.endTime != null) {
        _eventEndTime = active!.endTime;
        _updateCountdown();
      }
    });
    // If a real event is active, also fetch the event leaderboard for a more
    // accurate ranking than the generic weekly ranking.
    final active = _isFriendMode ? _friendStarEvent : _cpStarEvent;
    if (active != null && active.isActive && (active.id ?? '').isNotEmpty) {
      if (_isFriendMode) {
        await ApiService.getFriendStarEventLeaderboard(active.id!);
      } else {
        await ApiService.getStarEventLeaderboard(active.id!);
      }
    }
  }

  /// Switch between CP and Friend mode and refresh the countdown + ranking
  /// for the newly selected mode.
  Future<void> _switchMode(bool friendMode) async {
    if (_isFriendMode == friendMode) return;
    setState(() => _isFriendMode = friendMode);
    final active = friendMode ? _friendStarEvent : _cpStarEvent;
    if (active?.endTime != null) {
      _eventEndTime = active!.endTime;
      _updateCountdown();
    } else {
      // No real event for this mode — reset to a generic fallback countdown.
      _eventEndTime = DateTime.now().add(const Duration(days: 4, hours: 17));
      _updateCountdown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeEvent = _isFriendMode ? _friendStarEvent : _cpStarEvent;
    final title = activeEvent?.name ??
        (_isFriendMode ? 'Friend Star' : 'CP Star');

    return Scaffold(
      backgroundColor: AppTheme.cpDarkBg,
      body: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgMid, _bgBot],
          ),
          image: DecorationImage(
            image: (activeEvent?.backgroundUrl ?? '').isNotEmpty
                ? CachedNetworkImageProvider(activeEvent!.backgroundUrl!)
                : const AssetImage('assets/cp_friend/bg_freind_star.webp')
                    as ImageProvider,
            fit: BoxFit.cover,
            opacity: 0.85,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                  child: Column(
                    children: [
                      const SizedBox(height: 6),
                      // Big gold title
                      Text(
                        title,
                        style: const TextStyle(
                          color: _goldBright,
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _countdownRow(),
                      const SizedBox(height: 10),
                      _tabButtons(),
                      const SizedBox(height: 8),
                      if (_tab == 0)
                        _rankingContent()
                      else
                        _rewardTable(weekly: _tab == 2),
                    ],
                  ),
                ),
              ),
              _inviteFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top bar — back, CP/Friend toggle, rules, my rewards
  // ---------------------------------------------------------------------------
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 2),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _switchModeButton(
                  'CP',
                  !_isFriendMode,
                  () => _switchMode(false),
                ),
                const SizedBox(width: 20),
                _switchModeButton(
                  'Friend',
                  _isFriendMode,
                  () => _switchMode(true),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showRulesDialog,
            icon: const Icon(
              Icons.help_outline_rounded,
              color: Color(0xFFBCE4FF),
              size: 22,
            ),
          ),
          GestureDetector(
            onTap: _showMyRewardsDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _myRewardsBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'My Rewards',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchModeButton(String text, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: selected ? 1 : 0.6),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 3,
            width: 28,
            decoration: BoxDecoration(
              color: selected ? _goldBright : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Countdown row
  // ---------------------------------------------------------------------------
  Widget _countdownRow() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _countdownText,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab buttons — Ranking / Ranking Rewards / Weekly Rewards
  // ---------------------------------------------------------------------------
  Widget _tabButtons() {
    final tabs = ['Ranking', 'Ranking Rewards', 'Weekly Rewards'];
    return Row(
      children: List.generate(tabs.length, (i) {
        final selected = _tab == i;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient:
                      selected
                          ? const LinearGradient(
                            colors: [_tabSelGrad1, _tabSelGrad2],
                          )
                          : const LinearGradient(
                            colors: [_tabUnselGrad1, _tabUnselGrad2],
                          ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _gold, width: 1),
                ),
                child: Text(
                  tabs[i],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Ranking content — Last Week TOP1 + This Week TOP2-TOP9
  // ---------------------------------------------------------------------------
  Widget _rankingContent() {
    final cpItems = context.watch<CpProvider>().ranking;
    final friendItems = context.watch<FriendProvider>().ranking;
    final sourceItems = _isFriendMode ? friendItems : cpItems;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold, width: 1.5),
      ),
      child: Column(
        children: [
          // Last Week Ranking section
          _sectionHeader('Last Week Ranking'),
          if (sourceItems.isNotEmpty)
            _isFriendMode
                ? _topOneFriendRow(friendItems.first)
                : _topOneCpRow(cpItems.first)
          else
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'No data',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          const SizedBox(height: 4),
          // This Week Ranking section
          _sectionHeader('This Week Ranking'),
          if (sourceItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'No ranking data',
                style: TextStyle(color: Colors.white54),
              ),
            )
          else
            ...List.generate(sourceItems.length.clamp(0, 9), (i) {
              final rank = i + 1;
              final leftName =
                  _isFriendMode
                      ? friendItems[i].friend?.user1?.name ?? '-'
                      : cpItems[i].cp?.user1?.name ?? '-';
              final rightName =
                  _isFriendMode
                      ? friendItems[i].friend?.user2?.name ?? '-'
                      : cpItems[i].cp?.user2?.name ?? '-';
              final leftImage =
                  _isFriendMode
                      ? friendItems[i].friend?.user1?.image
                      : cpItems[i].cp?.user1?.image;
              final rightImage =
                  _isFriendMode
                      ? friendItems[i].friend?.user2?.image
                      : cpItems[i].cp?.user2?.image;
              final score =
                  _isFriendMode ? friendItems[i].intimacy : cpItems[i].intimacy;
              return _rankRow(
                rank,
                leftName,
                rightName,
                leftImage,
                rightImage,
                score,
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _rankRow(
    int rank,
    String leftName,
    String rightName,
    String? leftImage,
    String? rightImage,
    int score,
  ) {
    String? tagAsset;
    if (rank == 1) {
      tagAsset = _isFriendMode
          ? 'assets/cp_friend/tag_friend_top1.webp'
          : 'assets/cp_friend/tag_cp_top1.webp';
    } else if (rank == 2) {
      tagAsset = _isFriendMode
          ? 'assets/cp_friend/tag_friend_top2.webp'
          : 'assets/cp_friend/tag_cp_top2.webp';
    } else if (rank == 3) {
      tagAsset = _isFriendMode
          ? 'assets/cp_friend/tag_friend_top3.webp'
          : 'assets/cp_friend/tag_cp_top3.webp';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: rank <= 3 ? _rowTopColor : _rowRestColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: rank <= 3
            ? [BoxShadow(color: _gold.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))]
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: tagAsset != null
                ? Image.asset(
                    tagAsset,
                    width: 32,
                    height: 20,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Text(
                      'TOP$rank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  )
                : Text(
                    'TOP$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
          ),
          _avatar(leftImage),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.handshake_rounded, size: 16, color: _gold),
          ),
          _avatar(rightImage),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$leftName & $rightName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            formatCount(score),
            style: const TextStyle(
              color: _scoreBlue,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TOP1 row — special highlighted row for last week winner
  // ---------------------------------------------------------------------------
  Widget _topOneCpRow(CPRankItem item) => _topOneRow(
    leftName: item.cp?.user1?.name ?? '-',
    rightName: item.cp?.user2?.name ?? '-',
    leftImage: item.cp?.user1?.image,
    rightImage: item.cp?.user2?.image,
    score: item.intimacy,
  );

  Widget _topOneFriendRow(FriendRankItem item) => _topOneRow(
    leftName: item.friend?.user1?.name ?? '-',
    rightName: item.friend?.user2?.name ?? '-',
    leftImage: item.friend?.user1?.image,
    rightImage: item.friend?.user2?.image,
    score: item.intimacy,
  );

  Widget _topOneRow({
    required String leftName,
    required String rightName,
    required String? leftImage,
    required String? rightImage,
    required int score,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD94B2F), Color(0xFF9E1F28)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD94B2F).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            'TOP1',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          _avatar(leftImage),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.handshake_rounded, size: 16, color: _gold),
          ),
          _avatar(rightImage),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$leftName & $rightName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            formatCount(score),
            style: const TextStyle(
              color: Color(0xFFBCEEFF),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Reward table — Ranking Rewards / Weekly Rewards
  // ---------------------------------------------------------------------------
  Widget _rewardTable({required bool weekly}) {
    const thresholds = [
      18000000,
      30000000,
      48000000,
      90000000,
      180000000,
      300000000,
      600000000,
      1200000000,
    ];
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold, width: 1.5),
      ),
      child: Column(
        children: [
          _sectionHeader(weekly ? 'Weekly Rewards' : 'Ranking Rewards'),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Column(
              children:
                  thresholds.map((value) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.diamond_rounded,
                            color: Color(0xFF8FE8FF),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              formatCount(value),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const ImageIcon(AssetImage("assets/gift/official_gift.png"), color: Color(0xFFFFCC58), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '*${(value / 12000000).ceil()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section header — purple gradient bar with white text
  // ---------------------------------------------------------------------------
  Widget _sectionHeader(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_headerGrad1, _headerGrad2]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Invite footer — bottom bar with invite button
  // ---------------------------------------------------------------------------
  Widget _inviteFooter() {
    final msg =
        _isFriendMode ? 'No Friend, go and invite' : 'No CP, go and invite';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_footerGrad1, _footerGrad2]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Text(
            msg,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 120,
            child: ElevatedButton(
              onPressed: () => context.pushNamed(AppRoutes.cp),
              style: ElevatedButton.styleFrom(
                backgroundColor: _goldInvite,
                foregroundColor: const Color(0xFF4C2A00),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text(
                'Invite',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Small avatar — Bigo-style with gradient ring + glow
  // ---------------------------------------------------------------------------
  Widget _avatar(String? image) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [_gold, _goldBright],
        ),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(1.5),
        child: CircleAvatar(
          radius: 12,
          backgroundColor: Colors.white24,
          backgroundImage:
              (image != null && image.isNotEmpty) ? NetworkImage(image) : null,
          child:
              (image == null || image.isEmpty)
                  ? const Icon(Icons.person, size: 12, color: Colors.white)
                  : null,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Rules dialog
  // ---------------------------------------------------------------------------
  void _showRulesDialog() {
    final text =
        _isFriendMode
            ? 'How do I increase my Friend ranking?\n'
                'Friend ranking is ranked by Friend EXP added each week.\n\n'
                'How do I increase Friend EXP?\n'
                '1) Gift sending: 1 diamond = 1 Friend EXP\n'
                '2) Co-streaming: every 5 mins = 120 Friend EXP, max 12000/day.'
            : 'How do I increase my CP ranking?\n'
                'CP ranking is ranked by CP EXP added each week.\n\n'
                'How do I increase CP EXP?\n'
                '1) Gift sending: 1 diamond = 1 CP EXP\n'
                '2) Co-streaming: every 5 mins = 120 CP EXP, max 12000/day.';
    showDialog<void>(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: const Color(0xFF6D2BC8),
            title: const Text(
              'Rules',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              text,
              style: const TextStyle(color: Colors.white, height: 1.4),
            ),
          ),
    );
  }

  void _showMyRewardsDialog() {
    showDialog<void>(
      context: context,
      builder:
          (_) => const AlertDialog(
            backgroundColor: Color(0xFF6D2BC8),
            title: Text(
              'My Rewards',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              'No more data',
              style: TextStyle(color: Colors.white54),
            ),
          ),
    );
  }
}
