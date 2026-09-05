import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../utils/media_utils.dart';
import '../widgets/svga_player_widget.dart';

bool _isSupportedAvatarFormat(String url) {
  final lower = url.toLowerCase();
  if (lower.contains('.heic') || lower.contains('.heif')) {
    return false;
  }
  return true;
}

/// Shared avatar widget that shows a user's profile image with optional
/// VIP frame overlay and verified badge.
///
/// Ported from native `UserProfileImageView` usage patterns.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.imageUrl,
    this.frameUrl,
    this.size = 48,
    this.isVerified = false,
    this.isVIP = false,
    this.vipBadgeUrl,
    this.borderRadius,
    this.frameScale = 1.22,
    this.familyFrameUrl,
  });

  final String? imageUrl;
  final String? frameUrl;
  final double size;
  final bool isVerified;
  final bool isVIP;
  final String? vipBadgeUrl;
  final double? borderRadius;

  /// Frame is rendered this much bigger than the avatar image.
  /// Native: avatar=90dp, frame=110dp → 1.22x.
  final double frameScale;

  /// Family profile frame URL — shown as a fallback when [frameUrl] (VIP
  /// frame) is not set. Mirrors Bigo/Chamet family frame perk.
  final String? familyFrameUrl;

  @override
  Widget build(BuildContext context) {
    final r = borderRadius ?? size / 2;
    final fullImageUrl = VideoUtil.getFullImageUrl(imageUrl);
    final fullFrameUrl =
        SvgaHelper.isSvgaUrl(frameUrl)
            ? VideoUtil.getFullSvgaUrl(frameUrl)
            : VideoUtil.getFullImageUrl(frameUrl);
    // Family frame is used as a fallback when no VIP frame is set.
    final effectiveFrameUrl =
        fullFrameUrl.isNotEmpty
            ? fullFrameUrl
            : (SvgaHelper.isSvgaUrl(familyFrameUrl)
                ? VideoUtil.getFullSvgaUrl(familyFrameUrl)
                : VideoUtil.getFullImageUrl(familyFrameUrl));
    final fullBadgeUrl =
        SvgaHelper.isSvgaUrl(vipBadgeUrl)
            ? VideoUtil.getFullSvgaUrl(vipBadgeUrl)
            : VideoUtil.getFullImageUrl(vipBadgeUrl);
    // Frame is bigger than avatar — native: 110dp frame over 90dp avatar
    final frameSize = size * frameScale;
    final frameOverflow = (frameSize - size) / 2;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topLeft,
        children: [
          // Profile image
          ClipRRect(
            borderRadius: BorderRadius.circular(r),
            child:
                (fullImageUrl.isNotEmpty &&
                        _isSupportedAvatarFormat(fullImageUrl))
                    ? CachedNetworkImage(
                      imageUrl: fullImageUrl,
                      fit: BoxFit.cover,
                      width: size,
                      height: size,
                      placeholder:
                          (_, _) => Container(
                            color: Colors.grey.shade300,
                            width: size,
                            height: size,
                          ),
                      errorWidget: (_, __, ___) => _placeholder(size),
                    )
                    : _placeholder(size),
          ),
          // VIP frame overlay — bigger than avatar (native: 110dp frame over 90dp avatar)
          // Falls back to family frame when VIP frame is not set.
          if (effectiveFrameUrl.isNotEmpty)
            Positioned(
              left: -frameOverflow,
              top: -frameOverflow,
              right: -frameOverflow,
              bottom: -frameOverflow,
              child:
                  SvgaHelper.isSvgaUrl(effectiveFrameUrl)
                      ? SvgaPlayer(
                        url: effectiveFrameUrl,
                        width: frameSize,
                        height: frameSize,
                        fit: BoxFit.contain,
                        repeat: true,
                      )
                      : CachedNetworkImage(
                        imageUrl: effectiveFrameUrl,
                        fit: BoxFit.contain,
                        width: frameSize,
                        height: frameSize,
                        errorWidget: (_, _, _) => const SizedBox.shrink(),
                      ),
            ),
          // VIP badge (crown) — shown when isVIP or vipBadgeUrl present.
          if (isVIP || fullBadgeUrl.isNotEmpty)
            Positioned(
              left: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFD54F).withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child:
                    (fullBadgeUrl.isNotEmpty)
                        ? (SvgaHelper.isSvgaUrl(fullBadgeUrl)
                            ? SvgaPlayer(
                              url: fullBadgeUrl,
                              width: size * 0.28,
                              height: size * 0.28,
                              repeat: true,
                            )
                            : ClipRRect(
                              borderRadius: BorderRadius.circular(size * 0.14),
                              child: CachedNetworkImage(
                                imageUrl: fullBadgeUrl,
                                width: size * 0.28,
                                height: size * 0.28,
                                fit: BoxFit.cover,
                                errorWidget:
                                    (_, _, _) => Icon(
                                      Icons.star,
                                      size: size * 0.24,
                                      color: const Color(0xFFFFD54F),
                                    ),
                              ),
                            ))
                        : Icon(
                          Icons.star,
                          size: size * 0.24,
                          color: const Color(0xFFFFD54F),
                        ),
              ),
            ),
          // Verified badge
          if (isVerified)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  Icons.verified,
                  size: size * 0.28,
                  color: Colors.blue,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder(double s) => Container(
    width: s,
    height: s,
    color: const Color(0xFF1A1A2E),
    child: Icon(Icons.person, size: s * 0.55, color: Colors.white24),
  );
}
