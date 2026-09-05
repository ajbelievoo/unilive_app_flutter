/// CP/Friend badge widget — shows a small badge/indicator on user avatars
/// to indicate the user has a CP or Friend relationship.
///
/// Used in: live room viewer lists, chat lists, profile screens, etc.
library cp_badge;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A small badge that can be overlaid on an avatar to show CP/Friend status.
class CPBadge extends StatelessWidget {
  const CPBadge({
    super.key,
    this.level = 1,
    this.size = 16,
    this.isFriend = false,
  });

  final int level;
  final double size;
  final bool isFriend;

  @override
  Widget build(BuildContext context) {
    final gradient = isFriend ? AppTheme.primaryGradient : AppTheme.pinkGradient;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle),
      child: Center(
        child: Icon(
          isFriend ? Icons.people_alt : Icons.favorite,
          size: size * 0.6,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// A CP/Friend level badge (pill shape) for use in profile headers.
class RelationshipLevelBadge extends StatelessWidget {
  const RelationshipLevelBadge({
    super.key,
    this.level = 1,
    this.isFriend = false,
    this.days = 0,
  });

  final int level;
  final bool isFriend;
  final int days;

  @override
  Widget build(BuildContext context) {
    final gradient = isFriend ? AppTheme.primaryGradient : AppTheme.pinkGradient;
    final label = isFriend ? 'Friend' : 'CP';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.primaryShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isFriend ? Icons.people_alt : Icons.favorite, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '$label Lv.$level',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (days > 0) ...[
            const SizedBox(width: 4),
            Text(
              '• ${days}d',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

/// Wraps an avatar widget with an optional CP/Friend badge in the corner.
class AvatarWithCPBadge extends StatelessWidget {
  const AvatarWithCPBadge({
    super.key,
    required this.child,
    this.showBadge = false,
    this.isFriend = false,
    this.badgeSize = 16,
  });

  final Widget child;
  final bool showBadge;
  final bool isFriend;
  final double badgeSize;

  @override
  Widget build(BuildContext context) {
    if (!showBadge) return child;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topLeft,
      children: [
        child,
        Positioned(
          bottom: -2,
          right: -2,
          child: CPBadge(size: badgeSize, isFriend: isFriend),
        ),
      ],
    );
  }
}
