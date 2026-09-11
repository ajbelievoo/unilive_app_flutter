import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routes/navigation_keys.dart' show rootNavigatorKey;

class FloatingLiveService {
  FloatingLiveService._();

  static final FloatingLiveService instance = FloatingLiveService._();

  OverlayEntry? _entry;
  RtcEngine? _engine;
  int? _remoteUid;
  int _localUid = 0;
  String _channelId = '';
  String _name = 'Live';
  String _image = '';
  bool _showLocalVideo = false;
  VoidCallback? _onTap;
  VoidCallback? _onMic;

  final ValueNotifier<bool> isMuted = ValueNotifier(false);

  bool get isShowing => _entry != null;

  void show({
    required BuildContext context,
    required RtcEngine engine,
    required String channelId,
    required String name,
    required String image,
    required bool showLocalVideo,
    required VoidCallback onTap,
    required VoidCallback onMic,
    int? remoteUid,
    int localUid = 0,
    bool muted = false,
  }) {
    _engine = engine;
    _remoteUid = remoteUid;
    _localUid = localUid;
    _channelId = channelId;
    _name = name;
    _image = image;
    _showLocalVideo = showLocalVideo;
    _onTap = onTap;
    _onMic = onMic;
    isMuted.value = muted;

    if (_entry != null) {
      _entry!.markNeedsBuild();
      return;
    }

    final overlay = Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(builder: (_) => _FloatingLiveOverlay(service: this));
    overlay.insert(_entry!);
  }

  void hide() {
    _entry?.remove();
    _entry = null;
    _engine = null;
    _remoteUid = null;
    _onTap = null;
    _onMic = null;
  }

  void popToRoute(String routeName) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    _popToRoute(context, routeName);
  }

  void _popToRoute(BuildContext context, String routeName) {
    final router = GoRouter.of(context);
    if (router.state.name == routeName || !router.canPop()) return;
    router.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nextContext = rootNavigatorKey.currentContext;
      if (nextContext != null) _popToRoute(nextContext, routeName);
    });
  }
}

class _FloatingLiveOverlay extends StatefulWidget {
  const _FloatingLiveOverlay({required this.service});

  final FloatingLiveService service;

  @override
  State<_FloatingLiveOverlay> createState() => _FloatingLiveOverlayState();
}

class _FloatingLiveOverlayState extends State<_FloatingLiveOverlay> {
  Offset? _position;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    _position ??= Offset(
      screen.width - 138,
      screen.height - 246 - padding.bottom,
    );
    final position = _position!;

    return Positioned(
      left: position.dx.clamp(8, screen.width - 130),
      top: position.dy.clamp(
        padding.top + 8,
        screen.height - 194 - padding.bottom,
      ),
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () => widget.service._onTap?.call(),
          onPanUpdate: (details) {
            setState(() {
              final next = _position! + details.delta;
              _position = Offset(
                next.dx.clamp(8, screen.width - 130),
                next.dy.clamp(
                  padding.top + 8,
                  screen.height - 194 - padding.bottom,
                ),
              );
            });
          },
          child: Container(
            width: 122,
            height: 186,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.redAccent, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildVideo(),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.service._name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: widget.service.isMuted,
                        builder:
                            (_, muted, __) => GestureDetector(
                              onTap: () => widget.service._onMic?.call(),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: muted ? Colors.red : Colors.black54,
                                ),
                                child: Icon(
                                  muted ? Icons.mic_off : Icons.mic,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideo() {
    final service = widget.service;
    final engine = service._engine;
    if (engine != null && service._channelId.isNotEmpty) {
      if (service._showLocalVideo) {
        return AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: engine,
            canvas: const VideoCanvas(
              uid: 0,
              renderMode: RenderModeType.renderModeHidden,
              mirrorMode: VideoMirrorModeType.videoMirrorModeEnabled,
            ),
            useFlutterTexture: true,
            useAndroidSurfaceView: false,
          ),
        );
      }
      final remoteUid = service._remoteUid;
      if (remoteUid != null && remoteUid > 0) {
        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: engine,
            canvas: VideoCanvas(
              uid: remoteUid,
              renderMode: RenderModeType.renderModeHidden,
            ),
            connection: RtcConnection(
              channelId: service._channelId,
              localUid: service._localUid,
            ),
            useFlutterTexture: true,
            useAndroidSurfaceView: false,
          ),
        );
      }
    }

    return Container(
      color: const Color(0xFF180C25),
      alignment: Alignment.center,
      child:
          service._image.isEmpty
              ? const Icon(Icons.videocam, color: Colors.white70, size: 34)
              : CachedNetworkImage(
                imageUrl: service._image,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorWidget:
                    (_, __, ___) => const Icon(
                      Icons.videocam,
                      color: Colors.white70,
                      size: 34,
                    ),
              ),
    );
  }
}
