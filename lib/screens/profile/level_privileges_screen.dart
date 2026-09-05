import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/level_privilege_models.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

const String _tag = 'LevelPrivileges';

// ---- Colours matching the native screenshots exactly -------------------------
const Color _bg = Color(0xFF0E0E13);
const Color _cardBg = Color(0xFF1B1B26);
const Color _iconBg = Color(0xFF2A2A3A);
const Color _tabBg = Color(0xFF121218);
const Color _divider = Color(0xFF2A2A3A);
const Color _purple = Color(0xFF9B6BFF);
const Color _goldLight = Color(0xFFFFD54F);
const Color _gold = Color(0xFFFFB300);
const Color _goldDark = Color(0xFFBF8A00);
const Color _white = Colors.white;
const Color _white70 = Colors.white70;
const Color _white50 = Colors.white54;
const Color _white30 = Colors.white30;

class LevelPrivilegesScreen extends StatefulWidget {
  const LevelPrivilegesScreen({super.key});

  @override
  State<LevelPrivilegesScreen> createState() => _LevelPrivilegesScreenState();
}

class _LevelPrivilegesScreenState extends State<LevelPrivilegesScreen>
    with TickerProviderStateMixin {
  final List<LevelPrivilegesItem> _levels = [];
  UserLevelProgress? _progress;
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final session = context.read<SessionManager>();
      final user = session.getUser();
      final results = await Future.wait([
        ApiService.getLevelPrivileges(),
        ApiService.getUserLevelProgress(user?.id ?? ''),
      ]);
      final levels = (results[0] as LevelPrivilegesRoot).levels;
      final progress = (results[1] as UserLevelProgressRoot).data;

      if (mounted) {
        setState(() {
          _progress = progress;
          _levels.addAll(levels.isEmpty ? _sampleLevels : levels);
          _tabController.dispose();
          _tabController = TabController(
            length: _levels.length,
            vsync: this,
            initialIndex: _selectedInitialIndex(),
          );
        });
      }
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
      if (mounted) {
        setState(() {
          _levels.addAll(_sampleLevels);
          _tabController.dispose();
          _tabController = TabController(
            length: _levels.length,
            vsync: this,
            initialIndex: 0,
          );
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _selectedInitialIndex() {
    final current = _progress?.currentLevel ?? 0;
    final idx = _levels.indexWhere((l) => l.level == current);
    return idx < 0 ? 0 : idx;
  }

  static final List<LevelPrivilegesItem> _sampleLevels = [
    LevelPrivilegesItem(
      level: 1,
      name: 'Lv1',
      requiredBeans: 10000,
      privileges: [
        LevelPrivilege(id: 'entry_bar', title: 'Entry Bar', description: 'There will be a striking bar when you enter a room.'),
        LevelPrivilege(id: 'portrait_frame', title: 'Portrait Frame', description: 'Show your noble status everywhere.'),
        LevelPrivilege(id: 'privilege_sticker', title: 'Privilege Sticker', description: 'Exclusive amazing stickers for high level users!'),
        LevelPrivilege(id: 'mass_messages', title: 'Mass Messages Privilege', description: 'Send massive messages with online users to get more phone calls.'),
        LevelPrivilege(id: 'party_room', title: 'Party Room Privilege', description: 'Open the Party room to have real-time video/voice chat with guests.'),
      ],
    ),
    LevelPrivilegesItem(
      level: 2,
      name: 'Lv2',
      requiredBeans: 50000,
      privileges: [
        LevelPrivilege(id: 'portrait_frame', title: 'Portrait Frame', description: 'Show your noble status everywhere.'),
        LevelPrivilege(id: 'privilege_sticker', title: 'Privilege Sticker', description: 'Exclusive amazing stickers for high level users!'),
        LevelPrivilege(id: 'mass_messages', title: 'Mass Messages Privilege', description: 'Send massive messages with online users to get more phone calls.'),
        LevelPrivilege(id: 'party_room', title: 'Party Room Privilege', description: 'Open the Party room to have real-time video/voice chat with guests.'),
        LevelPrivilege(id: 'party_room_bg', title: 'Privilege Party Room Background', description: 'Unlock exclusive party room backgrounds.'),
      ],
    ),
    LevelPrivilegesItem(
      level: 3,
      name: 'Lv3',
      requiredBeans: 100000,
      privileges: [
        LevelPrivilege(id: 'entry_bar', title: 'Entry Bar', description: 'There will be a striking bar when you enter a room.'),
        LevelPrivilege(id: 'portrait_frame', title: 'Portrait Frame', description: 'Show your noble status everywhere.'),
        LevelPrivilege(id: 'privilege_sticker', title: 'Privilege Sticker', description: 'Exclusive amazing stickers for high level users!'),
        LevelPrivilege(id: 'mass_messages', title: 'Mass Messages Privilege', description: 'Send massive messages with online users to get more phone calls.'),
        LevelPrivilege(id: 'party_room', title: 'Party Room Privilege', description: 'Open the Party room to have real-time video/voice chat with guests.'),
      ],
    ),
    LevelPrivilegesItem(
      level: 4,
      name: 'Lv4',
      requiredBeans: 300000,
      privileges: [
        LevelPrivilege(id: 'entry_bar', title: 'Entry Bar', description: 'There will be a striking bar when you enter a room.'),
        LevelPrivilege(id: 'portrait_frame', title: 'Portrait Frame', description: 'Show your noble status everywhere.'),
        LevelPrivilege(id: 'privilege_sticker', title: 'Privilege Sticker', description: 'Exclusive amazing stickers for high level users!'),
        LevelPrivilege(id: 'mass_messages', title: 'Mass Messages Privilege', description: 'Send massive messages with online users to get more phone calls.'),
        LevelPrivilege(id: 'party_room', title: 'Party Room Privilege', description: 'Open the Party room to have real-time video/voice chat with guests.'),
      ],
    ),
    LevelPrivilegesItem(
      level: 5,
      name: 'Lv5',
      requiredBeans: 600000,
      privileges: [
        LevelPrivilege(id: 'entry_bar', title: 'Entry Bar', description: 'There will be a striking bar when you enter a room.'),
        LevelPrivilege(id: 'portrait_frame', title: 'Portrait Frame', description: 'Show your noble status everywhere.'),
        LevelPrivilege(id: 'privilege_sticker', title: 'Privilege Sticker', description: 'Exclusive amazing stickers for high level users!'),
        LevelPrivilege(id: 'mass_messages', title: 'Mass Messages Privilege', description: 'Send massive messages with online users to get more phone calls.'),
        LevelPrivilege(id: 'party_room', title: 'Party Room Privilege', description: 'Open the Party room to have real-time video/voice chat with guests.'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Level', style: TextStyle(color: _white, fontSize: 18, fontWeight: FontWeight.w700)),
        leading: const BackButton(color: _white),
      ),
      body: _loading
          ? const Center(child: Preloader(color: _purple))
          : Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(child: _buildTabBarView()),
              ],
            ),
    );
  }

  // ---- Header with golden level badge ---------------------------------------
  Widget _buildHeader() {
    final p = _progress ??
        UserLevelProgress(
          currentLevel: 1,
          currentBeans: 1000,
          nextLevel: 2,
          beansNeededForNext: 9000,
          lastMonthBeans: 0,
          thisMonthBeans: 1000,
          randomCallEarningPerMin: 0,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          // Level badge + info row
          Row(
            children: [
              _LevelBadge(level: p.currentLevel),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Level',
                      style: TextStyle(color: _white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Get ${_fmt(p.beansNeededForNext)} beans to level up',
                      style: const TextStyle(color: _white, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Last Month / This Month
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _beanStat('Last Month', p.lastMonthBeans),
                Container(width: 1, height: 36, color: _divider),
                _beanStat('This Month', p.thisMonthBeans),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _beanStat(String label, int value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: _white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          '${_fmt(value)} beans',
          style: const TextStyle(color: _white, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  // ---- Tab bar ---------------------------------------------------------------
  Widget _buildTabBar() {
    final currentLevel = _progress?.currentLevel ?? 1;
    return Container(
      color: _tabBg,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: _purple,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: _white,
        unselectedLabelColor: _white50,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        tabAlignment: TabAlignment.start,
        tabs: _levels.map((l) {
          final isCurrent = l.level == currentLevel;
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.name ?? 'Lv${l.level}'),
                if (isCurrent) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: _purple,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(fontSize: 9, color: _white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: _levels.map((l) => _buildPrivilegeList(l)).toList(),
    );
  }

  Widget _buildPrivilegeList(LevelPrivilegesItem level) {
    final currentLevel = _progress?.currentLevel ?? 1;
    final isCurrentLevel = level.level == currentLevel;
    final isLocked = level.level > currentLevel;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: level.privileges.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _PrivilegeCard(
        privilege: level.privileges[i],
        isActive: isCurrentLevel,
        isLocked: isLocked,
      ),
    );
  }

  String _fmt(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}

// ---- Level badge (golden hexagon with crown) ---------------------------------
class _LevelBadge extends StatelessWidget {
  final int level;

  const _LevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hexagon shape with golden gradient
          CustomPaint(
            size: const Size(80, 90),
            painter: _HexagonPainter(),
          ),
          // Crown icon at top
          const Positioned(
            top: 10,
            child: Icon(
              Icons.emoji_events,
              color: _goldLight,
              size: 22,
            ),
          ),
          // Level text
          Positioned(
            top: 38,
            child: Text(
              'Lv.$level',
              style: const TextStyle(
                color: _white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HexagonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    // Hexagon shield shape
    path.moveTo(w * 0.5, 0);          // top center
    path.lineTo(w, h * 0.25);          // top right
    path.lineTo(w * 0.85, h);          // bottom right
    path.lineTo(w * 0.15, h);          // bottom left
    path.lineTo(0, h * 0.25);          // top left
    path.close();

    // Golden gradient fill
    final rect = Rect.fromLTWH(0, 0, w, h);
    const gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _goldLight,
        _gold,
        _goldDark,
      ],
    );
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    // Inner darker hexagon
    final innerPath = Path();
    const inset = 3.0;
    innerPath.moveTo(w * 0.5, inset);
    innerPath.lineTo(w - inset, h * 0.25 + inset * 0.5);
    innerPath.lineTo(w * 0.85 - inset, h - inset);
    innerPath.lineTo(w * 0.15 + inset, h - inset);
    innerPath.lineTo(inset, h * 0.25 + inset * 0.5);
    innerPath.close();
    final innerPaint = Paint()
      ..color = _bg
      ..style = PaintingStyle.fill;
    canvas.drawPath(innerPath, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---- Privilege card -----------------------------------------------------------
class _PrivilegeCard extends StatelessWidget {
  final LevelPrivilege privilege;
  final bool isActive;
  final bool isLocked;

  const _PrivilegeCard({
    required this.privilege,
    this.isActive = false,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isLocked ? _white30 : _white;
    final descColor = isLocked ? _white30 : _white70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: isActive ? Border.all(color: _purple.withValues(alpha: 0.4), width: 1) : null,
      ),
      child: Row(
        children: [
          _buildIcon(privilege.iconUrl, privilege.id),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        privilege.title ?? '',
                        style: TextStyle(color: titleColor, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: _purple,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(fontSize: 9, color: _white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                    if (isLocked) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.lock, color: _white30, size: 14),
                    ],
                  ],
                ),
                if (privilege.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    privilege.description ?? '',
                    style: TextStyle(color: descColor, fontSize: 12, height: 1.3),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            isLocked ? Icons.lock_outline : Icons.chevron_right,
            color: _white30,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(String? url, String? id) {
    final iconColor = isLocked ? _white30 : _purple;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Opacity(
          opacity: isLocked ? 0.4 : 1.0,
          child: CachedNetworkImage(
            imageUrl: url,
            width: 46,
            height: 46,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _placeholderIcon(id, iconColor),
          ),
        ),
      );
    }
    return _placeholderIcon(id, iconColor);
  }

  Widget _placeholderIcon(String? id, Color iconColor) {
    final icon = _iconForPrivilege(id);
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: _iconBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: iconColor, size: 24),
    );
  }

  IconData _iconForPrivilege(String? id) {
    switch (id) {
      case 'entry_bar':
        return Icons.login;
      case 'portrait_frame':
        return Icons.account_circle;
      case 'privilege_sticker':
        return Icons.emoji_emotions;
      case 'mass_messages':
        return Icons.sms;
      case 'party_room':
        return Icons.groups;
      case 'party_room_bg':
        return Icons.wallpaper;
      default:
        return Icons.card_giftcard;
    }
  }
}
