/// Content creation picker sheets â€” song picker, sticker picker, location picker.
///
/// Ports native `SongPickerActivity`, `StickerPickerActivity`, `LocationChooseActivity`.
library content_picker_sheets;
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/song_root.dart';
import '../models/gift_models.dart' show StickerItem;
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

const String _tag = 'ContentPickers';

// ---------------------------------------------------------------------------
// Song picker sheet
// ---------------------------------------------------------------------------
void showSongPickerSheet(
  BuildContext context, {
  required ValueChanged<SongItem> onSelected,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SongPickerSheet(onSelected: onSelected),
  );
}

class _SongPickerSheet extends StatefulWidget {
  const _SongPickerSheet({required this.onSelected});

  final ValueChanged<SongItem> onSelected;

  @override
  State<_SongPickerSheet> createState() => _SongPickerSheetState();
}

class _SongPickerSheetState extends State<_SongPickerSheet> {
  final _songs = <SongItem>[];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService.getSongs();
      if (mounted) setState(() => _songs.addAll(res.song));
    } catch (e, s) {
      Log.e(_tag, 'songs failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<SongItem> get _filtered {
    if (_query.isEmpty) return _songs;
    final q = _query.toLowerCase();
    return _songs.where((s) {
      return (s.title ?? '').toLowerCase().contains(q) || (s.singer ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.surface : AppTheme.lightSurface;

    return Container(
      height: MediaQuery.of(context).size.height * 0.60,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: AppTheme.primary.withValues(alpha: 0.25), blurRadius: 32, offset: const Offset(0, -8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          children: [
            _header(isDark),
            _searchBar(isDark),
            Expanded(child: _body(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _header(bool isDark) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(gradient: AppTheme.purpleGradient, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.music_note, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Choose Song',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: TextField(
        onChanged: (v) => setState(() => _query = v),
        style: TextStyle(color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary),
        decoration: InputDecoration(
          hintText: 'Search songs or artists...',
          hintStyle: TextStyle(color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary),
          prefixIcon: Icon(Icons.search, color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary, size: 20),
          filled: true,
          fillColor: isDark ? AppTheme.surfaceLight : AppTheme.lightBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _body(bool isDark) {
    if (_loading) return const Center(child: Preloader());
    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Text('No songs found', style: TextStyle(color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final s = list[i];
        return ListTile(
          onTap: () {
            Navigator.pop(context);
            widget.onSelected(s);
          },
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: s.image ?? '',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width: 48,
                height: 48,
                color: isDark ? AppTheme.surfaceLight : AppTheme.lightBg,
                child: const Icon(Icons.music_note, size: 20),
              ),
            ),
          ),
          title: Text(
            s.title ?? 'Unknown',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
            ),
          ),
          subtitle: Text(
            s.singer ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary),
          ),
          trailing: const Icon(Icons.play_circle_outline, color: AppTheme.primary),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Sticker picker sheet
// ---------------------------------------------------------------------------
void showStickerPickerSheet(
  BuildContext context, {
  required ValueChanged<StickerItem> onSelected,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StickerPickerSheet(onSelected: onSelected),
  );
}

class _StickerPickerSheet extends StatefulWidget {
  const _StickerPickerSheet({required this.onSelected});

  final ValueChanged<StickerItem> onSelected;

  @override
  State<_StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<_StickerPickerSheet> {
  final _stickers = <StickerItem>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService.getStickers();
      if (mounted) setState(() => _stickers.addAll(res.sticker));
    } catch (e, s) {
      Log.e(_tag, 'stickers failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.surface : AppTheme.lightSurface;

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: AppTheme.primary.withValues(alpha: 0.25), blurRadius: 32, offset: const Offset(0, -8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(gradient: AppTheme.pinkGradient, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.emoji_emotions, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Stickers',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: Preloader())
                  : _stickers.isEmpty
                      ? Center(
                          child: Text('No stickers', style: TextStyle(color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary)),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                          ),
                          itemCount: _stickers.length,
                          itemBuilder: (_, i) {
                            final s = _stickers[i];
                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                widget.onSelected(s);
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: s.sticker ?? '',
                                  fit: BoxFit.contain,
                                  errorWidget: (_, __, ___) => Container(
                                    color: isDark ? AppTheme.surfaceLight : AppTheme.lightBg,
                                    child: const Icon(Icons.image, size: 20),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Location picker sheet (uses PositionStack API)
// ---------------------------------------------------------------------------
void showLocationPickerSheet(
  BuildContext context, {
  required String accessKey,
  required ValueChanged<String> onSelected,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LocationPickerSheet(accessKey: accessKey, onSelected: onSelected),
  );
}

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet({required this.accessKey, required this.onSelected});

  final String accessKey;
  final ValueChanged<String> onSelected;

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _ctrl = TextEditingController();
  final _results = <Map<String, dynamic>>[];
  bool _searching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String q) {
    if (q.trim().isEmpty) {
      setState(() {
        _results.clear();
        _searching = false;
      });
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _searching = true);
      try {
        final query = q.trim();
        final list = await ApiService.searchLocations(query, widget.accessKey);
        if (mounted) {
          setState(() => _results
            ..clear()
            ..addAll(list));
        }
      } catch (e, s) {
        Log.e(_tag, 'location search failed', e, s);
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.surface : AppTheme.lightSurface;

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: AppTheme.primary.withValues(alpha: 0.25), blurRadius: 32, offset: const Offset(0, -8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          children: [
            _header(isDark),
            _searchField(isDark),
            Expanded(child: _body(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _header(bool isDark) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(gradient: AppTheme.blueGradient, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.location_on, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Add Location',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchField(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: TextField(
        controller: _ctrl,
        onChanged: _search,
        autofocus: true,
        style: TextStyle(color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary),
        decoration: InputDecoration(
          hintText: 'Search location...',
          hintStyle: TextStyle(color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary),
          prefixIcon: Icon(Icons.search, color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary, size: 20),
          suffixIcon: _searching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 18, height: 18, child: Preloader(strokeWidth: 2)),
                )
              : null,
          filled: true,
          fillColor: isDark ? AppTheme.surfaceLight : AppTheme.lightBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _body(bool isDark) {
    if (_results.isEmpty && !_searching) {
      return Center(
        child: Text(
          'Start typing to search',
          style: TextStyle(color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final item = _results[i];
        final label = item['label'] as String? ?? '';
        final region = item['region'] as String? ?? '';
        return ListTile(
          onTap: () {
            Navigator.pop(context);
            widget.onSelected(label);
          },
          leading: const Icon(Icons.location_on_outlined, color: AppTheme.primary),
          title: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
            ),
          ),
          subtitle: Text(
            region,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary),
          ),
        );
      },
    );
  }
}

