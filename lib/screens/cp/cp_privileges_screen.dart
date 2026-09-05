/// CP/Friend Privileges screen — shows per-level unlockable privileges.
///
/// Dynamic: levels come from backend (admin creates N levels: 1, 2, ... 15, 20, 30...).
/// Each level has privilege items with mainFile (used in app) + previewFile (shown here).
/// Supports PNG, SVG, GIF, and any image format.
/// Shows an empty state when backend levels/privileges are not available.
library cp_privileges;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../models/cp_models.dart';
import '../../models/friend_models.dart';
import '../../providers/cp_provider.dart';
import '../../providers/friend_provider.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';

class CPPrivilegesScreen extends StatefulWidget {
  const CPPrivilegesScreen({super.key, this.isFriend = false, this.cpId = ''});
  final bool isFriend;
  final String cpId;

  @override
  State<CPPrivilegesScreen> createState() => _CPPrivilegesScreenState();
}

class _CPPrivilegesScreenState extends State<CPPrivilegesScreen> {
  int _selectedLevel = 1;

  // Header gradients matching CP screen
  static const LinearGradient _cpGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF6C309B), Color(0xFFE35384), Color(0xFF6900BC)],
  );
  static const LinearGradient _friendGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF6C309B), Color(0xFF7B61FF), Color(0xFF4F8DFD)],
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final session = context.read<SessionManager>();
    final cp = context.read<CpProvider>();
    final friend = context.read<FriendProvider>();
    if (widget.isFriend) {
      await friend.loadLevels();
    } else {
      await cp.loadLevels();
      if (widget.cpId.isNotEmpty) {
        await cp.loadPrivileges(widget.cpId, userId: session.userId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFriend = widget.isFriend;
    final gradient = isFriend ? _friendGradient : _cpGradient;
    final accentColor = isFriend ? AppTheme.primary : const Color(0xFFE35384);

    final myLevel = isFriend ? 1 : context.watch<CpProvider>().myCP?.level ?? 1;

    // Get dynamic levels from API
    final cpLevels = context.watch<CpProvider>().levels;
    final friendLevels = context.watch<FriendProvider>().levels;
    final hasApiLevels =
        isFriend ? friendLevels.isNotEmpty : cpLevels.isNotEmpty;

    // Get dynamic privileges from API
    final cpPrivileges = context.watch<CpProvider>().privileges;

    // Build level list from API levels only.
    final levelCount =
        hasApiLevels ? (isFriend ? friendLevels.length : cpLevels.length) : 0;

    // Get level data for selected level
    dynamic selectedLevelData;
    if (hasApiLevels) {
      if (isFriend) {
        selectedLevelData = friendLevels.firstWhere(
          (l) => l.level == _selectedLevel,
          orElse: () => friendLevels.first,
        );
      } else {
        selectedLevelData = cpLevels.firstWhere(
          (l) => l.level == _selectedLevel,
          orElse: () => cpLevels.first,
        );
      }
    }

    // Get privilege items for selected level (real API data only)
    final privilegeItems = _getPrivilegeItemsForLevel(
      isFriend: isFriend,
      cpLevels: cpLevels,
      friendLevels: friendLevels,
      cpPrivileges: cpPrivileges,
      selectedLevel: _selectedLevel,
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 80,
            title: Text(
              '${isFriend ? 'Friend' : 'CP'} Privileges',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            flexibleSpace: Container(
              decoration: BoxDecoration(gradient: gradient),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),

          if (!hasApiLevels)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.layers_outlined,
                      size: 56,
                      color: accentColor.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No privilege levels available yet',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Admin can create levels and add privilege items from the backend',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
          // Level selector — dynamic (1 to N)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/cp_friend/heart_tow.png',
                      width: 64,
                      height: 40,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Select Level',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                      const Spacer(),
                      if (hasApiLevels)
                        Text(
                          'Total ${isFriend ? friendLevels.length : cpLevels.length} levels',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: levelCount,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final lvl = i + 1;
                        final selected = _selectedLevel == lvl;
                        final unlocked = myLevel >= lvl;
                        dynamic levelData;
                        if (hasApiLevels) {
                          if (isFriend && i < friendLevels.length) {
                            levelData = friendLevels[i];
                          } else if (!isFriend && i < cpLevels.length) {
                            levelData = cpLevels[i];
                          }
                        }
                        String? levelIcon;
                        if (levelData != null) {
                          levelIcon =
                              levelData.levelIcon ??
                              levelData.levelBadgeUrl ??
                              levelData.icon;
                        }

                        return GestureDetector(
                          onTap: () => setState(() => _selectedLevel = lvl),
                          child: Container(
                            width: 52,
                            decoration: BoxDecoration(
                              gradient: selected ? gradient : null,
                              color:
                                  selected
                                      ? null
                                      : (unlocked
                                          ? accentColor.withValues(alpha: 0.08)
                                          : AppTheme.surfaceVariant),
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  selected
                                      ? Border.all(
                                        color: gradient.colors.first,
                                        width: 1.5,
                                      )
                                      : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (levelIcon != null && levelIcon.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _buildImage(
                                      levelIcon,
                                      width: 24,
                                      height: 24,
                                    ),
                                  )
                                else
                                  Text(
                                    'Lv.$lvl',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          selected
                                              ? Colors.white
                                              : (unlocked
                                                  ? accentColor
                                                  : AppTheme.textTertiary),
                                    ),
                                  ),
                                const SizedBox(height: 2),
                                Text(
                                  '$lvl',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        selected
                                            ? Colors.white70
                                            : AppTheme.textTertiary,
                                  ),
                                ),
                                if (unlocked && !selected)
                                  const Icon(
                                    Icons.check_circle,
                                    size: 10,
                                    color: AppTheme.green,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Level name + required intimacy
                  if (selectedLevelData != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      selectedLevelData.name ?? 'Level $_selectedLevel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Required Intimacy: ${_formatIntimacy(selectedLevelData.requiredIntimacy)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Privilege items grid — from API only
          if (privilegeItems.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    ImageIcon(const AssetImage("assets/gift/official_gift.png"), color: accentColor.withValues(alpha: 0.3), size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'No privileges for this level yet',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Admin can add privilege items from backend',
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _PrivilegeCard(
                    item: privilegeItems[i],
                    unlocked: myLevel >= _selectedLevel,
                    gradient: gradient,
                    accentColor: accentColor,
                  ),
                  childCount: privilegeItems.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Get privilege items for a level — from API only
  // ---------------------------------------------------------------------------
  List<_PrivilegeDisplay> _getPrivilegeItemsForLevel({
    required bool isFriend,
    required List<CPLevel> cpLevels,
    required List<FriendLevel> friendLevels,
    required List<CPPrivilege> cpPrivileges,
    required int selectedLevel,
  }) {
    // Try API level privilege items first
    if (isFriend && friendLevels.isNotEmpty) {
      try {
        final level = friendLevels.firstWhere(
          (l) => l.level == selectedLevel,
          orElse: () => friendLevels.first,
        );
        final items = level.privilegeItems;
        if (items.isNotEmpty) {
          return items
              .map<_PrivilegeDisplay>(
                (item) => _PrivilegeDisplay(
                  name: item.name ?? 'Privilege',
                  description: item.description ?? '',
                  previewUrl: item.effectivePreviewUrl,
                  fileType: item.fileType ?? 'png',
                  type: item.type ?? 'custom',
                  unlockLevel: item.unlockLevel,
                  unlocked: item.unlocked,
                ),
              )
              .toList();
        }
      } catch (_) {}
    } else if (!isFriend && cpLevels.isNotEmpty) {
      try {
        final level = cpLevels.firstWhere(
          (l) => l.level == selectedLevel,
          orElse: () => cpLevels.first,
        );
        final items = level.privilegeItems;
        if (items.isNotEmpty) {
          return items
              .map<_PrivilegeDisplay>(
                (item) => _PrivilegeDisplay(
                  name: item.name ?? 'Privilege',
                  description: item.description ?? '',
                  previewUrl: item.effectivePreviewUrl,
                  fileType: item.fileType ?? 'png',
                  type: item.type ?? 'custom',
                  unlockLevel: item.unlockLevel,
                  unlocked: item.unlocked,
                ),
              )
              .toList();
        }
      } catch (_) {}
    }

    // Try API privileges filtered by level (CP only)
    if (!isFriend && cpPrivileges.isNotEmpty) {
      final filtered =
          cpPrivileges
              .where(
                (p) =>
                    p.unlockLevel == selectedLevel ||
                    p.unlockLevel <= selectedLevel,
              )
              .toList();
      if (filtered.isNotEmpty) {
        return filtered
            .map<_PrivilegeDisplay>(
              (p) => _PrivilegeDisplay(
                name: p.name ?? 'Privilege',
                description: p.description ?? '',
                previewUrl: p.effectivePreviewUrl,
                fileType: p.fileType ?? 'png',
                type: p.type ?? 'custom',
                unlockLevel: p.unlockLevel,
                unlocked: p.unlocked,
              ),
            )
            .toList();
      }
    }

    // No real privilege items available for this level.
    return [];
  }

  String _formatIntimacy(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return '$value';
  }

  // ---------------------------------------------------------------------------
  // Image builder — supports PNG, SVG, GIF, JPG
  // ---------------------------------------------------------------------------
  Widget _buildImage(String url, {double width = 80, double height = 80}) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.svg')) {
      return SvgPicture.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.contain,
        placeholderBuilder:
            (_) => Container(
              width: width,
              height: height,
              color: AppTheme.surfaceVariant,
            ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: BoxFit.contain,
      placeholder:
          (_, __) => Container(
            width: width,
            height: height,
            color: AppTheme.surfaceVariant,
          ),
      errorWidget:
          (_, __, ___) => Container(
            width: width,
            height: height,
            color: AppTheme.surfaceVariant,
            child: const Icon(Icons.broken_image, size: 20, color: Colors.grey),
          ),
    );
  }
}

// ---------------------------------------------------------------------------
// Display model for privilege items
// ---------------------------------------------------------------------------
class _PrivilegeDisplay {
  final String name;
  final String description;
  final String? previewUrl;
  final String fileType;
  final String type;
  final int unlockLevel;
  final bool unlocked;

  _PrivilegeDisplay({
    required this.name,
    required this.description,
    this.previewUrl,
    this.fileType = 'png',
    required this.type,
    required this.unlockLevel,
    this.unlocked = false,
  });
}

/// Maps a privilege item [type] to a representative icon, used when an item has
/// no preview image uploaded by the admin.
IconData _iconForType(String? type) {
  switch (type) {
    case 'broadcast':
      return Icons.campaign_outlined;
    case 'frame':
    case 'frame_theme':
      return Icons.crop_free;
    case 'ring':
    case 'ring_gallery':
      return Icons.diamond_outlined;
    case 'emoji':
    case 'room_emoji':
      return Icons.emoji_emotions_outlined;
    case 'background':
    case 'room_profile':
    case 'profileBackground':
      return Icons.person_outline;
    case 'gift':
      return Icons.card_giftcard_outlined;
    case 'icon_medal':
    case 'medal':
      return Icons.military_tech_outlined;
    case 'theme':
      return Icons.palette_outlined;
    case 'entrance':
      return Icons.auto_awesome_outlined;
    case 'badge':
      return Icons.military_tech_outlined;
    default:
      return Icons.card_giftcard_outlined;
  }
}

// ---------------------------------------------------------------------------
// Privilege card — shows preview image (PNG/SVG/GIF) or type icon
// ---------------------------------------------------------------------------
class _PrivilegeCard extends StatelessWidget {
  const _PrivilegeCard({
    required this.item,
    required this.unlocked,
    required this.gradient,
    required this.accentColor,
  });
  final _PrivilegeDisplay item;
  final bool unlocked;
  final Gradient gradient;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final hasImage = item.previewUrl != null && item.previewUrl!.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border:
            unlocked
                ? Border.all(
                  color: accentColor.withValues(alpha: 0.3),
                  width: 1.2,
                )
                : null,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Stack(
        children: [
          // Main content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Preview image or icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: unlocked ? gradient : null,
                  color: unlocked ? null : AppTheme.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child:
                    hasImage
                        ? ClipOval(
                          child:
                              unlocked
                                  ? _buildPreviewImage(
                                    item.previewUrl!,
                                    item.fileType,
                                  )
                                  : ColorFiltered(
                                    colorFilter: const ColorFilter.mode(
                                      Colors.grey,
                                      BlendMode.saturation,
                                    ),
                                    child: _buildPreviewImage(
                                      item.previewUrl!,
                                      item.fileType,
                                    ),
                                  ),
                        )
                        : Icon(
                          unlocked
                              ? _iconForType(item.type)
                              : Icons.lock_outline,
                          color:
                              unlocked ? Colors.white : AppTheme.textTertiary,
                          size: 28,
                        ),
              ),
              const SizedBox(height: 10),
              Text(
                item.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      unlocked ? AppTheme.textPrimary : AppTheme.textTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  item.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color:
                        unlocked
                            ? AppTheme.textSecondary
                            : AppTheme.textTertiary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // Lock overlay
          if (!unlocked)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock,
                  size: 12,
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
          // Level badge
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Lv.${item.unlockLevel}',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewImage(String url, String fileType) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.svg')) {
      return SvgPicture.network(url, fit: BoxFit.cover);
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      errorWidget:
          (_, __, ___) =>
              const Icon(Icons.broken_image, size: 24, color: Colors.grey),
    );
  }
}
