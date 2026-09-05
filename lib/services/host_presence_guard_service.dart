/// Host Presence Guard — local, on-device AI compliance service for live
/// stream hosts (Bigo Live style).
///
/// This service runs entirely on the host's device using
/// `google_mlkit_face_detection` against the **real camera frames** captured
/// directly from Agora's native `VideoFrameObserver` (`onCaptureVideoFrame`).
/// It has **zero cloud cost** — no frame is ever uploaded.
///
/// Two frame sources are supported:
///  * **CameraController** (pre-live / GoLive screen): uses `takePicture`
///    on a timer. Simple and reliable but cannot be used during a live
///    stream because Agora owns the camera.
///  * **Agora VideoFrameObserver** (during live): the live room registers
///    a `VideoFrameObserver` on the Agora engine and feeds captured frames
///    to [submitAgoraFrame]. The service throttles internally to one
///    analysis every [analysisInterval].
///
/// Checks performed on each frame:
///  1. Camera covered / black screen / off.
///  2. No face detected (host away from frame).
///
/// Dynamic exemptions (Bigo Live style) — presence checking is **paused**
/// (the violation timer is frozen, not reset) while any of these are true:
///  * Host is screen sharing / Game LIVE.
///  * Host is playing an in-app mini-game (Draw & Guess, Co-Watch, etc.).
///  * Host has AR masks / face filters / virtual avatars active
///    (`hasMask` / beauty mode active).
///  * Host is active in a PK battle or PK punishment round.
///  * A blocking UI popup / bottom sheet is open.
///
/// Enforcement workflow (Bigo Live style):
///  * 60s of continuous violation → on-screen "Please return to camera"
///    warning overlay (no backend event yet).
///  * 180s (3 minutes) of continuous violation → declare a valid presence
///    violation: emit the backend `hostComplianceViolation` event **once**
///    with the escalating ban tier, persist the ban locally, terminate the
///    stream.
///
/// Escalating ban & penalty rules (applied at the 180s threshold):
///  * 1st violation  → block Host ID from streaming for 5 minutes.
///  * 2nd violation  → block Host ID for 1 hour + deduct daily task
///    rewards / earnings for the day.
///  * 3rd violation  → block Host ID for 4 hours.
/// The daily violation counter resets on calendar-day rollover. The active
/// ban window is persisted to SharedPreferences so it survives app restarts.
///
/// The service is gated by the `ai_host_presence_guard` AI feature flag.
/// When the admin disables the feature, [start] is a no-op and no camera
/// frames are ever analysed, keeping the host's battery / CPU untouched.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_feature_model.dart';
import '../models/host_compliance_models.dart';
import '../providers/ai_feature_manager.dart';
import '../services/api_service.dart';
import '../utils/log.dart';

/// Severity of the current violation state.
enum HostPresenceSeverity {
  clear,

  /// 60s+ of continuous violation — visual warning only, no backend event.
  warning,

  /// 180s+ of continuous violation — declared violation, ban + terminate.
  violation,
}

/// Reason for the current violation.
enum HostPresenceReason {
  none,
  cameraCovered,
  cameraOff,
  noFace,
  facePartial,
  mask,
}

/// Snapshot emitted to listeners whenever the violation state changes.
class HostPresenceStatus {
  const HostPresenceStatus({
    required this.severity,
    required this.reason,
    required this.violationSeconds,
    this.ban,
  });

  final HostPresenceSeverity severity;
  final HostPresenceReason reason;
  final int violationSeconds;

  /// Populated when a ban has just been applied (severity == violation).
  final HostPresenceBanInfo? ban;

  static const HostPresenceStatus clear = HostPresenceStatus(
    severity: HostPresenceSeverity.clear,
    reason: HostPresenceReason.none,
    violationSeconds: 0,
  );

  bool get isViolating => severity != HostPresenceSeverity.clear;
}

typedef HostPresenceStatusCallback = void Function(HostPresenceStatus status);
typedef HostPresenceTerminateCallback = Future<bool> Function();

/// Returns `true` when the host is in an exempt state (screen share,
/// mini-game, AR mask / beauty, PK battle, UI popup, ...) and presence
/// checking should be paused.
typedef HostPresenceExemptionChecker = bool Function();

/// Local on-device host presence / compliance guard.
class HostPresenceGuardService {
  HostPresenceGuardService();

  static const String _tag = 'HostPresenceGuard';

  // ---- Tunables ----------------------------------------------------------
  // Tick every second; native frame intake is separately limited to 1 FPS.
  static const Duration analysisInterval = Duration(seconds: 1);
  // Bigo Live style: visual warning after 60s, declare violation at 180s
  // (3 continuous minutes). No backend event is sent before 180s.
  static const int _warningThresholdSec = 60;
  static const int _violationThresholdSec = 180;
  static const double _blackFrameBrightness = 12.0;

  // SharedPreferences keys for persisted ban state.
  static const String _kBanInfo = 'host_presence_ban_info';
  static const String _kViolationCount = 'host_presence_violation_count';
  static const String _kViolationDate = 'host_presence_violation_date';
  static const String _kProgressPrefix = 'host_presence_progress';

  // ---- State -------------------------------------------------------------
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: false,
      enableTracking: false,
      enableContours: false,
      enableLandmarks: false,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.05,
    ),
  );

  Timer? _timer;
  bool _running = false;
  bool _busy = false;

  CameraController? _cameraController;

  /// Last Agora frame submitted via [submitAgoraFrame]. Analysed on the
  /// periodic timer so we don't block the real-time video observer thread.
  InputImage? _pendingAgoraFrame;
  double _pendingAgoraBrightness = 255;

  // ---- Frame receipt diagnostics -----------------------------------------
  /// Timestamp of the last frame received via [submitAgoraFrame].
  DateTime? _lastFrameAt;

  /// Total number of frames received since the guard started.
  int _frameReceivedCount = 0;

  /// Last frame dimensions/format for diagnostics.
  int _lastFrameWidth = 0;
  int _lastFrameHeight = 0;

  /// Timestamp of the last frame accepted (after 1-fps downsampling).
  DateTime? _lastFrameAcceptedAt;

  /// Minimum interval between accepted frames (1 fps downsampling so we
  /// don't do heavy ML face detection on every camera frame).
  static const Duration _frameDownsampleInterval = Duration(seconds: 1);

  /// If no frame is received within this window while the camera is on,
  /// we treat it as a camera-covered / blocked violation (fallback).
  static const Duration _frameStaleThreshold = Duration(seconds: 5);
  int _pendingFrameSequence = 0;
  int _analysedFrameSequence = 0;
  DateTime? _monitoringStartedAt;
  DateTime? _lastTickAt;
  DateTime? _lastAnalysisAt;
  HostPresenceReason _lastAnalysisReason = HostPresenceReason.none;

  /// Accumulated continuous-violation seconds. Unlike an absolute start
  /// timestamp, an accumulated counter lets us **pause** (freeze) the
  /// timer while the host is in an exempt state and resume from the same
  /// point once the exemption ends.
  int _violationAccumulatedMs = 0;
  int get _violationAccumulatedSec => _violationAccumulatedMs ~/ 1000;
  int _lastPersistedSecond = -1;
  bool _progressWriteBusy = false;
  HostPresenceSeverity _currentSeverity = HostPresenceSeverity.clear;

  /// True once the 180s violation has been declared (ban applied + backend
  /// emit + terminate). Prevents re-declaring on every subsequent tick.
  bool _violationDeclared = false;

  /// Room / host identifiers needed to emit compliance socket events.
  String? _userId;
  String? _liveStreamingId;

  /// Optional callback that returns whether the local camera is currently on.
  bool Function()? _isCameraOn;

  /// Exemption checker — when it returns `true`, presence checking is
  /// paused (timer frozen, no analysis, no backend emit).
  HostPresenceExemptionChecker? _isExempted;

  /// Persisted ban state (loaded lazily on first use).
  HostPresenceBanInfo? _activeBan;
  String? _banStateLoadedForUser;

  final _statusController = StreamController<HostPresenceStatus>.broadcast(
    sync: true,
  );
  Stream<HostPresenceStatus> get statusStream => _statusController.stream;

  final _banController = StreamController<HostPresenceBanInfo?>.broadcast(
    sync: true,
  );

  /// Emits the active ban info whenever it changes (new ban applied, ban
  /// expired, daily rollover reset). Emits `null` when no ban is active.
  Stream<HostPresenceBanInfo?> get banStream => _banController.stream;

  HostPresenceTerminateCallback? onTerminateStream;
  VoidCallback? onBlockGifts;

  // ---- Lifecycle ---------------------------------------------------------

  /// Start monitoring with a [CameraController] (GoLive screen).
  Future<void> startWithCamera({
    required CameraController cameraController,
    required AIFeatureManager ai,
    required String userId,
    required String liveStreamingId,
    HostPresenceExemptionChecker? isExempted,
    HostPresenceTerminateCallback? onTerminate,
    VoidCallback? onGiftsBlocked,
  }) async {
    if (!ai.isFeatureEnabled(AIFeatureKeys.hostComplianceGuard)) {
      Log.w(_tag, 'host presence guard disabled by AI config — not starting');
      return;
    }
    if (_running) return;
    _userId = userId;
    _liveStreamingId = liveStreamingId;
    _cameraController = cameraController;
    _isExempted = isExempted;
    onTerminateStream = onTerminate;
    onBlockGifts = onGiftsBlocked;
    _running = true;
    _initializeMonitoringState();
    await _restoreViolationProgress();
    _timer?.cancel();
    _timer = Timer.periodic(analysisInterval, (_) => _tickCamera());
    unawaited(_tickCamera());
    Log.w(
      _tag,
      'host presence guard started (camera mode, ${analysisInterval.inSeconds}s)',
    );
  }

  /// Start monitoring with Agora video frames (LiveRoom screen).
  ///
  /// The caller must register a `VideoFrameObserver` on the Agora engine
  /// and forward captured frames to [submitAgoraFrame]. The service
  /// throttles analysis to [analysisInterval].
  Future<void> startWithAgora({
    required AIFeatureManager ai,
    required String userId,
    required String liveStreamingId,
    bool Function()? isCameraOn,
    HostPresenceExemptionChecker? isExempted,
    HostPresenceTerminateCallback? onTerminate,
    VoidCallback? onGiftsBlocked,
  }) async {
    if (!ai.isFeatureEnabled(AIFeatureKeys.hostComplianceGuard)) {
      Log.w(_tag, 'host presence guard disabled by AI config — not starting');
      return;
    }
    if (_running) return;
    _userId = userId;
    _liveStreamingId = liveStreamingId;
    _isCameraOn = isCameraOn;
    _isExempted = isExempted;
    onTerminateStream = onTerminate;
    onBlockGifts = onGiftsBlocked;
    _running = true;
    _initializeMonitoringState();
    await _restoreViolationProgress();
    _timer?.cancel();
    _timer = Timer.periodic(analysisInterval, (_) => _tickAgora());
    unawaited(_tickAgora());
    Log.w(
      _tag,
      'host presence guard started (agora mode, ${analysisInterval.inSeconds}s)',
    );
  }

  /// Update the exemption checker at runtime (e.g. when the host starts /
  /// stops a PK battle or mini-game).
  void setExemptionChecker(HostPresenceExemptionChecker? checker) {
    _isExempted = checker;
  }

  /// Submit a frame from the Agora `VideoFrameObserver`. The frame is
  /// stored and analysed on the next timer tick. Call this from
  /// `onCaptureVideoFrame` — it returns immediately so it never blocks
  /// the real-time video pipeline.
  ///
  /// Frames are downsampled to at most 1 per second to avoid heavy ML
  /// face detection on every camera frame.
  bool shouldProcessAgoraFrame({required int width, required int height}) {
    if (!_running) return false;
    final now = DateTime.now();
    _frameReceivedCount++;
    _lastFrameAt = now;
    _lastFrameWidth = width;
    _lastFrameHeight = height;
    final lastAccepted = _lastFrameAcceptedAt;
    if (lastAccepted != null &&
        now.difference(lastAccepted) < _frameDownsampleInterval) {
      return false;
    }
    _lastFrameAcceptedAt = now;
    return true;
  }

  void submitAgoraFrame(InputImage image, {double brightness = 255}) {
    if (!_running) return;
    _pendingAgoraFrame = image;
    _pendingAgoraBrightness = brightness;
    _pendingFrameSequence++;
  }

  void reportAgoraFrameFailure() {
    if (!_running) return;
    _lastAnalysisAt = DateTime.now();
    _lastAnalysisReason = HostPresenceReason.cameraCovered;
  }

  /// Process a `hostComplianceStrikeUpdate` received from the backend.
  /// Shows a warning and, if the backend ends/bans, escalates to violation.
  void onStrikeUpdateReceived(Map<String, dynamic> map) {
    try {
      final update = HostComplianceStrikeUpdate.fromJson(map);
      if (update.banned || update.liveEnded) {
        _statusController.add(
          HostPresenceStatus(
            severity: HostPresenceSeverity.violation,
            reason: _reasonFromBackendCodes(update.reasonCodes),
            violationSeconds: _violationThresholdSec,
          ),
        );
        _onSeverityChanged(HostPresenceSeverity.violation);
      } else if (update.consecutiveStrike > 0) {
        _currentSeverity = HostPresenceSeverity.warning;
        _statusController.add(
          HostPresenceStatus(
            severity: HostPresenceSeverity.warning,
            reason: _reasonFromBackendCodes(update.reasonCodes),
            violationSeconds:
                update.consecutiveStrike * analysisInterval.inSeconds,
          ),
        );
      }
    } catch (e) {
      Log.e(_tag, 'onStrikeUpdateReceived parse error', e);
    }
  }

  /// Process a `hostComplianceBan` event from the backend.
  void onBanReceived(Map<String, dynamic> map) {
    try {
      final ban = HostComplianceBan.fromJson(map);
      _statusController.add(
        HostPresenceStatus(
          severity: HostPresenceSeverity.violation,
          reason: _reasonFromBackendCodes(ban.reasonCodes),
          violationSeconds: _violationThresholdSec,
        ),
      );
      _onSeverityChanged(HostPresenceSeverity.violation);
    } catch (e) {
      Log.e(_tag, 'onBanReceived parse error', e);
    }
  }

  HostPresenceReason _reasonFromBackendCodes(List<String> codes) {
    if (codes.contains('no_face')) return HostPresenceReason.noFace;
    if (codes.contains('mask')) return HostPresenceReason.mask;
    if (codes.contains('camera_off')) return HostPresenceReason.cameraOff;
    if (codes.contains('black_screen')) return HostPresenceReason.cameraCovered;
    if (codes.contains('off_frame')) {
      return HostPresenceReason.facePartial;
    }
    return HostPresenceReason.facePartial;
  }

  /// Stop monitoring and release resources.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _running = false;
    _busy = false;
    await _clearViolationProgress();
    _cameraController = null;
    _pendingAgoraFrame = null;
    _lastFrameAt = null;
    _lastFrameAcceptedAt = null;
    _lastAnalysisAt = null;
    _monitoringStartedAt = null;
    _lastTickAt = null;
    _lastAnalysisReason = HostPresenceReason.none;
    _pendingFrameSequence = 0;
    _analysedFrameSequence = 0;
    _frameReceivedCount = 0;
    _lastFrameWidth = 0;
    _lastFrameHeight = 0;
    _userId = null;
    _liveStreamingId = null;
    _isCameraOn = null;
    _isExempted = null;
    _banStateLoadedForUser = null;
    _activeBan = null;
    _resetViolation(clearPersisted: false);
    try {
      await _faceDetector.close();
    } catch (_) {}
    Log.d(_tag, 'host presence guard stopped');
  }

  // ---- Tick handlers -----------------------------------------------------

  Future<void> _tickCamera() async {
    if (!_running || _busy) return;
    final elapsed = _takeTickElapsed(DateTime.now());
    if (_isExempted?.call() == true) return;
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    _busy = true;
    try {
      final image = await controller.takePicture();
      final bytes = await image.readAsBytes();
      final inputImage = InputImage.fromFilePath(image.path);
      final brightness = _estimateBrightnessFromBytes(bytes);
      final reason = await _analyseInputImage(inputImage, brightness);
      _updateViolation(reason, elapsed);
      try {
        final f = File(image.path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    } catch (e, s) {
      Log.e(_tag, 'camera tick failed', e, s);
      _updateViolation(HostPresenceReason.cameraCovered, elapsed);
    } finally {
      _busy = false;
    }
  }

  Future<void> _tickAgora() async {
    if (!_running || _busy) return;
    final now = DateTime.now();
    final elapsed = _takeTickElapsed(now);
    final exempt = _isExempted?.call() == true;
    final cameraOn = _isCameraOn?.call() ?? true;
    final lastFrameAge =
        _lastFrameAt != null ? now.difference(_lastFrameAt!).inSeconds : -1;
    Log.d(
      _tag,
      'tick: cameraOn=$cameraOn exempt=$exempt '
      'framesReceived=$_frameReceivedCount lastFrameAge=${lastFrameAge}s '
      'lastFrameSize=${_lastFrameWidth}x$_lastFrameHeight '
      'violationSecs=$_violationAccumulatedSec/$_violationThresholdSec',
    );

    if (exempt) {
      Log.d(
        _tag,
        'presence check paused (host exempt) — '
        'violation seconds frozen at $_violationAccumulatedSec/$_violationThresholdSec',
      );
      return;
    }

    if (!cameraOn) {
      _updateViolation(HostPresenceReason.cameraOff, elapsed);
      return;
    }

    var reason = _lastAnalysisReason;
    var stateElapsed = elapsed;
    final lastFrame = _lastFrameAt;
    final frameIsStale =
        lastFrame == null || now.difference(lastFrame) >= _frameStaleThreshold;

    if (frameIsStale) {
      // If we have NEVER received a frame yet, this is a startup race
      // condition — the Agora frame observer hasn't delivered frames yet.
      // Do NOT accumulate violation seconds in this state; just log and
      // return. This prevents false terminations during PK relay setup or
      // normal stream initialization.
      if (_frameReceivedCount == 0) {
        Log.d(
          _tag,
          'Agora frames not yet received (startup) — skipping violation tick. '
          'framesReceived=0, lastFrameAge=${lastFrameAge}s',
        );
        return;
      }
      if (_lastAnalysisReason == HostPresenceReason.none) {
        stateElapsed =
            lastFrame == null
                ? now.difference(_monitoringStartedAt ?? now)
                : now.difference(lastFrame);
      }
      reason = HostPresenceReason.cameraCovered;
      _lastAnalysisReason = reason;
      _lastAnalysisAt = now;
      Log.w(
        _tag,
        'Agora frame fallback active: framesReceived=$_frameReceivedCount, '
        'lastFrameAge=${lastFrameAge}s',
      );
    } else if (_pendingFrameSequence != _analysedFrameSequence &&
        _pendingAgoraFrame != null) {
      final image = _pendingAgoraFrame!;
      final frameSequence = _pendingFrameSequence;
      _busy = true;
      try {
        reason = await _analyseInputImage(image, _pendingAgoraBrightness);
      } catch (e, s) {
        Log.e(_tag, 'agora tick analysis failed', e, s);
        reason = HostPresenceReason.cameraCovered;
      } finally {
        _busy = false;
      }
      if (!_running) return;
      _analysedFrameSequence = frameSequence;
      _lastAnalysisAt = DateTime.now();
      _lastAnalysisReason = reason;
    } else if (_lastAnalysisAt == null) {
      return;
    }

    _updateViolation(reason, stateElapsed);
  }

  /// Core analysis: returns the violation reason for the given frame.
  ///
  /// Only flag a violation when the face is genuinely NOT visible — camera
  /// covered/off or no face detected at all. `facePartial` and `mask`
  /// reasons are intentionally NOT triggered because ML Kit false positives
  /// were causing bans even when the host was clearly in front of the camera.
  ///
  /// If ML Kit throws (corrupt frame, unsupported format, OOM), we return
  /// `cameraCovered` rather than propagating the exception — this ensures
  /// a silently failing detector still increments the violation counter
  /// instead of leaving the guard dead.
  Future<HostPresenceReason> _analyseInputImage(
    InputImage inputImage,
    double brightness,
  ) async {
    if (brightness < _blackFrameBrightness) {
      Log.d(
        _tag,
        'frame brightness $brightness < $_blackFrameBrightness — cameraCovered',
      );
      return HostPresenceReason.cameraCovered;
    }
    try {
      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isEmpty) {
        return HostPresenceReason.noFace;
      }
      // A face was detected — the host is present.
      return HostPresenceReason.none;
    } catch (e, s) {
      Log.e(
        _tag,
        'ML Kit face detection threw — treating as cameraCovered',
        e,
        s,
      );
      return HostPresenceReason.cameraCovered;
    }
  }

  // ---- Violation state machine ------------------------------------------

  void _initializeMonitoringState() {
    final now = DateTime.now();
    _monitoringStartedAt = now;
    _lastTickAt = now;
    _lastAnalysisAt = null;
    _lastAnalysisReason = HostPresenceReason.none;
    _pendingFrameSequence = 0;
    _analysedFrameSequence = 0;
    _resetViolation(clearPersisted: false);
  }

  Duration _takeTickElapsed(DateTime now) {
    final previous = _lastTickAt ?? now;
    _lastTickAt = now;
    final elapsed = now.difference(previous);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  String? get _progressKey {
    final userId = _userId;
    final liveId = _liveStreamingId;
    if (userId == null || userId.isEmpty || liveId == null || liveId.isEmpty) {
      return null;
    }
    return '${_kProgressPrefix}_${Uri.encodeComponent(userId)}_${Uri.encodeComponent(liveId)}';
  }

  Future<void> _restoreViolationProgress() async {
    final key = _progressKey;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic> || json['dateKey'] != _todayKey()) {
        await prefs.remove(key);
        return;
      }
      final elapsedMs = (json['elapsedMs'] as num?)?.toInt() ?? 0;
      final reasonName = json['reason']?.toString();
      final reason = HostPresenceReason.values.firstWhere(
        (value) => value.name == reasonName,
        orElse: () => HostPresenceReason.none,
      );
      if (elapsedMs <= 0 || reason == HostPresenceReason.none) return;
      _violationAccumulatedMs = elapsedMs.clamp(
        0,
        _violationThresholdSec * 1000,
      );
      _lastAnalysisReason = reason;
      _lastAnalysisAt = DateTime.now();
      _currentSeverity = severityForElapsedSeconds(_violationAccumulatedSec);
      _lastPersistedSecond = _violationAccumulatedSec;
      _statusController.add(
        HostPresenceStatus(
          severity: _currentSeverity,
          reason: reason,
          violationSeconds: _violationAccumulatedSec,
        ),
      );
      Log.w(
        _tag,
        'restored guard timer: $_violationAccumulatedSec/$_violationThresholdSec seconds',
      );
    } catch (e, s) {
      Log.e(_tag, 'restore violation progress failed', e, s);
    }
  }

  Future<void> _persistViolationProgress(HostPresenceReason reason) async {
    final key = _progressKey;
    if (key == null || _progressWriteBusy) return;
    _progressWriteBusy = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode({
          'elapsedMs': _violationAccumulatedMs,
          'reason': reason.name,
          'dateKey': _todayKey(),
          'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } catch (e) {
      Log.w(_tag, 'persist violation progress failed: $e');
    } finally {
      _progressWriteBusy = false;
    }
  }

  Future<void> _clearViolationProgress() async {
    final key = _progressKey;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (e) {
      Log.w(_tag, 'clear violation progress failed: $e');
    }
  }

  void _resetViolation({bool clearPersisted = true}) {
    _violationAccumulatedMs = 0;
    _lastPersistedSecond = -1;
    _currentSeverity = HostPresenceSeverity.clear;
    _violationDeclared = false;
    if (clearPersisted) unawaited(_clearViolationProgress());
    if (!_statusController.isClosed) {
      _statusController.add(HostPresenceStatus.clear);
    }
  }

  void _updateViolation(HostPresenceReason reason, Duration elapsed) {
    if (reason == HostPresenceReason.none) {
      if (_violationAccumulatedMs > 0) {
        Log.d(_tag, 'violation cleared — counter reset to 0');
        _resetViolation();
      }
      return;
    }

    _violationAccumulatedMs = nextViolationElapsedMs(
      currentMs: _violationAccumulatedMs,
      elapsed: elapsed,
      violating: true,
      paused: false,
    );
    final newSeverity = severityForElapsedSeconds(_violationAccumulatedSec);
    final crossedThreshold = newSeverity != _currentSeverity;

    Log.w(
      _tag,
      'Guard violation seconds: $_violationAccumulatedSec / '
      '$_violationThresholdSec (reason=$reason, severity=$newSeverity'
      '${crossedThreshold ? ', ESCALATED' : ''})',
    );

    _currentSeverity = newSeverity;
    if (!_statusController.isClosed) {
      _statusController.add(
        HostPresenceStatus(
          severity: newSeverity,
          reason: reason,
          violationSeconds: _violationAccumulatedSec,
        ),
      );
    }

    final currentSecond = _violationAccumulatedSec;
    if (currentSecond != _lastPersistedSecond &&
        (currentSecond % 5 == 0 || crossedThreshold)) {
      _lastPersistedSecond = currentSecond;
      unawaited(_persistViolationProgress(reason));
    }

    if (newSeverity == HostPresenceSeverity.violation && !_violationDeclared) {
      _violationDeclared = true;
      Log.w(_tag, '*** 180s threshold reached — declaring violation ***');
      _declareViolation(reason).catchError((e, s) {
        Log.e(_tag, '_declareViolation failed', e, s);
        onTerminateStream?.call().catchError((_) => Future.value(false));
      });
    }
  }

  /// Declare a valid presence violation at the 180s threshold: persist the
  /// escalating ban, emit the backend event **once**, and terminate the stream.
  Future<void> _declareViolation(HostPresenceReason reason) async {
    Log.w(
      _tag,
      'declaring presence violation after ${_violationAccumulatedSec}s '
      '(reason=$reason)',
    );
    final ban = await _applyEscalatingBan(reason);
    await _clearViolationProgress();
    if (!_statusController.isClosed) {
      _statusController.add(
        HostPresenceStatus(
          severity: HostPresenceSeverity.violation,
          reason: reason,
          violationSeconds: _violationAccumulatedSec,
          ban: ban,
        ),
      );
    }
    unawaited(
      _reportHostComplianceViolation(reason, ban).catchError((e, s) {
        Log.e(_tag, 'backend violation report failed', e, s);
      }),
    );
    await _onSeverityChanged(HostPresenceSeverity.violation);
  }

  static HostPresenceSeverity severityForElapsedSeconds(int seconds) {
    if (seconds >= _violationThresholdSec) {
      return HostPresenceSeverity.violation;
    }
    if (seconds >= _warningThresholdSec) return HostPresenceSeverity.warning;
    return HostPresenceSeverity.clear;
  }

  static int nextViolationElapsedMs({
    required int currentMs,
    required Duration elapsed,
    required bool violating,
    required bool paused,
  }) {
    if (!violating) return 0;
    if (paused) return currentMs;
    return (currentMs + elapsed.inMilliseconds).clamp(
      0,
      _violationThresholdSec * 1000,
    );
  }

  Future<void> _onSeverityChanged(HostPresenceSeverity severity) async {
    switch (severity) {
      case HostPresenceSeverity.violation:
        // Block gifts as part of the ban, then terminate the stream.
        onBlockGifts?.call();
        final ok = await onTerminateStream?.call() ?? false;
        if (ok) await stop();
        break;
      case HostPresenceSeverity.warning:
      case HostPresenceSeverity.clear:
        break;
    }
  }

  // ---- Escalating ban & persistence -------------------------------------

  /// Date key (`YYYY-MM-DD`) used for the daily violation counter.
  static String _todayKey() {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}'
        '-${d.month.toString().padLeft(2, '0')}'
        '-${d.day.toString().padLeft(2, '0')}';
  }

  /// Load the persisted ban state from SharedPreferences, resetting the
  /// daily violation counter on calendar-day rollover.
  static String _userScopedKey(String base, String userId) =>
      '${base}_${Uri.encodeComponent(userId)}';

  static HostPresenceBanTier tierForViolationCount(int dailyCount) {
    if (dailyCount <= 1) return HostPresenceBanTier.first;
    if (dailyCount == 2) return HostPresenceBanTier.second;
    return HostPresenceBanTier.third;
  }

  static int banDurationMinutesForTier(HostPresenceBanTier tier) {
    switch (tier) {
      case HostPresenceBanTier.first:
        return 5;
      case HostPresenceBanTier.second:
        return 60;
      case HostPresenceBanTier.third:
        return 240;
      case HostPresenceBanTier.none:
        return 0;
    }
  }

  static Future<HostPresenceBanInfo?> persistedBanForUser(String userId) async {
    if (userId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _userScopedKey(_kViolationDate, userId);
    final countKey = _userScopedKey(_kViolationCount, userId);
    final banKey = _userScopedKey(_kBanInfo, userId);
    final today = _todayKey();
    if (prefs.getString(dateKey) != today) {
      await prefs.setInt(countKey, 0);
      await prefs.setString(dateKey, today);
    }
    final raw = prefs.getString(banKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        await prefs.remove(banKey);
        return null;
      }
      final ban = HostPresenceBanInfo.fromJson(json);
      if (ban.isActive()) return ban;
      await prefs.remove(banKey);
    } catch (_) {
      await prefs.remove(banKey);
    }
    return null;
  }

  Future<void> _ensureBanStateLoaded({String? userId}) async {
    final resolvedUserId = userId ?? _userId;
    if (resolvedUserId == null || resolvedUserId.isEmpty) return;
    if (_banStateLoadedForUser == resolvedUserId) return;
    _activeBan = await persistedBanForUser(resolvedUserId);
    _banStateLoadedForUser = resolvedUserId;
  }

  /// Increment the daily violation counter, compute the escalating ban
  /// tier + duration, persist it, and broadcast the new ban info.
  Future<HostPresenceBanInfo> _applyEscalatingBan(
    HostPresenceReason reason,
  ) async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      throw StateError('Cannot apply host presence ban without a user ID');
    }
    await _ensureBanStateLoaded(userId: userId);
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _userScopedKey(_kViolationDate, userId);
    final countKey = _userScopedKey(_kViolationCount, userId);
    final banKey = _userScopedKey(_kBanInfo, userId);
    final today = _todayKey();
    var count = prefs.getInt(countKey) ?? 0;
    if (prefs.getString(dateKey) != today) count = 0;
    count += 1;

    final tier = tierForViolationCount(count);
    final durationMin = banDurationMinutesForTier(tier);
    final now = DateTime.now();
    final ban = HostPresenceBanInfo(
      tier: tier,
      banDurationMinutes: durationMin,
      banStartEpochMs: now.millisecondsSinceEpoch,
      banExpiresEpochMs: now.millisecondsSinceEpoch + durationMin * 60 * 1000,
      dailyViolationCount: count,
      violationDateKey: today,
      reasonCodes: [_reasonToBackendCode(reason)],
      reason: _reasonToBackendReason(reason),
    );

    await prefs.setInt(countKey, count);
    await prefs.setString(dateKey, today);
    await prefs.setString(banKey, jsonEncode(ban.toJson()));
    _activeBan = ban;
    if (!_banController.isClosed) _banController.add(ban);
    Log.w(
      _tag,
      'ban applied: tier=${tier.name} duration=${durationMin}min '
      'dailyCount=$count expires=${DateTime.fromMillisecondsSinceEpoch(ban.banExpiresEpochMs)}',
    );
    return ban;
  }

  /// Whether the host is currently serving an active presence ban.
  Future<bool> isHostBanned({String? userId}) async =>
      await getActiveBan(userId: userId) != null;

  /// The active ban info, or `null` if not currently banned.
  Future<HostPresenceBanInfo?> getActiveBan({String? userId}) async {
    final resolvedUserId = userId ?? _userId;
    if (resolvedUserId == null || resolvedUserId.isEmpty) return null;
    await _ensureBanStateLoaded(userId: resolvedUserId);
    if (_activeBan != null && !_activeBan!.isActive()) {
      _activeBan = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userScopedKey(_kBanInfo, resolvedUserId));
      if (!_banController.isClosed) _banController.add(null);
    }
    return _activeBan;
  }

  /// Clear any active or persisted presence ban for the given user.
  /// Use this when the backend confirms the user is no longer banned so
  /// the on-device guard does not keep blocking them with stale local state.
  Future<void> clearActiveBan({String? userId}) async {
    final resolvedUserId = userId ?? _userId;
    if (resolvedUserId == null || resolvedUserId.isEmpty) return;
    _activeBan = null;
    _banStateLoadedForUser = null;
    await clearPersistedBanForUser(resolvedUserId);
    if (!_banController.isClosed) _banController.add(null);
  }

  /// Remove the persisted ban for [userId] from SharedPreferences.
  static Future<void> clearPersistedBanForUser(String userId) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userScopedKey(_kBanInfo, userId));
  }

  // ---- Backend emission --------------------------------------------------

  /// Emit `hostComplianceViolation` to the backend **once** at the 180s
  /// violation threshold, including the escalating ban tier + duration so
  /// the backend can enforce the block / reward deduction server-side.
  Future<void> _reportHostComplianceViolation(
    HostPresenceReason reason,
    HostPresenceBanInfo ban,
  ) async {
    final userId = _userId;
    final liveId = _liveStreamingId;
    if (userId == null || liveId == null) return;
    final code = _reasonToBackendCode(reason);
    if (code.isEmpty) return;
    final now = DateTime.now();
    final violationEventId =
        '${Uri.encodeComponent(userId)}_${Uri.encodeComponent(liveId)}_${now.microsecondsSinceEpoch}';
    await ApiService.recordHostComplianceViolation(
      userId: userId,
      liveStreamingId: liveId,
      reasonCodes: [code],
      reason: _reasonToBackendReason(reason),
      hasMask: false,
      violationTier: ban.tier.name,
      banDurationMinutes: ban.banDurationMinutes,
      dailyViolationCount: ban.dailyViolationCount,
      deductDailyRewards: ban.tier == HostPresenceBanTier.second,
      violationEventId: violationEventId,
      clientDetectedAt: now.toUtc().toIso8601String(),
      gracePeriodSeconds: _violationThresholdSec,
    );
    Log.w(
      _tag,
      'backend violation recorded once: eventId=$violationEventId '
      'tier=${ban.tier.name} ban=${ban.banDurationMinutes}min',
    );
  }

  String _reasonToBackendCode(HostPresenceReason reason) {
    switch (reason) {
      case HostPresenceReason.cameraCovered:
        return 'black_screen';
      case HostPresenceReason.cameraOff:
        return 'camera_off';
      case HostPresenceReason.noFace:
        return 'no_face';
      case HostPresenceReason.facePartial:
        return 'off_frame';
      case HostPresenceReason.mask:
        return 'mask';
      case HostPresenceReason.none:
        return '';
    }
  }

  String _reasonToBackendReason(HostPresenceReason reason) {
    switch (reason) {
      case HostPresenceReason.cameraCovered:
        return 'Stream shows a black or blank screen';
      case HostPresenceReason.cameraOff:
        return 'Camera is turned off';
      case HostPresenceReason.noFace:
        return 'Host face is not visible';
      case HostPresenceReason.facePartial:
        return 'Host has left the frame';
      case HostPresenceReason.mask:
        return 'Host is wearing a mask or covering face';
      case HostPresenceReason.none:
        return '';
    }
  }

  // ---- Frame heuristics --------------------------------------------------

  double _estimateBrightnessFromBytes(Uint8List bytes) {
    if (bytes.length < 256) return 0;
    final start = bytes.length ~/ 2;
    int sum = 0;
    const sampleCount = 256;
    for (int i = 0; i < sampleCount; i++) {
      sum += bytes[start + i];
    }
    return sum / sampleCount;
  }

  /// Convert an Agora YUV420 `VideoFrame` to ML Kit's NV21 format and
  /// wrap it in an [InputImage]. Returns `null` if the frame is not YUV
  /// or the dimensions are invalid.
  ///
  /// The live room calls this from `onCaptureVideoFrame` and then passes
  /// the result to [submitAgoraFrame].
  static InputImage? agoraFrameToInputImage({
    required Uint8List yBuffer,
    required Uint8List uBuffer,
    required Uint8List vBuffer,
    required int yStride,
    required int uStride,
    required int vStride,
    required int width,
    required int height,
    required int rotation,
  }) {
    try {
      final inputRotation = InputImageRotationValue.fromRawValue(rotation);
      if (inputRotation == null) return null;
      final bytes =
          Platform.isIOS
              ? _i420ToBgra8888(
                yBuffer: yBuffer,
                uBuffer: uBuffer,
                vBuffer: vBuffer,
                yStride: yStride,
                uStride: uStride,
                vStride: vStride,
                width: width,
                height: height,
              )
              : _yuv420ToNv21(
                yBuffer: yBuffer,
                uBuffer: uBuffer,
                vBuffer: vBuffer,
                yStride: yStride,
                uStride: uStride,
                vStride: vStride,
                width: width,
                height: height,
              );
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(width.toDouble(), height.toDouble()),
          rotation: inputRotation,
          format:
              Platform.isIOS
                  ? InputImageFormat.bgra8888
                  : InputImageFormat.nv21,
          bytesPerRow: Platform.isIOS ? width * 4 : width,
        ),
      );
    } catch (e) {
      Log.w(_tag, 'agoraFrameToInputImage failed: $e');
      return null;
    }
  }

  /// Estimate brightness from the Y plane of a YUV frame (Y ≈ luminance).
  static double agoraFrameBrightness(
    Uint8List yBuffer,
    int yStride,
    int width,
    int height,
  ) {
    if (yBuffer.length < 256) return 0;
    // Sample a grid of pixels from the centre of the Y plane.
    final midRow = height ~/ 2;
    final midCol = width ~/ 2;
    int sum = 0;
    int count = 0;
    for (int dy = -8; dy <= 8; dy++) {
      for (int dx = -8; dx <= 8; dx++) {
        final row = midRow + dy;
        final col = midCol + dx;
        if (row < 0 || row >= height || col < 0 || col >= width) continue;
        final idx = row * yStride + col;
        if (idx >= yBuffer.length) continue;
        sum += yBuffer[idx];
        count++;
      }
    }
    return count > 0 ? sum / count : 0;
  }

  static Uint8List _i420ToBgra8888({
    required Uint8List yBuffer,
    required Uint8List uBuffer,
    required Uint8List vBuffer,
    required int yStride,
    required int uStride,
    required int vStride,
    required int width,
    required int height,
  }) {
    if (width <= 0 || height <= 0 || width.isOdd || height.isOdd) {
      throw ArgumentError('I420 dimensions must be positive and even');
    }
    final halfWidth = width ~/ 2;
    final halfHeight = height ~/ 2;
    if (yStride < width || uStride < halfWidth || vStride < halfWidth) {
      throw ArgumentError('I420 plane stride is smaller than the frame width');
    }
    if (yBuffer.length < (height - 1) * yStride + width ||
        uBuffer.length < (halfHeight - 1) * uStride + halfWidth ||
        vBuffer.length < (halfHeight - 1) * vStride + halfWidth) {
      throw ArgumentError(
        'I420 plane buffer is smaller than its stride metadata',
      );
    }
    final bgra = Uint8List(width * height * 4);
    var output = 0;
    for (var row = 0; row < height; row++) {
      final yRow = row * yStride;
      final uRow = (row ~/ 2) * uStride;
      final vRow = (row ~/ 2) * vStride;
      for (var col = 0; col < width; col++) {
        final y = yBuffer[yRow + col].toDouble();
        final u = uBuffer[uRow + col ~/ 2] - 128.0;
        final v = vBuffer[vRow + col ~/ 2] - 128.0;
        bgra[output++] = (y + 1.772 * u).round().clamp(0, 255);
        bgra[output++] = (y - 0.344136 * u - 0.714136 * v).round().clamp(
          0,
          255,
        );
        bgra[output++] = (y + 1.402 * v).round().clamp(0, 255);
        bgra[output++] = 255;
      }
    }
    return bgra;
  }

  static Uint8List _yuv420ToNv21({
    required Uint8List yBuffer,
    required Uint8List uBuffer,
    required Uint8List vBuffer,
    required int yStride,
    required int uStride,
    required int vStride,
    required int width,
    required int height,
  }) {
    if (width <= 0 || height <= 0 || width.isOdd || height.isOdd) {
      throw ArgumentError('I420 dimensions must be positive and even');
    }
    if (yStride < width || uStride < width ~/ 2 || vStride < width ~/ 2) {
      throw ArgumentError('I420 plane stride is smaller than the frame width');
    }
    final halfWidth = width ~/ 2;
    final halfHeight = height ~/ 2;
    final requiredYBytes = (height - 1) * yStride + width;
    final requiredUBytes = (halfHeight - 1) * uStride + halfWidth;
    final requiredVBytes = (halfHeight - 1) * vStride + halfWidth;
    if (yBuffer.length < requiredYBytes ||
        uBuffer.length < requiredUBytes ||
        vBuffer.length < requiredVBytes) {
      throw ArgumentError(
        'I420 plane buffer is smaller than its stride metadata',
      );
    }

    final ySize = width * height;
    final nv21 = Uint8List(ySize + ySize ~/ 2);
    var yIndex = 0;
    for (var row = 0; row < height; row++) {
      final rowOffset = row * yStride;
      nv21.setRange(yIndex, yIndex + width, yBuffer, rowOffset);
      yIndex += width;
    }

    var uvIndex = ySize;
    for (var row = 0; row < halfHeight; row++) {
      final vRowOffset = row * vStride;
      final uRowOffset = row * uStride;
      for (var col = 0; col < halfWidth; col++) {
        nv21[uvIndex++] = vBuffer[vRowOffset + col];
        nv21[uvIndex++] = uBuffer[uRowOffset + col];
      }
    }
    return nv21;
  }

  // ---- Cleanup -----------------------------------------------------------

  Future<void> dispose() async {
    await stop();
    await _statusController.close();
    await _banController.close();
  }
}
