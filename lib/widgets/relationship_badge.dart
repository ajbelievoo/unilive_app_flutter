import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A badge indicating relationship type (CP or Friend) and level.
class RelationshipBadge extends StatelessWidget {
  const RelationshipBadge({
    super.key,
    required this.type,
    required this.level,
    this.size = 20,
    this.showLevel = true,
  });

  /// 'cp' or 'friend'
  final String? type;
  final int level;
  final double size;
  final bool showLevel;

  @override
  Widget build(BuildContext context) {
    if (type == null || type!.isEmpty) return const SizedBox.shrink();

    final isCp = type!.toLowerCase() == 'cp';
    final gradient = isCp
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF48FB1), Color(0xFFE91E63)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF81D4FA), Color(0xFF03A9F4)],
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(size / 2),
        boxShadow: [
          BoxShadow(
            color: (isCp ? const Color(0xFFE91E63) : const Color(0xFF03A9F4)).withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCp ? Icons.favorite : Icons.stars,
            color: Colors.white,
            size: size * 0.6,
          ),
          if (showLevel && level > 0) ...[
            const SizedBox(width: 2),
            Text(
              'L$level',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.55,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
