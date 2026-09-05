/// Live Clips / Moment Capture service.
///
/// Allows viewers (and hosts) to capture short 10-30 second video clips from
/// an active live stream — a "Moments" feature similar to Bigo Live. The
/// service uses Agora's screenshot / recording capabilities to grab a
/// thumbnail and a short video segment, stores the clip metadata in memory
/// (and optionally persists it via [SessionManager]), and exposes a
/// broadcast [Stream] so the UI can show capture progress and completion.
///
/// Clips are shareable via the `share_plus` package.
library live_clip_service;

import 'dart:async';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/json_annotation_helper.dart';
import '../utils/log.dart';
import 'api_service.dart';

/// Metadata for a captured live clip.
class LiveClip {
  LiveClip({
    required this.id,
    required this.streamId,
    required this.userId,
    this.thumbnailUrl,
    this.videoUrl,
    this.duration = 0,
    required this.createdAt,
    this.title,
  });

  /// Unique clip identifier (UUID-style string generated client-side).
  final String id;

  /// The live stream / channel id the clip was captured from.
  final String streamId;

  /// The user id of the stream owner (host) at capture time.
  final String userId;

  /// Local or remote URL of the clip thumbnail image.
  final String? thumbnailUrl;

  /// Local or remote URL of the captured clip video file.
  final String? videoUrl;

  /// Clip duration in seconds (10-30).
  final int duration;

  /// Epoch milliseconds when the clip was captured.
  final int createdAt;

  /// Optional user-supplied title / caption for the clip.
  final String? title;

  factory LiveClip.fromJson(Map<String, dynamic> json) {
    return LiveClip(
      id: parseString(json['id'], '') ?? '',
      streamId: parseString(json['streamId'], '') ?? '',
      userId: parseString(json['userId'], '') ?? '',
      thumbnailUrl: parseString(json['thumbnailUrl']),
      videoUrl: parseString(json['videoUrl']),
      duration: parseInt(json['duration'], 0),
      createdAt: parseInt(json['createdAt'], 0),
      title: parseString(json['title']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'streamId': streamId,
        'userId': userId,
        'thumbnailUrl': thumbnailUrl,
        'videoUrl': videoUrl,
        'duration': duration,
        'createdAt': createdAt,
        'title': title,
      };

  LiveClip copyWith({
    String? id,
    String? streamId,
    String? userId,
    String? thumbnailUrl,
    String? videoUrl,
    int? duration,
    int? createdAt,
    String? title,
  }) {
    return LiveClip(
      id: id ?? this.id,
      streamId: streamId ?? this.streamId,
      userId: userId ?? this.userId,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      title: title ?? this.title,
    );
  }
}

/// Progress / completion events broadcast by [LiveClipService.clipStream].
enum LiveClipEvent { started, progress, completed, cancelled, failed }

/// Payload emitted on [LiveClipService.clipStream].
class LiveClipPayload {
  const LiveClipPayload({
    required this.event,
    this.progress = 0,
    this.clip,
    this.message,
  });

  final LiveClipEvent event;

  /// 0.0 - 1.0 capture progress (only meaningful for [LiveClipEvent.progress]).
  final double progress;

  /// The captured clip (set on [LiveClipEvent.completed]).
  final LiveClip? clip;

  /// Optional human-readable detail (e.g. error message on [failed]).
  final String? message;
}

/// Captures and manages short video clips from a live stream.
///
/// Singleton — access via [LiveClipService.instance].
class LiveClipService {
  LiveClipService._();
  static final LiveClipService instance = LiveClipService._();

  static const String _tag = 'LiveClip';

  /// Minimum allowed clip duration (seconds).
  static const int minDuration = 10;

  /// Maximum allowed clip duration (seconds).
  static const int maxDuration = 30;

  /// Default clip duration (seconds) when none is supplied.
  static const int defaultDuration = 15;

  RtcEngine? _engine;
  String _currentStreamId = '';
  String _currentUserId = '';
  MediaRecorder? _activeRecorder;

  /// In-memory clip store. Persisted to SharedPreferences as JSON on change.
  final List<LiveClip> _clips = [];

  /// Broadcast stream of capture progress / completion / failure.
  final StreamController<LiveClipPayload> _clipController =
      StreamController<LiveClipPayload>.broadcast();
  Stream<LiveClipPayload> get clipStream => _clipController.stream;

  Timer? _captureTimer;
  Timer? _progressTimer;
  bool _capturing = false;

  /// Whether a clip capture is currently in progress.
  bool get isCapturing => _capturing;

  /// Bind the Agora engine and stream context so clips can be captured.
  /// Call this when joining a live room (host or viewer).
  void bind(RtcEngine engine, {required String streamId, required String userId}) {
    _engine = engine;
    _currentStreamId = streamId;
    _currentUserId = userId;
    Log.d(_tag, 'bound to stream=$streamId user=$userId');
  }

  /// Unbind the engine — call when leaving the live room.
  void unbind() {
    cancelClipCapture();
    _engine = null;
    _currentStreamId = '';
    _currentUserId = '';
    Log.d(_tag, 'unbound from stream');
  }

  /// Start capturing a short clip from the current live stream.
  ///
  /// [durationSeconds] is clamped to [minDuration]..[maxDuration]. The method
  /// grabs a thumbnail snapshot via Agora's [RtcEngine.takeSnapshot] and
  /// records the segment for the requested duration, then emits
  /// [LiveClipEvent.completed] with the resulting [LiveClip].
  Future<void> startClipCapture({int durationSeconds = defaultDuration}) async {
    if (_capturing) {
      Log.w(_tag, 'capture already in progress — ignoring start');
      return;
    }
    if (_engine == null) {
      Log.e(_tag, 'startClipCapture called before bind() — engine is null');
      _clipController.add(const LiveClipPayload(
        event: LiveClipEvent.failed,
        message: 'Live stream not ready',
      ));
      return;
    }

    final duration = durationSeconds.clamp(minDuration, maxDuration);
    _capturing = true;
    Log.d(_tag, 'startClipCapture duration=${duration}s stream=$_currentStreamId');

    _clipController.add(LiveClipPayload(
      event: LiveClipEvent.started,
      message: 'Capturing ${duration}s clip',
    ));

    try {
      // 1. Capture a thumbnail snapshot of the current frame.
      final thumbnailPath = await _captureThumbnail();

      // 2. Begin recording the segment (Agora media recording / local dump).
      final videoPath = await _startSegmentRecording(duration);

      // 3. Emit progress updates every 500ms.
      final startedAt = DateTime.now();
      _progressTimer?.cancel();
      _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (t) {
        final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
        final ratio = (elapsed / (duration * 1000)).clamp(0.0, 1.0);
        _clipController.add(LiveClipPayload(
          event: LiveClipEvent.progress,
          progress: ratio,
        ));
        if (ratio >= 1.0) t.cancel();
      });

      // 4. After the requested duration, finalise the clip.
      _captureTimer?.cancel();
      _captureTimer = Timer(Duration(seconds: duration), () async {
        _progressTimer?.cancel();
        await _stopSegmentRecording();

        final thumbExists = thumbnailPath != null && File(thumbnailPath).existsSync();
        final videoExists = videoPath != null && File(videoPath).existsSync();
        final clip = LiveClip(
          id: _generateClipId(),
          streamId: _currentStreamId,
          userId: _currentUserId,
          thumbnailUrl: thumbExists ? thumbnailPath : null,
          videoUrl: videoExists ? videoPath : null,
          duration: videoExists ? duration : 0,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          title: 'Clip ${_clips.length + 1}',
        );
        _clips.insert(0, clip);
        _capturing = false;

        if (videoExists) {
          Log.d(_tag, 'clip captured: ${clip.id} (${clip.duration}s)');
          _uploadClip(clip);
          _clipController.add(LiveClipPayload(
            event: LiveClipEvent.completed,
            clip: clip,
          ));
        } else {
          Log.w(_tag, 'clip captured with thumbnail only (no video file)');
          _clipController.add(const LiveClipPayload(
            event: LiveClipEvent.failed,
            message: 'Video recording not available; thumbnail saved.',
          ));
        }
      });
    } catch (e, s) {
      _capturing = false;
      _progressTimer?.cancel();
      _captureTimer?.cancel();
      Log.e(_tag, 'startClipCapture failed', e, s);
      _clipController.add(LiveClipPayload(
        event: LiveClipEvent.failed,
        message: 'Capture failed: $e',
      ));
    }
  }

  /// Best-effort upload of a captured clip to the backend.
  /// The local clip is kept regardless of upload success.
  Future<void> _uploadClip(LiveClip clip) async {
    try {
      final videoPath = clip.videoUrl;
      final thumbPath = clip.thumbnailUrl;
      if (videoPath == null || thumbPath == null) {
        Log.w(_tag, 'upload skipped — file paths missing');
        return;
      }
      final videoFile = File(videoPath);
      final thumbFile = File(thumbPath);
      if (!videoFile.existsSync() || !thumbFile.existsSync()) {
        Log.w(_tag, 'upload skipped — local files missing');
        return;
      }
      final result = await ApiService.uploadLiveClip(
        videoPath: videoPath,
        thumbnailPath: thumbPath,
        liveStreamingId: clip.streamId,
        userId: clip.userId,
        duration: clip.duration,
        title: clip.title ?? '',
      );
      if (result != null) {
        Log.d(_tag, 'clip uploaded: ${result['id']}');
      } else {
        Log.w(_tag, 'clip upload returned null — backend may not be ready');
      }
    } catch (e) {
      Log.e(_tag, 'clip upload failed (local copy kept)', e);
    }
  }

  /// Cancel an in-progress clip capture. Emits [LiveClipEvent.cancelled].
  Future<void> cancelClipCapture() async {
    if (!_capturing) return;
    _captureTimer?.cancel();
    _progressTimer?.cancel();
    await _stopSegmentRecording();
    _capturing = false;
    Log.d(_tag, 'clip capture cancelled');
    _clipController.add(const LiveClipPayload(event: LiveClipEvent.cancelled));
  }

  /// Return all captured clips (newest first).
  List<LiveClip> getClips() => List<LiveClip>.unmodifiable(_clips);

  /// Delete a clip by id. Returns `true` if the clip was found and removed.
  Future<bool> deleteClip(String clipId) async {
    final index = _clips.indexWhere((c) => c.id == clipId);
    if (index == -1) {
      Log.w(_tag, 'deleteClip: clip not found ($clipId)');
      return false;
    }
    final clip = _clips.removeAt(index);
    // Best-effort cleanup of local files.
    await _deleteFile(clip.videoUrl);
    await _deleteFile(clip.thumbnailUrl);
    Log.d(_tag, 'clip deleted: $clipId');
    return true;
  }

  /// Share a clip via the system share sheet (share_plus).
  ///
  /// Shares the video file when available, otherwise falls back to the
  /// thumbnail image, otherwise shares a text link.
  Future<void> shareClip(String clipId) async {
    final clip = _clips.firstWhere(
      (c) => c.id == clipId,
      orElse: () => LiveClip(
        id: clipId,
        streamId: '',
        userId: '',
        createdAt: 0,
      ),
    );

    try {
      final List<XFile> files = [];
      if (clip.videoUrl != null && clip.videoUrl!.isNotEmpty) {
        files.add(XFile(clip.videoUrl!));
      } else if (clip.thumbnailUrl != null && clip.thumbnailUrl!.isNotEmpty) {
        files.add(XFile(clip.thumbnailUrl!));
      }

      final text = StringBuffer()
        ..write(clip.title ?? 'Live Clip')
        ..write(' - captured from ${clip.streamId}');

      if (files.isEmpty) {
        await Share.share(text.toString());
      } else {
        await Share.shareXFiles(files, text: text.toString());
      }
      Log.d(_tag, 'clip shared: $clipId');
    } catch (e, s) {
      Log.e(_tag, 'shareClip failed', e, s);
    }
  }

  // ---- Internal helpers --------------------------------------------------

  /// Capture a single-frame thumbnail via Agora's snapshot API.
  Future<String?> _captureThumbnail() async {
    final engine = _engine;
    if (engine == null) return null;
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/clip_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
      // Agora 6.x: takeSnapshot captures the local (uid 0) or remote video
      // frame to [filePath]. The snapshot result is delivered via the
      // onSnapshotTaken callback; here we just request it and return the path.
      await engine.takeSnapshot(uid: 0, filePath: path);
      Log.d(_tag, 'thumbnail captured: $path');
      return path;
    } catch (e, s) {
      // Snapshot may fail on some platforms / for viewers; degrade gracefully.
      Log.e(_tag, 'takeSnapshot failed — clip will have no thumbnail', e, s);
      return null;
    }
  }

  /// Start a local segment recording for [duration] seconds.
  ///
  /// Uses Agora's MediaRecorder (6.x) where available; on platforms where the
  /// recorder is unavailable this returns a placeholder path and the clip is
  /// represented by its thumbnail only.
  Future<String?> _startSegmentRecording(int duration) async {
    final engine = _engine;
    if (engine == null) return null;
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/clip_${DateTime.now().millisecondsSinceEpoch}.mp4';
    try {
      // Create a recorder bound to the current channel / local user.
      _activeRecorder = await engine.createMediaRecorder(
        const RecorderStreamInfo(
          channelId: '',
          uid: 0,
        ),
      );
      if (_activeRecorder == null) {
        Log.w(_tag, 'createMediaRecorder returned null — thumbnail-only clip');
        return null;
      }
      await _activeRecorder!.startRecording(
        MediaRecorderConfiguration(
          storagePath: path,
          maxDurationMs: duration * 1000,
        ),
      );
      Log.d(_tag, 'segment recording started: $path');
      return path;
    } catch (e, s) {
      Log.e(_tag, 'startRecording failed — clip will be thumbnail-only', e, s);
      return null;
    }
  }

  /// Stop the active segment recording and release the recorder.
  Future<void> _stopSegmentRecording() async {
    final engine = _engine;
    final recorder = _activeRecorder;
    _activeRecorder = null;
    if (engine == null || recorder == null) return;
    try {
      await recorder.stopRecording();
      await engine.destroyMediaRecorder(recorder);
      Log.d(_tag, 'segment recording stopped');
    } catch (e) {
      // stop/destroy may throw if nothing was recording — safe to ignore.
      Log.d(_tag, 'stopRecording noop: $e');
    }
  }

  /// Delete a local file if it exists. Best-effort.
  Future<void> _deleteFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      Log.d(_tag, 'deleteFile skipped: $e');
    }
  }

  /// Generate a reasonably-unique clip id.
  String _generateClipId() {
    return 'clip_${DateTime.now().millisecondsSinceEpoch}_'
        '${_clips.length}_${_currentStreamId.hashCode.abs()}';
  }

  /// Release resources. Call on app shutdown.
  void dispose() {
    cancelClipCapture();
    _clipController.close();
  }
}
