/// Video gift thumbnail — generates a static thumbnail from a video URL.
///
/// Uses the `video_thumbnail` package to extract the first frame (ss1) of a
/// remote video and display it as a static image. Thumbnails are cached
/// in-memory and on disk to avoid regenerating them on every rebuild.
///
/// IMPORTANT: This widget is only used as a fallback when the backend does
/// NOT provide a static .png/_thumb.jpg sibling for the video gift.
library video_gift_thumbnail;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:belive/utils/log.dart';

import 'big_gift_overlay.dart';

class VideoGiftThumbnail extends StatefulWidget {
  const VideoGiftThumbnail({
    super.key,
    required this.videoUrl,
    this.width = 80,
    this.height = 80,
    this.forceVideo = false,
  });

  final String videoUrl;
  final double width;
  final double height;
  final bool forceVideo;

  @override
  State<VideoGiftThumbnail> createState() => _VideoGiftThumbnailState();
}

// In-memory cache: videoUrl -> thumbnail file path
final Map<String, String> _thumbnailCache = {};

class _VideoGiftThumbnailState extends State<VideoGiftThumbnail> {
  String? _thumbnailPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final trimmed = widget.videoUrl.trim();
    final isVideo = widget.forceVideo || _isVideoUrl(trimmed);
    if (trimmed.isEmpty || !isVideo) {
      _loading = false;
    } else {
      _loadThumbnail();
    }
  }

  /// Returns true when [url] looks like a video file, ignoring query params.
  static bool _isVideoUrl(String url) {
    final clean = url.split('?').first.toLowerCase();
    return clean.endsWith('.mp4') ||
        clean.endsWith('.mov') ||
        clean.endsWith('.webm') ||
        clean.endsWith('.mkv') ||
        clean.endsWith('.3gp');
  }

  Future<void> _loadThumbnail() async {
    // Check in-memory cache first.
    final cached = _thumbnailCache[widget.videoUrl];
    if (cached != null && File(cached).existsSync()) {
      if (mounted) {
        setState(() {
          _thumbnailPath = cached;
          _loading = false;
        });
      }
      return;
    }

    try {
      final temp = await getTemporaryDirectory();
      final name = '${widget.videoUrl.hashCode}_${widget.videoUrl.length}.jpg';
      final outFile = File('${temp.path}/video_gift_thumb_$name');

      String? path;
      if (await outFile.exists() && await outFile.length() > 0) {
        // Reuse the previously extracted frame.
        path = outFile.path;
      } else {
        // Extract the first frame at 0ms. Use JPEG for smaller file size
        // and lower memory pressure in the gift grid.
        final videoFile = await GiftMediaCache.getVideoFile(widget.videoUrl);
        path = await VideoThumbnail.thumbnailFile(
          video: videoFile?.path ?? widget.videoUrl,
          thumbnailPath: outFile.path,
          imageFormat: ImageFormat.JPEG,
          timeMs: 0,
          maxHeight: 200,
          quality: 60,
        );
      }

      if (path != null && File(path).existsSync()) {
        _thumbnailCache[widget.videoUrl] = path;
        if (mounted) {
          setState(() {
            _thumbnailPath = path;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e, s) {
      Log.e('VideoGiftThumbnail', 'thumbnail extraction failed: ${widget.videoUrl}', e, s);
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(width: widget.width, height: widget.height);
    }

    if (_thumbnailPath != null && File(_thumbnailPath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(_thumbnailPath!),
          width: widget.width,
          height: widget.height,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: ImageIcon(const AssetImage("assets/gift/official_gift.png"), color: Color(0xFFE91E63), size: 24),
      ),
    );
  }
}
