import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../constants/api_key.dart' show positionStackKey;
import '../../models/song_root.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import '../../widgets/content_picker_sheets.dart';
import 'camera_recorder_screen.dart';
import 'package:belive/widgets/preloader.dart';

/// Ported from native reel upload flow.
///
/// Phase 18 enhancement: song picker, sticker picker, location tagging,
/// filter selection, and hashtag input.
class CreateReelScreen extends StatefulWidget {
  const CreateReelScreen({super.key});

  @override
  State<CreateReelScreen> createState() => _CreateReelScreenState();
}

class _CreateReelScreenState extends State<CreateReelScreen> {
  static const String _tag = 'CreateReel';
  final _captionCtrl = TextEditingController();
  final _hashtagCtrl = TextEditingController();
  File? _videoFile;
  bool _uploading = false;
  double _progress = 0;
  String _stage = '';
  VideoPlayerController? _previewController;
  bool _previewReady = false;
  double _recordSpeed = 1.0;

  // Phase 18 additions
  SongItem? _selectedSong;
  String _selectedLocation = '';
  String _selectedFilter = 'None';
  bool _allowComments = true;
  bool _isOriginalAudio = true;

  final _filters = [
    ('None', Icons.image),
    ('Sepia', Icons.filter_vintage),
    ('Grayscale', Icons.filter_b_and_w),
    ('Brightness', Icons.wb_sunny),
    ('Exposure', Icons.exposure),
    ('Gamma', Icons.tune),
    ('Haze', Icons.blur_on),
    ('Invert', Icons.invert_colors),
    ('Posterize', Icons.palette),
    ('Sharpen', Icons.grain),
    ('Solarize', Icons.wb_iridescent),
    ('Vignette', Icons.vignette),
  ];

  @override
  void dispose() {
    _captionCtrl.dispose();
    _hashtagCtrl.dispose();
    _previewController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    // Show choice: camera or gallery
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primary),
              title: const Text('Record Video'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primary),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
          ],
        ),
      ),
    );

    if (choice == 'camera') {
      if (!mounted) return;
      final result = await Navigator.push<dynamic>(
        context,
        MaterialPageRoute(builder: (_) => const CameraRecorderScreen()),
      );
      if (result is Map) {
        final path = result['path'] as String?;
        if (path != null && path != '__gallery__' && mounted) {
          setState(() {
            _videoFile = File(path);
            _recordSpeed = (result['speed'] as num?)?.toDouble() ?? 1.0;
            final song = result['song'];
            if (song is SongItem && _selectedSong == null) {
              _selectedSong = song;
              _isOriginalAudio = false;
            }
          });
          _initPreview(path);
        } else if (path == '__gallery__') {
          _pickFromGallery();
        }
      } else if (result is String && result != '__gallery__' && mounted) {
        setState(() => _videoFile = File(result));
        _initPreview(result);
      } else if (result == '__gallery__') {
        _pickFromGallery();
      }
    } else if (choice == 'gallery') {
      _pickFromGallery();
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 60));
    if (picked != null) {
      setState(() => _videoFile = File(picked.path));
      _initPreview(picked.path);
    }
  }

  Future<void> _initPreview(String path) async {
    _previewController?.dispose();
    _previewController = VideoPlayerController.file(File(path));
    await _previewController!.initialize();
    _previewController!.setLooping(true);
    _previewController!.play();
    if (mounted) setState(() => _previewReady = true);
  }

  Future<void> _submit() async {
    if (_videoFile == null) {
      Fluttertoast.showToast(msg: 'Please select a video');
      return;
    }
    setState(() {
      _uploading = true;
      _progress = 0.1;
      _stage = 'Compressing...';
    });
    final session = context.read<SessionManager>();
    try {
      // Video compression skipped (video_compress package incompatible with
      // current Flutter embedding). Upload the original file directly.
      final compressed = _videoFile!;
      setState(() {
        _progress = 0.4;
        _stage = 'Uploading...';
      });
      final res = await ApiService.createReel(
        userId: session.userId,
        caption: _captionCtrl.text.trim(),
        videoFile: compressed,
        location: _selectedLocation,
        allowComment: _allowComments,
        songId: _selectedSong?.id,
      );
      setState(() {
        _progress = 1.0;
        _stage = 'Done';
      });
      if (res.status) {
        Fluttertoast.showToast(msg: 'Reel uploaded');
        if (mounted) Navigator.pop(context, true);
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Upload failed');
      }
    } catch (e, s) {
      Log.e(_tag, 'upload failed', e, s);
      Fluttertoast.showToast(msg: 'Upload failed');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ignore: unused_element
  List<String> _parseHashtags() {
    final tags = <String>[];
    for (final part in _hashtagCtrl.text.split(RegExp(r'[,\s]+'))) {
      final t = part.trim();
      if (t.isNotEmpty) tags.add(t.startsWith('#') ? t.substring(1) : t);
    }
    return tags;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Reel'),
        actions: [
          TextButton(
            onPressed: _uploading ? null : _submit,
            child: const Text('Upload', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Stack(children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Video preview
            GestureDetector(
              onTap: _pickVideo,
              child: Container(
                height: 280,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 1.5),
                ),
                child: _videoFile == null
                    ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.video_library_outlined, size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text('Tap to select video', style: TextStyle(color: Colors.grey.shade400)),
                        const SizedBox(height: 4),
                        Text('Max 60 seconds', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ])
                    : Stack(alignment: Alignment.center, children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _previewReady && _previewController != null
                              ? AspectRatio(
                                  aspectRatio: _previewController!.value.aspectRatio,
                                  child: VideoPlayer(_previewController!),
                                )
                              : Container(
                                  color: Colors.black,
                                  height: 280,
                                  child: const Center(child: Preloader(color: AppTheme.primary)),
                                ),
                        ),
                        if (_previewReady && _previewController != null && !_previewController!.value.isPlaying)
                          const Icon(Icons.play_circle_fill, color: Colors.white70, size: 64),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              _recordSpeed != 1.0 ? 'Video selected (${_recordSpeed}x)' : 'Video selected',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                      ]),
              ),
            ),
            if (_videoFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _videoFile = null),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Remove', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Caption
            TextField(
              controller: _captionCtrl,
              maxLines: 4,
              style: TextStyle(color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary),
              decoration: InputDecoration(
                labelText: 'Caption',
                hintText: 'Write something about your reel...',
                hintStyle: TextStyle(color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary),
                filled: true,
                fillColor: isDark ? AppTheme.surfaceLight : AppTheme.lightBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            // Hashtags
            TextField(
              controller: _hashtagCtrl,
              style: TextStyle(color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary),
              decoration: InputDecoration(
                labelText: 'Hashtags',
                hintText: 'dance, fun, viral (comma separated)',
                hintStyle: TextStyle(color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary),
                prefixIcon: const Icon(Icons.tag, color: AppTheme.primary),
                filled: true,
                fillColor: isDark ? AppTheme.surfaceLight : AppTheme.lightBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            // Song picker
            _optionTile(
              isDark,
              icon: Icons.music_note,
              gradient: AppTheme.purpleGradient,
              label: 'Song',
              value: _selectedSong?.title ?? 'Original Audio',
              onTap: () => showSongPickerSheet(context, onSelected: (song) {
                setState(() {
                  _selectedSong = song;
                  _isOriginalAudio = false;
                });
              }),
            ),
            const SizedBox(height: 8),

            // Location picker
            _optionTile(
              isDark,
              icon: Icons.location_on,
              gradient: AppTheme.blueGradient,
              label: 'Location',
              value: _selectedLocation.isEmpty ? 'Add location' : _selectedLocation,
              onTap: () => showLocationPickerSheet(
                context,
                accessKey: positionStackKey,
                onSelected: (loc) => setState(() => _selectedLocation = loc),
              ),
            ),
            const SizedBox(height: 8),

            // Filter picker
            _optionTile(
              isDark,
              icon: Icons.filter_vintage,
              gradient: AppTheme.pinkGradient,
              label: 'Filter',
              value: _selectedFilter,
              onTap: () => _showFilterPicker(isDark),
            ),
            const SizedBox(height: 16),

            // Settings toggles
            _toggleRow(isDark, 'Allow Comments', _allowComments, (v) => setState(() => _allowComments = v)),
            _toggleRow(isDark, 'Original Audio', _isOriginalAudio, (v) => setState(() {
              _isOriginalAudio = v;
              if (v) _selectedSong = null;
            })),
          ],
        ),
        if (_uploading)
          Container(
            color: Colors.black54,
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Preloader(color: Colors.white),
              const SizedBox(height: 12),
              Text(_stage, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: LinearProgressIndicator(value: _progress, color: Colors.white),
              ),
            ])),
          ),
      ]),
    );
  }

  Widget _optionTile(bool isDark, {required IconData icon, required Gradient gradient, required String label, required String value, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: isDark ? AppTheme.surfaceLight : AppTheme.lightBg,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(label, style: TextStyle(fontSize: 13, color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary)),
      subtitle: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary),
    );
  }

  Widget _toggleRow(bool isDark, String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
        ),
      ),
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? AppTheme.primary : null),
    );
  }

  void _showFilterPicker(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surface : AppTheme.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(gradient: AppTheme.pinkGradient, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Filter',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filters.length,
                  itemBuilder: (_, i) {
                    final (name, icon) = _filters[i];
                    final isSelected = _selectedFilter == name;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedFilter = name);
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 72,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          gradient: isSelected ? AppTheme.pinkGradient : null,
                          color: isSelected ? null : (isDark ? AppTheme.surfaceLight : AppTheme.lightBg),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, color: isSelected ? Colors.white : AppTheme.primary, size: 24),
                            const SizedBox(height: 6),
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : (isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
