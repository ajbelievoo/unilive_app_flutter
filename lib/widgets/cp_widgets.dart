/// Shared CP (Couple) & Friend UI widgets — Bigo-style fully dark premium design.
///
/// Keeps the couple avatar pair, bond progress bar, level badge and stat
/// tiles in one place so the screens stay compact and consistent.
library cp_widgets;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import 'package:belive/widgets/preloader.dart';

// ---------------------------------------------------------------------------
// CoupleAvatarPair — overlapping avatars with heart decoration
// ---------------------------------------------------------------------------
class CoupleAvatarPair extends StatelessWidget {
  const CoupleAvatarPair({
    super.key,
    required this.user1,
    required this.user2,
    this.size = 64,
    this.overlap = 22,
    this.showHeart = true,
    this.border,
    this.isFriend = false,
  });

  /// Accepts CPUser, FriendUsers, or any object with `image` and `name` fields.
  final dynamic user1;
  final dynamic user2;
  final double size;
  final double overlap;
  final bool showHeart;
  final Color? border;
  final bool isFriend;

  @override
  Widget build(BuildContext context) {
    final totalWidth = size + (size - overlap);
    final ringColor1 = isFriend ? AppTheme.friendAccent : const Color(0xFFE84B8A);
    final ringColor2 = isFriend ? AppTheme.friendAccentLight : const Color(0xFF6A5AE0);
    return SizedBox(
      width: totalWidth,
      height: size + 10,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topLeft,
        children: [
          // Soft glow behind avatars
          Positioned(
            left: size * 0.1,
            top: size * 0.05,
            child: Container(
              width: size * 1.4,
              height: size * 1.1,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isFriend ? AppTheme.friendAccent : AppTheme.cpAccent)
                    .withValues(alpha: 0.2),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 5,
            child: _avatar(user1, size / 2, ringColor1),
          ),
          Positioned(
            left: size - overlap,
            top: 5,
            child: _avatar(user2, size / 2, ringColor2),
          ),
          if (showHeart) ...[
            Positioned(
              left: size - overlap / 2 - 16,
              top: -8,
              child: Image.asset(
                'assets/cp_friend/cp_moda.webp',
                width: 36,
                height: 36,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            Positioned(
              left: size - overlap / 2 - 10,
              top: -2,
              child: Image.asset(
                'assets/cp_friend/heart_tow.webp',
                width: 24,
                height: 24,
                errorBuilder: (_, __, ___) => Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    gradient: AppTheme.pinkGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0x66E84B8A), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  child: const Icon(Icons.favorite, size: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _avatar(dynamic u, double radius, Color ring) {
    final image = u?.image as String?;
    final name = u?.name as String?;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [ring, ring.withValues(alpha: 0.5)],
        ),
        boxShadow: [
          BoxShadow(
            color: ring.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(2.5),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.cpDarkSurface,
        ),
        child: CircleAvatar(
          radius: radius - 5,
          backgroundColor: AppTheme.cpDarkSurfaceLight,
          backgroundImage: (image != null && image.isNotEmpty)
              ? CachedNetworkImageProvider(image)
              : null,
          child: (image == null || image.isEmpty)
              ? Text(
                  (name != null && name.isNotEmpty ? name[0].toUpperCase() : '?'),
                  style: TextStyle(
                    fontSize: radius * 0.6,
                    color: ring,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CPLevelBadge — heart-shaped gradient badge with level number
// ---------------------------------------------------------------------------
class CPLevelBadge extends StatelessWidget {
  const CPLevelBadge({super.key, required this.level, this.size = 28, this.isFriend = false});
  final int level;
  final double size;
  final bool isFriend;

  @override
  Widget build(BuildContext context) {
    final gradient = isFriend ? AppTheme.primaryGradient : AppTheme.pinkGradient;
    final accentColor = isFriend ? AppTheme.friendAccent : AppTheme.cpAccent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.favorite, size: size * 0.6, color: Colors.white),
          Center(
            child: Padding(
              padding: EdgeInsets.only(top: size * 0.05),
              child: Text(
                '$level',
                style: TextStyle(
                  color: accentColor,
                  fontSize: size * 0.32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BondProgressBar — animated gradient progress bar with glow (dark theme)
// ---------------------------------------------------------------------------
class BondProgressBar extends StatelessWidget {
  const BondProgressBar({
    super.key,
    required this.current,
    required this.target,
    this.label = 'Intimacy',
    this.isFriend = false,
  });

  final int current;
  final int target;
  final String label;
  final bool isFriend;

  @override
  Widget build(BuildContext context) {
    final pct = target == 0 ? 0.0 : (current / target).clamp(0.0, 1.0);
    final accentColor = isFriend ? AppTheme.friendAccent : AppTheme.cpAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.cpDarkTextSecondary)),
            Text('${formatCount(current)} / ${formatCount(target)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accentColor)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 12,
            backgroundColor: AppTheme.cpDarkSurfaceLight,
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
          ),
        ),
        // Glow line under the bar
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 3,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(
              accentColor.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// CPStatTile — compact stat tile with gradient icon circle (dark theme)
// ---------------------------------------------------------------------------
class CPStatTile extends StatelessWidget {
  const CPStatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color = AppTheme.primary,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.cpDarkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.cpDarkText)),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.cpDarkTextSecondary)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CPUserRow — user row for requests / discover lists (dark theme)
// ---------------------------------------------------------------------------
class CPUserRow extends StatelessWidget {
  const CPUserRow({
    super.key,
    required this.user,
    required this.actionLabel,
    required this.onAction,
    this.subtitle,
    this.actionColor = AppTheme.primary,
    this.actionLoading = false,
  });

  final dynamic user;
  final String actionLabel;
  final VoidCallback onAction;
  final String? subtitle;
  final Color actionColor;
  final bool actionLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [actionColor, actionColor.withValues(alpha: 0.6)],
              ),
              boxShadow: [
                BoxShadow(
                  color: actionColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(2.5),
              child: CircleAvatar(
                radius: 23.5,
                backgroundColor: AppTheme.cpDarkSurfaceLight,
                backgroundImage: (user?.image != null && user!.image!.isNotEmpty)
                    ? CachedNetworkImageProvider(user!.image!)
                    : null,
                child: (user?.image == null || user!.image!.isEmpty)
                    ? const Icon(Icons.person, color: Colors.white54)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user?.name ?? 'Unknown',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.cpDarkText),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user?.isLive == true) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: AppTheme.pinkGradient,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('LIVE', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: user?.isOnline == true ? AppTheme.green : AppTheme.cpDarkTextTertiary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      subtitle ?? (user?.isOnline == true ? 'Online' : 'Offline'),
                      style: TextStyle(
                        fontSize: 12,
                        color: user?.isOnline == true ? AppTheme.green : AppTheme.cpDarkTextTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          actionLoading
              ? const SizedBox(width: 22, height: 22, child: Preloader(strokeWidth: 2))
              : GestureDetector(
                  onTap: onAction,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [actionColor, actionColor.withValues(alpha: 0.7)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: actionColor.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(actionLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DarkEmptyState — Bigo-style dark empty state with decorative glow
// ---------------------------------------------------------------------------
class DarkEmptyState extends StatelessWidget {
  const DarkEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accentColor = AppTheme.cpAccent,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.08),
                border: Border.all(color: accentColor.withValues(alpha: 0.15), width: 1),
              ),
              child: Icon(icon, size: 36, color: accentColor.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(color: AppTheme.cpDarkText, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.cpDarkTextTertiary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// GlassCard — frosted glass surface for premium CP/Friend cards
// ---------------------------------------------------------------------------
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 24,
    this.borderColor,
    this.backgroundColor,
    this.intensity = 0.12,
    this.shadow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;
  final double intensity;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.cpDarkCard.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: shadow ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
      ),
      child: child,
    );
  }
}
