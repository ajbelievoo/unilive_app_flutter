/// Screen Share service — drives the Game LIVE / Screen Share broadcast mode.
///
/// A host can switch from camera to mobile-screen capture so viewers watch the
/// host's screen instead of the front/back camera. This wraps Agora's
/// `startScreenCapture` / `stopScreenCapture` calls behind a small singleton
/// that:
///   * exposes [startScreenShare] / [stopScreenShare] / [isScreenSharing],
///   * broadcasts state changes through [screenShareStateStream],
///   * handles the Android `MediaProjection` permission request flow, and
///   * falls back gracefully (no-op + `false`) on platforms / engines where
///     screen capture is not supported.
///
/// The active [RtcEngine] is injected via [setEngine] by the live room screen
/// before [startScreenShare] is called, mirroring [AudioRoomEngineService].
///
/// Android requirement: the host app must declare the Agora screen-capture
/// foreground service in `AndroidManifest.xml`
/// (`<service android:name="io.agora.rtc.ss.service.AgoraScreenCaptureService"
///  android:foregroundServiceType="mediaProjection" />`) plus the
/// `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MEDIA_PROJECTION` permissions.
/// Without it `startScreenCapture` throws and the service reports
/// `isScreenSharing == false`.
library;

import 'dart:async';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../utils/log.dart';

/// State broadcast on [ScreenShareService.screenShareStateStream].
enum ScreenShareState {
  /// No screen capture in progress (initial / stopped / failed).
  idle,

  /// Screen capture has been requested and the Android `MediaProjection`
  /// permission dialog is showing (Android only).
  requestingPermission,

  /// Screen capture is active and being published to the channel.
  sharing,

  /// Screen capture is not supported on this platform / engine combination.
  unsupported,
}

/// Singleton wrapping Agora screen-share capture for the Game LIVE mode.
class ScreenShareService {
  ScreenShareService._();
  static final ScreenShareService instance = ScreenShareService._();

  static const String _tag = 'ScreenShareService';

  RtcEngine? _engine;

  bool _sharing = false;
  bool _permissionPending = false;

  /// Broadcasts [ScreenShareState] changes so UI (toggle button, badge, etc.)
  /// can react without polling. Emits the current state to new listeners.
  final StreamController<ScreenShareState> _stateController =
      StreamController<ScreenShareState>.broadcast();

  Stream<ScreenShareState> get screenShareStateStream => _stateController.stream;

  /// Whether screen capture is currently active and being published.
  bool get isScreenSharing => _sharing;

  /// Whether the Android `MediaProjection` permission dialog is currently
  /// showing. UI may use this to display a "waiting for permission" spinner.
  bool get isPermissionPending => _permissionPending;

  /// Inject the active Agora engine. Called by the live room screen on init.
  void setEngine(RtcEngine? engine) {
    _engine = engine;
    Log.d(_tag, 'engine set: ${engine != null ? 'yes' : 'no'}');
  }

  /// Release the engine reference and reset state. Called on room dispose.
  void clear() {
    if (_sharing) {
      // Best-effort stop; ignore errors since the engine may be gone.
      stopScreenShare(silent: true);
    }
    _engine = null;
    _sharing = false;
    _permissionPending = false;
    Log.d(_tag, 'cleared');
  }

  /// Returns `true` if screen capture is supported on the current platform.
  ///
  /// Agora's `startScreenCapture` is only implemented for Android and iOS in
  /// the mobile Flutter wrapper. On other platforms we short-circuit so the
  /// host UI can hide / disable the Game LIVE toggle.
  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  // ---- Public API ---------------------------------------------------------

  /// Start broadcasting the host's mobile screen.
  ///
  /// On Android this triggers the system `MediaProjection` permission dialog;
  /// the state stream emits [ScreenShareState.requestingPermission] while the
  /// dialog is up, then [ScreenShareState.sharing] once capture begins.
  ///
  /// Returns `true` on success, `false` if screen share is unsupported, the
  /// engine is missing, capture is already active, or the call threw.
  Future<bool> startScreenShare() async {
    if (!isSupported) {
      Log.d(_tag, 'startScreenShare: unsupported platform');
      _emit(ScreenShareState.unsupported);
      return false;
    }
    if (_sharing) {
      Log.d(_tag, 'startScreenShare: already sharing');
      return true;
    }
    final engine = _engine;
    if (engine == null) {
      Log.e(_tag, 'startScreenShare: engine not set');
      _emit(ScreenShareState.idle);
      return false;
    }

    // Android requires the user to grant MediaProjection. We surface the
    // "requesting permission" state before the SDK shows the system dialog so
    // the UI can display a spinner / hint. On iOS there is no such dialog.
    if (Platform.isAndroid) {
      _permissionPending = true;
      _emit(ScreenShareState.requestingPermission);
    }

    try {
      await engine.startScreenCapture(const ScreenCaptureParameters2(
        captureVideo: true,
        captureAudio: false,
        videoParams: ScreenVideoParameters(
          dimensions: VideoDimensions(width: 1280, height: 720),
          frameRate: 15,
        ),
      ));
      _sharing = true;
      _permissionPending = false;
      _emit(ScreenShareState.sharing);
      Log.d(_tag, 'screen share started');
      return true;
    } catch (e, s) {
      _sharing = false;
      _permissionPending = false;
      _emit(ScreenShareState.idle);
      Log.e(_tag, 'startScreenShare failed', e, s);
      return false;
    }
  }

  /// Stop broadcasting the host's screen and resume the previous video source.
  ///
  /// [silent] suppresses error logging — used by [clear] during teardown where
  /// the engine may already be released.
  ///
  /// Returns `true` on success (or when not sharing), `false` on error.
  Future<bool> stopScreenShare({bool silent = false}) async {
    if (!_sharing) {
      if (!silent) Log.d(_tag, 'stopScreenShare: not sharing');
      _permissionPending = false;
      _emit(ScreenShareState.idle);
      return true;
    }
    final engine = _engine;
    if (engine == null) {
      _sharing = false;
      _permissionPending = false;
      _emit(ScreenShareState.idle);
      if (!silent) Log.e(_tag, 'stopScreenShare: engine not set');
      return false;
    }

    try {
      await engine.stopScreenCapture();
      _sharing = false;
      _permissionPending = false;
      _emit(ScreenShareState.idle);
      Log.d(_tag, 'screen share stopped');
      return true;
    } catch (e, s) {
      // Mark stopped even on error so the UI does not get stuck "on".
      _sharing = false;
      _permissionPending = false;
      _emit(ScreenShareState.idle);
      if (!silent) Log.e(_tag, 'stopScreenShare failed', e, s);
      return false;
    }
  }

  /// Toggle screen share on/off. Convenience for the host toggle button.
  Future<bool> toggleScreenShare() =>
      _sharing ? stopScreenShare() : startScreenShare();

  // ---- Internals ----------------------------------------------------------

  void _emit(ScreenShareState state) {
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  /// Permanently close the state stream. Only call this during app teardown;
  /// the live room screen should use [clear] instead.
  void dispose() {
    clear();
    _stateController.close();
  }
}
