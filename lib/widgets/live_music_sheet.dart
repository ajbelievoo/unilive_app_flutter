import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

/// Shows a bottom sheet for live room background music.
/// Host can pick local audio files and mix them into the Agora stream.
void showLiveMusicSheet(
  BuildContext context, {
  required RtcEngine engine,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LiveMusicSheet(engine: engine),
  );
}

class _MusicTrack {
  _MusicTrack({required this.path, required this.name});

  final String path;
  final String name;

  Map<String, dynamic> toJson() => {'path': path, 'name': name};
}

class _LiveMusicSheet extends StatefulWidget {
  const _LiveMusicSheet({required this.engine});

  final RtcEngine engine;

  @override
  State<_LiveMusicSheet> createState() => _LiveMusicSheetState();
}

class _LiveMusicSheetState extends State<_LiveMusicSheet> {
  static const String _tag = 'LiveMusic';
  static const String _prefsKey = 'live_music_queue';

  final _tracks = <_MusicTrack>[];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = raw.split('||');
        for (final item in list) {
          final parts = item.split('|');
          if (parts.length == 2) {
            _tracks.add(_MusicTrack(name: parts[0], path: parts[1]));
          }
        }
      }
    } catch (e, s) {
      Log.e(_tag, 'load tracks failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_tracks.isEmpty) {
        await prefs.remove(_prefsKey);
        return;
      }
      final raw = _tracks.map((t) => '${t.name}|${t.path}').join('||');
      await prefs.setString(_prefsKey, raw);
    } catch (e, s) {
      Log.e(_tag, 'save tracks failed', e, s);
    }
  }

  Future<void> _pickAudio() async {
    var status = await Permission.audio.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      status = await Permission.storage.request();
    }
    if (status.isPermanentlyDenied) {
      Fluttertoast.showToast(msg: 'Storage permission denied');
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;
      for (final f in result.files) {
        final path = f.path;
        if (path == null || path.isEmpty) continue;
        _tracks.add(_MusicTrack(
          name: f.name.isNotEmpty ? f.name : _fileName(path),
          path: path,
        ));
      }
      await _saveTracks();
      if (mounted) setState(() {});
    } catch (e, s) {
      Log.e(_tag, 'pick audio failed', e, s);
      Fluttertoast.showToast(msg: 'Could not load audio');
    }
  }

  String _fileName(String path) {
    final idx = path.lastIndexOf(Platform.pathSeparator);
    return idx >= 0 ? path.substring(idx + 1) : path;
  }

  Future<void> _playAt(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    final track = _tracks[index];
    if (!File(track.path).existsSync()) {
      Fluttertoast.showToast(msg: 'File not found');
      return;
    }
    try {
      await _stop();
      await widget.engine.startAudioMixing(
        filePath: track.path,
        loopback: false,
        cycle: 1,
      );
      _currentIndex = index;
      _isPlaying = true;
    } catch (e, s) {
      Log.e(_tag, 'startAudioMixing failed', e, s);
      Fluttertoast.showToast(msg: 'Could not play track');
    }
    if (mounted) setState(() {});
  }

  Future<void> _pauseOrResume() async {
    if (_currentIndex < 0) return;
    try {
      if (_isPlaying) {
        await widget.engine.pauseAudioMixing();
      } else {
        await widget.engine.resumeAudioMixing();
      }
      _isPlaying = !_isPlaying;
    } catch (e, s) {
      Log.e(_tag, 'pause/resume failed', e, s);
    }
    if (mounted) setState(() {});
  }

  Future<void> _stop() async {
    try {
      await widget.engine.stopAudioMixing();
    } catch (e, s) {
      Log.e(_tag, 'stopAudioMixing failed', e, s);
    }
    _isPlaying = false;
  }

  Future<void> _removeAt(int index) async {
    final wasPlaying = _isPlaying && _currentIndex == index;
    _tracks.removeAt(index);
    if (_currentIndex > index) _currentIndex--;
    if (wasPlaying || _currentIndex >= _tracks.length) {
      await _stop();
      _currentIndex = -1;
    }
    await _saveTracks();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Live Music', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            const Divider(color: Colors.white12),
            if (_loading)
              const SizedBox(height: 120, child: Center(child: Preloader()))
            else if (_tracks.isEmpty)
              const SizedBox(
                height: 120,
                child: Center(child: Text('No songs added yet', style: TextStyle(color: Colors.white70))),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _tracks.length,
                  itemBuilder: (_, i) {
                    final isCurrent = i == _currentIndex;
                    final isPlaying = isCurrent && _isPlaying;
                    return ListTile(
                      leading: Icon(
                        isPlaying ? Icons.pause_circle_filled : (isCurrent ? Icons.play_circle_filled : Icons.music_note),
                        color: isCurrent ? const Color(0xFF7E3FF2) : Colors.white70,
                      ),
                      title: Text(
                        _tracks[i].name,
                        style: TextStyle(color: isCurrent ? Colors.white : Colors.white70, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCurrent)
                            IconButton(
                              onPressed: _pauseOrResume,
                              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                            ),
                          IconButton(
                            onPressed: () => _removeAt(i),
                            icon: const Icon(Icons.delete, color: Colors.red),
                          ),
                        ],
                      ),
                      onTap: () => _playAt(i),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickAudio,
                icon: const Icon(Icons.add),
                label: const Text('Add Songs'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E3FF2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
