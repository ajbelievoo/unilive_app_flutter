import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

class AddMusicScreen extends StatefulWidget {
  const AddMusicScreen({super.key, this.roomId, this.onSongSelected});

  final String? roomId;
  final void Function({String? url, String? title, String? artist, String? image})? onSongSelected;

  @override
  State<AddMusicScreen> createState() => _AddMusicScreenState();
}

class _AddMusicScreenState extends State<AddMusicScreen> {
  static const String _tag = 'AddMusic';
  final _searchCtrl = TextEditingController();
  final _songs = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _searching = false;

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
          _songs.add({
            'id': s.id,
            'title': s.title,
            'artist': s.singer,
            'url': s.song,
            'image': s.image,
          });
        }
      }
    } catch (e, s) {
      Log.e(_tag, 'loadSongs failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String q) {
    setState(() => _searching = q.isNotEmpty);
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
          onChanged: _onSearch,
          decoration: InputDecoration(
            hintText: 'Search songs...',
            border: InputBorder.none,
            suffixIcon: _searching
                ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _onSearch(''); })
                : null,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: Preloader())
          : list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.music_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(_searching ? 'No songs found' : 'No songs available', style: const TextStyle(color: Colors.grey)),
                      if (!_searching) ...[
                        const SizedBox(height: 8),
                        TextButton(onPressed: _loadSongs, child: const Text('Refresh')),
                      ],
                    ],
                  ),
                )
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
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle, color: AppTheme.primary),
                        onPressed: () {
                          if (widget.onSongSelected != null) {
                            widget.onSongSelected!(
                              url: s['url']?.toString(),
                              title: s['title']?.toString(),
                              artist: s['artist']?.toString(),
                              image: s['image']?.toString(),
                            );
                          }
                          Navigator.pop(context, s);
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
