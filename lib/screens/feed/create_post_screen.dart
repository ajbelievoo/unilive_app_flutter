import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

/// Ported from native `UploadPostActivity.java`.
///
/// Phase 4 implementation: pick image, write caption, choose privacy,
/// toggle allow-comments, then upload via multipart.
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const String _tag = 'CreatePost';
  final _captionCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  File? _imageFile;
  bool _isPublic = true;
  bool _allowComment = true;
  bool _uploading = false;
  double _progress = 0;

  @override
  void dispose() {
    _captionCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  String _extractCommaSeparated(String text, RegExp regex) {
    final matches = regex.allMatches(text).map((m) => m.group(0)).whereType<String>().toList();
    if (matches.isEmpty) return '';
    return '${matches.join(',')},';
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (_imageFile == null) {
      Fluttertoast.showToast(msg: 'Please select an image');
      return;
    }
    if (_captionCtrl.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: 'Please write a caption');
      return;
    }
    setState(() {
      _uploading = true;
      _progress = 0.1;
    });
    try {
      final session = context.read<SessionManager>();
      setState(() => _progress = 0.5);
      final caption = _captionCtrl.text.trim();
      final hashTag = _extractCommaSeparated(caption, RegExp(r'#\w+'));
      final mentionPeople = _extractCommaSeparated(caption, RegExp(r'@\w+'));
      final res = await ApiService.createPost(
        userId: session.userId,
        caption: caption,
        imageFile: _imageFile!,
        location: _locationCtrl.text.trim(),
        allowComment: _allowComment,
        isPublic: _isPublic,
        hashTag: hashTag,
        mentionPeople: mentionPeople,
      );
      setState(() => _progress = 1.0);
      if (res.status) {
        Fluttertoast.showToast(msg: 'Post uploaded');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          TextButton(
            onPressed: _uploading ? null : _submit,
            child: const Text('Post', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Stack(children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Image picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 240,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _imageFile == null
                    ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text('Tap to select image', style: TextStyle(color: Colors.grey.shade500)),
                      ])
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity, height: 240),
                      ),
              ),
            ),
            if (_imageFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _imageFile = null),
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
              decoration: const InputDecoration(
                labelText: 'Caption',
                hintText: 'Write something...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // Location
            TextField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Location',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // Privacy
            Row(children: [
              const Text('Privacy: ', style: TextStyle(fontWeight: FontWeight.w600)),
              ChoiceChip(label: const Text('Public'), selected: _isPublic, onSelected: (_) => setState(() => _isPublic = true)),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('Followers'), selected: !_isPublic, onSelected: (_) => setState(() => _isPublic = false)),
            ]),
            const SizedBox(height: 8),
            // Allow comments
            SwitchListTile(
              title: const Text('Allow Comments'),
              value: _allowComment,
              onChanged: (v) => setState(() => _allowComment = v),
            ),
          ],
        ),
        if (_uploading)
          Container(
            color: Colors.black54,
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Preloader(color: Colors.white),
              const SizedBox(height: 12),
              Text('Uploading... ${(_progress * 100).toInt()}%', style: const TextStyle(color: Colors.white)),
            ])),
          ),
      ]),
    );
  }
}
