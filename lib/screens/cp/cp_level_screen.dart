/// CP/Friend Bond Level screen — shows the level table with required intimacy
/// and perks unlocked at each level.
///
/// Dynamic: levels come from backend (admin creates N levels: 1, 2, ... 15, 20, 30...).
/// Each level shows privilege items (PNG/SVG/GIF preview images) from admin.
/// Shows an empty state when backend levels are not available.
library cp_level;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../providers/cp_provider.dart';
import '../../providers/friend_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../widgets/cp_widgets.dart';
import '../../widgets/premium_ui.dart';

class CPLevelScreen extends StatefulWidget {
  const CPLevelScreen({super.key, this.isFriend = false});
  final bool isFriend;

  @override
  State<CPLevelScreen> createState() => _CPLevelScreenState();
}

class _CPLevelScreenState extends State<CPLevelScreen> {
  @override
  void initState() {
    super.initState();
    _loadLevels();
  }

  Future<void> _loadLevels() async {
    if (widget.isFriend) {
      final friend = context.read<FriendProvider>();
      if (friend.levels.isEmpty) await friend.loadLevels();
    } else {
      final cp = context.read<CpProvider>();
      if (cp.levels.isEmpty) await cp.loadLevels();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFriend = widget.isFriend;
    final gradient =
        isFriend ? AppTheme.primaryGradient : AppTheme.pinkGradient;
    final accentColor = isFriend ? AppTheme.primary : const Color(0xFFE84B8A);

    final cpLevels = context.watch<CpProvider>().levels;
    final friendLevels = context.watch<FriendProvider>().levels;
    final hasApiLevels =
        isFriend ? friendLevels.isNotEmpty : cpLevels.isNotEmpty;

    final myLevel = isFriend ? 1 : context.watch<CpProvider>().myCP?.level ?? 1;
    final myIntimacy =
        isFriend ? 0 : context.watch<CpProvider>().myCP?.intimacy ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('${isFriend ? 'Friend' : 'CP'} Bond Levels'),
        backgroundColor: gradient.colors.first,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CurrentLevelCard(
            level: myLevel,
            intimacy: myIntimacy,
            gradient: gradient,
          ),
          const SizedBox(height: 16),
          if (!hasApiLevels)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.layers_outlined,
                    size: 48,
                    color: accentColor.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No levels available yet',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Admin can create levels from the backend',
                    style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                  ),
                ],
              ),
            )
          else ...[
            SectionHeader(
              title:
                  'All Levels (${isFriend ? friendLevels.length : cpLevels.length})',
              color: accentColor,
            ),
            if (isFriend)
              ...friendLevels.map(
                (l) => _LevelTile(
                  level: l,
                  isCurrent: l.level == myLevel,
                  isUnlocked: l.level <= myLevel,
                  gradient: gradient,
                  accentColor: accentColor,
                  isFriend: true,
                ),
              )
            else
              ...cpLevels.map(
                (l) => _LevelTile(
                  level: l,
                  isCurrent: l.level == myLevel,
                  isUnlocked: l.level <= myLevel,
                  gradient: gradient,
                  accentColor: accentColor,
                  isFriend: false,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CurrentLevelCard extends StatelessWidget {
  const _CurrentLevelCard({
    required this.level,
    required this.intimacy,
    required this.gradient,
  });
  final int level;
  final int intimacy;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final nextTarget = (level * 500) + 500;
    return GradientCard(
      gradient: gradient,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Level medal
          Image.asset(
            'assets/cp_friend/cp1_level+madale.png',
            width: 80,
            height: 56,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/cp_friend/heart_tow.png',
              width: 72,
              height: 48,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 8),
          CPLevelBadge(level: level, size: 56),
          const SizedBox(height: 12),
          Text(
            'Bond Level $level',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          BondProgressBar(current: intimacy, target: nextTarget),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.isCurrent,
    required this.isUnlocked,
    required this.gradient,
    required this.accentColor,
    this.isFriend = false,
  });
  final dynamic level;
  final bool isCurrent;
  final bool isUnlocked;
  final Gradient gradient;
  final Color accentColor;
  final bool isFriend;

  int get lvl => level.level as int;
  String get lvlName => (level.name as String?) ?? 'Level ${level.level}';
  int get req => (level.requiredIntimacy as int?) ?? 0;
  List<String> get perkList =>
      (level.perks as List?)?.cast<String>() ?? const [];

  /// Get privilege items from API level (CPPrivilegeItem or FriendPrivilegeItem)
  List<dynamic> get _privilegeItems {
    try {
      return (level.privilegeItems as List?) ?? [];
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _privilegeItems;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: isCurrent ? Border.all(color: accentColor, width: 1.5) : null,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CPLevelBadge(level: lvl, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Lv.$lvl  $lvlName',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: gradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'YOU',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatCount(req)} intimacy',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Perks chips
          if (perkList.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  perkList
                      .map((p) => _perkChip(p, isUnlocked, accentColor))
                      .toList(),
            ),
          ],
          // Privilege items with preview images (from API)
          if (items.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Privilege Items',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  final previewUrl = item.effectivePreviewUrl;
                  final name = item.name ?? 'Item';
                  return Container(
                    width: 70,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            isUnlocked
                                ? accentColor.withValues(alpha: 0.2)
                                : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (previewUrl != null && previewUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child:
                                  isUnlocked
                                      ? _buildImage(previewUrl)
                                      : ColorFiltered(
                                        colorFilter: const ColorFilter.mode(
                                          Colors.grey,
                                          BlendMode.saturation,
                                        ),
                                        child: _buildImage(previewUrl),
                                      ),
                            ),
                          )
                        else
                          Icon(
                            isUnlocked ? Icons.star : Icons.lock,
                            size: 24,
                            color:
                                isUnlocked
                                    ? accentColor
                                    : AppTheme.textTertiary,
                          ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            color:
                                isUnlocked
                                    ? AppTheme.textPrimary
                                    : AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _perkChip(String perk, bool unlocked, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            unlocked ? accent.withValues(alpha: 0.1) : AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            unlocked ? Icons.check_circle : Icons.lock_outline,
            size: 12,
            color: unlocked ? accent : AppTheme.textTertiary,
          ),
          const SizedBox(width: 4),
          Text(
            perk,
            style: TextStyle(
              fontSize: 11,
              color: unlocked ? accent : AppTheme.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String url) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.svg')) {
      return SvgPicture.network(url, fit: BoxFit.cover);
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      errorWidget:
          (_, __, ___) =>
              const Icon(Icons.broken_image, size: 20, color: Colors.grey),
    );
  }
}
