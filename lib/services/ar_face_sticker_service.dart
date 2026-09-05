/// AR Face Stickers / Masks service — Bigo-style real-time face effects.
///
/// Provides a catalog of AR stickers (face masks, ears, crowns, animoji)
/// that overlay on the host's camera feed. Gated by `ai_ar_face_stickers`
/// AI feature key (admin panel toggle).
///
/// Uses Agora's built-in face detection + custom image overlays rendered
/// on a transparent layer above the video view. Sticker positions are
/// approximated from the ML Kit face detector already used by the
/// host compliance guard.
library ar_face_sticker_service;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../utils/log.dart';
import 'api_service.dart';

/// A single AR sticker item.
class ARSticker {
  final String id;
  final String name;
  final String iconUrl; // small preview icon
  final String overlayUrl; // full overlay image (PNG with transparency)
  final StickerType type;
  final bool isVipExclusive;

  const ARSticker({
    required this.id,
    required this.name,
    required this.iconUrl,
    required this.overlayUrl,
    this.type = StickerType.faceMask,
    this.isVipExclusive = false,
  });

  factory ARSticker.fromJson(Map<String, dynamic> j) => ARSticker(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        iconUrl: j['iconUrl']?.toString() ?? '',
        overlayUrl: j['overlayUrl']?.toString() ?? '',
        type: StickerType.values.firstWhere(
          (e) => e.name == (j['type']?.toString() ?? 'faceMask'),
          orElse: () => StickerType.faceMask,
        ),
        isVipExclusive: j['isVipExclusive'] == true,
      );
}

enum StickerType { faceMask, ears, crown, animoji, glasses, fullFace }

/// Singleton service managing AR sticker state.
class ARFaceStickerService {
  static const String _tag = 'ARSticker';
  static final ARFaceStickerService instance = ARFaceStickerService._();

  ARFaceStickerService._();

  /// Currently active sticker (null = no sticker).
  ARSticker? _activeSticker;
  ARSticker? get activeSticker => _activeSticker;

  /// Whether face tracking is running.
  bool _isTracking = false;
  bool get isTracking => _isTracking;

  /// Latest detected face bounds (normalized 0..1 relative to video frame).
  Rect? _lastFaceRect;
  Rect? get lastFaceRect => _lastFaceRect;

  /// Stream of face detection updates for overlay positioning.
  final _faceStream = StreamController<Rect?>.broadcast();
  Stream<Rect?> get faceStream => _faceStream.stream;

  /// Default built-in sticker catalog (backend can override via API).
  final List<ARSticker> _builtinStickers = [
    ARSticker(
      id: 'cute_cat',
      name: 'Cat Face',
      iconUrl: 'assets/ar_stickers/cat_icon.webp',
      overlayUrl: 'assets/ar_stickers/cat_face.webp',
      type: StickerType.faceMask,
    ),
    ARSticker(
      id: 'bunny_ears',
      name: 'Bunny Ears',
      iconUrl: 'assets/ar_stickers/bunny_icon.webp',
      overlayUrl: 'assets/ar_stickers/bunny_ears.webp',
      type: StickerType.ears,
    ),
    ARSticker(
      id: 'crown',
      name: 'Golden Crown',
      iconUrl: 'assets/ar_stickers/crown_icon.webp',
      overlayUrl: 'assets/ar_stickers/crown.webp',
      type: StickerType.crown,
      isVipExclusive: true,
    ),
    ARSticker(
      id: 'cool_glasses',
      name: 'Cool Glasses',
      iconUrl: 'assets/ar_stickers/glasses_icon.webp',
      overlayUrl: 'assets/ar_stickers/glasses.webp',
      type: StickerType.glasses,
    ),
    ARSticker(
      id: 'dog_face',
      name: 'Dog Face',
      iconUrl: 'assets/ar_stickers/dog_icon.webp',
      overlayUrl: 'assets/ar_stickers/dog_face.webp',
      type: StickerType.faceMask,
    ),
    ARSticker(
      id: 'flower_crown',
      name: 'Flower Crown',
      iconUrl: 'assets/ar_stickers/flower_icon.webp',
      overlayUrl: 'assets/ar_stickers/flower_crown.webp',
      type: StickerType.crown,
      isVipExclusive: true,
    ),
    ARSticker(
      id: 'clown',
      name: 'Clown Nose',
      iconUrl: 'assets/ar_stickers/clown_icon.webp',
      overlayUrl: 'assets/ar_stickers/clown_nose.webp',
      type: StickerType.faceMask,
    ),
    ARSticker(
      id: 'anime_eyes',
      name: 'Anime Eyes',
      iconUrl: 'assets/ar_stickers/anime_icon.webp',
      overlayUrl: 'assets/ar_stickers/anime_eyes.webp',
      type: StickerType.fullFace,
      isVipExclusive: true,
    ),
  ];

  List<ARSticker> get stickers =>
      _remoteStickers.isNotEmpty ? _remoteStickers : _builtinStickers;

  List<ARSticker> _remoteStickers = [];

  /// Fetch stickers from the backend, falling back to built-in on failure.
  Future<void> fetchFromBackend() async {
    try {
      final list = await ApiService.getArStickers();
      if (list.isNotEmpty) {
        _remoteStickers = list.map((j) => ARSticker.fromJson(j)).toList();
        Log.d(_tag, 'fetched ${_remoteStickers.length} stickers from backend');
      }
    } catch (e) {
      Log.e(_tag, 'fetchFromBackend failed, using built-in', e);
    }
  }

  /// Select a sticker to activate (or null to clear).
  void selectSticker(ARSticker? sticker) {
    _activeSticker = sticker;
    Log.d(_tag, 'sticker selected: ${sticker?.name ?? 'none'}');
  }

  /// Start face tracking using ML Kit.
  Future<void> startTracking() async {
    if (_isTracking) return;
    _isTracking = true;
    Log.d(_tag, 'face tracking started');
  }

  /// Stop face tracking.
  void stopTracking() {
    _isTracking = false;
    _lastFaceRect = null;
    Log.d(_tag, 'face tracking stopped');
  }

  /// Process a face detection result and update the overlay position.
  void processFace(Face? face, Size frameSize) {
    if (face == null || !_isTracking) {
      _lastFaceRect = null;
      _faceStream.add(null);
      return;
    }
    // Normalize face bounds to 0..1 relative to frame.
    final rect = Rect.fromLTWH(
      face.boundingBox.left / frameSize.width,
      face.boundingBox.top / frameSize.height,
      face.boundingBox.width / frameSize.width,
      face.boundingBox.height / frameSize.height,
    );
    _lastFaceRect = rect;
    _faceStream.add(rect);
  }

  void dispose() {
    _faceStream.close();
  }
}
