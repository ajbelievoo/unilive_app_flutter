/// Virtual Avatar / VTuber service — lets hosts stream as an animated
/// avatar instead of showing their real face.
///
/// Provides a catalog of built-in 2D/3D avatars (anime girl, anime boy,
/// robot, animal, cartoon) that the host can select. When face tracking
/// is enabled, ML Kit face detection drives the avatar's expressions:
/// head rotation (euler angles Y/Z), blink (eye openness), and smile
/// (smiling probability). The rendering widget listens to the avatar
/// state stream and applies animated transforms accordingly.
///
/// This service is a singleton ([VirtualAvatarService.instance]) and
/// emits state snapshots via [avatarStateStream].
library;

import 'dart:async';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../utils/log.dart';
import 'api_service.dart';

/// Avatar render type.
enum AvatarType { twoD, threeD }

/// Face tracking mode.
enum AvatarTrackingMode {
  /// No tracking — avatar stays in a neutral idle pose.
  off,

  /// Full tracking — head rotation, blink, and smile are applied.
  full,

  /// Head-only tracking — rotation only (lighter CPU).
  headOnly,
}

/// A selectable virtual avatar.
class Avatar {
  final String id;
  final String name;
  final String previewUrl;
  final String animationUrl;
  final AvatarType type;
  final bool isVipExclusive;

  const Avatar({
    required this.id,
    required this.name,
    required this.previewUrl,
    required this.animationUrl,
    this.type = AvatarType.twoD,
    this.isVipExclusive = false,
  });

  factory Avatar.fromJson(Map<String, dynamic> j) => Avatar(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        previewUrl: j['previewUrl']?.toString() ?? '',
        animationUrl: j['animationUrl']?.toString() ?? '',
        type: (j['type']?.toString() == '3d')
            ? AvatarType.threeD
            : AvatarType.twoD,
        isVipExclusive: j['isVipExclusive'] == true,
      );
}

/// Live face-tracking data extracted from ML Kit and normalized for the
/// rendering widget. All values are in avatar-local space (0..1 for
/// probabilities, degrees for rotation, 0..1 for openness).
class AvatarTrackingData {
  /// Head rotation around the vertical axis (left/right). Degrees.
  final double headRotationY;

  /// Head rotation around the depth axis (tilt). Degrees.
  final double headRotationZ;

  /// Left eye openness (0 = closed, 1 = open).
  final double leftEyeOpen;

  /// Right eye openness (0 = closed, 1 = open).
  final double rightEyeOpen;

  /// Smile probability (0 = neutral, 1 = full smile).
  final double smile;

  /// Whether a face was detected in the last frame.
  final bool faceDetected;

  const AvatarTrackingData({
    this.headRotationY = 0,
    this.headRotationZ = 0,
    this.leftEyeOpen = 1,
    this.rightEyeOpen = 1,
    this.smile = 0,
    this.faceDetected = false,
  });

  static const AvatarTrackingData neutral = AvatarTrackingData();

  AvatarTrackingData copyWith({
    double? headRotationY,
    double? headRotationZ,
    double? leftEyeOpen,
    double? rightEyeOpen,
    double? smile,
    bool? faceDetected,
  }) {
    return AvatarTrackingData(
      headRotationY: headRotationY ?? this.headRotationY,
      headRotationZ: headRotationZ ?? this.headRotationZ,
      leftEyeOpen: leftEyeOpen ?? this.leftEyeOpen,
      rightEyeOpen: rightEyeOpen ?? this.rightEyeOpen,
      smile: smile ?? this.smile,
      faceDetected: faceDetected ?? this.faceDetected,
    );
  }
}

/// Immutable snapshot of the full avatar service state, emitted on the
/// [VirtualAvatarService.avatarStateStream].
class VirtualAvatarState {
  final Avatar? activeAvatar;
  final AvatarTrackingMode trackingMode;
  final bool isTracking;
  final AvatarTrackingData trackingData;

  const VirtualAvatarState({
    this.activeAvatar,
    this.trackingMode = AvatarTrackingMode.off,
    this.isTracking = false,
    this.trackingData = AvatarTrackingData.neutral,
  });

  static const VirtualAvatarState initial = VirtualAvatarState();

  VirtualAvatarState copyWith({
    Avatar? activeAvatar,
    AvatarTrackingMode? trackingMode,
    bool? isTracking,
    AvatarTrackingData? trackingData,
    bool clearAvatar = false,
  }) {
    return VirtualAvatarState(
      activeAvatar: clearAvatar ? null : (activeAvatar ?? this.activeAvatar),
      trackingMode: trackingMode ?? this.trackingMode,
      isTracking: isTracking ?? this.isTracking,
      trackingData: trackingData ?? this.trackingData,
    );
  }
}

/// Singleton service managing virtual avatar / VTuber state.
class VirtualAvatarService {
  VirtualAvatarService._();

  static final VirtualAvatarService instance = VirtualAvatarService._();

  static const String _tag = 'VirtualAvatar';

  // ---- State -------------------------------------------------------------

  VirtualAvatarState _state = VirtualAvatarState.initial;
  VirtualAvatarState get state => _state;

  Avatar? get activeAvatar => _state.activeAvatar;
  AvatarTrackingMode get trackingMode => _state.trackingMode;
  bool get isTracking => _state.isTracking;
  AvatarTrackingData get trackingData => _state.trackingData;

  final _stateController =
      StreamController<VirtualAvatarState>.broadcast();
  Stream<VirtualAvatarState> get avatarStateStream =>
      _stateController.stream;

  // ---- Face detector -----------------------------------------------------

  late final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // eye openness + smile
      enableTracking: false,
      enableContours: false,
      enableLandmarks: false,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.15,
    ),
  );

  bool _detectorClosed = false;

  // ---- Built-in avatar catalog ------------------------------------------

  final List<Avatar> _builtinAvatars = const [
    Avatar(
      id: 'anime_girl',
      name: 'Anime Girl',
      previewUrl:
          'https://cdn.belive.app/avatars/anime_girl_preview.webp',
      animationUrl:
          'https://cdn.belive.app/avatars/anime_girl_sheet.webp',
      type: AvatarType.twoD,
    ),
    Avatar(
      id: 'anime_boy',
      name: 'Anime Boy',
      previewUrl:
          'https://cdn.belive.app/avatars/anime_boy_preview.webp',
      animationUrl:
          'https://cdn.belive.app/avatars/anime_boy_sheet.webp',
      type: AvatarType.twoD,
    ),
    Avatar(
      id: 'robot',
      name: 'Robot',
      previewUrl:
          'https://cdn.belive.app/avatars/robot_preview.webp',
      animationUrl:
          'https://cdn.belive.app/avatars/robot_sheet.webp',
      type: AvatarType.twoD,
    ),
    Avatar(
      id: 'animal',
      name: 'Animal',
      previewUrl:
          'https://cdn.belive.app/avatars/animal_preview.webp',
      animationUrl:
          'https://cdn.belive.app/avatars/animal_sheet.webp',
      type: AvatarType.twoD,
    ),
    Avatar(
      id: 'cartoon',
      name: 'Cartoon',
      previewUrl:
          'https://cdn.belive.app/avatars/cartoon_preview.webp',
      animationUrl:
          'https://cdn.belive.app/avatars/cartoon_sheet.webp',
      type: AvatarType.twoD,
    ),
    Avatar(
      id: 'anime_girl_vip',
      name: 'Premium Anime Girl',
      previewUrl:
          'https://cdn.belive.app/avatars/anime_girl_vip_preview.webp',
      animationUrl:
          'https://cdn.belive.app/avatars/anime_girl_vip_sheet.webp',
      type: AvatarType.twoD,
      isVipExclusive: true,
    ),
    Avatar(
      id: 'robot_3d',
      name: '3D Robot',
      previewUrl:
          'https://cdn.belive.app/avatars/robot_3d_preview.webp',
      animationUrl:
          'https://cdn.belive.app/avatars/robot_3d_model.glb',
      type: AvatarType.threeD,
      isVipExclusive: true,
    ),
  ];

  List<Avatar> get avatars =>
      _remoteAvatars.isNotEmpty ? _remoteAvatars : _builtinAvatars;

  List<Avatar> _remoteAvatars = [];

  /// Fetch avatars from the backend, falling back to built-in on failure.
  Future<void> fetchFromBackend() async {
    try {
      final list = await ApiService.getVirtualAvatars();
      if (list.isNotEmpty) {
        _remoteAvatars = list.map((j) => Avatar.fromJson(j)).toList();
        Log.d(_tag, 'fetched ${_remoteAvatars.length} avatars from backend');
      }
    } catch (e) {
      Log.e(_tag, 'fetchFromBackend failed, using built-in', e);
    }
  }

  // ---- Avatar selection --------------------------------------------------

  /// Select an avatar to activate. Pass `null` is not supported here —
  /// use [clearAvatar] to remove the active avatar.
  void selectAvatar(Avatar avatar) {
    _state = _state.copyWith(activeAvatar: avatar);
    _emit();
    Log.d(_tag, 'avatar selected: ${avatar.name} (${avatar.id})');
  }

  /// Remove the active avatar and stop tracking.
  void clearAvatar() {
    stopTracking();
    _state = _state.copyWith(clearAvatar: true);
    _emit();
    Log.d(_tag, 'avatar cleared');
  }

  // ---- Tracking ----------------------------------------------------------

  /// Start face tracking with the given [mode] (defaults to [full]).
  Future<void> startTracking(
      [AvatarTrackingMode mode = AvatarTrackingMode.full]) async {
    if (_state.isTracking && _state.trackingMode == mode) return;
    if (_detectorClosed) {
      Log.e(_tag, 'face detector already closed — cannot start tracking');
      return;
    }
    _state = _state.copyWith(
      trackingMode: mode,
      isTracking: true,
      trackingData: AvatarTrackingData.neutral,
    );
    _emit();
    Log.d(_tag, 'tracking started (mode=$mode)');
  }

  /// Stop face tracking and reset tracking data to neutral.
  void stopTracking() {
    if (!_state.isTracking) return;
    _state = _state.copyWith(
      isTracking: false,
      trackingData: AvatarTrackingData.neutral,
    );
    _emit();
    Log.d(_tag, 'tracking stopped');
  }

  // ---- ML Kit face processing -------------------------------------------

  /// Process an [InputImage] through ML Kit and update the tracking data.
  ///
  /// The live room / GoLive screen calls this from its periodic frame
  /// capture (camera or Agora `VideoFrameObserver`). The service extracts
  /// head rotation, eye openness, and smile probability from the first
  /// detected face and emits a new state snapshot.
  Future<void> processFrame(InputImage inputImage) async {
    if (!_state.isTracking || _detectorClosed) return;
    try {
      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isEmpty) {
        _updateTrackingData(const AvatarTrackingData(faceDetected: false));
        return;
      }
      final face = faces.first;
      final data = _extractTrackingData(face);
      _updateTrackingData(data);
    } catch (e, s) {
      Log.e(_tag, 'processFrame failed', e, s);
    }
  }

  /// Process a raw [Face] (already detected by an external detector).
  /// Useful when the host compliance guard or AR sticker service already
  /// runs ML Kit on the same frame — avoids a second detection pass.
  void processFace(Face? face) {
    if (!_state.isTracking) return;
    if (face == null) {
      _updateTrackingData(const AvatarTrackingData(faceDetected: false));
      return;
    }
    final data = _extractTrackingData(face);
    _updateTrackingData(data);
  }

  AvatarTrackingData _extractTrackingData(Face face) {
    final mode = _state.trackingMode;

    if (mode == AvatarTrackingMode.headOnly) {
      return AvatarTrackingData(
        headRotationY: face.headEulerAngleY ?? 0,
        headRotationZ: face.headEulerAngleZ ?? 0,
        faceDetected: true,
      );
    }

    // full mode — eyes + smile + rotation.
    // ML Kit provides leftEyeOpenProbability / rightEyeOpenProbability
    // and smilingProbability. These are null when not available.
    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;
    return AvatarTrackingData(
      headRotationY: face.headEulerAngleY ?? 0,
      headRotationZ: face.headEulerAngleZ ?? 0,
      leftEyeOpen: leftEye != null ? leftEye.clamp(0.0, 1.0) : 1.0,
      rightEyeOpen: rightEye != null ? rightEye.clamp(0.0, 1.0) : 1.0,
      smile: (face.smilingProbability ?? 0.0).clamp(0.0, 1.0),
      faceDetected: true,
    );
  }

  void _updateTrackingData(AvatarTrackingData data) {
    _state = _state.copyWith(trackingData: data);
    _emit();
  }

  // ---- Helpers -----------------------------------------------------------

  void _emit() {
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }

  // ---- Cleanup -----------------------------------------------------------

  void dispose() {
    stopTracking();
    _stateController.close();
    if (!_detectorClosed) {
      _detectorClosed = true;
      _faceDetector.close().catchError((_) {});
    }
    Log.d(_tag, 'service disposed');
  }
}
