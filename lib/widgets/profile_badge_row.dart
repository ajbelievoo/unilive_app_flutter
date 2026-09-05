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
/// the primary role/designation string — all rendered without a bubble box.
///
/// Row 2 (admin tags): backend `tags` array (Agency, BD, Coin Seller, Super
/// Seller, Super Admin, Official Manager, Region Head, etc.) — shown as-is
/// without a bubble box, in a separate row below the status row.
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
  });

  factory ProfileBadgeRow.fromUser(
    User u, {
    bool isDark = false,
    VoidCallback? onFamilyTap,
    WrapAlignment alignment = WrapAlignment.start,
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
      );

  factory ProfileBadgeRow.fromGuestUser(
    GuestUser u, {
    bool isDark = false,
    VoidCallback? onFamilyTap,
    WrapAlignment alignment = WrapAlignment.start,
  }) => ProfileBadgeRow(
        tags: u.tags,
        level: u.level,
        hostLevel: u.hostLevel,
        vipDetails: u.vipDetails,
        vip: null,
        vipBadgeUrl: u.vipBadgeUrl,
        vipLevel: u.vipLevel,
        vipLevelName: u.vipLevelName,
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

  @override
  Widget build(BuildContext context) {
    final statusBadges = _buildStatusBadges();
    final tagBadges = _buildTagBadges();

    if (statusBadges.isEmpty && tagBadges.isEmpty) return const SizedBox.shrink();
    if (tagBadges.isEmpty) {
      return Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        alignment: alignment,
        children: statusBadges,
      );
    }
    if (statusBadges.isEmpty) {
      return Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        alignment: alignment,
        children: tagBadges,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          alignment: alignment,
          children: statusBadges,
        ),
        SizedBox(height: runSpacing),
        Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          alignment: alignment,
          children: tagBadges,
        ),
      ],
    );
  }

  /// Status row: VIP, user level, family, verified, host (mic), role string.
  /// Rendered without bubble/chip containers.
  List<Widget> _buildStatusBadges() {
    final displayed = <String>{};
    final chips = <Widget>[];

    void addChip(Widget chip, String key) {
      final normalized = key.trim().toLowerCase();
      if (normalized.isEmpty) return;
      if (displayed.contains(normalized)) return;
      displayed.add(normalized);
      chips.add(chip);
    }

    // VIP badge (image or text) — no box.
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
        addChip(_statusImage(badgeUrl!, label: 'VIP $tier'), 'vip');
      } else {
        addChip(_statusText('VIP $tier', color: const Color(0xFFFFD700)), 'vip');
      }
    }

    // User level (image or text) — no box.
    if (level?.name?.isNotEmpty == true) {
      final name = level!.name!;
      final image = level!.image;
      if (image?.isNotEmpty == true) {
        addChip(_statusImage(image!, label: 'Lv $name'), 'level_$name');
      } else {
        addChip(_statusText('Lv $name', color: const Color(0xFFFF6B9D)), 'level_$name');
      }
    }

    // Family badge — no box.
    final family = familyName ?? '';
    if (family.isNotEmpty) {
      Widget familyBadge;
      if (familyBadgeUrl?.isNotEmpty == true) {
        familyBadge = _statusImage(familyBadgeUrl!, label: family);
      } else {
        familyBadge = _statusText(family, color: const Color(0xFF1E88E5), icon: Icons.shield);
      }
      if (onFamilyTap != null) {
        familyBadge = GestureDetector(onTap: onFamilyTap, child: familyBadge);
      }
      addChip(familyBadge, 'family_$family');
    }

    // Verified — no box.
    if (isVerified) {
      addChip(_statusText('Verified', color: const Color(0xFF4F8DFD), icon: Icons.verified), 'verified');
    }

    // Host — mic icon only, no box.
    if (isHost) addChip(_statusIcon(Icons.mic, color: const Color(0xFF34C759)), 'host');

    // Primary role/designation string, split by comma if multiple.
    // The 7 admin-controlled role tags are filtered out — they only appear
    // from the backend `tags` array below.
    if (role?.isNotEmpty == true) {
      for (final part in role!.split(',')) {
        final r = part.trim();
        if (r.isNotEmpty && !_isAdminControlledRoleTag(r)) {
          addChip(_statusText(_displayRole(r), color: _colorForRole(r)), 'role_$r');
        }
      }
    }

    return chips;
  }

  /// Tag row: backend-assigned tags/badges only, as-is, no bubble.
  List<Widget> _buildTagBadges() {
    final displayed = <String>{};
    final chips = <Widget>[];

    void addChip(Widget chip, String key) {
      final normalized = key.trim().toLowerCase();
      if (normalized.isEmpty) return;
      if (displayed.contains(normalized)) return;
      displayed.add(normalized);
      chips.add(chip);
    }

    // Backend-assigned tags/badges — show as-is without bubble/chip styling.
    for (final tag in tags) {
      final name = tag.name?.trim() ?? '';
      final image = tag.image;
      final key = name.isNotEmpty ? name : (image ?? '');
      if (key.isEmpty) continue;
      if (image?.isNotEmpty == true) {
        addChip(_tagImage(image!, label: name), 'tag_$key');
      } else if (name.isNotEmpty) {
        addChip(_tagText(name), 'tag_$name');
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

  /// Renders a backend tag image directly (no bubble/chip container).
  Widget _tagImage(String imageUrl, {String? label, double size = 28}) {
    final fullUrl = VideoUtil.getFullImageUrl(imageUrl);
    if (fullUrl.isEmpty) {
      if (label?.isNotEmpty == true) return _tagText(label!);
      return const SizedBox.shrink();
    }
    final isSvga = SvgaHelper.isSvgaUrl(fullUrl);

    final imageWidget = isSvga
        ? SizedBox(
            width: size,
            height: size,
            child: SvgaPlayer(url: fullUrl, width: size, height: size, fit: BoxFit.contain),
          )
        : CachedNetworkImage(
            imageUrl: fullUrl,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorWidget: (_, __, ___) => label?.isNotEmpty == true ? _tagText(label!) : const SizedBox.shrink(),
          );

    return imageWidget;
  }

  /// Renders a backend tag name as plain text (no chip/bubble).
  Widget _tagText(String label) {
    return Text(
      label,
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// Renders a status image directly (no bubble/chip container).
  Widget _statusImage(String imageUrl, {String? label}) {
    return _tagImage(imageUrl, label: label);
  }

  /// Renders a status text label (no bubble/chip container).
  Widget _statusText(String label, {Color? color, IconData? icon}) {
    final hasIcon = icon != null;
    final textColor = color ?? (isDark ? Colors.white : const Color(0xFF1A1A2E));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasIcon) ...[
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 3),
        ],
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Renders a status icon directly (no bubble/chip container).
  Widget _statusIcon(IconData icon, {Color? color}) {
    return Icon(
      icon,
      color: color ?? (isDark ? Colors.white : const Color(0xFF1A1A2E)),
      size: 22,
    );
  }

}
