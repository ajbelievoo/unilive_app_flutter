/// Live room broadcast/announcement overlay.
///
/// Shows short-duration horizontal banners for:
/// - Gift Broadcast  ("X sent Y a gift x999")
/// - Game Broadcast  ("X won Y coins at game")
/// - Fighter Broadcast ("Room ID:N the fighter is about to launch")
/// - PK Broadcast    ("X got over Y coins support in PK")
/// - Lucky Bag Broadcast ("X send a Y Lucky Bag")
/// - Vehicle Effect  (entry vehicle banner)
/// - Enter Room Effect (welcome with level)
///
/// The overlay respects `EffectSettings` toggles: a banner is only enqueued
/// if its corresponding toggle is enabled.
library live_broadcast_overlay;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/effect_settings_service.dart';
import '../utils/media_utils.dart';

/// A single broadcast event.
class BroadcastEvent {
  BroadcastEvent({
    required this.type,
    required this.title,
    this.subtitle,
    this.avatar,
    this.image,
    this.rightText,
    this.backgroundColor,
    this.textColor = Colors.white,
    this.durationSeconds = 4,
    this.onTap,
  });

  final BroadcastType type;
  final String title;
  final String? subtitle;
  final String? avatar;
  final String? image;
  final String? rightText;
  final Color? backgroundColor;
  final Color textColor;
  final int durationSeconds;
  final VoidCallback? onTap;
}

enum BroadcastType {
  enterRoom,
  enterRoomMessage,
  giftEffect,
  vehicle,
  giftBroadcast,
  gameBroadcast,
  fighterBroadcast,
  pkBroadcast,
  luckyBagBroadcast,
}

class LiveBroadcastOverlay extends StatefulWidget {
  const LiveBroadcastOverlay({super.key});

  @override
  State<LiveBroadcastOverlay> createState() => LiveBroadcastOverlayState();
}

class LiveBroadcastOverlayState extends State<LiveBroadcastOverlay>
    with SingleTickerProviderStateMixin {
  final _queue = <BroadcastEvent>[];
  BroadcastEvent? _current;
  AnimationController? _animator;
  bool _showing = false;

  EffectSettings _effectSettings = EffectSettings();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await EffectSettingsService.instance.getSettings();
    if (mounted) setState(() => _effectSettings = s);
  }

  /// Refresh broadcast visibility settings from the outside (e.g. after the
  /// user returns from the Effect Settings screen).
  void updateSettings(EffectSettings s) {
    if (mounted) setState(() => _effectSettings = s);
  }

  /// Add a broadcast to the queue. Respects effect settings.
  void enqueue(BroadcastEvent event) {
    if (!_isEnabled(event.type)) return;
    if (mounted) {
      setState(() => _queue.add(event));
      if (!_showing) _showNext();
    }
  }

  bool _isEnabled(BroadcastType type) {
    switch (type) {
      case BroadcastType.enterRoomMessage:
        return _effectSettings.showEnterRoomMessage;
      case BroadcastType.enterRoom:
        return _effectSettings.showEnterRoomEffect;
      case BroadcastType.giftEffect:
        return _effectSettings.showGiftEffect;
      case BroadcastType.vehicle:
        return _effectSettings.showVehicleEffect;
      case BroadcastType.giftBroadcast:
        return _effectSettings.showGiftBroadcast;
      case BroadcastType.gameBroadcast:
        return _effectSettings.showGameBroadcast;
      case BroadcastType.fighterBroadcast:
        return _effectSettings.showFighterBroadcast;
      case BroadcastType.pkBroadcast:
        return _effectSettings.showPkBroadcast;
      case BroadcastType.luckyBagBroadcast:
        return _effectSettings.showLuckyBagBroadcast;
    }
  }

  Future<void> _showNext() async {
    if (_queue.isEmpty) {
      setState(() {
        _showing = false;
        _current = null;
      });
      return;
    }
    final next = _queue.removeAt(0);
    _animator?.dispose();
    _animator = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    setState(() {
      _showing = true;
      _current = next;
    });
    _animator!.forward();
    await Future.delayed(Duration(seconds: next.durationSeconds));
    if (!mounted) return;
    _animator?.reverse().then((_) => _showNext());
  }

  @override
  void dispose() {
    _animator?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_current == null) return const SizedBox.shrink();
    final e = _current!;

    // Slide + fade from top.
    final slide = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animator!, curve: Curves.easeOutBack));

    Widget banner;
    switch (e.type) {
      case BroadcastType.fighterBroadcast:
        banner = _fighterBanner(e);
        break;
      case BroadcastType.vehicle:
        banner = _vehicleBanner(e);
        break;
      default:
        banner = _standardBanner(e);
        break;
    }

    return Positioned(
      top: MediaQuery.of(context).viewPadding.top + 80,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: slide,
        child: FadeTransition(opacity: _animator!, child: banner),
      ),
    );
  }

  Widget _standardBanner(BroadcastEvent e) {
    final bg = e.backgroundColor ?? _defaultColor(e.type);
    final textColor = e.textColor;
    final rightIcon = _rightIcon(e.type);
    Widget banner = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bg, bg.withValues(alpha: 0.85)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (e.avatar != null && e.avatar!.isNotEmpty)
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: VideoUtil.getFullImageUrl(e.avatar!),
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                memCacheWidth: 68,
                memCacheHeight: 68,
                errorWidget:
                    (_, __, ___) =>
                        const Icon(Icons.person, color: Colors.white, size: 22),
              ),
            )
          else
            _typeIcon(e.type),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (e.subtitle != null)
                  Text(
                    e.subtitle!,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.9),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (e.image != null && e.image!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child:
                  e.image!.startsWith('assets/')
                      ? Image.asset(
                        e.image!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                      )
                      : CachedNetworkImage(
                        imageUrl: VideoUtil.getFullImageUrl(e.image!),
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
            ),
          if (e.rightText != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                e.rightText!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else if (rightIcon != null)
            Icon(rightIcon, color: textColor, size: 24),
        ],
      ),
    );
    if (e.onTap != null) {
      banner = GestureDetector(
        onTap: e.onTap,
        behavior: HitTestBehavior.opaque,
        child: banner,
      );
    }
    return banner;
  }

  Widget _fighterBanner(BroadcastEvent e) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.blue.withValues(alpha: 0.4), blurRadius: 12),
        ],
      ),
      child: Row(
        children: [
          if (e.avatar != null && e.avatar!.isNotEmpty)
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: VideoUtil.getFullImageUrl(e.avatar!),
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorWidget:
                    (_, __, ___) =>
                        const Icon(Icons.person, color: Colors.white, size: 22),
              ),
            )
          else
            const Icon(Icons.rocket_launch, color: Colors.white, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (e.subtitle != null)
                  Text(
                    e.subtitle!,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (e.image != null && e.image!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: VideoUtil.getFullImageUrl(e.image!),
              width: 42,
              height: 42,
              fit: BoxFit.contain,
              errorWidget:
                  (_, __, ___) => const Icon(
                    Icons.rocket_launch,
                    color: Colors.white,
                    size: 24,
                  ),
            )
          else
            const Icon(Icons.rocket_launch, color: Colors.white, size: 28),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              e.rightText ?? 'GO',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vehicleBanner(BroadcastEvent e) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF424242), Color(0xFF212121)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          if (e.image != null && e.image!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: VideoUtil.getFullImageUrl(e.image!),
              width: 60,
              height: 36,
              fit: BoxFit.contain,
              errorWidget:
                  (_, __, ___) => const Icon(
                    Icons.directions_car,
                    color: Colors.white,
                    size: 28,
                  ),
            )
          else
            const Icon(Icons.directions_car, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (e.subtitle != null)
                  Text(
                    e.subtitle!,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeIcon(BroadcastType type) {
    final icon = switch (type) {
      BroadcastType.giftBroadcast => Icons.card_giftcard,
      BroadcastType.gameBroadcast => Icons.sports_esports,
      BroadcastType.pkBroadcast => Icons.sports_kabaddi,
      BroadcastType.luckyBagBroadcast => Icons.redeem,
      BroadcastType.enterRoom => Icons.stars,
      BroadcastType.enterRoomMessage => Icons.chat_bubble,
      BroadcastType.giftEffect => Icons.card_giftcard,
      BroadcastType.vehicle => Icons.directions_car,
      _ => Icons.notifications,
    };
    return Icon(icon, color: Colors.white, size: 22);
  }

  IconData? _rightIcon(BroadcastType type) {
    return switch (type) {
      BroadcastType.giftBroadcast => Icons.play_circle,
      BroadcastType.gameBroadcast => Icons.sports_esports,
      BroadcastType.fighterBroadcast => Icons.rocket_launch,
      BroadcastType.pkBroadcast => Icons.sports_kabaddi,
      BroadcastType.luckyBagBroadcast => Icons.redeem,
      _ => null,
    };
  }

  Color _defaultColor(BroadcastType type) {
    return switch (type) {
      BroadcastType.giftBroadcast => const Color(0xFF9C27B0),
      BroadcastType.gameBroadcast => const Color(0xFFFFA000),
      BroadcastType.pkBroadcast => const Color(0xFFF44336),
      BroadcastType.luckyBagBroadcast => const Color(0xFFFF6B00),
      BroadcastType.enterRoom => const Color(0xFF43A047),
      BroadcastType.enterRoomMessage => const Color(0xFF78909C),
      BroadcastType.giftEffect => const Color(0xFFE91E63),
      _ => const Color(0xFF7E3FF2),
    };
  }
}
