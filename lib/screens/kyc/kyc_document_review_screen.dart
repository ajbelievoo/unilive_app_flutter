/// Post-capture review screen for KYC documents.
///
/// After the camera captures the ID card full-frame, the user lands here to
/// review, manually crop and rotate it before accepting. This puts the user in
/// full control so the card can be centered and straightened before saving.
///
/// Returns the final image path via `Navigator.pop` as `{'path': ...}` or
/// `null` if the user taps "Retake".
library kyc_document_review;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

enum KycReviewMode {
  idFront,
  idBack,
  selfie,
}

class KycDocumentReviewScreen extends StatefulWidget {
  const KycDocumentReviewScreen({
    super.key,
    required this.imagePath,
    required this.mode,
  });

  final String imagePath;
  final KycReviewMode mode;

  @override
  State<KycDocumentReviewScreen> createState() => _KycDocumentReviewScreenState();
}

class _KycDocumentReviewScreenState extends State<KycDocumentReviewScreen> {
  static const String _tag = 'KycDocumentReview';

  late String _currentPath;
  // Number of 90° clockwise rotations applied relative to the original.
  int _rotationSteps = 0;
  bool _processing = false;

  // Title and guidance based on the capture mode.
  String get _title {
    switch (widget.mode) {
      case KycReviewMode.idFront:
        return 'Review ID Front';
      case KycReviewMode.idBack:
        return 'Review ID Back';
      case KycReviewMode.selfie:
        return 'Review Selfie';
    }
  }

  String get _instruction {
    switch (widget.mode) {
      case KycReviewMode.idFront:
      case KycReviewMode.idBack:
        return 'Make sure the card is straight, readable, and fills the crop frame. Use rotate or crop if needed.';
      case KycReviewMode.selfie:
        return 'Make sure your face is clearly visible and well-lit.';
    }
  }

  @override
  void initState() {
    super.initState();
    _currentPath = widget.imagePath;
  }

  /// Rotate the image 90° clockwise and save to a new temp file.
  Future<void> _rotate() async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final bytes = await File(_currentPath).readAsBytes();
      var decoded = img.decodeImage(bytes);
      if (decoded == null) {
        Fluttertoast.showToast(msg: 'Could not load image for rotate');
        return;
      }
      decoded = img.bakeOrientation(decoded);
      final rotated = img.copyRotate(decoded, angle: 90);

      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final newPath = '${dir.path}/kyc_rotated_$ts.jpg';
      final newBytes = img.encodeJpg(rotated, quality: 92);
      await File(newPath).writeAsBytes(newBytes);

      setState(() {
        _currentPath = newPath;
        _rotationSteps = (_rotationSteps + 1) % 4;
      });
    } catch (e, s) {
      Log.e(_tag, 'rotate failed', e, s);
      Fluttertoast.showToast(msg: 'Rotate failed. Try again.');
    } finally {
      setState(() => _processing = false);
    }
  }

  /// Open the platform image cropper. For ID cards we lock to the standard
  /// ID card aspect ratio (~1.586:1).
  Future<void> _crop() async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: _currentPath,
        // ID cards are ~1.586:1 (standard credit-card / Aadhaar / DL ratio).
        aspectRatio: const CropAspectRatio(ratioX: 1.586, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: _title,
            toolbarColor: AppTheme.primary,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: _title,
            aspectRatioLockEnabled: true,
            resetButtonHidden: false,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
      );
      if (cropped != null) {
        setState(() => _currentPath = cropped.path);
      }
    } catch (e, s) {
      Log.e(_tag, 'crop failed', e, s);
      Fluttertoast.showToast(msg: 'Crop failed. Try again.');
    } finally {
      setState(() => _processing = false);
    }
  }

  void _confirm() {
    Navigator.pop(context, {'path': _currentPath});
  }

  void _retake() {
    Navigator.pop(context, null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _retake,
            child: const Text('Retake', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(_currentPath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            decoration: const BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _instruction,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _actionButton(
                        icon: Icons.rotate_90_degrees_cw_outlined,
                        label: 'Rotate',
                        onTap: _processing ? null : _rotate,
                      ),
                      const SizedBox(width: 16),
                      _actionButton(
                        icon: Icons.crop,
                        label: 'Crop',
                        onTap: _processing ? null : _crop,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _processing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: Preloader(color: AppTheme.primary, strokeWidth: 2.5),
                        )
                      : FilledButton.icon(
                          onPressed: _confirm,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Use this photo',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: enabled ? Colors.white12 : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: enabled ? Colors.white38 : Colors.white24, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: enabled ? Colors.white : Colors.white38, size: 24),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: enabled ? Colors.white : Colors.white38, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
