import 'package:flutter/material.dart';

/// Renders a preview of one of the 12 built-in VIP chat bubble styles.
/// Used in the VIP store grid so users can see what each VIP level's
/// chat bubble looks like without loading any network assets.
class VipBubblePreview extends StatelessWidget {
  const VipBubblePreview({
    super.key,
    required this.vipLevel,
    this.size = 48,
    this.showLabel = false,
  });

  /// VIP level 1-12. Values outside this range fall back to the default
  /// non-VIP bubble style.
  final int vipLevel;
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final id = vipLevel.clamp(0, 12);
    final style = _VipBubblePreviewStyles.byId(id);

    return Container(
      width: size,
      height: size * 0.7,
      decoration: style.decoration,
      alignment: Alignment.center,
      child: Text(
        showLabel ? 'VIP $id' : 'Hi',
        style: TextStyle(
          color: style.textColor,
          fontSize: size * 0.22,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Style definitions — mirrors the 12 styles in audio_room_comment_bubble.dart
// ---------------------------------------------------------------------------
class _VipBubblePreviewStyles {
  static _VipPreviewStyle byId(int id) {
    switch (id) {
      case 1:
        return _VipPreviewStyle(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [Color(0xFF00E676), Color(0xFF00C853), Color(0xFF1B5E20)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFFB9F6CA).withValues(alpha: 0.7), width: 0.8),
          ),
          textColor: Colors.white,
        );
      case 2:
        return _VipPreviewStyle(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF8E1), Color(0xFFFFC107), Color(0xFF8D6E63)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFFFFE082), width: 0.8),
          ),
          textColor: const Color(0xFF4E342E),
        );
      case 3:
        return _VipPreviewStyle(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [Color(0xFF8E24AA), Color(0xFF4A148C), Color(0xFF311B92)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFFEA80FC).withValues(alpha: 0.7), width: 0.8),
          ),
          textColor: Colors.white,
        );
      case 4:
        return _VipPreviewStyle(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [Color(0xFFFF1744), Color(0xFFD50000), Color(0xFF880E4F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFFFF8A80).withValues(alpha: 0.7), width: 0.8),
          ),
          textColor: Colors.white,
        );
      case 5:
        return _VipPreviewStyle(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [Color(0xFF00E676), Color(0xFF00897B), Color(0xFF004D40)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFFB9F6CA).withValues(alpha: 0.7), width: 0.8),
          ),
          textColor: Colors.white,
        );
      case 6:
        return _VipPreviewStyle(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [Color(0xFF00B0FF), Color(0xFF0091EA), Color(0xFF01579B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFF40C4FF).withValues(alpha: 0.7), width: 0.8),
          ),
          textColor: Colors.white,
        );
      case 7:
        return _VipPreviewStyle(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [Color(0xFFFF80AB), Color(0xFFF06292), Color(0xFFC2185B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFFFFCDD2).withValues(alpha: 0.7), width: 0.8),
          ),
          textColor: Colors.white,
        );
      case 8:
        return _VipPreviewStyle(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [Color(0xFF00E5FF), Color(0xFF651FFF), Color(0xFF212121)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.8), width: 0.8),
          ),
          textColor: Colors.white,
        );
      case 9:
        return _VipPreviewStyle(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFEA00), Color(0xFFFFD600), Color(0xFFFF6F00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFFFFFF8D), width: 0.8),
          ),
          textColor: const Color(0xFF3E2723),
        );
      case 10:
        return _VipPreviewStyle(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [Color(0xFFE0E0E0), Color(0xFFBDBDBD), Color(0xFF757575)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFFFFFFFF).withValues(alpha: 0.8), width: 0.8),
          ),
          textColor: const Color(0xFF212121),
        );
      case 11:
        return _VipPreviewStyle(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFF1744),
                Color(0xFFFF9100),
                Color(0xFFFFEA00),
                Color(0xFF00E676),
                Color(0xFF00B0FF),
                Color(0xFF651FFF),
                Color(0xFFD500F9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 0.8),
          ),
          textColor: Colors.white,
        );
      case 12:
        return _VipPreviewStyle(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1A237E),
                Color(0xFF311B92),
                Color(0xFF6200EA),
                Color(0xFF00BCD4),
                Color(0xFF18FFFF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFF80D8FF).withValues(alpha: 0.8), width: 0.8),
          ),
          textColor: Colors.white,
        );
      default:
        return _VipPreviewStyle(
          decoration: BoxDecoration(
            color: const Color(0xFF17141F).withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(8),
          ),
          textColor: Colors.white,
        );
    }
  }
}

class _VipPreviewStyle {
  const _VipPreviewStyle({
    required this.decoration,
    required this.textColor,
  });

  final BoxDecoration decoration;
  final Color textColor;
}
