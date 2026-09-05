/// Floating call service — shows a draggable video-call overlay (WhatsApp-style
/// Picture-in-Picture) when the active call is minimized, letting the user
/// continue browsing the app while the call runs in the background.
library;

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routes/app_routes.dart';
import '../routes/navigation_keys.dart' show rootNavigatorKey;

/// Singleton that manages the floating 1-on-1 call overlay.
class FloatingCallService {
  FloatingCallService._();
  static final FloatingCallService instance = FloatingCallService._();

  OverlayEntry? _entry;
  bool _isShowing = false;

  RtcEngine? _engine;
  int? _remoteUid;
  int? _localUid;
  String? _channelId;
  String? _userName;
  String? _userImage;
  VoidCallback? _onTap;
  VoidCallback? _onEnd;
  VoidCallback? _onMic;

  /// Current mute state of the call (synced from [ActiveCallScreen]).
  final ValueNotifier<bool> isMuted = ValueNotifier(false);

  /// Current camera state of the call (synced from [ActiveCallScreen]).
  final ValueNotifier<bool> isCameraOff = ValueNotifier(false);

  /// Whether the remote peer's video should be hidden (their privacy guard).
  final ValueNotifier<bool> isPeerFaceHidden = ValueNotifier(false);

  /// Whether the floating overlay is currently visible.
  bool get isShowing => _isShowing;

  /// Show the floating call overlay.
  ///
  /// [engine] — the active Agora [RtcEngine] (must remain alive).
  /// [remoteUid], [localUid], [channelId] — Agora session details.
  /// [userName] / [userImage] — remote user details shown in audio/placeholder.
  /// [onTap] — expand back to the full-screen call.
  /// [onEnd] — end the call.
  /// [onMic] — toggle the microphone.
  void show({
    required BuildContext context,
    required RtcEngine engine,
    int? remoteUid,
    int? localUid,
    String? channelId,
    String? userName,
    String? userImage,
    required VoidCallback onTap,
    required VoidCallback onEnd,
    required VoidCallback onMic,
    bool muted = false,
    bool cameraOff = false,
  }) {
    if (_isShowing) {
      // Update the existing session instead of replacing the overlay.
      _engine = engine;
      _remoteUid = remoteUid;
      _localUid = localUid;
      _channelId = channelId;
      _userName = userName;
      _userImage = userImage;
      _onTap = onTap;
      _onEnd = onEnd;
      _onMic = onMic;
      isMuted.value = muted;
      isCameraOff.value = cameraOff;
      return;
    }

    _engine = engine;
    _remoteUid = remoteUid;
    _localUid = localUid;
    _channelId = channelId;
    _userName = userName;
    _userImage = userImage;
    _onTap = onTap;
    _onEnd = onEnd;
    _onMic = onMic;
    isMuted.value = muted;
    isCameraOff.value = cameraOff;

    final overlay = Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(
      builder: (_) => _FloatingCallOverlay(
        service: this,
      ),
    );
    overlay.insert(_entry!);
    _isShowing = true;
  }

  /// Hide the floating overlay.
  void hide() {
    _entry?.remove();
    _entry = null;
    _isShowing = false;
    _engine = null;
    _remoteUid = null;
    _localUid = null;
    _channelId = null;
    _userName = null;
    _userImage = null;
    _onTap = null;
    _onEnd = null;
    _onMic = null;
  }

  /// Expand the call by popping routes until the active call screen is on top.
  void popToCall() {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    _popToRoute(ctx, AppRoutes.activeCall);
  }

  void _popToRoute(BuildContext context, String routeName) {
    final router = GoRouter.of(context);
    final current = router.state.name;
    if (current == routeName) return;
    if (!router.canPop()) return;

    router.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final newCtx = rootNavigatorKey.currentContext;
      if (newCtx == null) return;
      _popToRoute(newCtx, routeName);
    });
  }
}

/// Draggable floating call overlay widget.
class _FloatingCallOverlay extends StatefulWidget {
  const _FloatingCallOverlay({required this.service});

  final FloatingCallService service;

  @override
  State<_FloatingCallOverlay> createState() => _FloatingCallOverlayState();
}

class _FloatingCallOverlayState extends State<_FloatingCallOverlay> {
  Offset _position = const Offset(20, 200);
  Size _lastSize = Size.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    if (_lastSize != size) {
      _lastSize = size;
      // Default to bottom-right corner.
      _position = Offset(
        size.width - 132,
        size.height - 220 - MediaQuery.of(context).padding.bottom,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _position += details.delta;
              _position = Offset(
                _position.dx.clamp(0, size.width - 130),
                _position.dy.clamp(
                  padding.top,
                  size.height - 190 - padding.bottom,
                ),
              );
            });
          },
          onTap: () => widget.service._onTap?.call(),
          child: Container(
            width: 130,
            height: 190,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildVideoArea(),
                // Top status bar (name + time if available).
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Text(
                      widget.service._userName ?? 'Call',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Bottom control bar.
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Mic toggle.
                        ValueListenableBuilder<bool>(
                          valueListenable: widget.service.isMuted,
                          builder: (_, muted, __) {
                            return _circleButton(
                              icon: muted ? Icons.mic_off : Icons.mic,
                              color: muted ? Colors.red : Colors.white,
                              onTap: () => widget.service._onMic?.call(),
                            );
                          },
                        ),
                        // End call.
                        _circleButton(
                          icon: Icons.call_end,
                          color: Colors.red,
                          onTap: () => widget.service._onEnd?.call(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoArea() {
    final engine = widget.service._engine;
    final remoteUid = widget.service._remoteUid;
    final channelId = widget.service._channelId;
    final localUid = widget.service._localUid;

    if (engine == null || remoteUid == null || channelId == null) {
      return _buildPlaceholder();
    }

    return ValueListenableBuilder<bool>(
      valueListenable: widget.service.isPeerFaceHidden,
      builder: (context, hidden, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: engine,
                canvas: VideoCanvas(
                  uid: remoteUid,
                  renderMode: RenderModeType.renderModeHidden,
                  mirrorMode: VideoMirrorModeType.videoMirrorModeDisabled,
                ),
                connection: RtcConnection(
                  channelId: channelId,
                  localUid: localUid ?? 0,
                ),
                useFlutterTexture: true,
                useAndroidSurfaceView: false,
              ),
            ),
            if (hidden)
              Container(
                color: Colors.black.withValues(alpha: 0.85),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.face_retouching_natural,
                  color: Colors.white70,
                  size: 32,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    final image = widget.service._userImage;
    return Container(
      color: const Color(0xFF1A0A2E),
      alignment: Alignment.center,
      child: image != null && image.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: image,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                placeholder: (_, __) => const _DefaultAvatar(),
                errorWidget: (_, __, ___) => const _DefaultAvatar(),
              ),
            )
          : const _DefaultAvatar(),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  const _DefaultAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFF2A1A3E),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, color: Colors.white54, size: 28),
    );
  }
}
