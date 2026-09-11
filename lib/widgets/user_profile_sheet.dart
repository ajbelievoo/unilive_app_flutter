/// User profile bottom sheet â€” shows a user's profile in a bottom sheet.
///
/// Ports native `UserProfileBottomSheet.java` and `BottomSheetViewersUserProfile.java`.
library user_profile;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../utils/media_utils.dart';
import '../models/guest_profile_root.dart';
import '../widgets/profile_badge_row.dart';
import '../providers/cp_provider.dart';
import '../providers/friend_provider.dart';
import '../routes/app_routes.dart';
import '../services/api_service.dart';
import '../services/live_room_join_service.dart';
import '../services/session_manager.dart';
import '../theme/app_theme.dart';
import '../utils/log.dart';
import '../screens/feed/image_preview_screen.dart';
import 'svga_player_widget.dart' show SvgaPlayer;
import 'package:belive/widgets/preloader.dart';

const String _tag = 'UserProfileSheet';

void showUserProfileSheet(
  BuildContext context, {
  required String userId,
  bool showAdminActions = false,
  VoidCallback? onMakeAdmin,
  VoidCallback? onMute,
  VoidCallback? onKick,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _UserProfileSheet(
      userId: userId,
      showAdminActions: showAdminActions,
      onMakeAdmin: onMakeAdmin,
      onMute: onMute,
      onKick: onKick,
    ),
  );
}

class _UserProfileSheet extends StatefulWidget {
  const _UserProfileSheet({
    required this.userId,
    this.showAdminActions = false,
    this.onMakeAdmin,
    this.onMute,
    this.onKick,
  });

  final String userId;
  final bool showAdminActions;
  final VoidCallback? onMakeAdmin;
  final VoidCallback? onMute;
  final VoidCallback? onKick;

  @override
  State<_UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<_UserProfileSheet> {
  GuestProfileRoot? _profile;
  bool _loading = true;
  bool _isFollowing = false;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService.getGuestProfile(widget.userId);
      if (mounted) {
        setState(() {
          _profile = res;
          _isFollowing = res.user?.isFollow ?? false;
        });
      }
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      final session = context.read<SessionManager>();
      await ApiService.followUnfollow({
        'userId': session.userId,
        'followingUserId': widget.userId,
      });
      if (mounted) setState(() => _isFollowing = !_isFollowing);
    } catch (e, s) {
      Log.e(_tag, 'follow failed', e, s);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final height = MediaQuery.of(context).size.height;

    return Container(
      height: height * 0.5,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surface : AppTheme.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: AppTheme.primary.withValues(alpha: 0.25), blurRadius: 32, offset: const Offset(0, -8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: _loading
            ? const Center(child: Preloader())
            : _profile == null
                ? Center(child: Text('Failed to load', style: TextStyle(color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary)))
                : _body(isDark),
      ),
    );
  }

  Widget _body(bool isDark) {
    final user = _profile!.user;
    if (user == null) {
      return Center(child: Text('User not found', style: TextStyle(color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary)));
    }
    final rawFrameUrl = user.avatarFrameImage ?? user.familyImage;
    final frameUrl = SvgaHelper.isSvgaUrl(rawFrameUrl)
        ? VideoUtil.getFullSvgaUrl(rawFrameUrl)
        : VideoUtil.getFullImageUrl(rawFrameUrl);

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    user.name ?? 'Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              // Avatar + info (with VIP frame overlay + live indicator)
              Center(
                child: GestureDetector(
                  onTap: () {
                    if (user.image != null && user.image!.isNotEmpty) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ImagePreviewScreen(url: user.image!),
                      ));
                    }
                  },
                  child: SizedBox(
                    width: 112,
                    height: 112,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Gradient ring + avatar image
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.purpleGradient,
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: VideoUtil.getFullImageUrl(user.image),
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: 90,
                                height: 90,
                                color: isDark ? AppTheme.surfaceLight : AppTheme.lightBg,
                                child: const Icon(Icons.person, size: 40),
                              ),
                            ),
                          ),
                        ),
                        // VIP avatar frame overlay (SVGA or static image)
                        // Falls back to family frame when VIP frame is not set.
                        if (frameUrl.isNotEmpty)
                          Positioned.fill(
                            child: SvgaHelper.isSvgaUrl(frameUrl)
                                ? SvgaPlayer(
                                    url: frameUrl,
                                    width: 112,
                                    height: 112,
                                    fit: BoxFit.cover,
                                    repeat: true,
                                  )
                                : CachedNetworkImage(
                                    imageUrl: frameUrl,
                                    width: 112,
                                    height: 112,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                                  ),
                          ),
                        // LIVE badge when the user is in a live room
                        if (user.isInLiveRoom)
                          Positioned(
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFFFF512F), Color(0xFFE74C3C)]),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white, width: 1.2),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x66E74C3C), blurRadius: 8, offset: Offset(0, 2)),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle, color: Colors.white, size: 6),
                                  SizedBox(width: 3),
                                  Text('LIVE',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  user.name ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: ProfileBadgeRow.fromGuestUser(
                  user,
                  isDark: isDark,
                  alignment: WrapAlignment.center,
                  onFamilyTap: () {
                    final fid = user.familyId ?? '';
                    if (fid.isNotEmpty) {
                      context.pushNamed(AppRoutes.familyDetail, extra: {'familyId': fid});
                    } else {
                      context.pushNamed(AppRoutes.family);
                    }
                  },
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: user.username ?? ''));
                    Fluttertoast.showToast(msg: 'ID copied');
                  },
                  child: Text(
                    'ID: ${user.username ?? ''}',
                    style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary),
                  ),
                ),
              ),
              if (user.bio != null && user.bio!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    user.bio!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary),
                  ),
                ),
              ],
              // Join Room button — shown when the user is currently in a live room.
              if (user.isInLiveRoom) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF512F), Color(0xFFE74C3C)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Color(0x66E74C3C), blurRadius: 10, offset: Offset(0, 3)),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final room = user.liveRoom!;
                        Navigator.pop(context);
                        await joinLiveRoom(
                          context: context,
                          liveUserId: room.liveUserId!,
                          liveStreamingId: room.liveStreamingId,
                          isAudio: room.isAudio,
                          viaProfileUserId: user.id,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.live_tv, size: 20),
                      label: Text(
                        user.liveRoom?.isHost == true
                            ? 'Join ${user.name ?? 'Host'}\'s Live'
                            : 'Join Room',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _stat(isDark, 'Followers', user.followers),
                  _stat(isDark, 'Following', user.following),
                  _stat(isDark, 'Likes', user.likeCount),
                ],
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _actionLoading ? null : _toggleFollow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFollowing ? null : AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: Icon(_isFollowing ? Icons.check : Icons.add),
                      label: Text(_isFollowing ? 'Following' : 'Follow'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.message, color: AppTheme.primary),
                    style: IconButton.styleFrom(backgroundColor: isDark ? AppTheme.surfaceLight : AppTheme.lightBg),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _showInviteDialog(context),
                    icon: const Icon(Icons.favorite, color: Color(0xFFE84B8A)),
                    style: IconButton.styleFrom(backgroundColor: isDark ? AppTheme.surfaceLight : AppTheme.lightBg),
                    tooltip: 'Invite as CP/Friend',
                  ),
                ],
              ),

              // Admin actions
              if (widget.showAdminActions) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                if (widget.onMakeAdmin != null)
                  ListTile(
                    leading: const Icon(Icons.shield, color: AppTheme.primary),
                    title: const Text('Make Admin'),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onMakeAdmin?.call();
                    },
                  ),
                if (widget.onMute != null)
                  ListTile(
                    leading: const Icon(Icons.mic_off, color: Colors.orange),
                    title: const Text('Mute'),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onMute?.call();
                    },
                  ),
                if (widget.onKick != null)
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Kick'),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onKick?.call();
                    },
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(bool isDark, String label, int count) {
    return Column(
      children: [
        Text(
          _formatCount(count),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary),
        ),
      ],
    );
  }

  String _formatCount(int n) {
    if (n < 1000) return '$n';
    if (n < 1000000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }

  /// Show a bottom sheet to invite the user as CP or Friend.
  void _showInviteDialog(BuildContext context) {
    final session = context.read<SessionManager>();
    // Don't allow inviting yourself
    if (widget.userId == session.userId) {
      Fluttertoast.showToast(msg: 'You cannot invite yourself');
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Invite as',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              // CP option
              _inviteOption(
                context: context,
                icon: Icons.favorite,
                iconColor: const Color(0xFFE84B8A),
                title: 'Become CP',
                subtitle: 'Send a CP request to become a couple',
                onTap: () async {
                  Navigator.pop(ctx);
                  final cp = context.read<CpProvider>();
                  final res = await cp.sendRequest(
                    fromUserId: session.userId,
                    toUserId: widget.userId,
                  );
                  Fluttertoast.showToast(
                    msg: res.ok
                        ? 'CP request sent!'
                        : (res.message ?? 'Failed to send CP request'),
                  );
                },
              ),
              const SizedBox(height: 10),
              // Friend option
              _inviteOption(
                context: context,
                icon: Icons.people_alt,
                iconColor: AppTheme.primary,
                title: 'Become Friend',
                subtitle: 'Send a friend request (max 9 friends)',
                onTap: () async {
                  Navigator.pop(ctx);
                  final friend = context.read<FriendProvider>();
                  if (!friend.canAddMore) {
                    Fluttertoast.showToast(msg: 'Friend slots are full (9/9)');
                    return;
                  }
                  final res = await friend.sendRequest(
                    fromUserId: session.userId,
                    toUserId: widget.userId,
                  );
                  Fluttertoast.showToast(
                    msg: res.ok
                        ? 'Friend request sent!'
                        : (res.message ?? 'Failed to send friend request'),
                  );
                },
              ),
              const SizedBox(height: 16),
              // Open CP/Friend hub
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                    context.pushNamed(AppRoutes.cp);
                  },
                  child: const Text('Open CP/Friend page',
                      style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inviteOption({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}

