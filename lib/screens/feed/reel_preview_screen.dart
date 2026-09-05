import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:belive/widgets/preloader.dart';

class ReelPreviewScreen extends StatefulWidget {
  const ReelPreviewScreen({
    super.key,
    required this.videoPath,
    this.caption = '',
  });

  final String videoPath;
  final String caption;

  @override
  State<ReelPreviewScreen> createState() => _ReelPreviewScreenState();
}

class _ReelPreviewScreenState extends State<ReelPreviewScreen> {
  VideoPlayerController? _controller;
  bool _initializing = true;
  final _captionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _captionCtrl.text = widget.caption;
    _initVideo();
  }

  Future<void> _initVideo() async {
    _controller = VideoPlayerController.file(File(widget.videoPath));
    await _controller!.initialize();
    _controller!.setLooping(true);
    _controller!.play();
    if (mounted) setState(() => _initializing = false);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Preview', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed:
                () => Navigator.pop(context, {'caption': _captionCtrl.text}),
            child: const Text(
              'Next',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body:
          _initializing
              ? const Center(child: Preloader(color: Colors.white))
              : GestureDetector(
                onTap: () {
                  setState(() {
                    _controller!.value.isPlaying
                        ? _controller!.pause()
                        : _controller!.play();
                  });
                },
                child: Stack(
                  alignment: Alignment.topLeft,
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                    if (!_controller!.value.isPlaying)
                      const Center(
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white54,
                          size: 80,
                        ),
                      ),
                    Positioned(
                      bottom: 100,
                      left: 16,
                      right: 80,
                      child: TextField(
                        controller: _captionCtrl,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Write a caption...',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.black54,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
