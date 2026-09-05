/// CP / Friend room entrance overlay — Bigo/Chamet-style "couple enters
/// together" full-screen animation.
///
/// When a user with an active CP/Friend relationship joins a live or audio
/// room, the backend emits a `cpRoomEntry` socket event (see
/// `docs/CP_FRIEND_BACKEND_REMAINING.md` § "CP/Friend room entrance"). This
/// overlay plays:
///   - A full-screen SVGA entrance animation (from the CP level's
///     `entranceAnimationUrl` asset).
///   - A banner showing both partners' avatars face-to-face + names + the
///     relationship badge chip + bond level.
///
/// Falls back to a simple gradient banner when no SVGA asset is configured.
library cp_entry_overlay;

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'svga_player_widget.dart';
import 'relationship_badge.dart';

/// Data for a CP/Friend room entrance event.
class CpEntryData {
  final String userId;
  final String userName;
  final String? userImage;
  final String? partnerId;
  final String? partnerName;
  final String? partnerImage;
  final String? relationshipType; // 'cp' | 'friend'
  final int? cpLevel;
  final int? friendLevel;
  final String? entranceSvgaUrl; // full-screen SVGA
  final String? badgeUrl; // CP/Friend badge image
  final String? frameUrl; // avatar frame

  CpEntryData({
    required this.userId,
    required this.userName,
    this.userImage,
    this.partnerId,
    this.partnerName,
    this.partnerImage,
    this.relationshipType,
    this.cpLevel,
    this.friendLevel,
    this.entranceSvgaUrl,
    this.badgeUrl,
    this.frameUrl,
  });

  bool get isCp => relationshipType?.toLowerCase() == 'cp';

  factory CpEntryData.fromSocketJson(Map<String, dynamic> json) {
    final user = json['user'] is Map ? json['user'] as Map<String, dynamic> : null;
    final cpDetails = json['cpDetails'] is Map
        ? json['cpDetails'] as Map<String, dynamic>
        : (user?['cpDetails'] is Map
            ? user!['cpDetails'] as Map<String, dynamic>
            : null);
    return CpEntryData(
      userId: json['userId']?.toString() ?? user?['_id']?.toString() ?? '',
      userName: json['userName']?.toString() ?? user?['name']?.toString() ?? '',
      userImage: json['image']?.toString() ?? user?['image']?.toString(),
      partnerId: json['partnerId']?.toString() ?? cpDetails?['partnerId']?.toString(),
      partnerName: json['partnerName']?.toString() ??
          cpDetails?['partnerName']?.toString(),
      partnerImage: json['partnerImage']?.toString() ??
          cpDetails?['partnerImage']?.toString(),
      relationshipType: json['relationshipType']?.toString() ??
          cpDetails?['relationshipType']?.toString() ??
          user?['relationshipType']?.toString(),
      cpLevel: _parseInt(json['cpLevel'] ?? user?['cpLevel'] ?? cpDetails?['cpLevel']),
      friendLevel: _parseInt(
          json['friendLevel'] ?? user?['friendLevel'] ?? cpDetails?['friendLevel']),
      entranceSvgaUrl: json['entranceSvgaUrl']?.toString() ??
          cpDetails?['entranceAnimationUrl']?.toString(),
      badgeUrl: json['cpBadgeUrl']?.toString() ??
          cpDetails?['badgeUrl']?.toString(),
      frameUrl: json['cpFrameUrl']?.toString() ??
          cpDetails?['frameUrl']?.toString(),
    );
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}

class CpEntryOverlay extends StatefulWidget {
  const CpEntryOverlay({super.key});

  @override
  State<CpEntryOverlay> createState() => CpEntryOverlayState();
}

class CpEntryOverlayState extends State<CpEntryOverlay>
    with TickerProviderStateMixin {
  final _queue = <CpEntryData>[];
  bool _playing = false;
  CpEntryData? _current;
  Timer? _timer;
  Timer? _pauseTimer;

  late final AnimationController _inController;
  late final AnimationController _outController;
  late Animation<Offset> _slideIn;
  late Animation<double> _fadeIn;
  late Animation<double> _fadeOut;
  late Animation<Offset> _slideOut;

  @override
  void initState() {
    super.initState();
    _inController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideIn = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _inController, curve: Curves.easeOutCubic));
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _inController, curve: Curves.easeOut),
    );

    _outController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideOut = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, -1.0),
    ).animate(CurvedAnimation(parent: _outController, curve: Curves.easeInCubic));
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _outController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pauseTimer?.cancel();
    _inController.dispose();
    _outController.dispose();
    super.dispose();
  }

  void addEntry(CpEntryData entry) {
    if (_queue.any((e) => e.userId == entry.userId) ||
        _current?.userId == entry.userId) {
      return;
    }
    _queue.add(entry);
    _triggerNext();
  }

  void _triggerNext() {
    if (_playing || _queue.isEmpty || !mounted) return;
    _playing = true;
    _current = _queue.removeAt(0);

    _inController.reset();
    _outController.reset();

    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 15), () => _reset());

    _inController.forward(from: 0.0).then((_) {
      if (!mounted || !_playing) return;
      _pauseTimer?.cancel();
      _pauseTimer = Timer(const Duration(milliseconds: 4500), () {
        if (!mounted || !_playing) return;
        _outController.forward(from: 0.0).then((_) => _reset());
      });
    });
    setState(() {});
  }

  void _reset() {
    if (!mounted) return;
    _timer?.cancel();
    _pauseTimer?.cancel();
    _timer = null;
    _pauseTimer = null;
    setState(() {
      _playing = false;
      _current = null;
    });
    _inController.reset();
    _outController.reset();
    _triggerNext();
  }

  @override
  Widget build(BuildContext context) {
    if (!_playing || _current == null) return const SizedBox.shrink();
    final e = _current!;
    final screen = MediaQuery.of(context).size;
    final isCp = e.isCp;
    final accent = isCp ? const Color(0xFFE91E63) : const Color(0xFF03A9F4);
    final accentLight = isCp ? const Color(0xFFF48FB1) : const Color(0xFF81D4FA);

    return Positioned.fill(
      child: IgnorePointer(
        child: SlideTransition(
          position: _outController.isAnimating ? _slideOut : _slideIn,
          child: FadeTransition(
            opacity: _outController.isAnimating ? _fadeOut : _fadeIn,
            child: Stack(
              alignment: Alignment.topLeft,
              children: [
                // Full-screen SVGA entrance animation
                if ((e.entranceSvgaUrl ?? '').isNotEmpty)
                  Positioned.fill(
                    child: SvgaPlayer(
                      url: e.entranceSvgaUrl!,
                      width: screen.width,
                      height: screen.height,
                    ),
                  ),
                // Banner with both avatars + names
                Positioned(
                  top: screen.height * 0.18,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black.withValues(alpha: 0.75),
                            accent.withValues(alpha: 0.55),
                            Colors.black.withValues(alpha: 0.75),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: accent.withValues(alpha: 0.6), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Avatars face-to-face
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _avatar(e.userImage, e.frameUrl),
                              const SizedBox(width: 8),
                              Icon(Icons.favorite,
                                  color: accentLight, size: 22),
                              const SizedBox(width: 8),
                              _avatar(e.partnerImage, null),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Names
                          Text(
                            '${e.userName} & ${e.partnerName ?? 'Partner'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                    color: Colors.black54,
                                    blurRadius: 4,
                                    offset: Offset(1, 1)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Relationship badge + level
                          RelationshipBadge(
                            type: isCp ? 'cp' : 'friend',
                            level: isCp ? (e.cpLevel ?? 1) : (e.friendLevel ?? 1),
                            size: 18,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isCp
                                ? 'entered the room as a couple'
                                : 'entered the room as friends',
                            style: TextStyle(
                              color: accentLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
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

  Widget _avatar(String? url, String? frameUrl) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if ((frameUrl ?? '').isNotEmpty)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: frameUrl!,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ClipOval(
            child: (url ?? '').isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: url!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                        width: 56, height: 56, color: Colors.grey.shade800),
                    errorWidget: (_, __, ___) => Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey.shade800,
                      child: const Icon(Icons.person,
                          color: Colors.white54, size: 28),
                    ),
                  )
                : Container(
                    width: 56,
                    height: 56,
                    color: Colors.grey.shade800,
                    child: const Icon(Icons.person,
                        color: Colors.white54, size: 28),
                  ),
          ),
        ],
      ),
    );
  }
}
