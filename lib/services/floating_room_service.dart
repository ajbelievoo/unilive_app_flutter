/// Floating room service — shows a draggable circular floating bubble overlay
/// when the audio room is minimized, allowing the user to return to the room
/// from anywhere in the app.
///
/// The bubble shows the room host avatar with a pulsing wave ring.
library floating_room_service;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routes/navigation_keys.dart' show rootNavigatorKey;
import '../widgets/mic_wave_widget.dart';

/// Singleton that manages the floating room bubble overlay.
class FloatingRoomService {
  FloatingRoomService._();
  static final FloatingRoomService instance = FloatingRoomService._();

  OverlayEntry? _entry;
  bool _isShowing = false;

  /// Whether the floating bubble is currently visible.
  bool get isShowing => _isShowing;

  /// Show the floating bubble. Call this when the user minimizes the room.
  ///
  /// [roomName] is displayed on the bubble.
  /// [roomImage] is shown as the bubble avatar.
  /// [onTap] is called when the user taps the bubble (e.g. navigate back).
  /// [onClose] is called when the user dismisses the bubble.
  void show({
    required BuildContext context,
    required String roomName,
    String? roomImage,
    required VoidCallback onTap,
    required VoidCallback onClose,
  }) {
    if (_isShowing) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(
      builder: (_) => _FloatingBubble(
        roomImage: roomImage,
        onTap: () {
          hide();
          onTap();
        },
        onClose: () {
          hide();
          onClose();
        },
      ),
    );
    overlay.insert(_entry!);
    _isShowing = true;
  }

  /// Hide the floating bubble. Call this when the user returns to the room
  /// or the room ends.
  void hide() {
    _entry?.remove();
    _entry = null;
    _isShowing = false;
  }

  /// Pop the navigation stack until [routeName] becomes the current route.
  /// Used by the floating bubble to return to the room even when the user
  /// has opened several screens on top of it.
  void popToRoute(String routeName) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    _popToRoute(ctx, routeName);
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

/// The floating bubble widget — draggable circular avatar with a pulsing
/// wave ring, tap to return to the room, X to dismiss.
class _FloatingBubble extends StatefulWidget {
  const _FloatingBubble({
    this.roomImage,
    required this.onTap,
    required this.onClose,
  });

  final String? roomImage;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  State<_FloatingBubble> createState() => _FloatingBubbleState();
}

class _FloatingBubbleState extends State<_FloatingBubble> {
  Offset _position = const Offset(20, 200);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start at bottom-right, above system navigation.
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    _position = Offset(size.width - 72, size.height - 72 - padding.bottom - 16);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    const bubbleSize = 64.0;
    const waveSize = 84.0;

    return Positioned(
      left: _position.dx.clamp(8, size.width - bubbleSize - 8),
      top: _position.dy.clamp(padding.top + 8, size.height - bubbleSize - padding.bottom - 8),
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
            _position = Offset(
              _position.dx.clamp(8.0, size.width - bubbleSize - 8),
              _position.dy.clamp(padding.top + 8.0, size.height - bubbleSize - padding.bottom - 8),
            );
          });
        },
        onTap: widget.onTap,
        child: SizedBox(
          width: waveSize,
          height: waveSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing wave ring behind the bubble.
              const SeatPulseWave(size: waveSize, color: Color(0xFF00E5FF)),
              // Circular avatar bubble.
              Container(
                width: bubbleSize,
                height: bubbleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  border: Border.all(color: const Color(0xFF00E5FF), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.45),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: (widget.roomImage ?? '').isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.roomImage!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Icon(
                            Icons.graphic_eq,
                            color: Colors.white,
                            size: 24,
                          ),
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.graphic_eq,
                            color: Colors.white,
                            size: 24,
                          ),
                        )
                      : const Icon(
                          Icons.graphic_eq,
                          color: Colors.white,
                          size: 24,
                        ),
                ),
              ),
              // Close (X) button in top-right of the wave.
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30, width: 0.5),
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
