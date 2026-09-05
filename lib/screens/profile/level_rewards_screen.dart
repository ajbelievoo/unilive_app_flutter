/// Level Rewards screen — premium per-level reward list.
///
/// Matches the native design: a header with the current level, a horizontal
/// level selector, and a vertical list of rewards for the selected level.
///
/// Rewards are loaded from `/level/rewards` (user) or `/hostLevel/rewards`
/// (host) and grouped by `level` number.
library level_rewards;

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/level_rewards_models.dart';
import '../../models/user_root.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../utils/log.dart';
import '../../widgets/store_widgets.dart';
import 'package:belive/widgets/preloader.dart';

const String _tag = 'LevelRewards';

// ---- Premium dark palette --------------------------------------------------
const Color _bg = Color(0xFF0A0A15);
const Color _cardBg = Color(0xFF151526);
const Color _cardBorder = Color(0xFF2A2A40);
const Color _gold = Color(0xFFFFB800);
const Color _goldLight = Color(0xFFFFD700);
const Color _cyan = Color(0xFF4ECDC4);
const Color _purple = Color(0xFF9B6BFF);
const Color _white = Colors.white;
const Color _white70 = Colors.white70;
const Color _white50 = Colors.white54;
const Color _white24 = Colors.white24;

class LevelRewardsScreen extends StatefulWidget {
  const LevelRewardsScreen({super.key, this.isHost = false});

  final bool isHost;

  @override
  State<LevelRewardsScreen> createState() => _LevelRewardsScreenState();
}

class _LevelRewardsScreenState extends State<LevelRewardsScreen> {
  final _groups = <LevelRewardGroup>[];
  bool _loading = true;
  int _selectedLevelIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (widget.isHost) {
        final res = await ApiService.getHostLevelRewards();
        if (res.status) _groups.addAll(res.data);
      } else {
        final res = await ApiService.getLevelRewards();
        if (res.status) _groups.addAll(res.data);
      }
      _selectInitialLevel();
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectInitialLevel() {
    // Pre-select the highest unlocked level for users, or the first for hosts.
    if (_groups.isEmpty) return;
    int idx = 0;
    for (int i = 0; i < _groups.length; i++) {
      if (!_isLevelLocked(i)) {
        idx = i;
      }
    }
    _selectedLevelIndex = idx;
  }

  bool _isLevelLocked(int index) {
    final session = context.read<SessionManager>();
    final user = session.getUser();
    final currentCoin = user?.coin.toInt() ?? 0;
    return _groups[index].coin > currentCoin;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionManager>();
    final user = session.getUser();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: Preloader(color: _gold))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: _gold,
                      backgroundColor: _cardBg,
                      child: _groups.isEmpty
                          ? const Center(
                              child: Text(
                                'No rewards available',
                                style: TextStyle(color: _white50),
                              ),
                            )
                          : _buildBody(user),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cardBorder),
            ),
            child: const BackButton(color: _white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${widget.isHost ? 'Host ' : ''}Level Rewards',
              style: const TextStyle(
                color: _white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(User? user) {
    final currentCoin = user?.coin.toInt() ?? 0;
    final selectedGroup = _groups[_selectedLevelIndex];
    final nextCoin = _nextLevelCoin(currentCoin);
    final beansNeeded = (nextCoin - currentCoin).clamp(0, double.infinity).toInt();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildCurrentLevelCard(selectedGroup, currentCoin, beansNeeded),
        const SizedBox(height: 20),
        _buildLevelTabs(),
        const SizedBox(height: 20),
        _buildRewardList(selectedGroup),
        const SizedBox(height: 24),
      ],
    );
  }

  // -------------------------------------------------------------------------
  //  Header card
  // -------------------------------------------------------------------------

  Widget _buildCurrentLevelCard(
      LevelRewardGroup current, int currentCoin, int beansNeeded) {
    final isLocked = current.coin > currentCoin;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_purple, Color(0xFF4F8DFD)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildLevelBadge(current.name ?? 'Lv.${current.level}'),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Level',
                      style: TextStyle(
                        color: _white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLocked
                          ? 'Reach ${current.coin} diamonds to unlock'
                          : 'Get $beansNeeded diamonds to level up',
                      style: const TextStyle(
                        color: _white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current diamonds',
                        style: TextStyle(
                          color: _white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$currentCoin',
                        style: const TextStyle(
                          color: _white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: _white24,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Next level',
                        style: TextStyle(
                          color: _white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$beansNeeded diamonds needed',
                        style: const TextStyle(
                          color: _white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

  Widget _buildLevelBadge(String label) {
    final text = label.contains('Lv')
        ? label
        : 'Lv.${label.replaceAll(RegExp(r'[^0-9]'), '')}';
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: _white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, color: _gold, size: 24),
          const SizedBox(height: 4),
          Text(
            text.length > 6 ? text.substring(0, 6) : text,
            style: const TextStyle(
              color: _white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  //  Level tabs
  // -------------------------------------------------------------------------

  Widget _buildLevelTabs() {
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _groups.length,
        itemBuilder: (context, i) {
          final isSelected = i == _selectedLevelIndex;
          final group = _groups[i];
          final isLocked = _isLevelLocked(i);
          return GestureDetector(
            onTap: () => setState(() => _selectedLevelIndex = i),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(colors: [_goldLight, _gold])
                    : null,
                color: isSelected ? null : _cardBg,
                borderRadius: BorderRadius.circular(21),
                border: isSelected
                    ? null
                    : Border.all(
                        color: isLocked ? _cardBorder : _white24,
                      ),
              ),
              child: Center(
                child: Text(
                  group.name ?? 'Lv.${group.level}',
                  style: TextStyle(
                    color: isSelected ? _bg : (isLocked ? _white50 : _white70),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  //  Reward list
  // -------------------------------------------------------------------------

  Widget _buildRewardList(LevelRewardGroup group) {
    if (group.rewards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'No rewards for ${group.name ?? 'this level'}',
            style: const TextStyle(color: _white50),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rewards · ${group.rewards.length}',
          style: const TextStyle(
            color: _white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        ...group.rewards.map((r) => _rewardRow(r)),
      ],
    );
  }

  Widget _rewardRow(LevelReward r) {
    final isLocked = r.isLocked;
    final isUsableUnlocked = !isLocked && r.isUsable;
    final iconData = _iconForType(r.type);
    final iconColor = _colorForType(r.type);

    return GestureDetector(
      onTap: () => _onRewardTap(r),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isUsableUnlocked ? _purple.withValues(alpha: 0.5) : _cardBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: _rewardIcon(r, iconData, iconColor),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.name ?? r.typeLabel,
                          style: TextStyle(
                            color: isLocked ? _white50 : _white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (isUsableUnlocked)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _gold,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Use',
                            style: TextStyle(
                              color: _bg,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      else if (!isLocked)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _purple,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              color: _white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _cardBorder,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Locked',
                            style: TextStyle(
                              color: _white50,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (r.description != null && r.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      r.description!,
                      style: TextStyle(
                        color: isLocked ? _white50.withValues(alpha: 0.7) : _white50,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isUsableUnlocked ? Icons.arrow_forward : (isLocked ? Icons.lock : Icons.chevron_right),
              color: isUsableUnlocked ? _gold : (isLocked ? _white24 : _white50),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  /// Handles tapping a reward row.
  /// Usable unlocked rewards (frame, custom id, background, opening, entrance)
  /// navigate to My Store so the user can equip the owned item.  Locked or
  /// informational rewards show a toast.
  void _onRewardTap(LevelReward r) {
    if (r.isLocked) {
      Fluttertoast.showToast(msg: 'Reach level ${r.requiredLevel} to unlock this reward');
      return;
    }
    if (!r.isUsable) {
      Fluttertoast.showToast(msg: '${r.typeLabel} is active — enjoy your reward!');
      return;
    }
    // Level-reward store items are synced to My Store by the backend.
    // Open My Store so the user can equip/use the granted item.
    context.pushNamed(AppRoutes.myStore);
  }

  Widget _rewardIcon(LevelReward r, IconData iconData, Color iconColor) {
    if (r.image != null && r.image!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: StoreNetworkImage(
          url: r.image!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          placeholderIcon: iconData,
        ),
      );
    }
    return Icon(
      iconData,
      color: iconColor,
      size: 26,
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'medal':
        return Icons.emoji_events;
      case 'frame':
        return Icons.portrait;
      case 'customid':
      case 'custom_id':
        return Icons.tag;
      case 'background':
        return Icons.wallpaper;
      case 'openingpage':
      case 'opening_page':
        return Icons.open_in_full;
      case 'entrance':
        return Icons.door_front_door_outlined;
      case 'privilege':
        return Icons.diamond;
      case 'rule':
        return Icons.rule;
      default:
        return Icons.card_giftcard;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'medal':
        return _gold;
      case 'frame':
        return _purple;
      case 'customid':
      case 'custom_id':
        return _cyan;
      case 'background':
        return const Color(0xFFFF6B9D);
      case 'openingpage':
      case 'opening_page':
        return const Color(0xFF34C759);
      case 'entrance':
        return const Color(0xFFFFA94D);
      case 'privilege':
        return _purple;
      case 'rule':
        return _white50;
      default:
        return _white50;
    }
  }

  int _nextLevelCoin(int currentCoin) {
    for (final g in _groups) {
      if (g.coin > currentCoin) return g.coin;
    }
    if (_groups.isNotEmpty) {
      return _groups.map((g) => g.coin).reduce((a, b) => a > b ? a : b);
    }
    return 0;
  }
}
