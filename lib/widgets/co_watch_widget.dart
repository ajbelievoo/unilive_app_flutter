/// Co-Watch / Watch Together overlay for live rooms.
///
/// Lets a host and viewers watch a video (YouTube or direct URL) together in
/// the live room. The host sets the video URL; viewers receive the same video
/// and playback state synced via socket events so everyone stays in lock-step.
///
/// The widget has two visual modes:
/// - **Maximised**: a 16:9 video panel docked at the top of the room with the
///   video title, a play/pause toggle, a seek bar, and a close button.
/// - **Minimised**: a small floating bar that shows the title and a restore
///   button, keeping the video audible while the room is browsed.
///
/// Playback is driven by the `video_player` package. Sync is coordinated by
/// [CoWatchController] (a [ChangeNotifier]) which exposes socket hooks the
/// screen wires to `SocketService`.
library co_watch_widget;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_theme.dart';
import '../utils/log.dart';

/// Socket event hooks the host fires so viewers can mirror state.
///
/// The screen wires these to `SocketService.emit(...)` so every viewer applies
/// the same playback command. Viewers never emit — only the host drives sync.
class CoWatchSocketHooks {
  const CoWatchSocketHooks({
    this.onPlay,
    this.onPause,
    this.onResume,
    this.onStop,
    this.onSeek,
    this.onVideoChanged,
  });

  /// Host started/resumed a video from [positionMs].
  final void Function(String url, String title, int positionMs)? onPlay;

  /// Host paused.
  final void Function()? onPause;

  /// Host resumed.
  final void Function()? onResume;

  /// Host stopped / cleared the video.
  final void Function()? onStop;

  /// Host seeked to [positionMs].
  final void Function(int positionMs)? onSeek;

  /// Host switched the video URL — viewers should load the new source.
  final void Function(String url, String title)? onVideoChanged;
}

/// A [ChangeNotifier]-backed controller that manages co-watch playback state
/// and sync between host and viewers.
///
/// The host owns the authoritative playback timeline. Viewers apply remote
/// commands via the `apply*` methods (called from socket event handlers) which
/// seek the local player to match the host without re-emitting anything.
class CoWatchController extends ChangeNotifier {
  CoWatchController({
    required bool isHost,
    CoWatchSocketHooks? hooks,
  })  : _isHost = isHost,
        _hooks = hooks ?? const CoWatchSocketHooks();

  static const String _tag = 'CoWatch';

  final bool _isHost;
  CoWatchSocketHooks _hooks;

  /// Update hooks (e.g. after socket subscriptions are wired).
  set hooks(CoWatchSocketHooks value) {
    _hooks = value;
  }

  // ---- Source ----
  String? _url;
  String? get url => _url;
  String _title = '';
  String get title => _title;

  // ---- Playback state ----
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;
  int _positionMs = 0;
  int get positionMs => _positionMs;
  int _durationMs = 0;
  int get durationMs => _durationMs;
  bool _isReady = false;
  bool get isReady => _isReady;
  bool _hasError = false;
  bool get hasError => _hasError;

  // ---- View state ----
  bool _isMinimized = false;
  bool get isMinimized => _isMinimized;
  bool get isActive => _url != null && _url!.isNotEmpty;

  VideoPlayerController? _videoCtrl;
  VideoPlayerController? get videoController => _videoCtrl;
  Timer? _posTimer;
  bool _applyingRemote = false;

  // ---- Host: set / change video ----

  /// Host sets a new video URL and title. Loads the player, starts playback,
  /// and emits the `onVideoChanged` + `onPlay` hooks so viewers mirror.
  Future<void> setVideo(String url, {String title = ''}) async {
    if (url.isEmpty) return;
    Log.d(_tag, 'setVideo host=$url title=$title');
    _url = url;
    _title = title;
    _hasError = false;
    _isReady = false;
    notifyListeners();
    await _loadAndPlay(fromMs: 0);
    _hooks.onVideoChanged?.call(url, title);
    _hooks.onPlay?.call(url, title, 0);
  }

  // ---- Host: transport controls ----

  Future<void> togglePlayPause() async {
    if (_videoCtrl == null || !_isReady) return;
    if (_isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> pause() async {
    if (_videoCtrl == null || !_isPlaying) return;
    Log.d(_tag, 'pause');
    await _videoCtrl!.pause();
    _isPlaying = false;
    _stopPositionTimer();
    notifyListeners();
    if (_isHost) _hooks.onPause?.call();
  }

  Future<void> resume() async {
    if (_videoCtrl == null || _isPlaying) return;
    Log.d(_tag, 'resume');
    await _videoCtrl!.play();
    _isPlaying = true;
    _startPositionTimer();
    notifyListeners();
    if (_isHost) {
      _hooks.onResume?.call();
    }
  }

  Future<void> seekTo(int positionMs) async {
    if (_videoCtrl == null || !_isReady) return;
    Log.d(_tag, 'seekTo $positionMs');
    await _videoCtrl!.seekTo(Duration(milliseconds: positionMs));
    _positionMs = positionMs;
    notifyListeners();
    if (_isHost && !_applyingRemote) _hooks.onSeek?.call(positionMs);
  }

  /// Host stops and clears the video.
  Future<void> stop() async {
    Log.d(_tag, 'stop');
    _stopPositionTimer();
    await _videoCtrl?.dispose();
    _videoCtrl = null;
    _url = null;
    _title = '';
    _isPlaying = false;
    _isReady = false;
    _hasError = false;
    _positionMs = 0;
    _durationMs = 0;
    _isMinimized = false;
    notifyListeners();
    if (_isHost) _hooks.onStop?.call();
  }

  // ---- View: view state ----

  void toggleMinimize() {
    _isMinimized = !_isMinimized;
    notifyListeners();
  }

  void minimize() {
    if (!_isMinimized) {
      _isMinimized = true;
      notifyListeners();
    }
  }

  void maximize() {
    if (_isMinimized) {
      _isMinimized = false;
      notifyListeners();
    }
  }

  // ---- Viewer: remote sync commands (called from socket handlers) ----

  /// Viewer loads a video that the host just started.
  Future<void> applyPlay(String url, String title, int positionMs) async {
    if (_isHost) return; // host is the source of truth
    Log.d(_tag, 'applyPlay url=$url pos=$positionMs');
    _url = url;
    _title = title;
    _hasError = false;
    _isReady = false;
    notifyListeners();
    await _loadAndPlay(fromMs: positionMs);
  }

  /// Viewer mirrors a host pause.
  Future<void> applyPause() async {
    if (_isHost) return;
    Log.d(_tag, 'applyPause');
    await _videoCtrl?.pause();
    _isPlaying = false;
    _stopPositionTimer();
    notifyListeners();
  }

  /// Viewer mirrors a host resume.
  Future<void> applyResume() async {
    if (_isHost) return;
    Log.d(_tag, 'applyResume');
    await _videoCtrl?.play();
    _isPlaying = true;
    _startPositionTimer();
    notifyListeners();
  }

  /// Viewer mirrors a host seek.
  Future<void> applySeek(int positionMs) async {
    if (_isHost) return;
    Log.d(_tag, 'applySeek $positionMs');
    _applyingRemote = true;
    await _videoCtrl?.seekTo(Duration(milliseconds: positionMs));
    _positionMs = positionMs;
    _applyingRemote = false;
    notifyListeners();
  }

  /// Viewer mirrors a host stop.
  Future<void> applyStop() async {
    if (_isHost) return;
    Log.d(_tag, 'applyStop');
    await stop();
  }

  // ---- Internal player lifecycle ----

  Future<void> _loadAndPlay({required int fromMs}) async {
    final url = _url;
    if (url == null || url.isEmpty) return;
    await _videoCtrl?.dispose();
    _videoCtrl = null;
    _isReady = false;
    _hasError = false;
    notifyListeners();

    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoCtrl = ctrl;
    try {
      await ctrl.initialize();
      if (!isActive) {
        // Video was cleared while initializing.
        await ctrl.dispose();
        _videoCtrl = null;
        return;
      }
      _durationMs = ctrl.value.duration.inMilliseconds;
      if (fromMs > 0 && fromMs < _durationMs) {
        await ctrl.seekTo(Duration(milliseconds: fromMs));
      }
      _positionMs = fromMs.clamp(0, _durationMs > 0 ? _durationMs : fromMs);
      await ctrl.play();
      _isPlaying = true;
      _isReady = true;
      _startPositionTimer();
      notifyListeners();
      Log.d(_tag, 'ready dur=${_durationMs}ms pos=${_positionMs}ms');
    } catch (e, st) {
      Log.e(_tag, 'failed to initialize video', e, st);
      _hasError = true;
      _isReady = false;
      _isPlaying = false;
      notifyListeners();
    }
  }

  void _startPositionTimer() {
    _stopPositionTimer();
    _posTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final ctrl = _videoCtrl;
      if (ctrl == null || !ctrl.value.isInitialized) return;
      _positionMs = ctrl.value.position.inMilliseconds;
      if (_durationMs <= 0) {
        _durationMs = ctrl.value.duration.inMilliseconds;
      }
      notifyListeners();
    });
  }

  void _stopPositionTimer() {
    _posTimer?.cancel();
    _posTimer = null;
  }

  @override
  void dispose() {
    _stopPositionTimer();
    _videoCtrl?.dispose();
    _videoCtrl = null;
    super.dispose();
  }
}

/// Co-Watch overlay widget. Mount this on top of the live room surface.
///
/// When [controller.isActive] is false the widget renders nothing. Otherwise it
/// shows either the maximised panel or the minimised floating bar depending on
/// [CoWatchController.isMinimized].
class CoWatchWidget extends StatefulWidget {
  const CoWatchWidget({
    super.key,
    required this.controller,
    this.onClose,
  });

  final CoWatchController controller;

  /// Called when the user taps the close button. The screen should call
  /// [CoWatchController.stop] (host) or clear local state (viewer).
  final VoidCallback? onClose;

  @override
  State<CoWatchWidget> createState() => _CoWatchWidgetState();
}

class _CoWatchWidgetState extends State<CoWatchWidget> {
  bool _seeking = false;
  double _seekValue = 0;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.controller,
      child: Consumer<CoWatchController>(
        builder: (_, c, __) {
          if (!c.isActive) return const SizedBox.shrink();
          if (c.isMinimized) return _minimizedBar(c);
          return _maximizedPanel(c);
        },
      ),
    );
  }

  // ---- Maximised panel ----

  Widget _maximizedPanel(CoWatchController c) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(c),
          _videoArea(c),
          _controls(c),
        ],
      ),
    );
  }

  Widget _header(CoWatchController c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          const Icon(Icons.live_tv, color: AppTheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              c.title.isEmpty ? 'Co-Watch' : c.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.minimize, color: Colors.white70),
            tooltip: 'Minimize',
            onPressed: c.minimize,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: 'Close',
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _videoArea(CoWatchController c) {
    final ctrl = c.videoController;
    if (c.hasError) {
      return _placeholder(
        icon: Icons.error_outline,
        label: 'Video unavailable',
      );
    }
    if (ctrl == null || !c.isReady) {
      return _placeholder(
        icon: Icons.hourglass_top,
        label: 'Loading...',
        spin: true,
      );
    }
    final size = ctrl.value.size;
    final aspect = size.width > 0 && size.height > 0
        ? size.width / size.height
        : 16 / 9;
    return AspectRatio(
      aspectRatio: aspect,
      child: VideoPlayer(ctrl),
    );
  }

  Widget _placeholder({
    required IconData icon,
    required String label,
    bool spin = false,
  }) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black12,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            spin
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  )
                : Icon(icon, color: Colors.white54, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls(CoWatchController c) {
    final dur = c.durationMs > 0 ? c.durationMs : 0;
    final pos = c.positionMs.clamp(0, dur > 0 ? dur : c.positionMs);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: c.togglePlayPause,
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                c.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _fmt(pos),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                activeTrackColor: AppTheme.primary,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: AppTheme.primary.withValues(alpha: 0.2),
              ),
              child: Slider(
                min: 0,
                max: dur > 0 ? dur.toDouble() : 1.0,
                value: _seeking
                    ? _seekValue
                    : pos.toDouble().clamp(0.0, dur > 0 ? dur.toDouble() : 0.0),
                onChanged: dur > 0
                    ? (v) {
                        setState(() {
                          _seeking = true;
                          _seekValue = v;
                        });
                      }
                    : null,
                onChangeEnd: (v) async {
                  await c.seekTo(v.round());
                  if (mounted) setState(() => _seeking = false);
                },
              ),
            ),
          ),
          Text(
            _fmt(dur),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ---- Minimised floating bar ----

  Widget _minimizedBar(CoWatchController c) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(
              c.isPlaying ? Icons.play_circle : Icons.pause_circle,
              color: AppTheme.primary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                c.title.isEmpty ? 'Co-Watch' : c.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white70),
              tooltip: 'Maximize',
              onPressed: c.maximize,
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: const Icon(Icons.close, color: Colors.white70),
              tooltip: 'Close',
              onPressed: widget.onClose,
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int ms) {
    if (ms <= 0) return '0:00';
    final s = (ms / 1000).round();
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }
}
