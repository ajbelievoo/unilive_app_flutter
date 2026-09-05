import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/cp_provider.dart';
import '../../providers/friend_provider.dart';
import '../../providers/minimized_live_provider.dart';
import '../../providers/notification_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/audio_room_navigation.dart';
import '../../utils/log.dart';
import '../../widgets/user_avatar.dart';
import '../chat/message_hub_screen.dart';
import '../feed/posts_feed_screen.dart';
import '../live/live_list_screen.dart';
import '../profile/profile_screen.dart';

/// Ported from native `MainActivity.java`.
///
/// Premium bottom navigation with center Go-Live FAB (Bigo Live style).
/// 4 side tabs + center live button.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;
  final GlobalKey<LiveListScreenState> _liveListKey =
      GlobalKey<LiveListScreenState>();
  static const String _tag = 'MainScreen';

  @override
  void initState() {
    super.initState();
    _loadNotificationCount();
    _loadAds();
    _loadRelationships();
  }

  /// Pre-load the user's CP and Friend list so room visibility (badges,
  /// entrance animations) and CP/Friend-exclusive gift gating work without
  /// first visiting the CP screen.
  Future<void> _loadRelationships() async {
    try {
      final session = context.read<SessionManager>();
      if (session.userId.isEmpty) return;
      final cp = context.read<CpProvider>();
      final friend = context.read<FriendProvider>();
      await Future.wait([
        cp.loadMyCP(session.userId),
        friend.loadFriends(session.userId),
      ]);
    } catch (e) {
      Log.e(_tag, 'loadRelationships failed', e);
    }
  }

  Future<void> _loadNotificationCount() async {
    final session = context.read<SessionManager>();
    final notifProvider = context.read<NotificationProvider>();
    await notifProvider.loadNotifications(session.userId);
  }

  Future<void> _loadAds() async {
    try {
      final res = await ApiService.getAds();
      if (res.advertisement != null && res.advertisement!.show) {
        Log.i(
          _tag,
          'Ads enabled: banner=${res.advertisement!.banner}, interstitial=${res.advertisement!.interstitial}',
        );
      }
    } catch (e, s) {
      Log.e(_tag, 'loadAds failed', e, s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      LiveListScreen(key: _liveListKey),
      const PostsFeedScreen(),
      const MessageHubScreen(),
      const ProfileScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _showExitConfirmation(context);
        if (shouldExit == true && mounted) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          alignment: Alignment.topLeft,
          index: _index,
          children: tabs,
        ),
        extendBody: true,
        bottomNavigationBar: _buildBottomNav(context),
        floatingActionButton: _buildMinimizedLiveBox(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final notifProvider = context.watch<NotificationProvider>();
    final unread = notifProvider.unreadCount;
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, -10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.background.withValues(alpha: 0.78),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _navItem(Icons.explore_outlined, Icons.explore, 'Live', 0),
                    _navItem(
                      Icons.dynamic_feed_outlined,
                      Icons.dynamic_feed,
                      'Feed',
                      1,
                    ),
                    // Center FAB — Go Live.
                    _centerFab(),
                    _navItem(
                      Icons.chat_outlined,
                      Icons.chat,
                      'Message',
                      2,
                      badge: unread,
                    ),
                    _navItem(Icons.person_outline, Icons.person, 'Profile', 3),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    IconData outlineIcon,
    IconData filledIcon,
    String label,
    int index, {
    int badge = 0,
  }) {
    final selected = _index == index;
    return GestureDetector(
      onTap: () {
        setState(() => _index = index);
        // Whenever the Live (home) tab becomes active, reset to the "All"
        // tab and silently refresh so the user always sees fresh content.
        if (index == 0) {
          _liveListKey.currentState?.refreshHome();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (selected)
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.25),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                Icon(
                  selected ? filledIcon : outlineIcon,
                  color: selected ? AppTheme.primary : AppTheme.textTertiary,
                  size: selected ? 26 : 24,
                ),
                if (badge > 0)
                  Positioned(
                    right: -10,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.primary : AppTheme.textTertiary,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _centerFab() {
    return GestureDetector(
      onTap: () => _showGoLiveOptions(context),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            // Outer brand glow.
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.55),
              blurRadius: 26,
              spreadRadius: 3,
              offset: const Offset(0, 8),
            ),
            // 3D depth shadow.
            BoxShadow(
              color: AppTheme.primaryDark.withValues(alpha: 0.5),
              blurRadius: 14,
              offset: const Offset(0, 10),
            ),
            // Top highlight for convex 3D look.
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }

  Widget? _buildMinimizedLiveBox() {
    final minLive = context.watch<MinimizedLiveProvider>();
    if (!minLive.hasMinimizedLive) return null;

    final user = minLive.liveUser!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 72),
      child: GestureDetector(
        onTap: () {
          final u = minLive.liveUser!;
          final isHost = minLive.isHost;
          minLive.clear();
          context.pushNamed(
            AppRoutes.liveRoom,
            extra: {'liveUser': u, 'isHost': isHost},
          );
        },
        child: Container(
          width: 140,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.primary, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
                child: UserAvatar(
                  imageUrl: user.image,
                  size: 48,
                  isVIP: user.isVIP,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.name ?? 'Host',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.play_circle_fill,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showExitConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder:
          (ctx) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 30,
                      spreadRadius: 4,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.45),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.logout,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Exit App',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Are you sure you want to close the app?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(ctx, false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: AppTheme.surfaceLight,
                                border: Border.all(
                                  color: AppTheme.textTertiary.withValues(
                                    alpha: 0.25,
                                  ),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'No',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(ctx, true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: AppTheme.primaryGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.45,
                                    ),
                                    blurRadius: 16,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'Yes',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  void _showGoLiveOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Create',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.add_photo_alternate,
                      color: AppTheme.primary,
                    ),
                    title: const Text('Create Post'),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.pushNamed(AppRoutes.createPost);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.videocam,
                      color: AppTheme.primary,
                    ),
                    title: const Text('Video Live'),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.pushNamed(AppRoutes.goLive);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.mic, color: AppTheme.primary),
                    title: const Text('Audio Live'),
                    onTap: () {
                      Navigator.pop(ctx);
                      AudioRoomNavigation.openAudioRoomOrCreate(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.video_call,
                      color: AppTheme.primary,
                    ),
                    title: const Text('Random Call'),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.pushNamed(AppRoutes.randomCall);
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
    );
  }
}
