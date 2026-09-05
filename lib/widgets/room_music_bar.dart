/// Compact now-playing bar for live & audio rooms.
///
/// Sits above the bottom action bar and shows: album art / music icon, title,
/// seekable progress, play/pause, next, previous, and an expandable volume
/// slider. Driven by [RoomMusicController] (a ChangeNotifier) so it rebuilds
/// on every state change.
library room_music_bar;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/room_music_models.dart';
import '../services/room_music_controller.dart';
import '../theme/app_theme.dart';

class RoomMusicBar extends StatefulWidget {
  const RoomMusicBar({
    super.key,
    required this.controller,
    this.onPickMusic,
    this.compact = false,
    this.rightSide = false,
  });

  final RoomMusicController controller;

  /// Called when the user taps the "add music" affordance (host only).
  final VoidCallback? onPickMusic;

  /// When true, renders a slimmer single-line bar (used when space is tight).
  final bool compact;

  /// When true, renders a right-edge collapsible music pill that expands to
  /// the left when tapped (audio room side-rail layout).
  final bool rightSide;

  @override
  State<RoomMusicBar> createState() => _RoomMusicBarState();
}

class _RoomMusicBarState extends State<RoomMusicBar> {
  bool _volumeOpen = false;
  bool _seeking = false;
  double _seekValue = 0;
  bool _rightSideExpanded = false;

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    return ChangeNotifierProvider.value(
      value: ctrl,
      child: Consumer<RoomMusicController>(
        builder: (_, c, __) {
          final track = c.currentTrack;
          if (track == null) {
            // Empty state — host sees a quick "add music" hint.
            if (!widget.compact && !widget.rightSide && widget.onPickMusic != null) {
              return _emptyHostHint();
            }
            return const SizedBox.shrink();
          }
          if (widget.rightSide) return _rightSidePill(c, track);
          if (widget.compact) return _sideControl(c, track);
          return _bar(c, track);
        },
      ),
    );
  }

  Widget _rightSidePill(RoomMusicController c, RoomMusicTrack track) {
    const collapsedSize = 44.0;
    const expandedWidth = 220.0;
    final hasQueue = c.queue.length > 1;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      width: _rightSideExpanded ? expandedWidth : collapsedSize,
      height: _rightSideExpanded ? 92 : collapsedSize,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xF01A1A2E),
        borderRadius: BorderRadius.circular(collapsedSize / 2),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.45)),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: expandedWidth,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: _rightSideExpanded
              ? _rightSideExpandedContent(c, track, hasQueue)
              : _rightSideCollapsedContent(c, track),
        ),
      ),
    );
  }

  /// Collapsed state — just the music note icon (tap to expand).
  Widget _rightSideCollapsedContent(RoomMusicController c, RoomMusicTrack track) {
    return GestureDetector(
      onTap: () => setState(() => _rightSideExpanded = true),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.music_note,
              color: AppTheme.primary,
              size: 17,
            ),
          ),
        ],
      ),
    );
  }

  /// Expanded state — title on top, playback controls in the middle.
  Widget _rightSideExpandedContent(
    RoomMusicController c,
    RoomMusicTrack track,
    bool hasQueue,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Song title row with close button on the right
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() => _rightSideExpanded = false),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.keyboard_arrow_right,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Centered playback controls: prev | play/pause | next | close
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Previous
            InkWell(
              onTap: hasQueue ? c.previous : null,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.skip_previous_rounded,
                  color: hasQueue ? Colors.white : Colors.white24,
                  size: 22,
                ),
              ),
            ),
            // Play / Pause (center, highlighted)
            GestureDetector(
              onTap: c.togglePlayPause,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  c.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            // Next
            InkWell(
              onTap: hasQueue ? c.next : null,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.skip_next_rounded,
                  color: hasQueue ? Colors.white : Colors.white24,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Close (stop music) — in the middle row, after playback controls
            if (c.canControl)
              InkWell(
                onTap: c.close,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _emptyHostHint() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.music_note, color: AppTheme.primary, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Add background music',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          GestureDetector(
            onTap: widget.onPickMusic,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Add',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideControl(RoomMusicController c, RoomMusicTrack track) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xE61A1A2E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.45)),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.music_note,
              color: AppTheme.primary,
              size: 17,
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (c.canControl) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: c.togglePlayPause,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Icon(
                  c.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            InkWell(
              onTap: c.close,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(5),
                child: Icon(Icons.close, color: Colors.white70, size: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bar(RoomMusicController c, RoomMusicTrack track) {
    final dur = c.durationMs > 0 ? c.durationMs : (track.durationMs ?? 0);
    final pos = c.positionMs.clamp(0, dur > 0 ? dur : c.positionMs);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A1A4A), Color(0xFF1A1A2E)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _art(track),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (track.artist != null && track.artist!.isNotEmpty)
                      Text(
                        track.artist!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11,
                        ),
                      ),
                    const SizedBox(height: 4),
                    _progress(c, pos, dur),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _controls(c),
            ],
          ),
          if (_volumeOpen) ...[const SizedBox(height: 6), _volumeRow(c)],
        ],
      ),
    );
  }

  Widget _art(RoomMusicTrack track) {
    final art = track.artUri;
    Widget child;
    if (art != null && art.isNotEmpty) {
      final uri = Uri.tryParse(art);
      if (uri != null && uri.scheme == 'content') {
        // Android content uri from MediaStore — can't render directly in
        // Image.network; fall back to icon.
        child = const Icon(Icons.album, color: Colors.white70, size: 22);
      } else if (art.startsWith('http')) {
        child = Image.network(
          art,
          fit: BoxFit.cover,
          errorBuilder:
              (_, __, ___) =>
                  const Icon(Icons.music_note, color: Colors.white70, size: 22),
        );
      } else if (track.isLocal && File(art).existsSync()) {
        child = Image.file(
          File(art),
          fit: BoxFit.cover,
          errorBuilder:
              (_, __, ___) =>
                  const Icon(Icons.music_note, color: Colors.white70, size: 22),
        );
      } else {
        child = const Icon(Icons.music_note, color: Colors.white70, size: 22);
      }
    } else {
      child = const Icon(Icons.music_note, color: Colors.white70, size: 22);
    }
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _progress(RoomMusicController c, int pos, int dur) {
    final max = dur > 0 ? dur.toDouble() : 1.0;
    final value = _seeking ? _seekValue : pos.toDouble().clamp(0.0, max);
    return Row(
      children: [
        Text(
          _fmt(pos),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 10,
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: AppTheme.primary,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: AppTheme.primary.withValues(alpha: 0.2),
            ),
            child: Slider(
              min: 0,
              max: max,
              value: value,
              onChanged:
                  dur > 0 && c.canControl
                      ? (v) {
                        setState(() {
                          _seeking = true;
                          _seekValue = v;
                        });
                      }
                      : null,
              onChangeEnd:
                  dur > 0 && c.canControl
                      ? (v) async {
                        await c.seekTo(v.round());
                        if (mounted) setState(() => _seeking = false);
                      }
                      : null,
            ),
          ),
        ),
        Text(
          _fmt(dur),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _controls(RoomMusicController c) {
    if (!c.canControl) {
      return Icon(
        c.isPlaying ? Icons.graphic_eq : Icons.music_note,
        color: AppTheme.primary,
        size: 24,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 22,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          icon: const Icon(Icons.skip_previous, color: Colors.white70),
          onPressed: c.queue.length > 1 ? c.previous : null,
        ),
        GestureDetector(
          onTap: c.togglePlayPause,
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              c.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 22,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          icon: const Icon(Icons.skip_next, color: Colors.white70),
          onPressed: c.queue.length > 1 ? c.next : null,
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          icon: Icon(
            _volumeOpen ? Icons.volume_up : Icons.volume_down,
            color: Colors.white70,
          ),
          onPressed: () => setState(() => _volumeOpen = !_volumeOpen),
        ),
      ],
    );
  }

  Widget _volumeRow(RoomMusicController c) {
    return Row(
      children: [
        Icon(
          Icons.volume_mute,
          size: 16,
          color: Colors.white.withValues(alpha: 0.6),
        ),
        Expanded(
          child: SliderTheme(
            data: const SliderThemeData(
              trackHeight: 3,
              activeTrackColor: AppTheme.primary,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
            ),
            child: Slider(
              min: 0,
              max: 1,
              value: c.volume,
              onChanged: c.setVolume,
            ),
          ),
        ),
        Icon(
          Icons.volume_up,
          size: 16,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ],
    );
  }

  String _fmt(int ms) {
    if (ms <= 0) return '0:00';
    final s = (ms / 1000).round();
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }
}
