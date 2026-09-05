/// AR Sticker Overlay — renders the active AR sticker on top of the video view.
///
/// Listens to face detection stream for positioning. If no face is detected,
/// the sticker sits centered (fallback). The overlay is transparent and
/// pointer-ignorant so it doesn't block video interaction.
library ar_sticker_overlay;

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/ar_face_sticker_service.dart';

/// Renders the active AR sticker overlay on the video feed.
class ArStickerOverlay extends StatefulWidget {
  const ArStickerOverlay({super.key});

  @override
  State<ArStickerOverlay> createState() => _ArStickerOverlayState();
}

class _ArStickerOverlayState extends State<ArStickerOverlay> {
  StreamSubscription<Rect?>? _sub;
  Rect? _faceRect;
  ARSticker? _sticker;

  @override
  void initState() {
    super.initState();
    final svc = ARFaceStickerService.instance;
    _sticker = svc.activeSticker;
    _sub = svc.faceStream.listen((rect) {
      if (mounted) setState(() => _faceRect = rect);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sticker = ARFaceStickerService.instance.activeSticker ?? _sticker;
    if (sticker == null) return const SizedBox.shrink();

    final screenSize = MediaQuery.of(context).size;
    // If we have a face rect, position sticker relative to it.
    // Otherwise center it as fallback.
    double top, left, width, height;

    if (_faceRect != null) {
      // Expand face rect slightly for sticker coverage.
      final expanded = Rect.fromCenter(
        center: _faceRect!.center,
        width: _faceRect!.width * 1.8,
        height: _faceRect!.height * 1.8,
      );
      // Adjust position based on sticker type.
      switch (sticker.type) {
        case StickerType.ears:
        case StickerType.crown:
          // Position above the face.
          top = (expanded.top * screenSize.height) - (expanded.height * screenSize.height * 0.3);
          left = expanded.left * screenSize.width;
          width = expanded.width * screenSize.width;
          height = expanded.height * screenSize.height * 0.6;
          break;
        case StickerType.glasses:
          // Position on upper face.
          top = (expanded.top * screenSize.height) + (expanded.height * screenSize.height * 0.15);
          left = expanded.left * screenSize.width;
          width = expanded.width * screenSize.width;
          height = expanded.height * screenSize.height * 0.3;
          break;
        default:
          // Full face mask.
          top = expanded.top * screenSize.height;
          left = expanded.left * screenSize.width;
          width = expanded.width * screenSize.width;
          height = expanded.height * screenSize.height;
      }
    } else {
      // Fallback: center of screen, upper portion.
      width = screenSize.width * 0.5;
      height = screenSize.width * 0.5;
      left = (screenSize.width - width) / 2;
      top = screenSize.height * 0.15;
    }

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: IgnorePointer(
        child: _buildStickerImage(sticker),
      ),
    );
  }

  Widget _buildStickerImage(ARSticker sticker) {
    final url = sticker.overlayUrl;
    if (url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return Image.asset(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}
