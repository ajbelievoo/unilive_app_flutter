/// VIP Profile + Frame Preview widget.
///
/// Shows the user's avatar with the currently-selected VIP tier's frame
/// overlaid on top — Bigo Live style "you'll get this look" preview.
/// Used in the VIP Store hero section.
library vip_profile_preview;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../utils/media_utils.dart';
import 'svga_player_widget.dart';

class VipProfilePreview extends StatelessWidget {
  const VipProfilePreview({
    super.key,
    required this.userImage,
    required this.frameUrl,
    required this.badgeUrl,
    required this.glowColor,
    this.userName,
    this.nameColor,
    this.size = 110,
    this.frameSize = 140,
    this.showName = true,
  });

  final String? userImage;
  final String? frameUrl;
  final String? badgeUrl;
  final Color glowColor;
  final String? userName;
  final Color? nameColor;
  final double size;
  final double frameSize;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar with frame — frame renders ON TOP of avatar (Bigo style)
        SizedBox(
          width: frameSize,
          height: frameSize,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // 1. Glow (bottom layer)
              Container(
                width: frameSize,
                height: frameSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
              // 2. User avatar (centered, smaller) — BELOW the frame
              ClipOval(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: _buildAvatar(),
                ),
              ),
              // 3. Frame (SVGA or image) — ON TOP of avatar
              //    This is the key fix: frame must render after avatar
              //    so the decorative border overlays the avatar correctly.
              if (frameUrl != null && frameUrl!.isNotEmpty)
                Positioned.fill(
                  child: SvgaHelper.isSvgaUrl(frameUrl!)
                      ? SvgaPlayer(
                          url: VideoUtil.getFullSvgaUrl(frameUrl),
                          width: frameSize,
                          height: frameSize,
                          allowAnimation: true,
                          repeat: true,
                        )
                      : CachedNetworkImage(
                          imageUrl: VideoUtil.getFullImageUrl(frameUrl),
                          width: frameSize,
                          height: frameSize,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const SizedBox.shrink(),
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        ),
                ),
              // 4. Badge (bottom-right, on top of everything)
              if (badgeUrl != null && badgeUrl!.isNotEmpty)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: SvgaHelper.isSvgaUrl(badgeUrl!)
                        ? SvgaPlayer(
                            url: VideoUtil.getFullSvgaUrl(badgeUrl),
                            allowAnimation: true,
                            repeat: true,
                          )
                        : CachedNetworkImage(
                            imageUrl: VideoUtil.getFullImageUrl(badgeUrl),
                            fit: BoxFit.contain,
                            placeholder: (_, __) => const SizedBox.shrink(),
                            errorWidget: (_, __, ___) => const SizedBox.shrink(),
                          ),
                  ),
                ),
            ],
          ),
        ),
        if (showName && userName != null && userName!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            userName!,
            style: TextStyle(
              color: nameColor ?? Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAvatar() {
    if (userImage != null && userImage!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: VideoUtil.getFullImageUrl(userImage),
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: Colors.grey.shade800,
          child: const Icon(Icons.person, color: Colors.white54, size: 40),
        ),
        errorWidget: (_, __, ___) => Container(
          color: Colors.grey.shade800,
          child: const Icon(Icons.person, color: Colors.white54, size: 40),
        ),
      );
    }
    return Container(
      color: Colors.grey.shade800,
      child: const Icon(Icons.person, color: Colors.white54, size: 40),
    );
  }
}
