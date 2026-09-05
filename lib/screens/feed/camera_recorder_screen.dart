/// Camera recording screen for reels â€” records video with front/back camera.
///
/// Ports native `RecorderActivity.java`. Provides live camera preview,
/// front/back switch, flash, beauty filter, and video recording with
/// progress bar. Recorded video is passed to CreateReelScreen for upload.
library camera_recorder;

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../models/song_root.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import 'song_picker_screen.dart';
import 'package:belive/widgets/preloader.dart';

const String _tag = 'CameraRecorder';

class CameraRecorderScreen extends StatefulWidget {
  const CameraRecorderScreen({super.key});

  @override
  State<CameraRecorderScreen> createState() => _CameraRecorderScreenState();
}

class _CameraRecorderScreenState extends State<CameraRecorderScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIdx = 0;
  bool _isRecording = false;
  bool _isInitializing = true;
  bool _flashOn = false;
  Timer? _recordTimer;
  int _recordSeconds = 0;
  int _totalRecordedSeconds = 0; // accumulated across segments
  static const int _maxDuration = 60;

  // Multi-segment recording: list of recorded segment file paths.
  final List<String> _segments = [];
  bool _isPaused = false; // recording is paused (between segments)

  // Beauty filter state
  bool _beautyMode = false;

  // Speed control state
  double _currentSpeed = 1.0;
  static const _speeds = [0.3, 0.5, 1.0, 2.0, 3.0];

  // Countdown timer state
  int _countdown = 0;
  Timer? _countdownTimer;
  bool _countdownActive = false;

  // Music selection state
  SongItem? _selectedSong;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordTimer?.cancel();
    _countdownTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        Fluttertoast.showToast(msg: 'No cameras available');
        if (mounted) setState(() => _isInitializing = false);
        return;
      }
      _cameras = cameras;
      // Prefer front camera for reels
      _selectedCameraIdx = cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (_selectedCameraIdx == -1) _selectedCameraIdx = 0;

      await _startController();
    } catch (e, s) {
      Log.e(_tag, 'init camera failed', e, s);
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _startController() async {
    final controller = CameraController(
      _cameras[_selectedCameraIdx],
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;
    await controller.initialize();
    if (mounted) setState(() => _isInitializing = false);
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    setState(() => _isInitializing = true);
    await _controller?.dispose();
    _selectedCameraIdx = (_selectedCameraIdx + 1) % _cameras.length;
    await _startController();
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    try {
      final mode = _flashOn ? FlashMode.off : FlashMode.auto;
      await _controller!.setFlashMode(mode);
      setState(() => _flashOn = !_flashOn);
    } catch (e) {
      Log.e(_tag, 'flash toggle failed', e, null);
    }
  }

  Future<void> _startRecording() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isRecording)
      return;

    // Start countdown if enabled
    if (_countdownActive) {
      setState(() => _countdown = 3);
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() => _countdown--);
        if (_countdown <= 0) {
          t.cancel();
          _beginRecording();
        }
      });
    } else {
      _beginRecording();
    }
  }

  Future<void> _beginRecording() async {
    if (_totalRecordedSeconds >= _maxDuration) {
      Fluttertoast.showToast(msg: 'Max duration reached');
      _finishRecording();
      return;
    }
    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _isPaused = false;
        _recordSeconds = 0;
        _countdown = 0;
        _countdownActive = false;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() => _recordSeconds++);
        if (_totalRecordedSeconds + _recordSeconds >= _maxDuration) {
          _pauseRecording();
        }
      });
    } catch (e, s) {
      Log.e(_tag, 'start recording failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to start recording');
    }
  }

  /// Pause recording — saves the current segment, ready to resume.
  Future<void> _pauseRecording() async {
    if (_controller == null || !_isRecording) return;
    _recordTimer?.cancel();

    try {
      final file = await _controller!.stopVideoRecording();
      _segments.add(file.path);
      _totalRecordedSeconds += _recordSeconds;
      setState(() {
        _isRecording = false;
        _isPaused = true;
      });
      Log.d(
        _tag,
        'Segment saved: ${file.path} (segments: ${_segments.length})',
      );
    } catch (e, s) {
      Log.e(_tag, 'pause recording failed', e, s);
      setState(() => _isRecording = false);
    }
  }

  /// Delete the last recorded segment.
  void _deleteLastSegment() {
    if (_segments.isEmpty) return;
    setState(() {
      _segments.removeLast();
      // Recalculate total recorded time (approximate — we don't know exact segment duration)
      // For simplicity, reduce by the last segment's contribution
      _totalRecordedSeconds = (_totalRecordedSeconds - _recordSeconds).clamp(
        0,
        _maxDuration,
      );
      _recordSeconds = 0;
    });
    Fluttertoast.showToast(msg: 'Last segment deleted');
  }

  /// Finish recording — merge segments and return result.
  Future<void> _finishRecording() async {
    _recordTimer?.cancel();

    // If currently recording, stop and save last segment
    if (_isRecording && _controller != null) {
      try {
        final file = await _controller!.stopVideoRecording();
        _segments.add(file.path);
        _totalRecordedSeconds += _recordSeconds;
      } catch (e, s) {
        Log.e(_tag, 'finish recording stop failed', e, s);
      }
    }

    setState(() {
      _isRecording = false;
      _isPaused = false;
    });

    if (_segments.isEmpty) {
      Fluttertoast.showToast(msg: 'No video recorded');
      return;
    }

    if (mounted) {
      // If only 1 segment, return single path.
      // If multiple segments, return list of paths for concatenation.
      Navigator.pop(context, {
        'path': _segments.first,
        'segments': _segments.length > 1 ? _segments : null,
        'song': _selectedSong,
        'speed': _currentSpeed,
      });
    }
  }

  Future<void> _pickFromGallery() async {
    Navigator.pop(context, {'path': '__gallery__'});
  }

  Future<void> _pickMusic() async {
    if (_isRecording) return;
    try {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (_) => const SongPickerScreen()),
      );
      if (result != null) {
        setState(
          () =>
              _selectedSong = SongItem(
                id: result['id']?.toString(),
                title: result['title']?.toString(),
                singer: result['artist']?.toString(),
                song: result['url']?.toString(),
                image: result['image']?.toString(),
              ),
        );
        Fluttertoast.showToast(
          msg:
              'Song: ${_selectedSong!.title ?? _selectedSong!.singer ?? "Selected"}',
        );
      }
    } catch (e) {
      Log.e(_tag, 'pick music failed', e, null);
      Fluttertoast.showToast(msg: 'Failed to load songs');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body:
          _isInitializing
              ? const Center(child: Preloader(color: AppTheme.primary))
              : Stack(
                alignment: Alignment.topLeft,
                fit: StackFit.expand,
                children: [
                  // Camera preview
                  if (_controller != null && _controller!.value.isInitialized)
                    CameraPreview(_controller!),
                  // Gradient overlay for controls
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                        ],
                        stops: const [0, 0.15, 0.7, 1],
                      ),
                    ),
                  ),
                  // Top bar
                  _buildTopBar(),
                  // Right side controls
                  _buildSideControls(),
                  // Speed selector
                  if (!_isRecording && _countdown == 0) _buildSpeedSelector(),
                  // Countdown overlay
                  if (_countdown > 0) _buildCountdownOverlay(),
                  // Bottom controls
                  _buildBottomControls(),
                ],
              ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              if (_isRecording)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.fiber_manual_record,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(_recordSeconds),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSideControls() {
    return Positioned(
      right: 16,
      bottom: 120,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sideButton(
            _flashOn ? Icons.flash_on : Icons.flash_off,
            'Flash',
            _toggleFlash,
          ),
          const SizedBox(height: 16),
          _sideButton(Icons.cameraswitch_outlined, 'Flip', _switchCamera),
          const SizedBox(height: 16),
          _sideButton(
            _beautyMode ? Icons.face : Icons.face_outlined,
            'Beauty',
            () => setState(() => _beautyMode = !_beautyMode),
          ),
          const SizedBox(height: 16),
          _sideButton(
            Icons.timer,
            'Timer',
            () => setState(() => _countdownActive = !_countdownActive),
          ),
        ],
      ),
    );
  }

  Widget _sideButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(
            children: [
              // Progress bar — shows total recorded time (segments + current)
              if (_isRecording || _isPaused)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    children: [
                      // Segment indicators
                      if (_segments.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ...List.generate(
                                _segments.length,
                                (i) => Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Seg ${i + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                              if (_isRecording)
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'REC',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      LinearProgressIndicator(
                        value:
                            (_totalRecordedSeconds + _recordSeconds) /
                            _maxDuration,
                        backgroundColor: Colors.white24,
                        color: Colors.red,
                        minHeight: 3,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      if (_isPaused) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: _deleteLastSegment,
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 16,
                              ),
                              label: const Text(
                                'Delete Last',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '$_totalRecordedSeconds/${_maxDuration}s recorded',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              // Record / gallery buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Gallery
                  GestureDetector(
                    onTap: _pickFromGallery,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: const Icon(
                        Icons.photo_library,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Record button — toggle record/pause/resume
                  GestureDetector(
                    onTap: () {
                      if (_isRecording) {
                        // Pause: save segment
                        _pauseRecording();
                      } else if (_isPaused && _segments.isNotEmpty) {
                        // Resume: start new segment
                        if (_totalRecordedSeconds < _maxDuration) {
                          _beginRecording();
                        } else {
                          _finishRecording();
                        }
                      } else {
                        // Start fresh recording
                        _startRecording();
                      }
                    },
                    onLongPress: _isRecording ? null : _startRecording,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: _isRecording ? 30 : 60,
                          height: _isRecording ? 30 : 60,
                          decoration: BoxDecoration(
                            color:
                                _isRecording
                                    ? Colors.red
                                    : (_isPaused
                                        ? Colors.green
                                        : AppTheme.primary),
                            borderRadius: BorderRadius.circular(
                              _isRecording ? 6 : 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Music picker
                  GestureDetector(
                    onTap: _pickMusic,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: const Icon(Icons.music_note, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isPaused && _segments.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: _finishRecording,
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text(
                    'Done',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                )
              else
                Text(
                  _isRecording
                      ? 'Tap to pause'
                      : 'Tap to record (max ${_maxDuration}s)',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              if (_selectedSong != null && !_isRecording)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '♪ ${_selectedSong!.title ?? _selectedSong!.singer ?? 'Song'}',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 11,
                    ),
                  ),
                ),
              if (_countdownActive && !_isRecording && _countdown == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Timer: 3s',
                    style: TextStyle(
                      color: Colors.orange.shade300,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedSelector() {
    return Positioned(
      bottom: 160,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children:
                _speeds.map((speed) {
                  final isSelected = _currentSpeed == speed;
                  return GestureDetector(
                    onTap: () => setState(() => _currentSpeed = speed),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? AppTheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${speed}x',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1.0),
            duration: const Duration(milliseconds: 800),
            builder:
                (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
            child: Text(
              '$_countdown',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 80,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
