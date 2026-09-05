import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

/// A compact progress bar showing bond level and intimacy progress.
/// Used in Live/Audio room headers.
class BondProgressBarRoom extends StatelessWidget {
  const BondProgressBarRoom({
    super.key,
    required this.level,
    required this.currentIntimacy,
    required this.targetIntimacy,
    this.type = 'cp',
    this.width = 120,
  });

  final int level;
  final int currentIntimacy;
  final int targetIntimacy;
  final String type;
  final double width;

  @override
  Widget build(BuildContext context) {
    final isCp = type.toLowerCase() == 'cp';
    final accentColor = isCp ? const Color(0xFFE91E63) : const Color(0xFF03A9F4);
    final progress = targetIntimacy == 0 ? 0.0 : (currentIntimacy / targetIntimacy).clamp(0.0, 1.0);

    return Container(
      width: width,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Progress fill
          FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor.withValues(alpha: 0.5), accentColor],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Icon(
                  isCp ? Icons.favorite : Icons.stars,
                  color: Colors.white,
                  size: 10,
                ),
                const SizedBox(width: 4),
                Text(
                  'Lv.$level',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${formatCount(currentIntimacy)}/${formatCount(targetIntimacy)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
