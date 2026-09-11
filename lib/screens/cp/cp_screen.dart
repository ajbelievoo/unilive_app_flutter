/// CP/Friend main hub screen — Bigo-style fully dark premium redesign.
///
/// Features:
/// - Dark gradient header with CP/Friend toggle pill
/// - Hero status card (couple avatar pair / friends count with glow)
/// - Animated tab bar with gradient pills
/// - All content sections dark themed: Privileges, Ring Gallery, Rules,
///   Requests, Ranking, Invite (with discover filters)
library cp_screen;

import 'dart:math';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/cp_models.dart';
import '../../models/friend_models.dart';
import '../../providers/cp_provider.dart';
import '../../providers/friend_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../widgets/cp_widgets.dart';

class CPScreen extends StatefulWidget {
  const CPScreen({
    super.key,
    this.initialIsFriendMode = false,
    this.initialTab = 0,
  });

  final bool initialIsFriendMode;
  final int initialTab;

  @override
  State<CPScreen> createState() => _CPScreenState();
}

class _CPScreenState extends State<CPScreen>
    with SingleTickerProviderStateMixin {
  late bool _isFriendMode;
  late int _selectedTab;
  int _selectedLevel = 1;
  late final PageController _pageController;
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _isFriendMode = widget.initialIsFriendMode;
    _selectedTab = widget.initialTab;
    _pageController = PageController(initialPage: _selectedTab);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _loadAll();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final session = context.read<SessionManager>();
    final cp = context.read<CpProvider>();
    final friend = context.read<FriendProvider>();
    cp.initSocketListeners(session.userId);
    friend.initSocketListeners(session.userId);
    await Future.wait([
      cp.loadMyCP(session.userId),
      cp.loadRequests(session.userId),
      cp.loadDiscover(session.userId),
      cp.loadLevels(),
      friend.loadFriends(session.userId),
      friend.loadRequests(session.userId),
      friend.loadDiscover(session.userId),
      friend.loadLevels(),
    ]);
  }

  void _switchMode(bool isFriend) {
    if (_isFriendMode == isFriend) return;
    setState(() {
      _isFriendMode = isFriend;
      _selectedTab = 0;
      _selectedLevel = 1;
    });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  void _onTabSelected(int index) {
    if (_selectedTab == index) return;
    setState(() => _selectedTab = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  List<String> get _tabNames =>
      _isFriendMode
          ? ['Privileges', 'Rules', 'Requests', 'Ranking', 'Invite']
          : ['Privileges', 'Rings', 'Rules', 'Requests', 'Ranking', 'Invite'];

  List<IconData> get _tabIcons =>
      _isFriendMode
          ? [
            Icons.diamond_outlined,
            Icons.menu_book_outlined,
            Icons.mail_outlined,
            Icons.emoji_events_outlined,
            Icons.person_add_outlined,
          ]
          : [
            Icons.diamond_outlined,
            Icons.diamond_outlined,
            Icons.menu_book_outlined,
            Icons.mail_outlined,
            Icons.emoji_events_outlined,
            Icons.person_add_outlined,
          ];

  @override
  Widget build(BuildContext context) {
    final headerGradient =
        _isFriendMode
            ? AppTheme.friendHeaderGradient
            : AppTheme.cpHeaderGradient;
    final cp = context.watch<CpProvider>();
    final friend = context.watch<FriendProvider>();

    final accentColor = _isFriendMode ? AppTheme.friendAccent : AppTheme.cpAccent;

    return Scaffold(
      backgroundColor: AppTheme.cpDarkBg,
      body: Stack(
        children: [
          // Base animated-style gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(gradient: headerGradient),
            ),
          ),
          // Radial glow behind the hero card
          Positioned(
            top: -60,
            left: -80,
            right: -80,
            height: 360,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.8,
                  colors: [
                    accentColor.withValues(alpha: 0.55),
                    accentColor.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          // Bottom vignette
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppTheme.cpDarkBg.withValues(alpha: 0.4),
                    AppTheme.cpDarkBg.withValues(alpha: 0.9),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
          // Twinkling star field
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _glowController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _StarFieldPainter(
                      animation: _glowController.value,
                      accentColor: accentColor,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            ),
          ),
          // Floating blurred orbs
          Positioned(
            top: MediaQuery.of(context).padding.top + 120,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.22),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 260,
            left: -50,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (_isFriendMode ? AppTheme.friendAccentLight : AppTheme.cpAccentLight).withValues(alpha: 0.18),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          // Content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildTopBar(),
                _isFriendMode ? _friendStatus(friend) : _cpStatus(cp),
                const SizedBox(height: 6),
                _buildTabs(),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 30,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: PageView.builder(
                          key: ValueKey('pageview_$_isFriendMode'),
                          controller: _pageController,
                          itemCount: _tabNames.length,
                          onPageChanged: (i) {
                            if (_selectedTab != i) setState(() => _selectedTab = i);
                          },
                          itemBuilder:
                              (context, index) => _buildPage(_tabNames[index]),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Top bar — back, CP/Friend toggle pill, history
  // -------------------------------------------------------------------------
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          _iconBtn(Icons.arrow_back_rounded, () => context.pop()),
          const SizedBox(width: 8),
          // CP/Friend toggle pill
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _togglePill(
                  'CP',
                  Icons.favorite,
                  !_isFriendMode,
                  () => _switchMode(false),
                ),
                _togglePill(
                  'Friend',
                  Icons.people_alt,
                  _isFriendMode,
                  () => _switchMode(true),
                ),
              ],
            ),
          ),
          const Spacer(),
          _iconBtn(
            Icons.history_rounded,
            () => context.pushNamed(
              _isFriendMode ? AppRoutes.friendHistory : AppRoutes.cpHistory,
            ),
          ),
        ],
      ),
    );
  }

  Widget _togglePill(
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient:
              selected
                  ? (label == 'CP'
                      ? AppTheme.pinkGradient
                      : AppTheme.primaryGradient)
                  : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // CP status hero — premium glass card with couple avatars & stats
  // -------------------------------------------------------------------------
  Widget _cpStatus(CpProvider cp) {
    final myCP = cp.myCP;
    if (myCP == null) {
      return _emptyStatus(
        icon: Icons.favorite_outline,
        title: 'No CP Yet',
        subtitle: 'Find your perfect match in the Invite tab!',
      );
    }
    return GestureDetector(
      onTap: () {
        if (myCP.id != null && myCP.id!.isNotEmpty) {
          context.pushNamed(
            AppRoutes.cpDetail,
            extra: {'cpId': myCP.id!},
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: GlassCard(
          padding: const EdgeInsets.all(18),
          borderRadius: 28,
          borderColor: Colors.white.withValues(alpha: 0.12),
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          shadow: [
            BoxShadow(
              color: AppTheme.cpAccent.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // Glow halo
                  Container(
                    width: 160,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.cpAccent.withValues(alpha: 0.12),
                    ),
                  ),
                  Image.asset(
                    'assets/cp_friend/heart_tow.webp',
                    width: 130,
                    height: 80,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  CoupleAvatarPair(
                    user1: myCP.user1,
                    user2: myCP.user2,
                    size: 64,
                    overlap: 24,
                    showHeart: true,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ShaderMask(
                shaderCallback: (bounds) => AppTheme.pinkGradient.createShader(bounds),
                child: Text(
                  myCP.title ?? '${myCP.user1?.name ?? ''} & ${myCP.user2?.name ?? ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _statChip(
                    icon: Icons.favorite,
                    label: 'Lv.${myCP.level}',
                    color: AppTheme.cpAccent,
                  ),
                  const SizedBox(width: 10),
                  _statChip(
                    icon: Icons.calendar_today_rounded,
                    label: '${myCP.daysTogether} days',
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 10),
                  _statChip(
                    icon: Icons.favorite,
                    label: formatCount(myCP.intimacy),
                    color: AppTheme.cpAccent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Friend status hero — premium glass card with friends strip & slots
  // -------------------------------------------------------------------------
  Widget _friendStatus(FriendProvider friend) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        borderRadius: 28,
        borderColor: Colors.white.withValues(alpha: 0.12),
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        shadow: [
          BoxShadow(
            color: AppTheme.friendAccent.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
        child: Column(
          children: [
            if (friend.friends.isEmpty)
              _emptyStatus(
                icon: Icons.people_outline,
                title: 'No Friends Yet',
                subtitle: 'Find new friends in the Invite tab!',
              )
            else ...[
              SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  itemCount: friend.friends.length > 6 ? 6 : friend.friends.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final f = friend.friends[i];
                    return GestureDetector(
                      onTap: () {
                        if (f.id != null && f.id!.isNotEmpty) {
                          context.pushNamed(
                            AppRoutes.friendDetail,
                            extra: {'friendshipId': f.id!},
                          );
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _friendAvatar(f.partner?.image),
                          const SizedBox(height: 6),
                          Text(
                            (f.partner?.name ?? 'Friend').split(' ').first,
                            style: const TextStyle(color: Colors.white70, fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _statChip(
                    icon: Icons.people_alt,
                    label: 'Friends ${friend.friendCount}/${FriendProvider.maxFriends}',
                    color: AppTheme.friendAccent,
                  ),
                  const SizedBox(width: 10),
                  _statChip(
                    icon: Icons.add_circle_outline,
                    label: '${friend.availableSlots} slots left',
                    color: Colors.white70,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _friendAvatar(String? image) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppTheme.friendAccent, AppTheme.friendAccentLight],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.friendAccent.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.5),
        child: CircleAvatar(
          backgroundColor: AppTheme.cpDarkSurfaceLight,
          backgroundImage: image?.isNotEmpty == true ? CachedNetworkImageProvider(image!) : null,
          child: image?.isNotEmpty != true ? const Icon(Icons.person, color: Colors.white54) : null,
        ),
      ),
    );
  }

  Widget _statChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _emptyStatus({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
              boxShadow: [
                BoxShadow(color: Colors.white.withValues(alpha: 0.1), blurRadius: 20),
              ],
            ),
            child: Icon(icon, color: Colors.white54, size: 32),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Tab bar — premium glass capsule bar with animated active glow
  // -------------------------------------------------------------------------
  Widget _buildTabs() {
    final tabs = _tabNames;
    final icons = _tabIcons;
    final accentColor = _isFriendMode ? AppTheme.friendAccent : AppTheme.cpAccent;
    final gradient = _isFriendMode ? AppTheme.friendHeaderGradient : AppTheme.cpHeaderGradient;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (_, i) {
          final selected = _selectedTab == i;
          return GestureDetector(
            onTap: () => _onTabSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutQuart,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                gradient: selected ? gradient : null,
                color: selected ? null : AppTheme.cpDarkCard.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: selected ? Colors.white.withValues(alpha: 0.25) : accentColor.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(color: accentColor.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 5)),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icons[i], size: 15, color: selected ? Colors.white : accentColor),
                  const SizedBox(width: 6),
                  Text(
                    tabs[i],
                    style: TextStyle(
                      color: selected ? Colors.white : accentColor,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Page builder
  // -------------------------------------------------------------------------
  Widget _buildPage(String tabName) {
    switch (tabName) {
      case 'Privileges':
        return _PrivilegesContent(
          key: const ValueKey('privileges'),
          isFriend: _isFriendMode,
          selectedLevel: _selectedLevel,
          onLevelChange: (l) => setState(() => _selectedLevel = l),
        );
      case 'Rings':
        final cp = context.read<CpProvider>();
        final cpId = cp.myCP?.id ?? '';
        return cpId.isEmpty
            ? const DarkEmptyState(
              key: ValueKey('ring_empty'),
              icon: Icons.diamond_outlined,
              title: 'You don\'t have any rings yet',
              subtitle: 'Become a couple to unlock rings!',
            )
            : _RingGalleryContent(
              key: const ValueKey('ring_gallery'),
              cpId: cpId,
            );
      case 'Rules':
        return _RulesContent(
          key: const ValueKey('rules'),
          isFriend: _isFriendMode,
        );
      case 'Requests':
        return _isFriendMode
            ? _FriendRequestsContent(
              key: const ValueKey('friend_requests'),
              onRefresh: _loadAll,
            )
            : _CPRequestsContent(
              key: const ValueKey('cp_requests'),
              onRefresh: _loadAll,
            );
      case 'Ranking':
        return _isFriendMode
            ? const _FriendRankingContent(key: ValueKey('friend_ranking'))
            : const _CPRankingContent(key: ValueKey('cp_ranking'));
      case 'Invite':
        return _isFriendMode
            ? _FriendInviteContent(
              key: const ValueKey('friend_invite'),
              onRefresh: _loadAll,
            )
            : _CPInviteContent(
              key: const ValueKey('cp_invite'),
              onRefresh: _loadAll,
            );
      default:
        return const SizedBox();
    }
  }
}

// ===========================================================================
// Privileges content — level selector + privilege grid (dark theme)
// ===========================================================================
class _PrivilegesContent extends StatelessWidget {
  const _PrivilegesContent({
    super.key,
    required this.isFriend,
    required this.selectedLevel,
    required this.onLevelChange,
  });
  final bool isFriend;
  final int selectedLevel;
  final ValueChanged<int> onLevelChange;

  @override
  Widget build(BuildContext context) {
    final gradient =
        isFriend ? AppTheme.primaryGradient : AppTheme.pinkGradient;
    final accentColor = isFriend ? AppTheme.friendAccent : AppTheme.cpAccent;
    final myLevel = isFriend
        ? context.watch<FriendProvider>().maxFriendLevel
        : context.watch<CpProvider>().myCP?.level ?? 1;

    final cpLevels = context.watch<CpProvider>().levels;
    final friendLevels = context.watch<FriendProvider>().levels;
    final levels =
        isFriend ? friendLevels as List<dynamic> : cpLevels as List<dynamic>;
    final hasApiLevels = levels.isNotEmpty;

    dynamic selectedLevelData;
    if (hasApiLevels) {
      selectedLevelData = levels.cast<dynamic>().firstWhere(
        (dynamic l) => (l as dynamic).level == selectedLevel,
        orElse: () => levels.first,
      );
    }

    final privilegeItems = _getLevelPrivilegeItems(selectedLevelData);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Level selector strip
        SizedBox(
          height: 68,
          child:
              hasApiLevels
                  ? ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: levels.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final level = levels[i] as dynamic;
                      final lvl = (level.level as int?) ?? (i + 1);
                      final isSelected = selectedLevel == lvl;
                      final isUnlocked = myLevel >= lvl;
                      final levelIcon =
                          isFriend
                              ? (level as FriendLevel).levelBadgeUrl ??
                                  level.icon
                              : (level as CPLevel).levelIcon ??
                                  level.levelBadgeUrl ??
                                  level.badge;
                      return GestureDetector(
                        onTap: () => onLevelChange(lvl),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 60,
                          decoration: BoxDecoration(
                            gradient: isSelected ? gradient : null,
                            color:
                                isSelected
                                    ? null
                                    : (isUnlocked
                                        ? AppTheme.cpDarkSurfaceLight
                                        : AppTheme.cpDarkSurface),
                            borderRadius: BorderRadius.circular(16),
                            border:
                                isSelected
                                    ? Border.all(
                                      color: accentColor.withValues(alpha: 0.5),
                                      width: 1.5,
                                    )
                                    : Border.all(
                                      color: Colors.transparent,
                                      width: 1,
                                    ),
                            boxShadow:
                                isSelected
                                    ? [
                                      BoxShadow(
                                        color: accentColor.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                    : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (levelIcon != null && levelIcon.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: _buildImageFromUrl(
                                    levelIcon,
                                    width: 28,
                                    height: 28,
                                  ),
                                )
                              else
                                Text(
                                  'Lv.$lvl',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : (isUnlocked
                                                ? accentColor
                                                : AppTheme.cpDarkTextTertiary),
                                  ),
                                ),
                              const SizedBox(height: 2),
                              Text(
                                '$lvl',
                                style: TextStyle(
                                  fontSize: 10,
                                  color:
                                      isSelected
                                          ? Colors.white70
                                          : AppTheme.cpDarkTextTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                  : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.layers_outlined,
                          size: 36,
                          color: accentColor.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'No levels available',
                          style: TextStyle(
                            color: AppTheme.cpDarkTextSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
        ),
        const SizedBox(height: 16),
        if (privilegeItems.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                ImageIcon(const AssetImage("assets/gift/official_gift.png"), color: accentColor.withValues(alpha: 0.3), size: 48),
                const SizedBox(height: 12),
                const Text(
                  'No privileges for this level',
                  style: TextStyle(
                    color: AppTheme.cpDarkTextSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.95,
            ),
            itemCount: privilegeItems.length,
            itemBuilder: (_, i) {
              final p = privilegeItems[i];
              final isUnlocked = myLevel >= selectedLevel;
              return _PrivilegeCard(
                icon: p.icon,
                name: p.name,
                desc: p.description,
                unlocked: isUnlocked,
                gradient: gradient,
                accentColor: accentColor,
              );
            },
          ),
      ],
    );
  }

  List<_PrivilegeDisplayData> _getLevelPrivilegeItems(dynamic levelData) {
    if (levelData == null) return [];
    if (isFriend) {
      final items = (levelData as FriendLevel).privilegeItems;
      if (items.isEmpty) return [];
      return items.map<_PrivilegeDisplayData>((FriendPrivilegeItem item) {
        return _PrivilegeDisplayData(
          name: item.name ?? 'Privilege',
          description: item.description ?? '',
          icon: _iconForType(item.type),
          type: item.type,
        );
      }).toList();
    } else {
      final items = (levelData as CPLevel).privilegeItems;
      if (items.isEmpty) return [];
      return items.map<_PrivilegeDisplayData>((CPPrivilegeItem item) {
        return _PrivilegeDisplayData(
          name: item.name ?? 'Privilege',
          description: item.description ?? '',
          icon: _iconForType(item.type),
          type: item.type,
        );
      }).toList();
    }
  }
}

class _PrivilegeDisplayData {
  final String name;
  final String description;
  final IconData icon;
  final String? type;
  _PrivilegeDisplayData({
    required this.name,
    required this.description,
    required this.icon,
    this.type,
  });
}

IconData _iconForType(String? type) {
  switch (type) {
    case 'broadcast':
      return Icons.campaign_outlined;
    case 'frame':
      return Icons.crop_free;
    case 'ring':
      return Icons.diamond_outlined;
    case 'emoji':
      return Icons.emoji_emotions_outlined;
    case 'background':
      return Icons.person_outline;
    case 'gift':
      return Icons.card_giftcard_outlined;
    case 'medal':
      return Icons.military_tech_outlined;
    default:
      return Icons.card_giftcard_outlined;
  }
}

Widget _buildImageFromUrl(String url, {double? width, double? height}) {
  if (url.isEmpty) {
    return Icon(
      Icons.image_not_supported,
      size: width,
      color: AppTheme.cpDarkTextTertiary,
    );
  }
  if (url.toLowerCase().endsWith('.svg')) {
    return SvgPicture.network(
      url,
      width: width,
      height: height,
      placeholderBuilder:
          (_) => Icon(
            Icons.image,
            size: width,
            color: AppTheme.cpDarkTextTertiary,
          ),
    );
  }
  return CachedNetworkImage(
    imageUrl: url,
    width: width,
    height: height,
    fit: BoxFit.contain,
    placeholder:
        (_, __) =>
            Icon(Icons.image, size: width, color: AppTheme.cpDarkTextTertiary),
    errorWidget:
        (_, __, ___) =>
            Icon(Icons.image, size: width, color: AppTheme.cpDarkTextTertiary),
  );
}

// ===========================================================================
// Privilege card — dark glassmorphism with gradient icon circle
// ===========================================================================
class _PrivilegeCard extends StatelessWidget {
  const _PrivilegeCard({
    required this.icon,
    required this.name,
    required this.desc,
    required this.unlocked,
    required this.gradient,
    required this.accentColor,
  });
  final IconData icon;
  final String name;
  final String desc;
  final bool unlocked;
  final Gradient gradient;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: unlocked ? AppTheme.cpDarkCard : AppTheme.cpDarkSurface,
        border: Border.all(
          color:
              unlocked
                  ? accentColor.withValues(alpha: 0.25)
                  : AppTheme.cpDarkBorder,
          width: 1,
        ),
        boxShadow:
            unlocked
                ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
                : null,
      ),
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: unlocked ? gradient : null,
                  color: unlocked ? null : AppTheme.cpDarkSurfaceLight,
                  shape: BoxShape.circle,
                  boxShadow:
                      unlocked
                          ? [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                          : null,
                ),
                child: Icon(
                  unlocked ? icon : Icons.lock_outline,
                  color: unlocked ? Colors.white : AppTheme.cpDarkTextTertiary,
                  size: 26,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      unlocked
                          ? AppTheme.cpDarkText
                          : AppTheme.cpDarkTextTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  desc,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color:
                        unlocked
                            ? AppTheme.cpDarkTextSecondary
                            : AppTheme.cpDarkTextTertiary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (!unlocked)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppTheme.cpDarkSurfaceLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock,
                  size: 12,
                  color: AppTheme.cpDarkTextTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Ring Gallery content (dark theme)
// ===========================================================================
class _RingGalleryContent extends StatefulWidget {
  const _RingGalleryContent({super.key, required this.cpId});
  final String cpId;

  @override
  State<_RingGalleryContent> createState() => _RingGalleryContentState();
}

class _RingGalleryContentState extends State<_RingGalleryContent> {
  @override
  void initState() {
    super.initState();
    context.read<CpProvider>().loadRings(widget.cpId);
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CpProvider>();
    final rings = cp.rings;
    final myLevel = cp.myCP?.level ?? 1;

    if (rings.isEmpty) {
      return const DarkEmptyState(
        icon: Icons.diamond_outlined,
        title: 'You don\'t have any rings yet',
        subtitle: 'Level up your CP bond to unlock beautiful couple rings!',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemCount: rings.length,
      itemBuilder: (_, i) {
        final ring = rings[i];
        final locked = !ring.isUnlocked && myLevel < ring.unlockLevel;
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.cpDarkCard,
            borderRadius: BorderRadius.circular(22),
            border:
                ring.isEquipped
                    ? Border.all(color: AppTheme.cpAccent, width: 2)
                    : Border.all(color: AppTheme.cpDarkBorder, width: 1),
            boxShadow:
                ring.isEquipped
                    ? [
                      BoxShadow(
                        color: AppTheme.cpAccent.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : null,
          ),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.topLeft,
                  children: [
                    Center(
                      child: Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient:
                              locked
                                  ? null
                                  : LinearGradient(
                                    colors:
                                        AppTheme.pinkGradient.colors
                                            .map(
                                              (c) => c.withValues(alpha: 0.15),
                                            )
                                            .toList(),
                                  ),
                          color: locked ? AppTheme.cpDarkSurface : null,
                          boxShadow:
                              locked
                                  ? null
                                  : [
                                    BoxShadow(
                                      color: AppTheme.cpAccent.withValues(
                                        alpha: 0.25,
                                      ),
                                      blurRadius: 10,
                                    ),
                                  ],
                        ),
                        child:
                            ring.image != null &&
                                    ring.image!.isNotEmpty &&
                                    !locked
                                ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: ring.image!,
                                    fit: BoxFit.cover,
                                    placeholder:
                                        (_, __) => const Icon(
                                          Icons.diamond,
                                          size: 34,
                                          color: AppTheme.cpAccent,
                                        ),
                                    errorWidget:
                                        (_, __, ___) => const Icon(
                                          Icons.diamond,
                                          size: 34,
                                          color: AppTheme.cpAccent,
                                        ),
                                  ),
                                )
                                : Icon(
                                  locked ? Icons.lock_outline : Icons.diamond,
                                  size: 34,
                                  color:
                                      locked
                                          ? AppTheme.cpDarkTextTertiary
                                          : AppTheme.cpAccent,
                                ),
                      ),
                    ),
                    if (ring.isEquipped)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: const BoxDecoration(
                            gradient: AppTheme.pinkGradient,
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          child: const Text(
                            'EQUIPPED',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    if (locked)
                      Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.cpDarkSurfaceLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Lv.${ring.unlockLevel}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.cpDarkTextTertiary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  children: [
                    Text(
                      ring.name ?? 'Ring',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.cpDarkText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    if (ring.isEquipped)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: AppTheme.green,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Equipped',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (ring.isUnlocked)
                      GestureDetector(
                        onTap:
                            () => context.read<CpProvider>().equipRing(
                              cpId: widget.cpId,
                              ringId: ring.id ?? '',
                              userId: context.read<SessionManager>().userId,
                            ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppTheme.pinkGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Equip',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        'Lv.${ring.unlockLevel} to unlock',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.cpDarkTextTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===========================================================================
// Rules content (dark theme)
// ===========================================================================
class _RulesContent extends StatelessWidget {
  const _RulesContent({super.key, required this.isFriend});
  final bool isFriend;

  @override
  Widget build(BuildContext context) {
    final accentColor = isFriend ? AppTheme.friendAccent : AppTheme.cpAccent;
    final gradient =
        isFriend ? AppTheme.primaryGradient : AppTheme.pinkGradient;
    final rules =
        isFriend
            ? [
              'Friend system allows you to have up to 9 friends.',
              'Earn intimacy by gifting and co-streaming.',
              'Higher bond levels unlock privileges.',
              'Costs 600,000 Diamonds to bind.',
            ]
            : [
              'CP system is for exclusive partners.',
              'Earn intimacy through shared activities.',
              'Unlock rings and special badges.',
              'Costs 1,000,000 Diamonds to bind.',
            ];

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: rules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, i) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cpDarkCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: gradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  rules[i],
                  style: const TextStyle(
                    color: AppTheme.cpDarkTextSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===========================================================================
// CP Requests content (dark theme)
// ===========================================================================
class _CPRequestsContent extends StatelessWidget {
  const _CPRequestsContent({super.key, required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CpProvider>();
    final requests = cp.incomingRequests;
    final session = context.read<SessionManager>();

    if (requests.isEmpty) {
      return const DarkEmptyState(
        icon: Icons.mark_email_unread_outlined,
        title: 'No pending CP requests',
        subtitle: 'Invite someone to become your CP!',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (_, i) {
          final r = requests[i];
          final user = r.fromUser;
          return _RequestRow(
            user: user,
            onAccept: () async {
              final res = await cp.acceptRequest(
                requestId: r.id ?? '',
                userId: session.userId,
              );
              Fluttertoast.showToast(
                msg: res.ok
                    ? 'Request accepted!'
                    : (res.message ?? 'Failed to accept request'),
              );
            },
            onReject: () async {
              final ok = await cp.rejectRequest(
                requestId: r.id ?? '',
                userId: session.userId,
              );
              if (ok) Fluttertoast.showToast(msg: 'Request rejected');
            },
            accentColor: AppTheme.cpAccent,
          );
        },
      ),
    );
  }
}

// ===========================================================================
// Friend Requests content (dark theme)
// ===========================================================================
class _FriendRequestsContent extends StatelessWidget {
  const _FriendRequestsContent({super.key, required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final friend = context.watch<FriendProvider>();
    final requests = friend.incomingRequests;
    final session = context.read<SessionManager>();

    if (requests.isEmpty) {
      return const DarkEmptyState(
        icon: Icons.people_outline,
        title: 'No pending friend requests',
        subtitle: 'Find new friends in the community!',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (_, i) {
          final r = requests[i];
          final user = r.fromUser;
          return _RequestRow(
            user: user,
            onAccept: () async {
              final res = await friend.acceptRequest(
                requestId: r.id ?? '',
                userId: session.userId,
              );
              Fluttertoast.showToast(
                msg: res.ok
                    ? 'Request accepted!'
                    : (res.message ?? 'Failed to accept request'),
              );
            },
            onReject: () async {
              final ok = await friend.rejectRequest(
                requestId: r.id ?? '',
                userId: session.userId,
              );
              if (ok) Fluttertoast.showToast(msg: 'Request rejected');
            },
            accentColor: AppTheme.friendAccent,
          );
        },
      ),
    );
  }
}

// ===========================================================================
// Request row — dark card with avatar + name + accept/reject buttons
// ===========================================================================
class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.user,
    required this.onAccept,
    required this.onReject,
    required this.accentColor,
  });
  final dynamic user;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cpDarkCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withValues(alpha: 0.6)],
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(2.5),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.cpDarkSurfaceLight,
                backgroundImage:
                    user?.image != null
                        ? CachedNetworkImageProvider(user!.image!)
                        : null,
                child:
                    user?.image == null
                        ? const Icon(Icons.person, color: Colors.white54)
                        : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user?.name ?? 'Unknown User',
              style: const TextStyle(
                color: AppTheme.cpDarkText,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onReject,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppTheme.cpDarkSurfaceLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: AppTheme.cpDarkTextSecondary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onAccept,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor, accentColor.withValues(alpha: 0.7)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// CP Ranking content (dark theme)
// ===========================================================================
class _CPRankingContent extends StatefulWidget {
  const _CPRankingContent({super.key});

  @override
  State<_CPRankingContent> createState() => _CPRankingContentState();
}

class _CPRankingContentState extends State<_CPRankingContent> {
  @override
  void initState() {
    super.initState();
    context.read<CpProvider>().loadRanking();
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CpProvider>();
    final items = cp.ranking;

    if (items.isEmpty) {
      return const DarkEmptyState(
        icon: Icons.emoji_events_outlined,
        title: 'No ranking data yet',
        subtitle: 'Start earning intimacy to top the leaderboards!',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return _RankingRow(
          rank: i + 1,
          name: item.cp?.title ?? 'Couple',
          value: formatCount(item.intimacy),
          accentColor: AppTheme.cpAccent,
        );
      },
    );
  }
}

// ===========================================================================
// Friend Ranking content (dark theme)
// ===========================================================================
class _FriendRankingContent extends StatefulWidget {
  const _FriendRankingContent({super.key});

  @override
  State<_FriendRankingContent> createState() => _FriendRankingContentState();
}

class _FriendRankingContentState extends State<_FriendRankingContent> {
  @override
  void initState() {
    super.initState();
    context.read<FriendProvider>().loadRanking();
  }

  @override
  Widget build(BuildContext context) {
    final friend = context.watch<FriendProvider>();
    final items = friend.ranking;

    if (items.isEmpty) {
      return const DarkEmptyState(
        icon: Icons.emoji_events_outlined,
        title: 'No ranking data yet',
        subtitle: 'Start earning intimacy with your friends!',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return _RankingRow(
          rank: i + 1,
          name: item.friend?.partner?.name ?? 'Friend',
          value: formatCount(item.intimacy),
          accentColor: AppTheme.friendAccent,
        );
      },
    );
  }
}

// ===========================================================================
// Ranking row — dark card with rank number + name + intimacy value
// ===========================================================================
class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.rank,
    required this.name,
    required this.value,
    required this.accentColor,
  });
  final int rank;
  final String name;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final rankColor =
        rank == 1
            ? AppTheme.rankGold
            : (rank == 2
                ? AppTheme.rankSilver
                : (rank == 3
                    ? AppTheme.rankBronze
                    : AppTheme.cpDarkTextTertiary));
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cpDarkCard,
        borderRadius: BorderRadius.circular(18),
        border:
            isTop3
                ? Border.all(
                  color: rankColor.withValues(alpha: 0.3),
                  width: 1.2,
                )
                : Border.all(color: AppTheme.cpDarkBorder, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient:
                  isTop3
                      ? LinearGradient(
                        colors: [rankColor, rankColor.withValues(alpha: 0.6)],
                      )
                      : null,
              color: isTop3 ? null : AppTheme.cpDarkSurfaceLight,
              shape: BoxShape.circle,
              boxShadow:
                  isTop3
                      ? [
                        BoxShadow(
                          color: rankColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : null,
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: isTop3 ? Colors.white : AppTheme.cpDarkTextSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: AppTheme.cpDarkText,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              Icon(Icons.favorite, size: 12, color: accentColor),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// CP Invite content — discover with filters (dark theme)
// ===========================================================================
class _CPInviteContent extends StatefulWidget {
  const _CPInviteContent({super.key, required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  State<_CPInviteContent> createState() => _CPInviteContentState();
}

class _CPInviteContentState extends State<_CPInviteContent> {
  String? _gender;
  String? _region;
  bool _onlineOnly = false;
  int _minLevel = 0;

  @override
  void initState() {
    super.initState();
    _applyFilters();
  }

  Future<void> _applyFilters() async {
    final session = context.read<SessionManager>();
    final cp = context.read<CpProvider>();
    await cp.loadDiscover(
      session.userId,
      gender: _gender,
      region: _region,
      onlineOnly: _onlineOnly ? true : null,
      minLevel: _minLevel > 0 ? _minLevel : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CpProvider>();
    final list = cp.discover;
    final session = context.read<SessionManager>();

    return Column(
      children: [
        _DiscoverFilterBar(
          gender: _gender,
          region: _region,
          onlineOnly: _onlineOnly,
          minLevel: _minLevel,
          onGenderChanged: (v) => setState(() => _gender = v),
          onRegionChanged: (v) => setState(() => _region = v),
          onOnlineChanged: (v) => setState(() => _onlineOnly = v),
          onMinLevelChanged: (v) => setState(() => _minLevel = v),
          onApply: _applyFilters,
          accentColor: AppTheme.cpAccent,
        ),
        Expanded(
          child:
              list.isEmpty
                  ? const DarkEmptyState(
                    icon: Icons.person_search_outlined,
                    title: 'No users found',
                    subtitle:
                        'Try adjusting your filters to find your perfect match!',
                  )
                  : RefreshIndicator(
                    onRefresh: () async => _applyFilters(),
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.78,
                          ),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final user = list[i].fromUser;
                        return _InviteCard(
                          user: user,
                          accentColor: AppTheme.cpAccent,
                          onInvite: () async {
                            final res = await cp.sendRequest(
                              fromUserId: session.userId,
                              toUserId: user?.id ?? '',
                            );
                            Fluttertoast.showToast(
                              msg: res.ok
                                  ? 'Invite sent!'
                                  : (res.message ?? 'Failed to send invite'),
                            );
                          },
                        );
                      },
                    ),
                  ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Friend Invite content — discover with filters (dark theme)
// ===========================================================================
class _FriendInviteContent extends StatefulWidget {
  const _FriendInviteContent({super.key, required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  State<_FriendInviteContent> createState() => _FriendInviteContentState();
}

class _FriendInviteContentState extends State<_FriendInviteContent> {
  String? _gender;
  String? _region;
  bool _onlineOnly = false;
  int _minLevel = 0;

  @override
  void initState() {
    super.initState();
    _applyFilters();
  }

  Future<void> _applyFilters() async {
    final session = context.read<SessionManager>();
    final friend = context.read<FriendProvider>();
    await friend.loadDiscover(
      session.userId,
      gender: _gender,
      region: _region,
      onlineOnly: _onlineOnly ? true : null,
      minLevel: _minLevel > 0 ? _minLevel : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final friend = context.watch<FriendProvider>();
    final list = friend.discover;
    final session = context.read<SessionManager>();

    return Column(
      children: [
        _DiscoverFilterBar(
          gender: _gender,
          region: _region,
          onlineOnly: _onlineOnly,
          minLevel: _minLevel,
          onGenderChanged: (v) => setState(() => _gender = v),
          onRegionChanged: (v) => setState(() => _region = v),
          onOnlineChanged: (v) => setState(() => _onlineOnly = v),
          onMinLevelChanged: (v) => setState(() => _minLevel = v),
          onApply: _applyFilters,
          accentColor: AppTheme.friendAccent,
        ),
        Expanded(
          child:
              list.isEmpty
                  ? const DarkEmptyState(
                    icon: Icons.person_search_outlined,
                    title: 'No users found',
                    subtitle: 'Try adjusting your filters to find new friends!',
                  )
                  : RefreshIndicator(
                    onRefresh: () async => _applyFilters(),
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.78,
                          ),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final user = list[i].fromUser;
                        return _InviteCard(
                          user: user,
                          accentColor: AppTheme.friendAccent,
                          onInvite: () async {
                            final res = await friend.sendRequest(
                              fromUserId: session.userId,
                              toUserId: user?.id ?? '',
                            );
                            Fluttertoast.showToast(
                              msg: res.ok
                                  ? 'Invite sent!'
                                  : (res.message ?? 'Failed to send invite'),
                            );
                          },
                        );
                      },
                    ),
                  ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Discover filter bar — Bigo-style dark filter chips
// ===========================================================================
class _DiscoverFilterBar extends StatelessWidget {
  const _DiscoverFilterBar({
    required this.gender,
    required this.region,
    required this.onlineOnly,
    required this.minLevel,
    required this.onGenderChanged,
    required this.onRegionChanged,
    required this.onOnlineChanged,
    required this.onMinLevelChanged,
    required this.onApply,
    required this.accentColor,
  });

  final String? gender;
  final String? region;
  final bool onlineOnly;
  final int minLevel;
  final ValueChanged<String?> onGenderChanged;
  final ValueChanged<String?> onRegionChanged;
  final ValueChanged<bool> onOnlineChanged;
  final ValueChanged<int> onMinLevelChanged;
  final VoidCallback onApply;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.cpDarkSurface,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          _filterChip(
            label:
                gender == null
                    ? 'Gender'
                    : (gender == 'male' ? 'Male' : 'Female'),
            selected: gender != null,
            onTap: () {
              if (gender == null) {
                onGenderChanged('female');
              } else if (gender == 'female') {
                onGenderChanged('male');
              } else {
                onGenderChanged(null);
              }
              onApply();
            },
          ),
          _filterChip(
            label: region == null ? 'Region' : region!,
            selected: region != null,
            onTap: () {
              const regions = ['IN', 'US', 'ID', 'PK', 'BD', 'EG'];
              final idx = regions.indexOf(region ?? '');
              onRegionChanged(
                idx < regions.length - 1 ? regions[idx + 1] : null,
              );
              onApply();
            },
          ),
          _filterChip(
            label: 'Online',
            selected: onlineOnly,
            onTap: () {
              onOnlineChanged(!onlineOnly);
              onApply();
            },
          ),
          _filterChip(
            label: minLevel > 0 ? 'Lv+$minLevel' : 'Any Level',
            selected: minLevel > 0,
            onTap: () {
              onMinLevelChanged(minLevel < 5 ? minLevel + 1 : 0);
              onApply();
            },
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient:
              selected
                  ? LinearGradient(
                    colors: [accentColor, accentColor.withValues(alpha: 0.7)],
                  )
                  : null,
          color: selected ? null : AppTheme.cpDarkCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                selected
                    ? Colors.transparent
                    : accentColor.withValues(alpha: 0.2),
          ),
          boxShadow:
              selected
                  ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : accentColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Invite card — dark card with avatar + name + invite button (grid layout)
// ===========================================================================
class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.user,
    required this.accentColor,
    required this.onInvite,
  });
  final dynamic user;
  final Color accentColor;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cpDarkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.topLeft,
              children: [
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          accentColor,
                          accentColor.withValues(alpha: 0.5),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(2.5),
                      child: CircleAvatar(
                        radius: 38,
                        backgroundColor: AppTheme.cpDarkSurfaceLight,
                        backgroundImage:
                            (user?.image != null && user!.image!.isNotEmpty)
                                ? CachedNetworkImageProvider(user!.image!)
                                : null,
                        child:
                            (user?.image == null || user!.image!.isEmpty)
                                ? const Icon(
                                  Icons.person,
                                  size: 36,
                                  color: Colors.white54,
                                )
                                : null,
                      ),
                    ),
                  ),
                ),
                if (user?.isLive == true)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppTheme.pinkGradient,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (user?.isOnline == true)
                  Positioned(
                    bottom: 8,
                    right: 30,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.green,
                        border: Border.all(
                          color: AppTheme.cpDarkCard,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            child: Column(
              children: [
                Text(
                  user?.name ?? 'Unknown',
                  style: const TextStyle(
                    color: AppTheme.cpDarkText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onInvite,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor,
                          accentColor.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Invite',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Twinkling star-field background for CP/Friend hub
// ===========================================================================
class _StarFieldPainter extends CustomPainter {
  _StarFieldPainter({required this.animation, required this.accentColor});

  final double animation;
  final Color accentColor;

  static List<_Star>? _stars;
  static Size? _lastSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (_stars == null || _lastSize != size) {
      _lastSize = size;
      final random = Random(42);
      final count = ((size.width * size.height) / 4500).clamp(30, 90).toInt();
      _stars = List<_Star>.generate(
        count,
        (i) => _Star(
          x: random.nextDouble() * size.width,
          y: random.nextDouble() * size.height,
          radius: random.nextDouble() * 1.4 + 0.4,
          phase: random.nextDouble() * pi * 2,
          speed: random.nextDouble() * 2 + 1,
        ),
      );
    }

    final paint = Paint()..strokeCap = StrokeCap.round;
    for (final star in _stars!) {
      final twinkle = 0.4 + 0.6 * sin(animation * pi * 2 * star.speed + star.phase);
      paint.color = accentColor.withValues(alpha: twinkle * 0.45);
      paint.strokeWidth = star.radius;
      canvas.drawCircle(Offset(star.x, star.y), star.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) => true;
}

class _Star {
  _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.phase,
    required this.speed,
  });

  final double x;
  final double y;
  final double radius;
  final double phase;
  final double speed;
}
