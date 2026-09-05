/// Audio room music manager — lets the host build a playlist and control
/// playback during the audio room session.
///
/// Ports native `AddMusicActivity.java`. Rewritten to drive the shared
/// [RoomMusicController] (Agora audio mixing) instead of a local just_audio
/// preview, so what the host picks is what every viewer hears.
library audio_room_music;

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../models/room_music_models.dart';
import '../../services/room_music_controller.dart';
import '../../theme/app_theme.dart';
import 'add_music_screen.dart';
import 'device_music_picker_screen.dart';

class AudioRoomMusicScreen extends StatefulWidget {
  const AudioRoomMusicScreen({super.key, required this.controller});

  final RoomMusicController controller;

  @override
  State<AudioRoomMusicScreen> createState() => _AudioRoomMusicScreenState();
}

class _AudioRoomMusicScreenState extends State<AudioRoomMusicScreen> {
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Music'),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppTheme.purpleGradient)),
        actions: [
          IconButton(
            icon: const Icon(Icons.library_music),
            tooltip: 'Add from device',
            onPressed: _addFromDevice,
          ),
          IconButton(
            icon: const Icon(Icons.cloud_download_outlined),
            tooltip: 'Add from server',
            onPressed: _addFromServer,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: c,
        builder: (_, __) {
          final queue = c.queue;
          if (queue.isEmpty) return _empty();
          return Column(
            children: [
              if (c.currentTrack != null) _nowPlaying(c),
              Expanded(child: _playlist(c, queue)),
            ],
          );
        },
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.music_note, size: 72, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No songs in playlist', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _addFromDevice,
                icon: const Icon(Icons.library_music),
                label: const Text('Device'),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _addFromServer,
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Server'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nowPlaying(RoomMusicController c) {
    final track = c.currentTrack!;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.accent]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            track.title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (track.artist != null && track.artist!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              track.artist!,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          // Progress
          Row(
            children: [
              Text(_fmt(c.positionMs), style: const TextStyle(color: Colors.white70, fontSize: 11)),
              Expanded(
                child: Slider(
                  min: 0,
                  max: (c.durationMs > 0 ? c.durationMs : 1).toDouble(),
                  value: c.positionMs.toDouble().clamp(
                      0, (c.durationMs > 0 ? c.durationMs : 1).toDouble()),
                  activeColor: Colors.white,
                  inactiveColor: Colors.white24,
                  thumbColor: Colors.white,
                  onChanged: c.durationMs > 0
                      ? (v) => c.seekTo(v.round())
                      : null,
                ),
              ),
              Text(_fmt(c.durationMs), style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white, size: 32),
                onPressed: c.queue.length > 1 ? c.previous : null,
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: c.togglePlayPause,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Icon(
                    c.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: AppTheme.primary,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white, size: 32),
                onPressed: c.queue.length > 1 ? c.next : null,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.stop, color: Colors.white70),
                onPressed: () => c.stop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _playlist(RoomMusicController c, List<RoomMusicTrack> queue) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: queue.length,
      itemBuilder: (_, i) => _tile(c, queue[i], i),
    );
  }

  Widget _tile(RoomMusicController c, RoomMusicTrack song, int i) {
    final isCurrent = c.currentIndex == i;
    final isPlaying = isCurrent && c.isPlaying;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrent ? const BorderSide(color: AppTheme.primary, width: 2) : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: _art(song),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
        ),
        subtitle: Text(
          [
            if (song.artist != null && song.artist!.isNotEmpty) song.artist!,
            if (song.durationMs != null && song.durationMs! > 0) _fmt(song.durationMs!),
          ].join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isPlaying ? Icons.pause_circle_filled : Icons.play_circle,
                color: AppTheme.primary,
              ),
              onPressed: () {
                if (isCurrent) {
                  c.togglePlayPause();
                } else {
                  c.playAt(i);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => c.removeAt(i),
            ),
          ],
        ),
      ),
    );
  }

  Widget _art(RoomMusicTrack song) {
    final art = song.artUri;
    Widget child;
    if (art != null && art.isNotEmpty && art.startsWith('http')) {
      child = Image.network(art, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.music_note, color: Colors.white70));
    } else {
      child = const Icon(Icons.music_note, color: Colors.white70);
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Future<void> _addFromDevice() async {
    final tracks = await showDeviceMusicPicker(context);
    if (tracks == null || tracks.isEmpty) return;
    widget.controller.addTracks(tracks);
    if (!mounted) return;
    Fluttertoast.showToast(msg: '${tracks.length} song(s) added');
    if (widget.controller.currentIndex == -1) {
      await widget.controller.playAt(0);
    }
  }

  Future<void> _addFromServer() async {
    await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddMusicScreen(
          onSongSelected: ({url, title, artist, image}) {
            if (url == null || url.isEmpty) return;
            widget.controller.addTracks([
              RoomMusicTrack.fromServerSong(
                id: title ?? url,
                title: title ?? 'Unknown',
                artist: artist,
                url: url,
                image: image,
              ),
            ]);
          },
        ),
      ),
    );
    if (!mounted) return;
    if (widget.controller.currentIndex == -1 && widget.controller.queue.isNotEmpty) {
      await widget.controller.playAt(0);
    }
  }

  String _fmt(int ms) {
    if (ms <= 0) return '0:00';
    final s = (ms / 1000).round();
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }
}
