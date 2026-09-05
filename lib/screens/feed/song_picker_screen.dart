import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

class SongPickerScreen extends StatefulWidget {
  const SongPickerScreen({super.key});

  @override
  State<SongPickerScreen> createState() => _SongPickerScreenState();
}

class _SongPickerScreenState extends State<SongPickerScreen> {
  static const String _tag = 'SongPicker';
  final _searchCtrl = TextEditingController();
  final _songs = <Map<String, dynamic>>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSongs() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getSongs();
      if (res.status) {
        _songs.clear();
        for (final s in res.song) {
          _songs.add({'id': s.id, 'title': s.title, 'artist': s.singer, 'url': s.song, 'image': s.image});
        }
      }
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchCtrl.text.isEmpty) return _songs;
    final q = _searchCtrl.text.toLowerCase();
    return _songs.where((s) =>
        (s['title'] ?? '').toString().toLowerCase().contains(q) ||
        (s['artist'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(hintText: 'Search songs...', border: InputBorder.none),
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSongs),
        ],
      ),
      body: _loading
          ? const Center(child: Preloader())
          : list.isEmpty
              ? Center(child: Text(_searchCtrl.text.isEmpty ? 'No songs available' : 'No songs found', style: const TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final s = list[i];
                    return ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.music_note, color: AppTheme.primary),
                      ),
                      title: Text(s['title'] ?? 'Unknown', maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(s['artist'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                      onTap: () => Navigator.pop(context, s),
                    );
                  },
                ),
    );
  }
}
