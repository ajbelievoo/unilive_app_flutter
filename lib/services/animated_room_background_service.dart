/// Animated Room Backgrounds service — Bigo-style animated/gradient backgrounds
/// for live and audio rooms.
///
/// Provides a catalog of animated backgrounds (gradient flows, particle
/// effects, bokeh, aurora, etc.) that can be applied to any room.
/// Backgrounds are fetched from the backend `/api/v1/room-themes` endpoint
/// (same as ThemePicker) but with an `isAnimated` flag for Lottie/SVGA-based
/// animated backgrounds.
library animated_room_background_service;

import 'package:flutter/material.dart';

import '../utils/log.dart';
import 'api_service.dart';

/// A room background item (static or animated).
class RoomBackground {
  final String id;
  final String name;
  final String previewUrl;
  final String? staticImageUrl;
  final String? animationUrl; // Lottie JSON or SVGA URL for animated backgrounds
  final bool isAnimated;
  final bool isVipExclusive;
  final List<Color> gradientColors; // for gradient-based backgrounds

  const RoomBackground({
    required this.id,
    required this.name,
    required this.previewUrl,
    this.staticImageUrl,
    this.animationUrl,
    this.isAnimated = false,
    this.isVipExclusive = false,
    this.gradientColors = const [Color(0xFF1A1A2E), Color(0xFF16213E)],
  });

  factory RoomBackground.fromJson(Map<String, dynamic> j) => RoomBackground(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        previewUrl: j['previewUrl']?.toString() ?? j['theme']?.toString() ?? '',
        staticImageUrl: j['staticImageUrl']?.toString(),
        animationUrl: j['animationUrl']?.toString(),
        isAnimated: j['isAnimated'] == true,
        isVipExclusive: j['isVipExclusive'] == true,
      );
}

/// Singleton service managing room background state.
class AnimatedRoomBackgroundService {
  static const String _tag = 'AnimatedBg';
  static final AnimatedRoomBackgroundService instance =
      AnimatedRoomBackgroundService._();

  AnimatedRoomBackgroundService._();

  RoomBackground? _activeBackground;
  RoomBackground? get activeBackground => _activeBackground;

  /// Built-in animated gradient backgrounds (fallback when backend has none).
  final List<RoomBackground> _builtinBackgrounds = [
    const RoomBackground(
      id: 'aurora',
      name: 'Aurora',
      previewUrl: '',
      isAnimated: true,
      gradientColors: [Color(0xFF00C9FF), Color(0xFF92FE9D), Color(0xFF00C9FF)],
    ),
    const RoomBackground(
      id: 'sunset',
      name: 'Sunset',
      previewUrl: '',
      isAnimated: true,
      gradientColors: [Color(0xFFFF6B6B), Color(0xFFFFE66D), Color(0xFFEE0979)],
    ),
    const RoomBackground(
      id: 'ocean',
      name: 'Ocean',
      previewUrl: '',
      isAnimated: true,
      gradientColors: [Color(0xFF006994), Color(0xFF004D7A), Color(0xFF001F3F)],
    ),
    const RoomBackground(
      id: 'galaxy',
      name: 'Galaxy',
      previewUrl: '',
      isAnimated: true,
      gradientColors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
    ),
    const RoomBackground(
      id: 'royal',
      name: 'Royal Purple',
      previewUrl: '',
      isAnimated: true,
      gradientColors: [Color(0xFF7E3FF2), Color(0xFFE91E63), Color(0xFF1A1A2E)],
    ),
    const RoomBackground(
      id: 'forest',
      name: 'Forest',
      previewUrl: '',
      isAnimated: true,
      gradientColors: [Color(0xFF134E5E), Color(0xFF71B280), Color(0xFF134E5E)],
    ),
    const RoomBackground(
      id: 'fire',
      name: 'Fire',
      previewUrl: '',
      isAnimated: true,
      gradientColors: [Color(0xFFF12711), Color(0xFFF5AF19), Color(0xFFF12711)],
    ),
    const RoomBackground(
      id: 'midnight',
      name: 'Midnight',
      previewUrl: '',
      isAnimated: true,
      gradientColors: [Color(0xFF0B0B3B), Color(0xFF1B1B4B), Color(0xFF000000)],
    ),
  ];

  List<RoomBackground> get backgrounds =>
      _remoteBackgrounds.isNotEmpty ? _remoteBackgrounds : _builtinBackgrounds;

  List<RoomBackground> _remoteBackgrounds = [];

  /// Fetch backgrounds from the backend, falling back to built-in on failure.
  Future<void> fetchFromBackend() async {
    try {
      final list = await ApiService.getRoomBackgrounds();
      if (list.isNotEmpty) {
        _remoteBackgrounds = list.map((j) => RoomBackground.fromJson(j)).toList();
        Log.d(_tag, 'fetched ${_remoteBackgrounds.length} backgrounds from backend');
      }
    } catch (e) {
      Log.e(_tag, 'fetchFromBackend failed, using built-in', e);
    }
  }

  /// Select a background to activate.
  void selectBackground(RoomBackground? bg) {
    _activeBackground = bg;
    Log.d(_tag, 'background selected: ${bg?.name ?? 'none'}');
  }

  /// Get the active gradient (or default).
  List<Color> get activeGradient =>
      _activeBackground?.gradientColors ??
      [const Color(0xFF1A1A2E), const Color(0xFF16213E)];

  void dispose() {}
}

/// Animated gradient background widget — renders a flowing animated gradient.
/// Used as the base layer in audio/video rooms for Bigo-style animated
/// backgrounds.
class AnimatedRoomBackgroundWidget extends StatefulWidget {
  final List<Color> colors;
  final bool animate;

  const AnimatedRoomBackgroundWidget({
    super.key,
    required this.colors,
    this.animate = true,
  });

  @override
  State<AnimatedRoomBackgroundWidget> createState() =>
      _AnimatedRoomBackgroundWidgetState();
}

class _AnimatedRoomBackgroundWidgetState
    extends State<AnimatedRoomBackgroundWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    if (widget.animate) _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) {
        final t = _ctrl.value;
        // Shift gradient begin/end points for flowing effect.
        final begin = Alignment(t * 2 - 1, -1);
        final end = Alignment(1 - t * 2, 1);
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: end,
              colors: widget.colors,
            ),
          ),
        );
      },
    );
  }
}
