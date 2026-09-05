/// Live camera capture screen for KYC verification with real-time
/// face detection, liveness checks, and auto-capture.
///
/// **Selfie mode** uses google_mlkit_face_detection to:
///   - Detect the face in real time
///   - Check head angle (headEulerAngleY / headEulerAngleZ) â†’ must be straight
///   - Check face is centered and large enough inside the oval guide
///   - Run a blink-detection liveness challenge (leftEyeOpenProbability /
///     rightEyeOpenProbability)
///   - Auto-capture when alignment is 100% + liveness confirmed
///   - Show real-time visual feedback (red frame = misaligned, green = perfect)
///   - Show instruction overlay ("Move Left", "Hold Still", "Blink Eyes", etc.)
///
/// **ID card mode** shows a rectangular frame guide and uses real-time
/// ML Kit text recognition to detect when a readable ID card is inside the
/// frame. When enough text is detected stably for a few consecutive checks,
/// the photo is auto-captured (no manual shutter tap needed). A manual
/// shutter button is kept as a fallback for poor-lighting edge cases.
///
/// Returns the captured file path via `Navigator.pop` as `{'path': ...}`.
library kyc_camera;

import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import 'kyc_document_review_screen.dart';
import 'kyc_ocr_parser.dart';
import 'package:belive/widgets/preloader.dart';

/// Capture mode â€” controls the camera direction and the on-screen guide.
enum KycCaptureMode {
  /// Front-camera selfie with an oval face guide + auto-capture + liveness.
  selfie,

  /// Rear-camera ID card capture with a rectangular card guide + auto-capture
  /// via real-time text recognition (manual shutter kept as fallback).
  idCard,
}

class KycCameraScreen extends StatefulWidget {
  const KycCameraScreen({
    super.key,
    required this.mode,
    this.instruction,
    this.cardType,
    this.requireLiveness = true,
  });

  final KycCaptureMode mode;
  final String? instruction;

  /// e.g. 'aadhaar', 'pan', 'voterId', 'passport', 'drivingLicense', 'other'.
  /// Used to tune OCR heuristics when extracting name/DOB/ID number/address.
  final String? cardType;

  /// Whether the user must perform the full liveness challenge. When false,
  /// the camera only requires a centered, straight face before auto-capture.
  final bool requireLiveness;

  @override
  State<KycCameraScreen> createState() => _KycCameraScreenState();
}

class _KycCameraScreenState extends State<KycCameraScreen>
    with WidgetsBindingObserver {
  static const String _tag = 'KycCamera';

  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedIdx = 0;
  bool _initializing = true;
  bool _capturing = false;
  FlashMode _flashMode = FlashMode.off;

  // ---- Face detection (selfie mode only) --------------------------------
  late final FaceDetector _faceDetector;
  // ---- Text recognition (ID card mode only) -----------------------------
  // Used for real-time auto-capture: detects when a readable ID card is in
  // the frame. Reused across frames (created once, closed in dispose).
  late final TextRecognizer _textRecognizer;
  bool _isBusy = false;
  // Frame throttling â€” process every 2nd frame (~15fps detection) for
  // responsive liveness challenges without overwhelming low-end devices.
  int _frameCounter = 0;
  static const int _frameSkip = 2;
  // Text recognition is much heavier than face detection, so for ID card
  // mode we run it on a much sparser cadence (~1.5fps) â€” enough to detect a
  // stable card without lagging the camera preview.
  static const int _textFrameSkip = 10;

  // Real-time detection state
  bool _faceDetected = false;
  bool _aligned = false; // face centered + correct size + head straight
  String _instruction = '';

  // ---- Professional liveness challenge flow ------------------------------
  // Sequential steps like Jumio/Onfido: center â†’ turn right â†’ turn left â†’
  // blink â†’ hold still â†’ capture. Each step must be completed in order.
  // A step is "completed" when its condition holds for N consecutive frames.
  _LivenessStep _livenessStep = _LivenessStep.centering;
  int _stepHoldFrames = 0; // consecutive frames current step's condition held
  static const int _stepHoldRequired = 4; // frames to confirm a step (~0.3s)
  int _captureHoldFrames = 0;
  static const int _captureHoldRequired = 10; // ~0.7s hold for capture

  // Which steps are done (for the progress indicator).
  final Set<_LivenessStep> _completedSteps = {};

  // ---- ID card auto-capture state ---------------------------------------
  // Counts consecutive text-recognition checks where a readable card was
  // detected. When it reaches [_idCardStableRequired], we auto-capture.
  bool _idCardDetected = false;
  int _idCardStableChecks = 0;
  static const int _idCardStableRequired = 3; // ~2s at 1.5fps detection

  // Exponential moving average smoothing to eliminate jitter between frames.
  double? _smoothDx;
  double? _smoothDy;
  double? _smoothWidthRatio;
  double? _smoothEulerY;
  double? _smoothEulerZ;
  static const double _smoothingAlpha = 0.30;

  // Hysteresis for centering check.
  bool _wasCentered = false;
  bool _wasLargeEnough = false;

  // Last rendered state â€” skip redundant setState calls.
  String _lastInstruction = '';
  bool _lastFaceDetected = false;
  bool _lastAligned = false;
  _LivenessStep _lastLivenessStep = _LivenessStep.centering;
  int _lastCompletedCount = 0;

  // Debug overlay â€” shows real-time detection values so we can see exactly
  // why a step is/isn't passing. Toggle by tapping the top-right corner.
  bool _showDebug = true;
  double _dbgDx = 0, _dbgDy = 0, _dbgWidth = 0, _dbgEulerY = 0, _dbgEulerZ = 0;
  double _dbgLeftEye = 1, _dbgRightEye = 1;
  bool _dbgCentered = false, _dbgLarge = false, _dbgStraight = false;

  double _smooth(double? prev, double current) =>
      prev == null
          ? current
          : (prev * (1 - _smoothingAlpha) + current * _smoothingAlpha);

  // Tutorial overlay
  bool _showTutorial = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true, // for eye-open probability
        enableTracking: false,
        enableContours: false,
        enableLandmarks: false,
        // `fast` mode is REQUIRED for real-time image stream processing.
        // `accurate` mode is meant for static images and is 3-5x slower,
        // causing severe lag and dropped frames on mid-range devices.
        performanceMode: FaceDetectorMode.fast,
        // Very low minFaceSize (0.08) â€” detects faces even when phone is
        // at a comfortable arm's length. Higher values miss far faces.
        minFaceSize: 0.08,
      ),
    );
    // Text recognizer for ID card auto-capture (latin script covers most
    // government IDs â€” passport, driver's license, national ID, etc.).
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _instruction =
        widget.mode == KycCaptureMode.selfie
            ? 'Position your face inside the oval'
            : 'Place your ID card inside the frame';
    // Start camera initialization as soon as the first frame is built.
    // Previously this was missing â€” the camera only initialized on app
    // resume (lifecycle event), which is why the loading spinner could
    // spin forever on first open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initCamera();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _faceDetector.close();
    _textRecognizer.close();
    // Stop the image stream before disposing to avoid race conditions.
    if (_controller != null && _controller!.value.isStreamingImages) {
      _controller!.stopImageStream();
    }
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Don't dispose on `inactive` â€” that fires when the permission dialog
    // or tutorial overlay appears, causing "disposed controller" crashes.
    // Only dispose on `paused` (app actually went to background).
    if (state == AppLifecycleState.paused) {
      if (_controller != null && _controller!.value.isStreamingImages) {
        _controller!.stopImageStream();
      }
      _controller?.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      if (_controller == null || !_controller!.value.isInitialized) {
        _initCamera();
      }
    }
  }

  // ---- Camera init -------------------------------------------------------

  Future<void> _initCamera() async {
    try {
      final camStatus = await Permission.camera.request();
      if (!camStatus.isGranted) {
        _showPermissionDenied();
        if (mounted) setState(() => _initializing = false);
        return;
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        Fluttertoast.showToast(msg: 'No cameras available');
        if (mounted) setState(() => _initializing = false);
        return;
      }
      _cameras = cameras;
      final wantFront = widget.mode == KycCaptureMode.selfie;
      final target =
          wantFront ? CameraLensDirection.front : CameraLensDirection.back;
      _selectedIdx = cameras.indexWhere((c) => c.lensDirection == target);
      if (_selectedIdx == -1) _selectedIdx = 0;
      await _startController();
    } catch (e, s) {
      Log.e(_tag, 'init camera failed', e, s);
      if (mounted) setState(() => _initializing = false);
    }
  }

  void _showPermissionDenied() {
    Fluttertoast.showToast(
      msg: 'Camera permission is required for KYC verification',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Camera Permission Required'),
              content: const Text(
                'KYC verification requires camera access to capture your live selfie and ID card. '
                'Please grant camera permission in app settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openAppSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
      );
    });
  }

  Future<void> _startController() async {
    final controller = CameraController(
      _cameras[_selectedIdx],
      // Selfie: `medium` is a good balance â€” enough detail for KYC capture,
      // and with frame throttling + fast mode + bulk YUV conversion the
      // stream processing stays responsive even on low-end devices.
      // ID card: `high` for sharp text readability.
      ResolutionPreset.high,
      enableAudio: false,
      // Both modes need YUV_420_888 for real-time ML Kit stream processing
      // (face detection for selfie, text recognition for ID card).
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    _controller = controller;
    await controller.initialize();
    try {
      await controller.setFlashMode(_flashMode);
    } catch (_) {}
    // Start the image stream for real-time detection in BOTH modes:
    //  - selfie: face detection + liveness auto-capture
    //  - idCard: text recognition + auto-capture when card is readable
    try {
      await controller.startImageStream(_processCameraImage);
    } catch (e, s) {
      Log.e(_tag, 'startImageStream failed', e, s);
    }
    if (mounted) setState(() => _initializing = false);
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    setState(() => _initializing = true);
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _selectedIdx = (_selectedIdx + 1) % _cameras.length;
    await _startController();
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    final next = _flashMode == FlashMode.off ? FlashMode.auto : FlashMode.off;
    try {
      await _controller!.setFlashMode(next);
      setState(() => _flashMode = next);
    } catch (_) {}
  }

  /// Resumes the image stream after the user taps "Retake" in the review
  /// screen, so auto-capture / auto-detection continues from the camera.
  Future<void> _resumeImageStream() async {
    if (_controller == null || _capturing) return;
    try {
      await _controller!.startImageStream(_processCameraImage);
    } catch (e, s) {
      Log.e(_tag, 'resumeImageStream failed', e, s);
    }
  }

  // ---- Face detection ----------------------------------------------------

  /// Convert Android YUV_420_888 CameraImage planes to NV21 byte array.
  ///
  /// Optimized: uses bulk `setRange` for the Y plane (the largest part)
  /// when there is no stride padding, and a tight loop only for the UV
  /// interleave (which is 1/4 the size of Y). This is ~5x faster than a
  /// naive per-byte double loop over the entire image.
  Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final ySize = width * height;
    final uvSize = ySize ~/ 2;
    final nv21 = Uint8List(ySize + uvSize);

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBuffer = yPlane.bytes;
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;

    final yRowStride = yPlane.bytesPerRow;
    final uRowStride = uPlane.bytesPerRow;
    final vRowStride = vPlane.bytesPerRow;
    final uPixelStride = uPlane.bytesPerPixel ?? 2;
    final vPixelStride = vPlane.bytesPerPixel ?? 2;

    // Fast path: Y plane with no padding â€” single bulk copy.
    if (yRowStride == width) {
      nv21.setRange(0, ySize, yBuffer);
    } else {
      // Slow path: row-by-row copy to skip stride padding.
      int yIndex = 0;
      for (int row = 0; row < height; row++) {
        final rowOffset = row * yRowStride;
        nv21.setRange(yIndex, yIndex + width, yBuffer, rowOffset);
        yIndex += width;
      }
    }

    // Interleave V and U (NV21 format: VUVUVU...).
    // UV plane is 1/4 the size of Y, so this loop is cheap.
    int uvIndex = ySize;
    final halfWidth = width ~/ 2;
    final halfHeight = height ~/ 2;
    for (int row = 0; row < halfHeight; row++) {
      final vRowOffset = row * vRowStride;
      final uRowOffset = row * uRowStride;
      for (int col = 0; col < halfWidth; col++) {
        nv21[uvIndex++] = vBuffer[vRowOffset + col * vPixelStride];
        nv21[uvIndex++] = uBuffer[uRowOffset + col * uPixelStride];
      }
    }

    return nv21;
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isBusy || _capturing) return;
    // Throttle: skip frames to keep UI responsive on low-end devices.
    _frameCounter++;
    if (_frameCounter % _frameSkip != 0) return;

    // ID card mode â€” run text recognition on a much sparser cadence (it is
    // far heavier than face detection) and dispatch to a separate handler.
    if (widget.mode == KycCaptureMode.idCard) {
      if (_frameCounter % _textFrameSkip != 0) return;
      await _processIdCardImage(image);
      return;
    }

    _isBusy = true;

    try {
      final Size rawImageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      final camera = _cameras[_selectedIdx];
      final sensorOrientation = camera.sensorOrientation;
      InputImageRotation? rotation;
      if (Platform.isIOS) {
        rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
      } else if (Platform.isAndroid) {
        rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
      }
      if (rotation == null) {
        Log.w(_tag, 'rotation is null, skipping frame');
        return;
      }

      // ML Kit returns face coordinates in the ROTATED coordinate space
      // (i.e., as if the image was already rotated to upright orientation).
      // The raw camera buffer is landscape (e.g., 640x480), but after
      // rotation 90/270 the upright image is portrait (e.g., 480x640).
      // We must use the ROTATED size for all centering / size calculations,
      // otherwise the image center is wrong and "centered" never passes.
      final Size rotatedSize;
      if (rotation == InputImageRotation.rotation90deg ||
          rotation == InputImageRotation.rotation270deg) {
        rotatedSize = Size(rawImageSize.height, rawImageSize.width);
      } else {
        rotatedSize = rawImageSize;
      }

      final InputImageFormat inputImageFormat;
      final Uint8List bytes;

      if (Platform.isIOS) {
        // iOS â€” BGRA8888, single plane.
        inputImageFormat = InputImageFormat.bgra8888;
        bytes = image.planes.first.bytes;
      } else {
        // Android â€” YUV_420_888, convert to NV21 for ML Kit.
        inputImageFormat = InputImageFormat.nv21;
        bytes = _yuv420ToNv21(image);
      }

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          // ML Kit expects the RAW buffer size here (before rotation).
          size: rawImageSize,
          rotation: rotation,
          format: inputImageFormat,
          bytesPerRow:
              Platform.isIOS ? image.planes.first.bytesPerRow : image.width,
        ),
      );

      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isNotEmpty) {
        final f = faces.first;
        Log.d(
          _tag,
          'face: bb=${f.boundingBox}, eulerY=${f.headEulerAngleY}, '
          'eulerZ=${f.headEulerAngleZ}, L=${f.leftEyeOpenProbability}, '
          'R=${f.rightEyeOpenProbability}, rotSize=$rotatedSize',
        );
      }
      // Pass the ROTATED size â€” face coordinates from ML Kit are in rotated space.
      _handleFaces(faces, rotatedSize, rotation);
    } catch (e, s) {
      Log.e(_tag, 'processCameraImage error', e, s);
    } finally {
      _isBusy = false;
    }
  }

  /// Process detected faces and update the alignment / liveness state.
  ///
  /// Professional liveness flow (like Jumio/Onfido):
  ///   1. Centering  â€” position face in oval (centered + correct size + straight)
  ///   2. Turn Right â€” turn head to the right (eulerY exceeds threshold)
  ///   3. Turn Left  â€” turn head to the left (opposite direction)
  ///   4. Blink      â€” blink eyes (close then open)
  ///   5. Capturing  â€” hold still, auto-capture
  ///
  /// Each step must hold its condition for [_stepHoldRequired] consecutive
  /// frames before advancing. Completed steps show a green checkmark.
  void _handleFaces(
    List<Face> faces,
    Size imageSize,
    InputImageRotation rotation,
  ) {
    if (!mounted || _capturing) return;

    if (faces.isEmpty) {
      const newInstruction =
          'No face detected. Position your face inside the oval.';
      final shouldRebuild =
          mounted &&
          (_lastFaceDetected ||
              _lastInstruction != newInstruction ||
              _lastLivenessStep != _LivenessStep.centering);
      _wasCentered = false;
      _wasLargeEnough = false;
      _smoothDx = null;
      _smoothDy = null;
      _smoothWidthRatio = null;
      _smoothEulerY = null;
      _smoothEulerZ = null;
      _stepHoldFrames = 0;
      _captureHoldFrames = 0;
      _livenessStep = _LivenessStep.centering;
      _completedSteps.clear();
      _faceDetected = false;
      _aligned = false;
      _instruction = newInstruction;
      _lastFaceDetected = false;
      _lastAligned = false;
      _lastInstruction = newInstruction;
      _lastLivenessStep = _LivenessStep.centering;
      _lastCompletedCount = 0;
      if (shouldRebuild) {
        setState(() {});
      }
      return;
    }

    // Use the largest face (closest to camera).
    final face = faces.reduce(
      (a, b) =>
          a.boundingBox.width * a.boundingBox.height >
                  b.boundingBox.width * b.boundingBox.height
              ? a
              : b,
    );

    final boundingBox = face.boundingBox;
    final faceCenterX = boundingBox.center.dx;
    final faceCenterY = boundingBox.center.dy;
    final imageCenterX = imageSize.width / 2;
    final imageCenterY = imageSize.height / 2;

    final isFrontCamera =
        _cameras[_selectedIdx].lensDirection == CameraLensDirection.front;

    // ---- Smooth raw per-frame values --------------------------------------
    final rawDx = (faceCenterX - imageCenterX) / imageSize.width;
    final rawDy = (faceCenterY - imageCenterY) / imageSize.height;
    final rawWidthRatio = boundingBox.width / imageSize.width;
    final rawEulerY = face.headEulerAngleY ?? 0;
    final rawEulerZ = face.headEulerAngleZ ?? 0;

    final dxRatio = _smoothDx = _smooth(_smoothDx, rawDx);
    final dyRatio = _smoothDy = _smooth(_smoothDy, rawDy);
    final faceWidthRatio =
        _smoothWidthRatio = _smooth(_smoothWidthRatio, rawWidthRatio);
    final eulerY = _smoothEulerY = _smooth(_smoothEulerY, rawEulerY);
    final eulerZ = _smoothEulerZ = _smooth(_smoothEulerZ, rawEulerZ);

    // ---- Basic alignment checks (used in centering step) -----------------
    // Generous thresholds â€” the goal is "face roughly in the oval", not
    // pixel-perfect centering. Too tight = user can never pass.
    final centerTolerance = _wasCentered ? 0.25 : 0.20;
    final isCentered =
        dxRatio.abs() < centerTolerance && dyRatio.abs() < centerTolerance;
    _wasCentered = isCentered;

    final sizeTolerance = _wasLargeEnough ? 0.10 : 0.12;
    final isLargeEnough = faceWidthRatio > sizeTolerance;
    _wasLargeEnough = isLargeEnough;

    final isStraight = eulerY.abs() < 15.0 && eulerZ.abs() < 15.0;

    // Eye states for blink detection.
    final leftEyeOpen = face.leftEyeOpenProbability ?? 1.0;
    final rightEyeOpen = face.rightEyeOpenProbability ?? 1.0;
    final eyesOpen = leftEyeOpen > 0.50 && rightEyeOpen > 0.50;
    final eyesClosed = leftEyeOpen < 0.30 && rightEyeOpen < 0.30;

    final aligned = isCentered && isLargeEnough && isStraight;

    // When liveness is not required, skip the full challenge sequence and
    // move straight to capture once the face is centered and straight.
    if (!widget.requireLiveness && aligned) {
      _livenessStep = _LivenessStep.capturing;
      _completedSteps
        ..clear()
        ..addAll(
          _LivenessStep.values.where((s) => s != _LivenessStep.capturing),
        );
    }

    // Store debug values for the overlay.
    _dbgDx = dxRatio;
    _dbgDy = dyRatio;
    _dbgWidth = faceWidthRatio;
    _dbgEulerY = eulerY;
    _dbgEulerZ = eulerZ;
    _dbgLeftEye = leftEyeOpen;
    _dbgRightEye = rightEyeOpen;
    _dbgCentered = isCentered;
    _dbgLarge = isLargeEnough;
    _dbgStraight = isStraight;

    // ---- Liveness step machine --------------------------------------------
    String instruction;

    switch (_livenessStep) {
      case _LivenessStep.centering:
        if (!isCentered) {
          final faceIsRightOfCenter = isFrontCamera ? dxRatio < 0 : dxRatio > 0;
          instruction =
              faceIsRightOfCenter
                  ? 'Move your face to the left'
                  : 'Move your face to the right';
          if (dyRatio > 0.06) {
            instruction += ' and up';
          } else if (dyRatio < -0.06) {
            instruction += ' and down';
          }
          _stepHoldFrames = 0;
        } else if (!isLargeEnough) {
          instruction = 'Move a little closer to the camera';
          _stepHoldFrames = 0;
        } else if (!isStraight) {
          instruction = 'Keep your head straight and look at the camera';
          _stepHoldFrames = 0;
        } else {
          // All conditions met â€” hold for confirmation.
          _stepHoldFrames++;
          if (_stepHoldFrames >= _stepHoldRequired) {
            _completedSteps.add(_LivenessStep.centering);
            _livenessStep = _LivenessStep.turnRight;
            _stepHoldFrames = 0;
            instruction = 'Now turn your head to the RIGHT â†’';
          } else {
            instruction = 'Hold stillâ€¦';
          }
        }
        break;

      case _LivenessStep.turnRight:
        // For front camera: eulerY < -15 means user turned right (mirrored).
        // For back camera: eulerY > 15 means turned right.
        final turnedRight = isFrontCamera ? eulerY < -15 : eulerY > 15;
        if (turnedRight) {
          _stepHoldFrames++;
          if (_stepHoldFrames >= 3) {
            _completedSteps.add(_LivenessStep.turnRight);
            _livenessStep = _LivenessStep.turnLeft;
            _stepHoldFrames = 0;
            instruction = 'Now turn your head to the LEFT â†';
          } else {
            instruction = 'Good! Keep turning rightâ€¦';
          }
        } else if (eulerY.abs() < 8) {
          // Back to center â€” prompt to turn right.
          instruction = 'Turn your head to the RIGHT â†’';
          _stepHoldFrames = 0;
        } else {
          instruction = 'Turn more to the RIGHT â†’';
          _stepHoldFrames = 0;
        }
        break;

      case _LivenessStep.turnLeft:
        final turnedLeft = isFrontCamera ? eulerY > 15 : eulerY < -15;
        if (turnedLeft) {
          _stepHoldFrames++;
          if (_stepHoldFrames >= 3) {
            _completedSteps.add(_LivenessStep.turnLeft);
            _livenessStep = _LivenessStep.blink;
            _stepHoldFrames = 0;
            instruction = 'Now face forward and BLINK your eyes';
          } else {
            instruction = 'Good! Keep turning leftâ€¦';
          }
        } else if (eulerY.abs() < 8) {
          instruction = 'Turn your head to the LEFT â†';
          _stepHoldFrames = 0;
        } else {
          instruction = 'Turn more to the LEFT â†';
          _stepHoldFrames = 0;
        }
        break;

      case _LivenessStep.blink:
        if (eyesClosed) {
          _stepHoldFrames++;
          instruction = 'Eyes closed detectedâ€¦ now open them';
          if (_stepHoldFrames >= 2) {
            _livenessStep = _LivenessStep.blinkOpen;
            _stepHoldFrames = 0;
          }
        } else {
          instruction = 'Blink your eyes now (close then open)';
          _stepHoldFrames = 0;
        }
        break;

      case _LivenessStep.blinkOpen:
        if (eyesOpen) {
          _stepHoldFrames++;
          if (_stepHoldFrames >= 2) {
            _completedSteps.add(_LivenessStep.blink);
            _livenessStep = _LivenessStep.capturing;
            _stepHoldFrames = 0;
            _captureHoldFrames = 0;
            instruction = 'Perfect! Hold stillâ€¦';
          } else {
            instruction = 'Eyes open â€” holdâ€¦';
          }
        } else {
          instruction = 'Open your eyes now';
          _stepHoldFrames = 0;
        }
        break;

      case _LivenessStep.capturing:
        // Must stay centered + straight while capturing.
        if (!isCentered || !isStraight) {
          _captureHoldFrames = 0;
          instruction = 'Hold still â€” don\'t move!';
        } else {
          _captureHoldFrames++;
          final framesLeft = _captureHoldRequired - _captureHoldFrames;
          final secondsLeft = (framesLeft / 15).ceil().clamp(0, 9);
          instruction =
              secondsLeft > 0 ? 'Hold stillâ€¦ $secondsLeft' : 'Capturingâ€¦';
          if (_captureHoldFrames >= _captureHoldRequired) {
            instruction = 'Capturingâ€¦';
            _autoCapture();
            return;
          }
        }
        break;
    }

    // Only rebuild the UI when the visible state actually changes.
    final completedCount = _completedSteps.length;
    if (mounted &&
        (instruction != _lastInstruction ||
            _faceDetected != _lastFaceDetected ||
            aligned != _lastAligned ||
            _livenessStep != _lastLivenessStep ||
            completedCount != _lastCompletedCount)) {
      _lastInstruction = instruction;
      _lastFaceDetected = true;
      _lastAligned = aligned;
      _lastLivenessStep = _livenessStep;
      _lastCompletedCount = completedCount;
      setState(() {
        _faceDetected = true;
        _aligned = aligned;
        _instruction = instruction;
      });
    } else {
      _faceDetected = true;
      _aligned = aligned;
      _instruction = instruction;
    }
  }

  /// Auto-capture the photo (called when alignment + liveness are confirmed).
  Future<void> _autoCapture() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      await _controller?.stopImageStream();
      final xFile = await _controller!.takePicture();
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final suffix = widget.mode == KycCaptureMode.selfie ? 'selfie' : 'idcard';
      final savedPath = '${dir.path}/kyc_${suffix}_$ts.jpg';
      await File(xFile.path).copy(savedPath);

      if (widget.mode == KycCaptureMode.selfie) {
        // Selfie is captured full-frame, no crop/review. The liveness/face
        // detection already ensured the face is centered in the guide.
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) Navigator.pop(context, {'path': savedPath});
        return;
      }

      // Crop the ID card capture to the on-screen guide rectangle, removing
      // background while keeping the full card in the frame.
      var croppedPath = await _cropToGuide(savedPath, widget.mode);

      // ID card review: let the user rotate the cropped card before confirming.
      final reviewed = await _openReviewScreen(
        croppedPath,
        KycReviewMode.idFront,
      );
      if (reviewed == null) {
        // User chose to retake.
        if (mounted) {
          setState(() => _capturing = false);
          await _resumeImageStream();
        }
        return;
      }
      croppedPath = reviewed;

      // Small delay so the user sees "Perfect! Capturing" feedback.
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) Navigator.pop(context, {'path': croppedPath});
    } catch (e, s) {
      Log.e(_tag, 'autoCapture failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to capture. Try again.');
      if (mounted) {
        setState(() => _capturing = false);
        await _resumeImageStream();
      }
    }
  }

  /// Process a camera frame in ID card mode using ML Kit text recognition.
  ///
  /// Detects when a readable ID card is inside the frame by checking that
  /// there are multiple text blocks with enough total characters. When the
  /// card is detected stably for [_idCardStableRequired] consecutive checks,
  /// [_autoCaptureIdCard] fires â€” no manual shutter tap needed.
  Future<void> _processIdCardImage(CameraImage image) async {
    if (!mounted || _capturing) return;
    _isBusy = true;
    try {
      final rawImageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final camera = _cameras[_selectedIdx];
      final sensorOrientation = camera.sensorOrientation;
      final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
      if (rotation == null) {
        Log.w(_tag, 'idCard: rotation is null, skipping frame');
        return;
      }

      final InputImageFormat inputImageFormat;
      final Uint8List bytes;
      if (Platform.isIOS) {
        inputImageFormat = InputImageFormat.bgra8888;
        bytes = image.planes.first.bytes;
      } else {
        inputImageFormat = InputImageFormat.nv21;
        bytes = _yuv420ToNv21(image);
      }

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: rawImageSize,
          rotation: rotation,
          format: inputImageFormat,
          bytesPerRow:
              Platform.isIOS ? image.planes.first.bytesPerRow : image.width,
        ),
      );

      final recognizedText = await _textRecognizer.processImage(inputImage);
      final blocks = recognizedText.blocks;
      // Total non-whitespace characters â€” a good proxy for "card is readable".
      final totalChars =
          recognizedText.text.replaceAll(RegExp(r'\s'), '').length;
      // A genuine ID card usually has several text blocks (name, DOB,
      // ID number, address, issuing authority, etc.). Requiring >= 2 blocks
      // and >= 20 chars filters out random background text/glare.
      final cardDetected = blocks.length >= 2 && totalChars >= 20;

      _handleIdCardDetection(cardDetected, totalChars, blocks.length);
    } catch (e, s) {
      Log.e(_tag, 'processIdCardImage error', e, s);
    } finally {
      _isBusy = false;
    }
  }

  /// Update ID card auto-capture state based on the latest text-detection
  /// result. Mirrors the selfie liveness hold-frame logic: the card must be
  /// detected for N consecutive checks before auto-capture fires.
  void _handleIdCardDetection(bool detected, int chars, int blocks) {
    if (!mounted || _capturing) return;
    _idCardDetected = detected;
    // chars/blocks are useful for tuning thresholds â€” log them at debug level.
    Log.d(
      _tag,
      'idCard detection: detected=$detected, blocks=$blocks, chars=$chars, '
      'stable=$_idCardStableChecks/$_idCardStableRequired',
    );

    String instruction;
    if (detected) {
      _idCardStableChecks++;
      if (_idCardStableChecks >= _idCardStableRequired) {
        instruction = 'Hold still â€” capturing';
        _autoCaptureIdCard();
        return;
      }
      final left = _idCardStableRequired - _idCardStableChecks;
      instruction = 'Card detected â€” hold still ($left)';
    } else {
      _idCardStableChecks = 0;
      instruction =
          widget.instruction ??
          'Place your ID card inside the frame. Make sure all text is clear and readable.';
    }

    if (mounted && instruction != _lastInstruction) {
      _lastInstruction = instruction;
      setState(() => _instruction = instruction);
    } else {
      _instruction = instruction;
    }
  }

  /// Crops a full camera capture to the visible guide region (oval for selfie,
  /// rounded rectangle for ID card). Uses the `image` package to decode the
  /// JPEG, apply its EXIF orientation, compute a crop rectangle in image
  /// coordinates that matches the on-screen guide, and re-encode as JPEG.
  ///
  /// Returns a new JPEG path. If decoding or cropping fails, the original
  /// [sourcePath] is returned so the capture is not lost.
  Future<String> _cropToGuide(String sourcePath, KycCaptureMode mode) async {
    if (!mounted) return sourcePath;

    // Capture the screen/preview geometry before any async work so we don't
    // hold a BuildContext across await gaps.
    final screenSize = MediaQuery.of(context).size;
    final previewSize = _controller?.value.previewSize;

    try {
      final bytes = await File(sourcePath).readAsBytes();
      var decoded = img.decodeImage(bytes);
      if (decoded == null) {
        Log.w(_tag, 'cropToGuide: decode failed, using full frame');
        return sourcePath;
      }

      // Bake EXIF orientation so we are working in the viewing (screen)
      // coordinate space, matching what the user saw in the preview.
      decoded = img.bakeOrientation(decoded);

      // Re-check preview size after the await (null promotion resets).
      if (previewSize == null) {
        Log.w(
          _tag,
          'cropToGuide: no preview size after decode, using full frame',
        );
        return sourcePath;
      }

      // The CameraPreview is wrapped in a FittedBox with fitWidth. The child
      // dimensions are (previewSize.height, previewSize.width) because the
      // sensor stream is landscape but the screen is portrait.
      final childW = previewSize.height;
      final childH = previewSize.width;

      final screenW = screenSize.width;
      final screenH = screenSize.height;

      // scale: how many child-pixels fit in one screen-pixel for fitWidth.
      final scale = childW / screenW;

      // The displayed child, after fitWidth scaling.
      final displayH = childH / scale; // screen-pixels
      final displayTop = (screenH - displayH) / 2; // centered

      // Guide rect in screen coordinates.
      final guideRect =
          mode == KycCaptureMode.selfie
              ? _selfieGuideSize(screenSize)
              : _idCardGuideSize(screenSize);

      // Map the guide from screen coordinates to child (preview) coordinates.
      // childX = screenX * scale
      // childY = (screenY - displayTop) * scale
      final childLeft = (guideRect.left) * scale;
      final childTop = (guideRect.top - displayTop) * scale;
      final childWidth = guideRect.width * scale;
      final childHeight = guideRect.height * scale;

      // Map child coordinates to the captured image. Both are in the same
      // (upright) orientation after EXIF baking. Since the camera stream and
      // the still capture usually share the same aspect ratio, the scale is
      // uniform.
      final imageW = decoded.width.toDouble();
      final imageH = decoded.height.toDouble();
      final scaleToImageX = imageW / childW;
      final scaleToImageY = imageH / childH;

      var cropLeft = (childLeft * scaleToImageX).round();
      var cropTop = (childTop * scaleToImageY).round();
      var cropWidth = (childWidth * scaleToImageX).round();
      var cropHeight = (childHeight * scaleToImageY).round();

      // Clamp to image bounds â€” guard against rounding / black-bar offsets.
      if (cropLeft < 0) {
        cropWidth += cropLeft;
        cropLeft = 0;
      }
      if (cropTop < 0) {
        cropHeight += cropTop;
        cropTop = 0;
      }
      if (cropLeft + cropWidth > decoded.width) {
        cropWidth = decoded.width - cropLeft;
      }
      if (cropTop + cropHeight > decoded.height) {
        cropHeight = decoded.height - cropTop;
      }

      if (cropWidth <= 0 || cropHeight <= 0) {
        Log.w(_tag, 'cropToGuide: computed empty crop, using full frame');
        return sourcePath;
      }

      final cropped = img.copyCrop(
        decoded,
        x: cropLeft,
        y: cropTop,
        width: cropWidth,
        height: cropHeight,
      );

      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final suffix = mode == KycCaptureMode.selfie ? 'selfie' : 'idcard';
      final croppedPath = '${dir.path}/kyc_${suffix}_cropped_$ts.jpg';
      final croppedBytes = img.encodeJpg(cropped, quality: 92);
      await File(croppedPath).writeAsBytes(croppedBytes);

      Log.d(
        _tag,
        'cropToGuide: $sourcePath â†’ $croppedPath (${cropWidth}x$cropHeight})',
      );
      return croppedPath;
    } catch (e, s) {
      Log.e(_tag, 'cropToGuide failed, using full frame', e, s);
      return sourcePath;
    }
  }

  /// Opens the post-capture review screen so the user can rotate/crop the
  /// captured image before accepting it. Returns the reviewed path, or `null`
  /// if the user taps "Retake".
  Future<String?> _openReviewScreen(String path, KycReviewMode mode) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => KycDocumentReviewScreen(imagePath: path, mode: mode),
      ),
    );
    if (result == null || result['path'] == null) return null;
    return result['path'] as String;
  }

  /// Auto-capture the ID card photo (called when text detection confirms a
  /// readable card has been stable in the frame). After capturing, runs OCR
  /// on the still image and returns both the file path and the extracted
  /// fields so the caller can auto-fill the form â€” same as [_manualCapture].
  Future<void> _autoCaptureIdCard() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      await _controller?.stopImageStream();
      final xFile = await _controller!.takePicture();
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final savedPath = '${dir.path}/kyc_idcard_$ts.jpg';
      await File(xFile.path).copy(savedPath);

      // Show the user the full camera frame. They can crop/rotate manually so
      // the card is perfectly centered and straight — no guesswork.
      var croppedPath = savedPath;

      // Let the user review, manually crop and rotate before we run OCR.
      final reviewed = await _openReviewScreen(
        croppedPath,
        KycReviewMode.idFront,
      );
      if (reviewed == null) {
        if (mounted) {
          setState(() => _capturing = false);
          await _resumeImageStream();
        }
        return;
      }
      croppedPath = reviewed;

      // Run OCR on the final (reviewed) image.
      Map<String, String>? extractedData;
      try {
        if (mounted) {
          setState(() => _instruction = 'Scanning card detailsâ€¦');
        }
        extractedData = await _extractIdCardText(
          croppedPath,
          cardType: widget.cardType,
        );
        final filled = extractedData.values.where((v) => v.isNotEmpty).length;
        Log.d(_tag, 'OCR result: $extractedData ($filled fields filled)');
        if (filled > 0) {
          Fluttertoast.showToast(
            msg: 'Extracted $filled field(s) from ID card',
            toastLength: Toast.LENGTH_SHORT,
          );
        }
      } catch (e) {
        // OCR failure is non-fatal â€” we still return the image path.
        Log.w(_tag, 'OCR failed (non-fatal): $e');
        Fluttertoast.showToast(
          msg: 'Could not read card text. You can fill manually.',
        );
      }

      // Small delay so the user sees "Capturingâ€¦" feedback before we pop.
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        Navigator.pop(context, {
          'path': croppedPath,
          if (extractedData != null) 'ocr': extractedData,
        });
      }
    } catch (e, s) {
      Log.e(_tag, 'autoCaptureIdCard failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to capture. Try again.');
      if (mounted) {
        setState(() => _capturing = false);
        await _resumeImageStream();
      }
    }
  }

  /// Manual capture (used for ID card mode).
  /// After capturing, runs ML Kit text recognition on the image and returns
  /// both the file path and the extracted text so the caller can auto-fill
  /// form fields (name, DOB, ID number, address).
  Future<void> _manualCapture() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      await _controller?.stopImageStream();
      final xFile = await _controller!.takePicture();
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final savedPath = '${dir.path}/kyc_idcard_$ts.jpg';
      await File(xFile.path).copy(savedPath);

      // Show the full camera frame in review. The user crops/rotates manually
      // so the card is centered and straight before OCR runs.
      var croppedPath = savedPath;

      // Manual capture also goes through review so the user can fix
      // orientation/crop before we run OCR.
      final reviewed = await _openReviewScreen(
        croppedPath,
        KycReviewMode.idFront,
      );
      if (reviewed == null) {
        if (mounted) {
          setState(() => _capturing = false);
          await _resumeImageStream();
        }
        return;
      }
      croppedPath = reviewed;

      // Run OCR on the captured ID card image.
      Map<String, String>? extractedData;
      try {
        if (mounted) {
          setState(() => _instruction = 'Scanning card detailsâ€¦');
        }
        extractedData = await _extractIdCardText(
          croppedPath,
          cardType: widget.cardType,
        );
        final filled = extractedData.values.where((v) => v.isNotEmpty).length;
        Log.d(_tag, 'OCR result: $extractedData ($filled fields filled)');
        if (filled > 0) {
          Fluttertoast.showToast(
            msg: 'Extracted $filled field(s) from ID card',
            toastLength: Toast.LENGTH_SHORT,
          );
        }
      } catch (e) {
        // OCR failure is non-fatal â€” we still return the image path.
        Log.w(_tag, 'OCR failed (non-fatal): $e');
        Fluttertoast.showToast(
          msg: 'Could not read card text. You can fill manually.',
        );
      }

      if (mounted) {
        Navigator.pop(context, {
          'path': croppedPath,
          if (extractedData != null) 'ocr': extractedData,
        });
      }
    } catch (e, s) {
      Log.e(_tag, 'manualCapture failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to capture. Try again.');
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
        await _resumeImageStream();
      }
    }
  }

  /// Run ML Kit text recognition on an image file and parse the result to
  /// extract common ID card fields (full name, date of birth, ID/document
  /// number, and address). Returns a map with keys: fullName, dob, idNumber,
  /// address. Fields that can't be found are empty strings.
  ///
  /// [cardType] helps the parser pick the right ID number regex.
  Future<Map<String, String>> _extractIdCardText(
    String imagePath, {
    String? cardType,
  }) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await recognizer.processImage(inputImage);
      final fullText = recognizedText.text;
      Log.d(_tag, 'OCR raw text (cardType=$cardType):\n$fullText');

      // Parse the raw text into structured fields using the type-aware parser.
      return KycOcrParser.parse(fullText, cardType: cardType, logTag: _tag);
    } finally {
      await recognizer.close();
    }
  }

  // ---- Build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isSelfie = widget.mode == KycCaptureMode.selfie;
    final title = isSelfie ? 'Live Selfie' : 'ID Card Photo';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (_cameras.length > 1)
            IconButton(
              icon: const Icon(Icons.cameraswitch_outlined),
              tooltip: 'Switch camera',
              onPressed: _initializing ? null : _switchCamera,
            ),
          if (!isSelfie)
            IconButton(
              icon: Icon(
                _flashMode == FlashMode.auto ? Icons.flash_on : Icons.flash_off,
              ),
              tooltip: 'Flash',
              onPressed: _initializing ? null : _toggleFlash,
            ),
        ],
      ),
      body:
          _initializing
              ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Preloader(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Starting cameraâ€¦',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              )
              : _controller == null || !_controller!.value.isInitialized
              ? const Center(
                child: Text(
                  'Camera not available',
                  style: TextStyle(color: Colors.white),
                ),
              )
              : Stack(
                alignment: Alignment.topLeft,
                fit: StackFit.expand,
                children: [
                  // Camera preview â€” fill the entire screen (cover fit).
                  _cameraPreview(),
                  // Darkened mask around the guide area.
                  _maskOverlay(isSelfie),
                  // Guide overlay (oval for selfie, rectangle for ID).
                  _guideOverlay(isSelfie),
                  // Top instruction banner.
                  _instructionBanner(isSelfie),
                  // Bottom bar (capture button for ID card / status for selfie).
                  _bottomBar(isSelfie),
                  // Debug overlay (tap top-right corner to toggle).
                  if (isSelfie && _showDebug && !_showTutorial) _debugOverlay(),
                  // Tutorial overlay (shown on first open).
                  if (_showTutorial) _tutorialOverlay(isSelfie),
                  // Invisible tap target to toggle debug overlay.
                  if (isSelfie)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => _showDebug = !_showDebug),
                        child: Container(
                          width: 60,
                          height: 80,
                          color: Colors.transparent,
                        ),
                      ),
                    ),
                ],
              ),
    );
  }

  /// Camera preview â€” fits the WIDTH of the screen (not cover) to minimize
  /// zoom. `BoxFit.cover` crops too aggressively on portrait phones with
  /// landscape camera sensors, making faces appear 2x larger than they are.
  /// `fitWidth` shows the full horizontal field of view and only crops
  /// top/bottom slightly, which is fine for a centered oval guide.
  Widget _cameraPreview() {
    return SizedBox.expand(
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.fitWidth,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: _controller!.value.previewSize?.height ?? 1,
            height: _controller!.value.previewSize?.width ?? 1,
            child: CameraPreview(_controller!),
          ),
        ),
      ),
    );
  }

  /// Darkened mask with a cut-out for the guide area.
  Widget _maskOverlay(bool isSelfie) {
    final size = MediaQuery.of(context).size;
    final guideSize =
        isSelfie ? _selfieGuideSize(size) : _idCardGuideSize(size);

    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _MaskPainter(guideRect: guideSize, isOval: isSelfie),
      ),
    );
  }

  /// Returns the rect (in screen coordinates) for the selfie oval guide.
  Rect _selfieGuideSize(Size screenSize) {
    // Smaller oval (0.50 of screen width) â€” user doesn't need to hold the
    // phone at arm's length to fill the guide. Combined with a lower
    // sizeTolerance, face detection passes at a comfortable distance.
    final guideWidth = screenSize.width * 0.50;
    final guideHeight = guideWidth * 1.35;
    final left = (screenSize.width - guideWidth) / 2;
    final top =
        (screenSize.height - guideHeight) / 2 - screenSize.height * 0.05;
    return Rect.fromLTWH(left, top, guideWidth, guideHeight);
  }

  /// Returns the rect (in screen coordinates) for the ID card rectangle guide.
  Rect _idCardGuideSize(Size screenSize) {
    final guideWidth = screenSize.width * 0.82;
    final guideHeight = guideWidth * 0.63; // ID card aspect ratio ~1.586
    final left = (screenSize.width - guideWidth) / 2;
    final top = (screenSize.height - guideHeight) / 2;
    return Rect.fromLTWH(left, top, guideWidth, guideHeight);
  }

  /// The guide overlay â€” oval for selfie, rectangle for ID card.
  /// Colour changes: red = misaligned, yellow = aligning, green = perfect.
  Widget _guideOverlay(bool isSelfie) {
    final size = MediaQuery.of(context).size;
    final guideRect =
        isSelfie ? _selfieGuideSize(size) : _idCardGuideSize(size);

    // Determine the guide colour based on liveness step.
    Color guideColor;
    if (isSelfie) {
      if (_capturing || _livenessStep == _LivenessStep.capturing) {
        guideColor = AppTheme.green;
      } else if (_completedSteps.length >= 3) {
        // Most steps done â€” almost there.
        guideColor = AppTheme.green;
      } else if (_aligned) {
        guideColor = AppTheme.yellow;
      } else if (_faceDetected) {
        guideColor = Colors.orange;
      } else {
        guideColor = Colors.red;
      }
    } else {
      guideColor = Colors.white.withValues(alpha: 0.85);
    }

    return IgnorePointer(
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          if (isSelfie)
            Positioned.fromRect(
              rect: guideRect,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: guideColor, width: 3),
                  borderRadius: BorderRadius.circular(guideRect.width / 2),
                ),
              ),
            )
          else
            Positioned.fromRect(
              rect: guideRect,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: guideColor, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          // Corner accents for extra clarity.
          if (isSelfie)
            ..._cornerAccents(guideRect, guideColor, isOval: true)
          else
            ..._cornerAccents(guideRect, guideColor, isOval: false),
        ],
      ),
    );
  }

  /// Corner accent marks for the guide frame.
  List<Widget> _cornerAccents(Rect rect, Color color, {required bool isOval}) {
    const cornerLen = 24.0;
    const cornerWidth = 4.0;
    if (isOval) return []; // Oval doesn't need corner accents.

    return [
      // Top-left
      Positioned(
        left: rect.left - cornerWidth / 2,
        top: rect.top - cornerWidth / 2,
        child: Row(
          children: [
            Container(width: cornerWidth, height: cornerLen, color: color),
            Container(width: cornerLen, height: cornerWidth, color: color),
          ],
        ),
      ),
      // Top-right
      Positioned(
        left: rect.right - cornerLen + cornerWidth / 2,
        top: rect.top - cornerWidth / 2,
        child: Row(
          children: [
            Container(width: cornerLen, height: cornerWidth, color: color),
            Container(width: cornerWidth, height: cornerLen, color: color),
          ],
        ),
      ),
      // Bottom-left
      Positioned(
        left: rect.left - cornerWidth / 2,
        top: rect.bottom - cornerLen + cornerWidth / 2,
        child: Row(
          children: [
            Container(width: cornerWidth, height: cornerLen, color: color),
            Container(width: cornerLen, height: cornerWidth, color: color),
          ],
        ),
      ),
      // Bottom-right
      Positioned(
        left: rect.right - cornerLen + cornerWidth / 2,
        top: rect.bottom - cornerLen + cornerWidth / 2,
        child: Row(
          children: [
            Container(width: cornerLen, height: cornerWidth, color: color),
            Container(width: cornerWidth, height: cornerLen, color: color),
          ],
        ),
      ),
    ];
  }

  /// Top instruction banner with real-time feedback.
  Widget _instructionBanner(bool isSelfie) {
    if (!isSelfie) {
      // Dynamic instruction â€” updated by [_handleIdCardDetection] as the
      // text recognizer detects / loses the card. Falls back to the static
      // [widget.instruction] until the first detection callback fires.
      final instruction =
          _instruction.isNotEmpty
              ? _instruction
              : (widget.instruction ??
                  'Place your ID card inside the frame. Make sure all text is clear and readable.');
      final Color bannerColor;
      final IconData bannerIcon;
      if (_capturing) {
        bannerColor = AppTheme.green;
        bannerIcon = Icons.check_circle;
      } else if (_idCardDetected) {
        bannerColor = AppTheme.green;
        bannerIcon = Icons.document_scanner;
      } else {
        bannerColor = Colors.orange;
        bannerIcon = Icons.info_outline;
      }
      return Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: bannerColor.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: bannerColor.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(bannerIcon, color: bannerColor, size: 20),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      _capturing ? 'Capturingâ€¦' : instruction,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Selfie mode â€” show dynamic instruction + progress steps.
    final Color bannerColor;
    final IconData bannerIcon;
    if (_capturing || _livenessStep == _LivenessStep.capturing) {
      bannerColor = AppTheme.green;
      bannerIcon = Icons.check_circle;
    } else if (_completedSteps.length >= 3) {
      bannerColor = AppTheme.green;
      bannerIcon = Icons.verified;
    } else if (_completedSteps.isNotEmpty) {
      bannerColor = AppTheme.yellow;
      bannerIcon = Icons.task_alt;
    } else if (_faceDetected) {
      bannerColor = Colors.orange;
      bannerIcon = Icons.face;
    } else {
      bannerColor = Colors.red;
      bannerIcon = Icons.info_outline;
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: bannerColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: bannerColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(bannerIcon, color: bannerColor, size: 20),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        _capturing ? 'Perfect! Capturingâ€¦' : _instruction,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Progress steps
              _progressSteps(),
            ],
          ),
        ),
      ),
    );
  }

  /// Progress step indicators: Center â†’ Turn Right â†’ Turn Left â†’ Blink â†’ Capture.
  /// Each step shows a green checkmark when completed, and the current step
  /// is highlighted with its icon.
  ///
  /// Hidden when the liveness challenge is disabled by the admin panel.
  Widget _progressSteps() {
    if (!widget.requireLiveness) return const SizedBox.shrink();

    final centerDone = _completedSteps.contains(_LivenessStep.centering);
    final turnRightDone = _completedSteps.contains(_LivenessStep.turnRight);
    final turnLeftDone = _completedSteps.contains(_LivenessStep.turnLeft);
    final blinkDone = _completedSteps.contains(_LivenessStep.blink);

    final steps = <_StepIndicator>[
      _StepIndicator(
        'Center',
        Icons.face,
        centerDone,
        _livenessStep == _LivenessStep.centering,
      ),
      _StepIndicator(
        'Right',
        Icons.arrow_forward,
        turnRightDone,
        _livenessStep == _LivenessStep.turnRight,
      ),
      _StepIndicator(
        'Left',
        Icons.arrow_back,
        turnLeftDone,
        _livenessStep == _LivenessStep.turnLeft,
      ),
      _StepIndicator(
        'Blink',
        Icons.visibility_off,
        blinkDone,
        _livenessStep == _LivenessStep.blink ||
            _livenessStep == _LivenessStep.blinkOpen,
      ),
      _StepIndicator(
        'Done',
        Icons.camera_alt,
        _livenessStep == _LivenessStep.capturing || _capturing,
        _livenessStep == _LivenessStep.capturing,
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _stepDot(steps[i]),
          if (i < steps.length - 1)
            Container(
              width: 16,
              height: 2,
              color:
                  steps[i].done
                      ? AppTheme.green.withValues(alpha: 0.5)
                      : Colors.white24,
            ),
        ],
      ],
    );
  }

  Widget _stepDot(_StepIndicator step) {
    final color =
        step.done
            ? AppTheme.green
            : step.active
            ? AppTheme.yellow
            : Colors.white38;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                step.done
                    ? AppTheme.green
                    : step.active
                    ? AppTheme.yellow.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: color, width: 1.5),
          ),
          child:
              step.done
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Icon(step.icon, color: color, size: 14),
        ),
        const SizedBox(height: 4),
        Text(
          step.label,
          style: TextStyle(
            fontSize: 9,
            color: color,
            fontWeight:
                step.done || step.active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Bottom bar â€” manual shutter for ID card, status indicator for selfie.
  Widget _bottomBar(bool isSelfie) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black87],
          ),
        ),
        child: SafeArea(
          top: false,
          child: isSelfie ? _selfieBottomBar() : _idCardBottomBar(),
        ),
      ),
    );
  }

  /// Selfie bottom bar â€” shows auto-capture status (no manual button).
  Widget _selfieBottomBar() {
    if (_capturing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Preloader(strokeWidth: 3, color: AppTheme.green),
            ),
            SizedBox(height: 8),
            Text(
              'Capturing photoâ€¦',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing ring to indicate auto-capture is active.
          _pulsingRing(),
          const SizedBox(height: 10),
          Text(
            _livenessStep == _LivenessStep.capturing
                ? 'Hold still â€” capturing automatically'
                : _completedSteps.isNotEmpty
                ? 'Step ${_completedSteps.length + 1} of 5 â€” follow the instructions'
                : 'Auto-capture is active â€” just follow the instructions',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Pulsing ring animation to indicate the camera is actively detecting.
  Widget _pulsingRing() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      builder: (context, value, child) {
        final color =
            _livenessStep == _LivenessStep.capturing
                ? AppTheme.green
                : _completedSteps.isNotEmpty
                ? AppTheme.yellow
                : Colors.white54;
        final icon =
            _livenessStep == _LivenessStep.turnRight
                ? Icons.arrow_forward
                : _livenessStep == _LivenessStep.turnLeft
                ? Icons.arrow_back
                : _livenessStep == _LivenessStep.blink ||
                    _livenessStep == _LivenessStep.blinkOpen
                ? Icons.visibility_off
                : _livenessStep == _LivenessStep.capturing
                ? Icons.camera_alt
                : Icons.center_focus_strong;
        return Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: 0.3 + 0.4 * value),
              width: 3,
            ),
          ),
          child: Icon(icon, color: color, size: 28),
        );
      },
    );
  }

  /// ID card bottom bar â€” auto-capture status indicator (primary) with a
  /// manual shutter button kept as a fallback for poor-lighting edge cases.
  Widget _idCardBottomBar() {
    if (_capturing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Preloader(strokeWidth: 3, color: AppTheme.green),
            ),
            SizedBox(height: 8),
            Text(
              'Scanning cardâ€¦',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Auto-capture status ring â€” turns green when a card is detected.
          _idCardStatusRing(),
          const SizedBox(height: 10),
          Text(
            _idCardDetected
                ? 'Card detected â€” hold still'
                : 'Auto-capture is active â€” place your ID card in the frame',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 14),
          // Manual fallback shutter (small) â€” used only if auto-detection
          // can't trigger (e.g. very low light / non-latin script).
          GestureDetector(
            onTap: _manualCapture,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54, width: 3),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'or tap to capture manually',
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  /// Status ring for ID card auto-capture. Pulses while searching, turns
  /// green and fills as the card is held stably in the frame.
  Widget _idCardStatusRing() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      builder: (context, value, child) {
        final color = _idCardDetected ? AppTheme.green : Colors.white54;
        final icon = _idCardDetected ? Icons.document_scanner : Icons.search;
        return Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: 0.3 + 0.4 * value),
              width: 3,
            ),
          ),
          child: Icon(icon, color: color, size: 28),
        );
      },
    );
  }

  // ---- Debug overlay -----------------------------------------------------

  /// Shows real-time face detection values so we can debug why a step
  /// isn't passing. Positioned at the left side, semi-transparent.
  /// Tap the top-right corner to toggle.
  Widget _debugOverlay() {
    final stepName = _livenessStep.name;
    final completed = _completedSteps.length;
    return Positioned(
      left: 8,
      top: 100,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Step: $stepName ($completed/5 done)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'dx: ${_dbgDx.toStringAsFixed(3)}  ${_dbgCentered ? "âœ“" : "âœ—"}',
                style: TextStyle(
                  color: _dbgCentered ? Colors.green : Colors.red,
                  fontSize: 9,
                ),
              ),
              Text(
                'dy: ${_dbgDy.toStringAsFixed(3)}',
                style: TextStyle(
                  color: _dbgCentered ? Colors.green : Colors.red,
                  fontSize: 9,
                ),
              ),
              Text(
                'width: ${_dbgWidth.toStringAsFixed(3)}  ${_dbgLarge ? "âœ“" : "âœ—"}',
                style: TextStyle(
                  color: _dbgLarge ? Colors.green : Colors.red,
                  fontSize: 9,
                ),
              ),
              Text(
                'eulerY: ${_dbgEulerY.toStringAsFixed(1)}Â°  ${_dbgStraight ? "âœ“" : "âœ—"}',
                style: TextStyle(
                  color: _dbgStraight ? Colors.green : Colors.red,
                  fontSize: 9,
                ),
              ),
              Text(
                'eulerZ: ${_dbgEulerZ.toStringAsFixed(1)}Â°',
                style: TextStyle(
                  color: _dbgStraight ? Colors.green : Colors.red,
                  fontSize: 9,
                ),
              ),
              Text(
                'L eye: ${_dbgLeftEye.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70, fontSize: 9),
              ),
              Text(
                'R eye: ${_dbgRightEye.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70, fontSize: 9),
              ),
              Text(
                'hold: $_stepHoldFrames/$_stepHoldRequired',
                style: const TextStyle(color: Colors.white70, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Tutorial overlay --------------------------------------------------

  /// 3-second animated tutorial shown before the camera becomes interactive.
  Widget _tutorialOverlay(bool isSelfie) {
    return _KycTutorialOverlay(
      isSelfie: isSelfie,
      onDone: () {
        if (mounted) setState(() => _showTutorial = false);
      },
    );
  }
}

// ---- Liveness challenge state machine -----------------------------------

/// Sequential liveness steps â€” like Jumio/Onfido challenge-response flow.
/// Each step must be completed in order before advancing to the next.
enum _LivenessStep {
  /// Step 1: Position face in oval (centered + correct size + straight).
  centering,

  /// Step 2: Turn head to the right.
  turnRight,

  /// Step 3: Turn head to the left.
  turnLeft,

  /// Step 4: Close eyes (blink).
  blink,

  /// Step 4b: Open eyes (completes the blink).
  blinkOpen,

  /// Step 5: Hold still â€” auto-capture.
  capturing,
}

/// Data for a single progress step indicator.
class _StepIndicator {
  const _StepIndicator(this.label, this.icon, this.done, this.active);
  final String label;
  final IconData icon;
  final bool done;
  final bool active;
}

// ---- Mask painter -------------------------------------------------------

/// Paints a darkened mask over the entire screen with a transparent cut-out
/// for the guide area (oval for selfie, rounded rectangle for ID card).
class _MaskPainter extends CustomPainter {
  _MaskPainter({required this.guideRect, required this.isOval});

  final Rect guideRect;
  final bool isOval;

  @override
  void paint(Canvas canvas, Size size) {
    // IMPORTANT: BlendMode.clear only punches a "transparent hole" correctly
    // when applied inside its own layer (saveLayer). Without saveLayer, the
    // clear operation punches through the *entire* composited scene below it
    // (including the camera preview), which is why the guide area was
    // rendering solid black instead of showing the camera feed.
    canvas.saveLayer(Offset.zero & size, Paint());

    final maskPaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.55)
          ..style = PaintingStyle.fill;

    // Fill the whole screen with the dark mask (within this layer only).
    canvas.drawRect(Offset.zero & size, maskPaint);

    // Clear the guide area â€” this punches a hole in the mask layer only,
    // revealing the camera preview underneath once the layer is composited.
    final clearPaint =
        Paint()
          ..blendMode = BlendMode.clear
          ..style = PaintingStyle.fill;

    if (isOval) {
      final rrect = RRect.fromRectAndRadius(
        guideRect,
        Radius.circular(guideRect.width / 2),
      );
      canvas.drawRRect(rrect, clearPaint);
    } else {
      final rrect = RRect.fromRectAndRadius(
        guideRect,
        const Radius.circular(16),
      );
      canvas.drawRRect(rrect, clearPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MaskPainter oldDelegate) =>
      guideRect != oldDelegate.guideRect || isOval != oldDelegate.isOval;
}

// ---- Tutorial overlay widget --------------------------------------------

/// Animated 3-second tutorial overlay shown when the camera screen opens.
///
/// For selfie mode: shows face positioning + blink instructions with
/// animated illustrations.
/// For ID card mode: shows card placement instructions.
class _KycTutorialOverlay extends StatefulWidget {
  const _KycTutorialOverlay({required this.isSelfie, required this.onDone});

  final bool isSelfie;
  final VoidCallback onDone;

  @override
  State<_KycTutorialOverlay> createState() => _KycTutorialOverlayState();
}

class _KycTutorialOverlayState extends State<_KycTutorialOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;
  late final Animation<double> _fade;
  int _currentStep = 0;

  final _selfieSteps = [
    (
      'Center your face',
      'Position your face inside the oval guide',
      Icons.face,
    ),
    (
      'Turn right â†’',
      'Turn your head to the right when asked',
      Icons.arrow_forward,
    ),
    (
      'Turn left â†',
      'Turn your head to the left when asked',
      Icons.arrow_back,
    ),
    (
      'Blink your eyes',
      'A blink confirms you are a real person',
      Icons.visibility_off,
    ),
    (
      'Auto-capture',
      'Hold still â€” photo is taken automatically',
      Icons.camera_alt,
    ),
  ];

  final _idCardSteps = [
    ('Place your ID card', 'Put your ID card inside the frame', Icons.badge),
    (
      'Good lighting',
      'Make sure there\'s no glare and all text is readable',
      Icons.wb_sunny,
    ),
    (
      'Auto-capture',
      'Hold still â€” photo is taken automatically when the card is readable',
      Icons.camera_alt,
    ),
  ];

  List<(String, String, IconData)> get _steps =>
      widget.isSelfie ? _selfieSteps : _idCardSteps;

  @override
  void initState() {
    super.initState();
    final stepCount = _steps.length;
    _controller = AnimationController(
      // Shortened from 750ms/step to 400ms/step â€” the tutorial should be a
      // quick hint, not a blocking wait. Total ~1.6s for selfie (4 steps).
      duration: Duration(milliseconds: 400 * stepCount),
      vsync: this,
    );
    _progress = Tween(begin: 0.0, end: 1.0).animate(_controller)
      ..addListener(() {
        final step = (_progress.value * stepCount).floor();
        if (step != _currentStep && step < stepCount) {
          setState(() => _currentStep = step);
        }
      });
    _fade = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.85, 1.0)),
    );
    _controller.forward().then((_) {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _skip() {
    _controller.stop();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep.clamp(0, _steps.length - 1)];
    final stepCount = _steps.length;

    return FadeTransition(
      opacity: _fade,
      child: Container(
        color: Colors.black.withValues(alpha: 0.88),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Spacer(),
                // Animated icon
                ScaleTransition(
                  scale: Tween(begin: 0.8, end: 1.1).animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: Interval(
                        _currentStep / stepCount,
                        (_currentStep + 1) / stepCount,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                  ),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(step.$3, color: Colors.white, size: 56),
                  ),
                ),
                const SizedBox(height: 32),
                // Step title
                Text(
                  step.$1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                // Step description
                Text(
                  step.$2,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                // Progress dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(stepCount, (i) {
                    final active = i == _currentStep;
                    final done = i < _currentStep;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color:
                            done
                                ? AppTheme.green
                                : (active ? AppTheme.primary : Colors.white24),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                // Skip button
                TextButton(
                  onPressed: _skip,
                  child: const Text(
                    'Skip tutorial',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
