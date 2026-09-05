import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_token_generator/agora_token_generator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/live_user_root.dart' as live_user;
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import '../../utils/media_utils.dart';
import '../../widgets/user_avatar.dart';
import 'package:belive/widgets/preloader.dart';

/// Preview screen shown when a user taps on a live stream from the list.
///
/// Displays the host's cover photo (roomImage) set during live creation.
/// User can:
/// - Swipe left/right to see subscription photos (if subscribed)
/// - Tap photo to open host profile
/// - Follow/unfollow the host
/// - Tap "Enter Live" to join the live stream
/// - Tap "Call" to initiate a call directly
class LivePreviewScreen extends StatefulWidget {
  const LivePreviewScreen({
    super.key,
    required this.user,
  });

  final live_user.LiveUser user;

  @override
  State<LivePreviewScreen> createState() => _LivePreviewScreenState();
}

class _LivePreviewScreenState extends State<LivePreviewScreen> {
  static const String _tag = 'LivePreview';
  bool _isFollowing = false;
  bool _isCheckingFollow = true;
  bool _isSubscribed = false;
  bool _isCheckingSub = true;
  List<String> _subscriptionImages = [];
  int _currentImageIndex = 0;
  bool _isJoining = false;

  // Call rate
  int _callRate = 0;
  bool _isLoadingRate = true;

  // Agora video preview (audio muted)
  RtcEngine? _previewEngine;
  bool _videoPreviewJoined = false;
  int? _remoteUid;
  VideoViewController? _remoteController;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
    _checkSubscriptionStatus();
    _loadCallRate();
    _initVideoPreview();
  }

  @override
  void dispose() {
    _disposeVideoPreview();
    super.dispose();
  }

  Future<void> _loadCallRate() async {
    final hostUserId = widget.user.liveUserId ?? widget.user.id ?? '';
    if (hostUserId.isEmpty) {
      if (mounted) setState(() => _isLoadingRate = false);
      return;
    }
    try {
      final rate = await ApiService.getHostCallRate(hostUserId);
      if (mounted) {
        setState(() {
          _callRate = rate.effectiveRate;
          _isLoadingRate = false;
        });
      }
    } catch (e) {
      Log.e(_tag, 'loadCallRate failed', e);
      if (mounted) setState(() => _isLoadingRate = false);
    }
  }

  Future<void> _initVideoPreview() async {
    try {
      final session = context.read<SessionManager>();
      final appId = session.getSetting()?.agoraKey ?? '';
      final appCert = session.getSetting()?.agoraCertificate;
      final channel = widget.user.channel ?? widget.user.id ?? '';
      final hostAgoraUid = widget.user.agoraUID != 0 ? widget.user.agoraUID : 1;

      if (appId.isEmpty || channel.isEmpty) {
        Log.e(_tag, 'videoPreview: appId or channel empty');
        return;
      }

      _previewEngine = createAgoraRtcEngine();
      await _previewEngine!.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      _previewEngine!.registerEventHandler(RtcEngineEventHandler(
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          Log.d(_tag, 'videoPreview: remote user $remoteUid joined');
          if (remoteUid == hostAgoraUid || _remoteUid == null) {
            if (mounted) {
              setState(() {
                _remoteUid = remoteUid;
                _remoteController = VideoViewController.remote(
                  rtcEngine: _previewEngine!,
                  canvas: VideoCanvas(
                    uid: remoteUid,
                    renderMode: RenderModeType.renderModeHidden,
                  ),
                  connection: RtcConnection(channelId: channel),
                  useFlutterTexture: true,
                  useAndroidSurfaceView: false,
                );
              });
            }
          }
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          Log.d(_tag, 'videoPreview: remote user $remoteUid offline');
          if (mounted) {
            setState(() {
              _remoteUid = null;
              _remoteController = null;
            });
          }
        },
      ));

      await _previewEngine!.setClientRole(role: ClientRoleType.clientRoleAudience);
      await _previewEngine!.enableVideo();
      await _previewEngine!.enableAudio();
      // Mute all remote audio — user should NOT hear audio in preview
      await _previewEngine!.muteAllRemoteAudioStreams(true);

      // Set up remote video controller for host
      _remoteUid = hostAgoraUid;
      _remoteController = VideoViewController.remote(
        rtcEngine: _previewEngine!,
        canvas: VideoCanvas(
          uid: hostAgoraUid,
          renderMode: RenderModeType.renderModeHidden,
        ),
        connection: RtcConnection(channelId: channel),
        useFlutterTexture: true,
        useAndroidSurfaceView: false,
      );

      // Generate token locally (audience with uid=0)
      String token = '';
      if (appCert != null && appCert.isNotEmpty) {
        try {
          token = RtcTokenBuilder.buildTokenWithUid(
            appId: appId,
            appCertificate: appCert,
            channelName: channel,
            uid: 0,
            tokenExpireSeconds: 36000,
          );
        } catch (e) {
          Log.e(_tag, 'videoPreview token gen failed', e);
        }
      }

      await _previewEngine!.joinChannel(
        token: token,
        channelId: channel,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          publishCameraTrack: false,
          publishMicrophoneTrack: false,
          autoSubscribeAudio: false,
          autoSubscribeVideo: true,
        ),
        uid: 0,
      );

      if (mounted) setState(() => _videoPreviewJoined = true);
      Log.d(_tag, 'videoPreview joined channel=$channel, hostUid=$hostAgoraUid');
    } catch (e, s) {
      Log.e(_tag, 'videoPreview init failed', e, s);
    }
  }

  Future<void> _disposeVideoPreview() async {
    try {
      if (_previewEngine != null) {
        await _previewEngine!.leaveChannel();
        await _previewEngine!.release();
        _previewEngine = null;
      }
    } catch (e) {
      Log.e(_tag, 'videoPreview dispose failed', e);
    }
  }

  Future<void> _checkFollowStatus() async {
    final session = context.read<SessionManager>();
    if (session.userId.isEmpty) {
      if (mounted) setState(() => _isCheckingFollow = false);
      return;
    }
    try {
      final res = await ApiService.getGuestProfile(
        widget.user.liveUserId ?? widget.user.id ?? '',
      );
      if (mounted) {
        setState(() {
          _isFollowing = res.user?.isFollow ?? false;
          _isCheckingFollow = false;
        });
      }
    } catch (e) {
      Log.e(_tag, 'checkFollow failed', e);
      if (mounted) setState(() => _isCheckingFollow = false);
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    final session = context.read<SessionManager>();
    if (session.userId.isEmpty) {
      if (mounted) setState(() => _isCheckingSub = false);
      return;
    }
    try {
      final res = await ApiService.checkSubscription(
        userId: session.userId,
        hostUserId: widget.user.liveUserId ?? widget.user.id ?? '',
      );
      if (mounted) {
        setState(() {
          _isSubscribed = res.isSubscribed;
          if (res.subscription != null) {
            _subscriptionImages = res.subscription!.tierImages;
          }
          _isCheckingSub = false;
        });
      }
    } catch (e) {
      Log.e(_tag, 'checkSub failed', e);
      if (mounted) setState(() => _isCheckingSub = false);
    }
  }

  Future<void> _toggleFollow() async {
    final session = context.read<SessionManager>();
    if (session.userId.isEmpty) return;
    setState(() => _isFollowing = !_isFollowing);
    try {
      await ApiService.followUnfollow({
        'userId': session.userId,
        'followingUserId': widget.user.liveUserId ?? widget.user.id ?? '',
      });
      Fluttertoast.showToast(
        msg: _isFollowing ? 'Following ${widget.user.name}' : 'Unfollowed',
      );
    } catch (e) {
      if (mounted) setState(() => _isFollowing = !_isFollowing);
      Log.e(_tag, 'toggleFollow failed', e);
    }
  }

  void _openProfile() {
    final userId = widget.user.liveUserId ?? widget.user.id ?? '';
    if (userId.isEmpty) return;
    context.pushNamed(AppRoutes.guestProfile, extra: {
      'userId': userId,
      'username': widget.user.username,
    });
  }

  void _openSubscriptionSheet() {
    context.pushNamed(AppRoutes.userSubscription, extra: {
      'hostUserId': widget.user.liveUserId ?? widget.user.id ?? '',
      'hostName': widget.user.name ?? 'Host',
      'hostImage': widget.user.image,
    });
  }

  void _initiateCall() {
    final userId = widget.user.liveUserId ?? widget.user.id ?? '';
    if (userId.isEmpty) return;
    _disposeVideoPreview();
    context.pushNamed(AppRoutes.callRequest, extra: {
      'userId2': userId,
      'userName': widget.user.name ?? '',
      'userImage': widget.user.image,
      'isAudioCall': false,
    });
  }

  /// All images to show in the swipeable page view:
  /// 1. Cover photo (roomImage or user image)
  /// 2. Subscription photos (if subscribed)
  List<String> get _allImages {
    final images = <String>[];
    final cover = widget.user.roomImage ?? widget.user.image ?? '';
    if (cover.isNotEmpty) images.add(cover);
    images.addAll(_subscriptionImages);
    return images;
  }

  @override
  Widget build(BuildContext context) {
    final images = _allImages;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background: cover photo / swipeable photos (always full screen)
          if (images.isNotEmpty)
            PageView.builder(
              itemCount: images.length,
              onPageChanged: (i) => setState(() => _currentImageIndex = i),
              itemBuilder: (_, i) {
                return GestureDetector(
                  onTap: _openProfile,
                  child: CachedNetworkImage(
                    imageUrl: VideoUtil.getFullImageUrl(images[i]),
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: Colors.grey.shade900,
                      child: const Center(child: Preloader()),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey.shade900,
                      child: const Icon(Icons.broken_image, color: Colors.white38, size: 48),
                    ),
                  ),
                );
              },
            )
          else
            Container(
              color: Colors.grey.shade900,
              child: const Center(child: Icon(Icons.live_tv, color: Colors.white38, size: 48)),
            ),

          // Small live video preview box (right side, below top bar)
          if (_videoPreviewJoined && _remoteController != null)
            Positioned(
              top: MediaQuery.of(context).viewPadding.top + 52,
              right: 12,
              child: Container(
                width: 120,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.8), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AgoraVideoView(
                      controller: _remoteController!,
                    ),
                    // LIVE badge on top of video box
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility, color: Colors.white, size: 10),
                            SizedBox(width: 2),
                            Text(
                              'LIVE',
                              style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.4, 0.7, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.5),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),

          // Top bar
          _buildTopBar(),

          // Page indicators
          if (images.length > 1) _buildPageIndicators(images.length),

          // Bottom section: host info + actions
          _buildBottomSection(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final topPad = MediaQuery.of(context).viewPadding.top;
    return Positioned(
      top: topPad == 0 ? 12 : topPad + 6,
      left: 8,
      right: 8,
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              _disposeVideoPreview();
              Navigator.pop(context);
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _initiateCall,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    'Call',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  if (!_isLoadingRate && _callRate > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.diamond, color: Colors.amber, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            '$_callRate',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicators(int count) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Positioned(
      bottom: 280 + (bottomPad == 0 ? 0 : bottomPad),
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          count,
          (i) => Container(
            width: i == _currentImageIndex ? 24 : 7,
            height: 7,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: i == _currentImageIndex ? AppTheme.primary : Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Positioned(
      bottom: bottomPad == 0 ? 16 : bottomPad + 10,
      left: 16,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Host info row
          Row(
            children: [
              GestureDetector(
                onTap: _openProfile,
                child: UserAvatar(
                  imageUrl: widget.user.image,
                  size: 48,
                  isVIP: widget.user.isVIP,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _openProfile,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.user.name ?? 'Host',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.user.isVIP)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.verified, color: Color(0xFFFFD54F), size: 16),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.user.view} watching',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Follow button
              if (!_isCheckingFollow && !_isFollowing)
                GestureDetector(
                  onTap: _toggleFollow,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 16),
                  ),
                )
              else if (_isFollowing)
                GestureDetector(
                  onTap: _toggleFollow,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'Following',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Action buttons
          Row(
            children: [
              // Subscribe button
              if (!_isCheckingSub && !_isSubscribed)
                Expanded(
                  child: _actionButton(
                    'Subscribe',
                    Icons.subscriptions,
                    AppTheme.primaryGradient,
                    _openSubscriptionSheet,
                  ),
                )
              else if (_isSubscribed)
                Expanded(
                  child: _actionButton(
                    'Subscribed',
                    Icons.check_circle,
                    const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF4CAF50)]),
                    _openSubscriptionSheet,
                  ),
                ),
              if (!_isCheckingSub && !_isSubscribed)
                const SizedBox(width: 12),
              // Enter Live button
              Expanded(
                flex: 2,
                child: _actionButton(
                  _isJoining ? 'Joining...' : 'Enter Live',
                  Icons.play_arrow,
                  const LinearGradient(
                    colors: [Color(0xFFFF1A79), Color(0xFFFF6B35)],
                  ),
                  _isJoining ? () {} : _enterLive,
                ),
              ),
              const SizedBox(width: 12),
              // Call button with rate
              _callButtonWithRate(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    String label,
    IconData icon,
    Gradient gradient,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _callButtonWithRate() {
    return GestureDetector(
      onTap: _initiateCall,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.videocam, color: Colors.white, size: 22),
          ),
          if (!_isLoadingRate && _callRate > 0)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.diamond, color: Colors.amber, size: 10),
                    const SizedBox(width: 2),
                    Text(
                      '$_callRate',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _enterLive() {
    if (_isJoining) return;
    setState(() => _isJoining = true);
    _disposeVideoPreview();
    // Pop this preview screen and trigger the join logic via the callback
    // The parent (live_list_screen) will handle the actual join
    Navigator.of(context).pop(widget.user);
  }
}
