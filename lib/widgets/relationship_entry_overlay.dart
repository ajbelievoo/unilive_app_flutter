import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../utils/media_utils.dart';
import 'relationship_badge.dart';

/// Entry data for a CP or Friend joining the room.
class RelationshipEntryData {
  final String userId;
  final String userName;
  final String? userImage;
  final String? relationshipType;
  final int level;

  RelationshipEntryData({
    required this.userId,
    required this.userName,
    this.userImage,
    this.relationshipType,
    this.level = 1,
  });
}

/// Relationship entry overlay — shows a slide-in banner when a CP or Friend joins.
class RelationshipEntryOverlay extends StatefulWidget {
  const RelationshipEntryOverlay({super.key});

  @override
  State<RelationshipEntryOverlay> createState() => RelationshipEntryOverlayState();
}

class RelationshipEntryOverlayState extends State<RelationshipEntryOverlay>
    with SingleTickerProviderStateMixin {
  final _entryQueue = <RelationshipEntryData>[];
  bool _isPlaying = false;
  RelationshipEntryData? _currentEntry;
  Timer? _timeoutTimer;
  late AnimationController _controller;
  late Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideIn = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _controller.dispose();
    super.dispose();
  }

  void addEntry(RelationshipEntryData entry) {
    final alreadyQueued =
        _entryQueue.any((e) => e.userId == entry.userId) ||
            (_currentEntry?.userId == entry.userId);
    if (alreadyQueued) return;
    _entryQueue.add(entry);
    _triggerNext();
  }

  void _triggerNext() {
    if (_isPlaying || _entryQueue.isEmpty || !mounted) return;
    _isPlaying = true;
    _currentEntry = _entryQueue.removeAt(0);

    // 15s safety timeout to force-reset stuck animations.
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted) return;
      _isPlaying = false;
      _currentEntry = null;
      _controller.reset();
      setState(() {});
      _triggerNext();
    });

    _controller.forward(from: 0.0).then((_) {
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 3000), () {
        if (!mounted) return;
        _controller.reverse().then((_) {
          if (!mounted) return;
          _timeoutTimer?.cancel();
          _timeoutTimer = null;
          setState(() {
            _isPlaying = false;
            _currentEntry = null;
          });
          _triggerNext();
        });
      });
    });

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPlaying || _currentEntry == null) return const SizedBox.shrink();

    final entry = _currentEntry!;
    final isCp = entry.relationshipType == 'cp';
    final accentColor = isCp ? const Color(0xFFE91E63) : const Color(0xFF03A9F4);

    return Positioned(
      top: MediaQuery.of(context).size.height * 0.25,
      right: 0,
      child: SlideTransition(
        position: _slideIn,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                accentColor.withValues(alpha: 0.9),
                accentColor.withValues(alpha: 0.2),
              ],
            ),
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar with relationship badge
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topLeft,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey.shade800,
                      backgroundImage: (entry.userImage ?? '').isNotEmpty
                          ? SafeImageProvider(VideoUtil.getFullImageUrl(entry.userImage))
                          : null,
                      child: (entry.userImage ?? '').isEmpty
                          ? const Icon(Icons.person, color: Colors.white, size: 20)
                          : null,
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: RelationshipBadge(
                      type: entry.relationshipType,
                      level: entry.level,
                      size: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    isCp ? 'Your CP has entered' : 'Your Friend has entered',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
