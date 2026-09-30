import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/assigned_tag.dart';
import '../models/guest_profile_root.dart';
import '../models/user_root.dart';
import '../utils/media_utils.dart';
import 'svga_player_widget.dart';

/// Resolves the best VIP badge/level image URL.
///
/// Priority: `vipDetails.tagUrl` > `vipDetails.levelBadgeUrl` > `vipBadgeUrl` > `vip.badgeUrl`.
String? resolveVipBadgeUrl({
  VipDetails? vipDetails,
  VipInfo? vip,
  String? vipBadgeUrl,
}) {
  if (vipDetails?.tagUrl?.isNotEmpty == true) return vipDetails!.tagUrl;
  if (vipDetails?.levelBadgeUrl?.isNotEmpty == true) return vipDetails!.levelBadgeUrl;
  if (vipBadgeUrl?.isNotEmpty == true) return vipBadgeUrl;
  if (vip?.badgeUrl?.isNotEmpty == true) return vip!.badgeUrl;
  return null;
}

/// Renders two rows of profile badges/tags matching Bigo/Chamet parity.
///
/// Row 1 (status): VIP, user level, family, verified, host (mic icon), and
/// the primary role/designation string.
///
/// Row 2 (admin tags): backend `tags` array (Agency, BD, Coin Seller, Super
/// Seller, Super Admin, Official Manager, Region Head, etc.) — shown in a
/// separate row below the status row.
///
/// Every badge renders at a uniform [_kBadgeHeight] — image badges keep their
/// aspect ratio (auto width), text tags render as small pill chips — so badges
/// never appear at mismatched sizes.
///
/// Role tags are **never** auto-derived from `isAgency`, `isBd`, etc. boolean
/// flags — service/role and tag display are fully decoupled.
///
/// `isDark: true` is meant for dark profile headers (white text);
/// `isDark: false` for light cards/sheets (dark text).
class ProfileBadgeRow extends StatelessWidget {
  const ProfileBadgeRow({
    super.key,
    this.tags = const [],
    this.level,
    this.hostLevel,
    this.vipDetails,
    this.vip,
    this.vipBadgeUrl,
    this.vipLevel = 0,
    this.vipLevelName,
    this.isVIP = false,
    this.isVerified = false,
    this.isHost = false,
    this.isBd = false,
    this.isAgency = false,
    this.isCoinSeller = false,
    this.isSuperSeller = false,
    this.isSuperAdmin = false,
    this.isOfficialManager = false,
    this.isRegionHead = false,
    this.familyName,
    this.familyBadgeUrl,
    this.onFamilyTap,
    this.role,
    this.isDark = false,
    this.spacing = 6,
    this.runSpacing = 6,
    this.alignment = WrapAlignment.start,
    this.showLevel = true,
    this.showVerified = true,
  });

  factory ProfileBadgeRow.fromUser(
    User u, {
    bool isDark = false,
    VoidCallback? onFamilyTap,
    WrapAlignment alignment = WrapAlignment.start,
    bool showLevel = true,
    bool showVerified = true,
  }) => ProfileBadgeRow(
        tags: u.tags,
        level: u.level,
        hostLevel: u.hostLevel,
        vipDetails: u.vipDetails,
        vip: u.vip,
        vipBadgeUrl: u.vipBadgeUrl,
        vipLevel: u.vipStatus?.currentLevel ?? 0,
        vipLevelName: u.vipStatus?.currentLevelName,
        isVIP: u.isVIP,
        isVerified: u.isVerified,
        isHost: u.isHost,
        isBd: u.isBd,
        isAgency: u.isAgency,
        isCoinSeller: u.isCoinSeller,
        isSuperSeller: u.isSuperSeller,
        isSuperAdmin: u.isSuperAdmin,
        isOfficialManager: u.isOfficialManager,
        isRegionHead: u.isRegionHead,
        familyName: u.familyName ?? u.family,
        familyBadgeUrl: u.familyBadgeUrl,
        onFamilyTap: onFamilyTap,
        role: u.role,
        isDark: isDark,
        alignment: alignment,
        showLevel: showLevel,
        showVerified: showVerified,
      );

  factory ProfileBadgeRow.fromGuestUser(
    GuestUser u, {
    bool isDark = false,
    VoidCallback? onFamilyTap,
    WrapAlignment alignment = WrapAlignment.start,
    bool showLevel = true,
    bool showVerified = true,
    bool? isVIP,
    String? vipBadgeUrl,
  }) => ProfileBadgeRow(
        tags: u.tags,
        level: u.level,
        hostLevel: u.hostLevel,
        vipDetails: u.vipDetails,
        vip: null,
        vipBadgeUrl: vipBadgeUrl ?? u.vipBadgeUrl,
        vipLevel: u.vipLevel,
        vipLevelName: u.vipLevelName,
        isVIP: isVIP ?? u.isVIP,
        isVerified: u.isVerified,
        isHost: u.isHost,
        isBd: u.isBd,
        isAgency: u.isAgency,
        isCoinSeller: u.isCoinSeller,
        isSuperSeller: u.isSuperSeller,
        isSuperAdmin: u.isSuperAdmin,
        isOfficialManager: u.isOfficialManager,
        isRegionHead: u.isRegionHead,
        familyName: u.familyName ?? u.family,
        familyBadgeUrl: u.familyBadgeUrl,
        onFamilyTap: onFamilyTap,
        role: u.role,
        isDark: isDark,
        alignment: alignment,
        showLevel: showLevel,
        showVerified: showVerified,
      );

  final List<AssignedTag> tags;
  final Level? level;
  final HostLevel? hostLevel;
  final VipDetails? vipDetails;
  final VipInfo? vip;
  final String? vipBadgeUrl;
  final int vipLevel;
  final String? vipLevelName;
  final bool isVIP;
  final bool isVerified;
  final bool isHost;
  final bool isBd;
  final bool isAgency;
  final bool isCoinSeller;
  final bool isSuperSeller;
  final bool isSuperAdmin;
  final bool isOfficialManager;
  final bool isRegionHead;
  final String? familyName;
  final String? familyBadgeUrl;
  final VoidCallback? onFamilyTap;
  final String? role;
  final bool isDark;
  final double spacing;
  final double runSpacing;
  final WrapAlignment alignment;

  /// When false, the user-level badge is skipped — used by cards that already
  /// render the level elsewhere (e.g. the gold "Lv.X" pill) so it isn't
  /// duplicated.
  final bool showLevel;

  /// When false, the "Verified" chip is skipped — used by cards that already
  /// render a verified check next to the name.
  final bool showVerified;

  /// Uniform badge height — every badge (image, pill chip, icon) renders at
  /// this height so nothing looks bigger/smaller than the rest.
  static const double _kBadgeHeight = 20;

  @override
  Widget build(BuildContext context) {
    // One shared dedupe set across both rows — a role string and a backend
    // tag with the same name must not render twice.
    final displayed = <String>{};
    final statusBadges = _buildStatusBadges(displayed);
    final tagBadges = _buildTagBadges(displayed);

    if (statusBadges.isEmpty && tagBadges.isEmpty) return const SizedBox.shrink();
    if (tagBadges.isEmpty) {
      return _badgeWrap(statusBadges);
    }
    if (statusBadges.isEmpty) {
      return _badgeWrap(tagBadges);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _badgeWrap(statusBadges),
        SizedBox(height: runSpacing),
        _badgeWrap(tagBadges),
      ],
    );
  }

  Widget _badgeWrap(List<Widget> badges) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: badges,
    );
  }

  /// Extracts the first digit run from a name ("Lv.12" -> "12") — used to
  /// detect when two different fields carry the same numeric level badge.
  static String? _digits(String? s) =>
      s == null ? null : RegExp(r'\d+').firstMatch(s)?.group(0);

  /// Status row: VIP, user level, family, verified, host (mic), role string.
  List<Widget> _buildStatusBadges(Set<String> displayed) {
    final chips = <Widget>[];

    void addChip(Widget chip, String key) {
      final normalized = key.trim().toLowerCase();
      if (normalized.isEmpty) return;
      if (!displayed.add(normalized)) return;
      chips.add(chip);
    }

    // Image URLs are also registered in `displayed` so a backend tag carrying
    // the same badge image isn't rendered a second time in the tag row.
    void addImageChip(Widget chip, String key, String imageUrl) {
      addChip(chip, key);
      displayed.add(imageUrl.trim().toLowerCase());
    }

    // VIP badge (image or pill chip).
    if (isVIP) {
      final badgeUrl = resolveVipBadgeUrl(
        vipDetails: vipDetails,
        vip: vip,
        vipBadgeUrl: vipBadgeUrl,
      );
      final tier = vipDetails?.tier ??
          vip?.tier ??
          vipLevelName ??
          (vipLevel > 0 ? vipLevel.toString() : '1');
      if (badgeUrl?.isNotEmpty == true) {
        final url = badgeUrl!;
        addImageChip(_badgeImage(url, label: 'VIP $tier'), 'vip $tier', url);
      } else {
        addChip(
          _textChip('VIP $tier', color: const Color(0xFFFFD700), icon: Icons.workspace_premium_rounded),
          'vip $tier',
        );
      }
    }

    // User level (image or pill chip) — the backend badge image is shown
    // even when the name is missing, since the image itself is the tag.
    if (showLevel &&
        (level?.name?.isNotEmpty == true || level?.image?.isNotEmpty == true)) {
      final name = level!.name ?? '';
      final image = level!.image;
      if (image?.isNotEmpty == true) {
        final url = image!;
        addImageChip(
          _badgeImage(url, label: name.isNotEmpty ? 'Lv $name' : 'Level'),
          'lv ${name.isNotEmpty ? name : url}',
          url,
        );
      } else {
        addChip(_textChip('Lv $name', color: const Color(0xFFFF6B9D)), 'lv $name');
      }
    }

    // Host level is never rendered as a badge — the green mic chip is the
    // only host indicator. `hostLevel` is still kept on the widget so tag-row
    // dedupe can drop a backend tag that merely echoes the host level.

    // Family badge.
    final family = familyName ?? '';
    if (family.isNotEmpty) {
      Widget familyBadge;
      if (familyBadgeUrl?.isNotEmpty == true) {
        familyBadge = _badgeImage(familyBadgeUrl!, label: family);
        displayed.add(familyBadgeUrl!.trim().toLowerCase());
      } else {
        familyBadge = _textChip(family, color: const Color(0xFF1E88E5), icon: Icons.shield_rounded);
      }
      if (onFamilyTap != null) {
        familyBadge = GestureDetector(onTap: onFamilyTap, child: familyBadge);
      }
      addChip(familyBadge, family);
    }

    // Verified.
    if (showVerified && isVerified) {
      addChip(
        _textChip('Verified', color: const Color(0xFF4F8DFD), icon: Icons.verified_rounded),
        'verified',
      );
    }

    // Host — mic icon chip.
    if (isHost) addChip(_iconChip(Icons.mic_rounded, color: const Color(0xFF34C759)), 'host');

    // Primary role/designation string, split by comma if multiple.
    // The 7 admin-controlled role tags are filtered out — they only appear
    // from the backend `tags` array below.
    if (role?.isNotEmpty == true) {
      for (final part in role!.split(',')) {
        final r = part.trim();
        if (r.isNotEmpty && !_isAdminControlledRoleTag(r)) {
          addChip(_textChip(_displayRole(r), color: _colorForRole(r)), r);
        }
      }
    }

    return chips;
  }

  /// Tag row: backend-assigned tags/badges only.
  List<Widget> _buildTagBadges(Set<String> displayed) {
    final chips = <Widget>[];

    void addChip(Widget chip, String key) {
      final normalized = key.trim().toLowerCase();
      if (normalized.isEmpty) return;
      if (!displayed.add(normalized)) return;
      chips.add(chip);
    }

    // Backend-assigned tags/badges — images render height-locked, text-only
    // tags render as colored pill chips. A tag that merely mirrors a badge
    // already rendered above (same image URL, or an "Lv.N"-style name echoing
    // the user's level or host level) is skipped.
    final levelNum = _digits(level?.name);
    final hostLevelNum = _digits(hostLevel?.name);
    for (final tag in tags) {
      final name = tag.name?.trim() ?? '';
      final image = tag.image;
      final key = name.isNotEmpty ? name : (image ?? '');
      if (key.isEmpty) continue;
      if (image != null && displayed.contains(image.trim().toLowerCase())) {
        continue;
      }
      final tagNum = _digits(name);
      if (tagNum != null &&
          (tagNum == levelNum || tagNum == hostLevelNum) &&
          RegExp(r'lv|level').hasMatch(name.toLowerCase())) {
        continue;
      }
      if (image?.isNotEmpty == true) {
        addChip(_badgeImage(image!, label: name), key);
      } else if (name.isNotEmpty) {
        addChip(
          _textChip(name, color: _tagColorFor(name), icon: _tagIconFor(name)),
          name,
        );
      }
    }

    return chips;
  }

  /// The 7 role tags whose visibility is admin-controlled via the backend
  /// `tags` array. These must never auto-show from boolean flags or the
  /// `role` string — only from `user.tags`.
  static final Set<String> _adminControlledRoleTags = {
    'agency',
    'bd',
    'coin seller',
    'coinseller',
    'super seller',
    'superseller',
    'super admin',
    'superadmin',
    'official manager',
    'officialmanager',
    'region head',
    'regionhead',
  };

  bool _isAdminControlledRoleTag(String raw) {
    return _adminControlledRoleTags.contains(raw.trim().toLowerCase());
  }

  String _displayRole(String raw) {
    // Convert camelCase / snake_case to readable text.
    final spaced = raw
        .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(0)}')
        .replaceAll(RegExp(r'[_-]'), ' ')
        .trim();
    if (spaced.isEmpty) return raw;
    return spaced
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  Color _colorForRole(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('official')) return const Color(0xFF7B61FF);
    if (lower.contains('region')) return const Color(0xFF4F8DFD);
    if (lower.contains('manager')) return const Color(0xFF6A5AE0);
    if (lower.contains('admin')) return const Color(0xFFE53935);
    return const Color(0xFF6A5AE0);
  }

  /// Renders a badge image height-locked at [_kBadgeHeight] with auto width
  /// (aspect ratio preserved) so wide pill badges and square badges all share
  /// the same visual height. A generous max-width cap prevents ultra-wide
  /// badges from overflowing the row.
  Widget _badgeImage(String imageUrl, {String? label}) {
    final fullUrl = VideoUtil.getFullImageUrl(imageUrl);
    if (fullUrl.isEmpty) {
      if (label?.isNotEmpty == true) return _textChip(label!);
      return const SizedBox.shrink();
    }

    if (SvgaHelper.isSvgaUrl(fullUrl)) {
      // SVGA needs a bounded box — most badge SVGAs are wide pills, so give
      // them a wider box; BoxFit.contain keeps square ones centered.
      const svgaWidth = _kBadgeHeight * 2.6;
      return SizedBox(
        height: _kBadgeHeight,
        width: svgaWidth,
        child: SvgaPlayer(
          url: fullUrl,
          width: svgaWidth,
          height: _kBadgeHeight,
          fit: BoxFit.contain,
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: _kBadgeHeight * 4.5,
        maxHeight: _kBadgeHeight,
      ),
      child: CachedNetworkImage(
        imageUrl: fullUrl,
        height: _kBadgeHeight,
        fit: BoxFit.contain,
        errorWidget: (_, __, ___) => label?.isNotEmpty == true
            ? _textChip(label!)
            : const SizedBox.shrink(),
      ),
    );
  }

  /// Renders a text tag/status as a subtle pill chip at [_kBadgeHeight].
  Widget _textChip(String label, {Color? color, IconData? icon}) {
    final c = color ?? (isDark ? Colors.white : const Color(0xFF1A1A2E));
    return Container(
      height: _kBadgeHeight,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: c.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(_kBadgeHeight / 2),
        border: Border.all(color: c.withValues(alpha: 0.45), width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: c, size: 12),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: c,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  /// Renders a single-icon chip (e.g. host mic) at [_kBadgeHeight].
  Widget _iconChip(IconData icon, {Color? color}) {
    final c = color ?? (isDark ? Colors.white : const Color(0xFF1A1A2E));
    return Container(
      height: _kBadgeHeight,
      width: _kBadgeHeight + 8,
      decoration: BoxDecoration(
        color: c.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(_kBadgeHeight / 2),
        border: Border.all(color: c.withValues(alpha: 0.45), width: 0.6),
      ),
      child: Icon(icon, color: c, size: 13),
    );
  }

  /// Per-tag accent color for well-known admin tag names.
  Color _tagColorFor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('admin')) return const Color(0xFFFF3B30);
    if (lower.contains('official') || lower.contains('manager')) {
      return const Color(0xFF7B61FF);
    }
    if (lower.contains('region')) return const Color(0xFF4F8DFD);
    if (lower.contains('bd')) return const Color(0xFF4F8DFD);
    if (lower.contains('agency')) return const Color(0xFF6A5AE0);
    if (lower.contains('seller')) return const Color(0xFFFFB800);
    if (lower.contains('host')) return const Color(0xFFFF6B9D);
    if (lower.contains('moderator') || lower.contains('mod')) {
      return const Color(0xFF34C759);
    }
    return isDark ? Colors.white : const Color(0xFF1A1A2E);
  }

  /// Per-tag icon for well-known admin tag names.
  IconData _tagIconFor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('admin')) return Icons.shield_rounded;
    if (lower.contains('official') || lower.contains('manager')) {
      return Icons.workspace_premium_rounded;
    }
    if (lower.contains('region')) return Icons.public_rounded;
    if (lower.contains('bd')) return Icons.headset_mic_rounded;
    if (lower.contains('agency')) return Icons.business_rounded;
    if (lower.contains('seller')) return Icons.diamond_rounded;
    if (lower.contains('host')) return Icons.mic_rounded;
    if (lower.contains('moderator') || lower.contains('mod')) {
      return Icons.gavel_rounded;
    }
    return Icons.label_rounded;
  }

}
