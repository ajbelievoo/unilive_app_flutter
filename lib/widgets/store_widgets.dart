/// Shared premium design widgets for the Store & My Store screens.
///
/// Dark, premium, Bigo-Live-style visual language matching the VIP screen:
/// - Dark gradient backgrounds with radial glows
/// - Glassmorphism cards
/// - Category-specific gradient colors
/// - Glow effects and animated rings
library store_widgets;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'svga_player_widget.dart';
import '../utils/media_utils.dart';

// ---- Category visual metadata ------------------------------------------------

/// Visual identity for each store category: icon, gradient, glow color.
class CategoryStyle {
  const CategoryStyle({
    required this.icon,
    required this.gradient,
    required this.glow,
    required this.label,
  });
  final IconData icon;
  final Gradient gradient;
  final Color glow;

  /// Display label (short).
  final String label;
}

const Map<String, CategoryStyle> categoryStyles = {
  'avatarFrame': CategoryStyle(
    icon: Icons.account_circle,
    gradient: LinearGradient(colors: [Color(0xFF9B6BFF), Color(0xFF6A5AE0)]),
    glow: Color(0xFF9B6BFF),
    label: 'Frames',
  ),
  'chatBubble': CategoryStyle(
    icon: Icons.chat_bubble,
    gradient: LinearGradient(colors: [Color(0xFF4F8DFD), Color(0xFF3B7BFF)]),
    glow: Color(0xFF4F8DFD),
    label: 'Bubbles',
  ),
  'roomCard': CategoryStyle(
    icon: Icons.card_giftcard,
    gradient: LinearGradient(colors: [Color(0xFFFF6B9D), Color(0xFFE84B8A)]),
    glow: Color(0xFFFF6B9D),
    label: 'Room Card',
  ),
  'micWave': CategoryStyle(
    icon: Icons.graphic_eq,
    gradient: LinearGradient(colors: [Color(0xFF00D9A3), Color(0xFF00B884)]),
    glow: Color(0xFF00D9A3),
    label: 'Mic Wave',
  ),
  'roomTheme': CategoryStyle(
    icon: Icons.palette,
    gradient: LinearGradient(colors: [Color(0xFFFFB800), Color(0xFFFF9500)]),
    glow: Color(0xFFFFB800),
    label: 'Theme',
  ),
  'entryEffect': CategoryStyle(
    icon: Icons.celebration,
    gradient: LinearGradient(colors: [Color(0xFFB388FF), Color(0xFF7C4DFF)]),
    glow: Color(0xFFB388FF),
    label: 'Entry',
  ),
  'entrance': CategoryStyle(
    icon: Icons.sensor_door,
    gradient: LinearGradient(colors: [Color(0xFF00D9A3), Color(0xFF00B884)]),
    glow: Color(0xFF00D9A3),
    label: 'Entrance',
  ),
  'badge': CategoryStyle(
    icon: Icons.military_tech,
    gradient: LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
    glow: Color(0xFFFFD700),
    label: 'Badge',
  ),
  'luckyId': CategoryStyle(
    icon: Icons.confirmation_number,
    gradient: LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFEE5A24)]),
    glow: Color(0xFFFF6B6B),
    label: 'Lucky ID',
  ),
};

/// Source visual metadata for My Store.
class SourceStyle {
  const SourceStyle({required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color color;
  final String label;
}

const Map<String, SourceStyle> sourceStyles = {
  'all': SourceStyle(icon: Icons.grid_view, color: Color(0xFF6A5AE0), label: 'All'),
  'buy': SourceStyle(icon: Icons.shopping_bag, color: Color(0xFF6A5AE0), label: 'Buy'),
  'cp': SourceStyle(icon: Icons.favorite, color: Color(0xFFFF6B9D), label: 'CP'),
  'friend': SourceStyle(icon: Icons.people, color: Color(0xFF4F8DFD), label: 'Friend'),
  'family': SourceStyle(icon: Icons.family_restroom, color: Color(0xFFFFB800), label: 'Family'),
  'vip': SourceStyle(icon: Icons.diamond, color: Color(0xFFB388FF), label: 'VIP'),
  'reward': SourceStyle(icon: Icons.card_giftcard, color: Color(0xFF00D9A3), label: 'Reward'),
  'admin': SourceStyle(icon: Icons.shield, color: Color(0xFF9A9AB0), label: 'Admin'),
};

// ---- Background ---------------------------------------------------------------

/// Dark premium background with a radial glow at the top using the given
/// [glowColor]. Matches the VIP screen's layered background approach.
class StoreBackground extends StatelessWidget {
  const StoreBackground({super.key, this.glowColor = const Color(0xFF6A5AE0)});
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topLeft,
      children: [
        // Base dark gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF15152A), Color(0xFF0D0D1A), Color(0xFF0A0A12)],
            ),
          ),
        ),
        // Radial glow at top
        Positioned(
          top: -100,
          left: 0,
          right: 0,
          height: 400,
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.2),
                radius: 0.9,
                colors: [glowColor.withValues(alpha: 0.18), Colors.transparent],
              ),
            ),
          ),
        ),
        // Subtle decorative circles
        Positioned(
          top: 60,
          right: -30,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: glowColor.withValues(alpha: 0.06), width: 1),
            ),
          ),
        ),
        Positioned(
          top: 200,
          left: -40,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.04), width: 1),
            ),
          ),
        ),
      ],
    );
  }
}

// ---- Glass card ---------------------------------------------------------------

/// Glassmorphism card — frosted glass on dark background.
class StoreGlassCard extends StatelessWidget {
  const StoreGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.glow,
    this.glowBlur = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? glow;
  final double glowBlur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
        boxShadow: glow != null
            ? [BoxShadow(color: glow!.withValues(alpha: 0.25), blurRadius: glowBlur, spreadRadius: 2)]
            : null,
      ),
      child: child,
    );
  }
}

// ---- Tab bar ------------------------------------------------------------------

/// Premium dark tab bar for store screens — pill-style with glow indicator.
class StoreTabBar extends StatelessWidget implements PreferredSizeWidget {
  const StoreTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    this.glowColor = const Color(0xFF6A5AE0),
  });

  final TabController controller;
  final List<Tab> tabs;
  final Color glowColor;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      isScrollable: true,
      tabs: tabs,
      indicator: BoxDecoration(
        gradient: LinearGradient(
          colors: [glowColor.withValues(alpha: 0.3), glowColor.withValues(alpha: 0.08)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: glowColor.withValues(alpha: 0.5), width: 1),
        boxShadow: [BoxShadow(color: glowColor.withValues(alpha: 0.2), blurRadius: 8)],
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      dividerColor: Colors.transparent,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white.withValues(alpha: 0.4),
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      splashBorderRadius: BorderRadius.circular(14),
      overlayColor: WidgetStateProperty.all(glowColor.withValues(alpha: 0.1)),
    );
  }
}

// ---- Balance bar --------------------------------------------------------------

/// Premium balance bar — glassmorphism with glow icon and gradient amount.
class BalanceBar extends StatelessWidget {
  const BalanceBar({
    super.key,
    required this.icon,
    required this.amount,
    required this.label,
    required this.color,
    this.onRecharge,
  });

  final IconData icon;
  final String amount;
  final String label;
  final Color color;
  final VoidCallback? onRecharge;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: StoreGlassCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        borderRadius: 18,
        glow: color,
        glowBlur: 16,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.6)]),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12)],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [Colors.white, color.withValues(alpha: 0.8)],
                    ).createShader(bounds),
                    child: Text(
                      amount,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (onRecharge != null)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onRecharge,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 18),
                          SizedBox(width: 4),
                          Text('Recharge', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---- Image --------------------------------------------------------------------

/// Premium image placeholder for dark backgrounds.
class StoreImagePlaceholder extends StatelessWidget {
  const StoreImagePlaceholder({super.key, this.icon = Icons.image, this.size = 36});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.04), Colors.white.withValues(alpha: 0.01)],
        ),
      ),
      child: Center(child: Icon(icon, size: size, color: Colors.white.withValues(alpha: 0.2))),
    );
  }
}

/// CachedNetworkImage with dark premium placeholder + error.
/// Automatically detects SVGA URLs and renders them with [SvgaPlayer]
/// when [allowAnimation] is true. When false, SVGA URLs render as a
/// single static frame or fallback image so the store list shows a photo.
class StoreNetworkImage extends StatelessWidget {
  const StoreNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholderIcon = Icons.image,
    this.allowAnimation = true,
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final IconData placeholderIcon;
  final bool allowAnimation;

  /// Returns true if the URL points to an SVGA animation file.
  static bool _isSvga(String? url) => SvgaHelper.isSvgaUrl(url);

  /// Returns true if the URL points to a video file.
  static bool _isVideo(String? url) {
    if (url == null || url.isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.contains('.mp4') || lower.contains('.mov') ||
        lower.contains('.webm') || lower.contains('.mkv') ||
        lower.contains('.3gp');
  }

  @override
  Widget build(BuildContext context) {
    final u = url;

    // SVGA animations — render with SvgaPlayer (only animate when requested).
    // Resolve the URL so relative backend paths become absolute.
    if (_isSvga(u)) {
      final fullUrl = VideoUtil.getFullSvgaUrl(u);
      if (fullUrl.isEmpty) {
        return const StoreImagePlaceholder(icon: Icons.broken_image);
      }
      return SizedBox(
        width: width,
        height: height ?? double.infinity,
        child: SvgaPlayer(
          url: fullUrl,
          fit: fit,
          width: width ?? 200,
          height: height ?? 200,
          allowAnimation: allowAnimation,
        ),
      );
    }

    // Video files — show video icon placeholder (can't render as image)
    if (_isVideo(u)) {
      return const StoreImagePlaceholder(
        icon: Icons.play_circle_outline,
        size: 40,
      );
    }

    // Regular images (png, jpg, jpeg, webp, gif) — resolve relative URLs.
    final fullImg = VideoUtil.getFullImageUrl(u);
    if (fullImg.isEmpty && u != null && u.isNotEmpty) {
      return const StoreImagePlaceholder(icon: Icons.broken_image);
    }
    return CachedNetworkImage(
      imageUrl: fullImg,
      fit: fit,
      width: width,
      height: height,
      placeholder: (_, __) => StoreImagePlaceholder(icon: placeholderIcon),
      errorWidget: (_, __, ___) => const StoreImagePlaceholder(icon: Icons.broken_image),
    );
  }
}

// ---- Badges -------------------------------------------------------------------

/// Small pill badge for dark backgrounds.
class PillBadge extends StatelessWidget {
  const PillBadge({
    super.key,
    required this.icon,
    required this.label,
    this.gradient,
    this.color,
    this.fontSize = 9,
  });

  final IconData icon;
  final String label;
  final Gradient? gradient;
  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: gradient,
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: gradient != null
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: fontSize + 3),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ---- Source filter chip -------------------------------------------------------

/// Premium source filter chip for dark backgrounds.
class SourceFilterChip extends StatelessWidget {
  const SourceFilterChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onSelected(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: selected ? LinearGradient(colors: [color, color.withValues(alpha: 0.6)]) : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.2 : 0.8,
          ),
          boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: selected ? Colors.white : color.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Icon button (app bar) ----------------------------------------------------

/// Premium pill icon button for the app bar on dark backgrounds.
class AppBarPillButton extends StatelessWidget {
  const AppBarPillButton({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 15),
                const SizedBox(width: 4),
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
