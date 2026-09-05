import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart' as archive;
import 'package:flutter/material.dart';
import 'package:svgaplayer_3/svgaplayer_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../services/gift_sound_service.dart';
import '../utils/log.dart';
import '../utils/media_utils.dart';
import 'preloader.dart';

/// Minimum bytes we consider a potentially valid file.
const _kMinSvgaBytes = 8;

/// Strips HTTP-level gzip/deflate compression if the CDN applied it on top
/// of the already zlib-compressed SVGA protobuf payload.
///
/// SVGA v2 files are **zlib-compressed protobuf**, NOT ZIP archives.
/// `SVGAParser.decodeFromBuffer()` itself calls `archive.ZLibDecoder().decodeBytes()`
/// internally, so we must pass the raw zlib-compressed bytes to it.
///
/// We only need to strip HTTP-level Content-Encoding (gzip/deflate) if the
/// transport layer compressed the response. Since we request
/// `Accept-Encoding: identity`, most servers send raw bytes. But some CDNs
/// ignore that header, so we handle gzip here as a safety net.
Uint8List _stripHttpCompression(Uint8List data) {
  if (data.length < _kMinSvgaBytes) return data;

  // Already a zlib stream (0x78 ...) — this is what the SVGA parser expects.
  // Don't touch it!
  if (data[0] == 0x78) return data;

  // gzip (0x1F 0x8B) — HTTP-level compression. Strip it to get the
  // underlying zlib-compressed SVGA bytes.
  if (data[0] == 0x1F && data[1] == 0x8B) {
    try {
      final out = const archive.GZipDecoder().decodeBytes(data);
      Log.d('SvgaCacheManager',
          'Stripped HTTP gzip: ${data.length} -> ${out.length}');
      return Uint8List.fromList(out);
    } catch (e) {
      Log.e('SvgaCacheManager', 'Failed to strip HTTP gzip: $e');
    }
  }

  return data;
}

/// Global SVGA cache with Disk & Memory persistence.
///
/// IMPORTANT: We cache the raw **bytes** (Uint8List), NOT the decoded
/// `MovieEntity`. The `svgaplayer_flutter` `MovieEntity`/videoItem is NOT
/// safe to share across multiple `SVGAAnimationController` instances — when
/// one controller is disposed it releases the videoItem's rendering
/// resources, which kills any other controller still holding the same
/// instance. Caching a single decoded `MovieEntity` caused the bug where a
/// frame/asset showed once, then never again until the app was restarted
/// (restart cleared the in-memory cache → fresh decode → worked once more).
///
/// By caching bytes and decoding a fresh `MovieEntity` per `load()` call,
/// every `SvgaPlayer` gets its own independent videoItem that can be
/// disposed safely without affecting siblings or future widgets.
///
/// SVGA v2 format: The file is a **zlib-compressed protobuf** `MovieEntity`.
/// `SVGAParser.decodeFromBuffer()` handles the zlib decompression internally,
/// so we pass the raw downloaded bytes directly to it.
class SvgaCacheManager {
  /// Small LRU of raw SVGA bytes. Keeping every animation forever caused
  /// large rooms to retain hundreds of megabytes after gifts/entries ended.
  static final LinkedHashMap<String, Uint8List> _bytesCache = LinkedHashMap();
  static final Map<String, Future<Uint8List?>> _inFlight = HashMap();
  static const int _maxMemoryEntries = 6;
  static const int _maxFileBytes = 40 * 1024 * 1024;
  static Directory? _cacheDir;

  static Future<void> init() async {
    if (_cacheDir != null) return;
    try {
      final temp = await getTemporaryDirectory();
      final dir = Directory('${temp.path}/svga_cache');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cacheDir = dir;
    } catch (e) {
      Log.e('SvgaCacheManager', 'Failed to init disk cache', e);
    }
  }

  /// Loads a fresh, independently-owned `MovieEntity` for the given URL.
  /// Bytes are cached (memory + disk); decoding runs per call so each
  /// returned videoItem has its own lifecycle.
  static Future<MovieEntity?> load(String rawUrl) async {
    // Resolve relative URLs (e.g. /uploads/svga/xxx.svga) to absolute URLs
    // so Dio can actually fetch them. Many callers (store, gift picker) pass
    // raw backend paths without calling VideoUtil.getFullSvgaUrl first.
    final url = VideoUtil.getFullSvgaUrl(rawUrl.trim());
    if (url.isEmpty) return null;

    for (var attempt = 0; attempt < 2; attempt++) {
      final bytes = await _getBytes(url, forceNetwork: attempt > 0);
      if (bytes == null || bytes.isEmpty) return null;

      try {
        // SVGAParser.decodeFromBuffer() handles zlib decompression internally
        // and then parses the protobuf MovieEntity. We pass the raw bytes
        // (which should be zlib-compressed protobuf starting with 0x78).
        final video = await SVGAParser.shared
            .decodeFromBuffer(bytes)
            .timeout(const Duration(seconds: 12));
        if (video.params.frames <= 0) {
          Log.e('SvgaCacheManager',
              'Decoded SVGA is empty (no frames) (attempt ${attempt + 1}): $url');
          await _invalidate(url);
          continue;
        }
        return video;
      } catch (e) {
        Log.e('SvgaCacheManager',
            'Failed to decode SVGA (attempt ${attempt + 1}): $url '
            '— first bytes: ${bytes.length >= 4 ? bytes.sublist(0, 4) : bytes}, '
            'len=${bytes.length}',
            e);
        await _invalidate(url);
      }
    }
    return null;
  }

  /// Returns cached bytes while coalescing concurrent downloads for one URL.
  static Future<Uint8List?> _getBytes(String url, {bool forceNetwork = false}) {
    if (forceNetwork) {
      _bytesCache.remove(url);
      _inFlight.remove(url);
    } else {
      final cached = _bytesCache.remove(url);
      if (cached != null) {
        _bytesCache[url] = cached;
        return Future.value(cached);
      }
      final pending = _inFlight[url];
      if (pending != null) return pending;
    }

    final future = _loadBytesFromDiskOrNet(url, forceNetwork: forceNetwork);
    _inFlight[url] = future;
    future.then((bytes) {
      _inFlight.remove(url);
      if (bytes == null || bytes.isEmpty) return;
      _bytesCache[url] = bytes;
      while (_bytesCache.length > _maxMemoryEntries) {
        _bytesCache.remove(_bytesCache.keys.first);
      }
    });
    return future;
  }

  static Future<Uint8List?> _loadBytesFromDiskOrNet(String url, {bool forceNetwork = false}) async {
    File? file;
    try {
      await init();
      final filename = '${url.hashCode}_${url.length}.svga';
      file = _cacheDir != null ? File('${_cacheDir!.path}/$filename') : null;

      if (!forceNetwork && file != null && await file.exists()) {
        final length = await file.length();
        if (length > 0 && length <= _maxFileBytes) {
          final raw = await file.readAsBytes();
          if (raw.length >= _kMinSvgaBytes) {
            // Disk cache stores the raw zlib-compressed SVGA bytes.
            // If a previous version stored something else, delete & re-download.
            if (raw[0] == 0x78 || (raw[0] == 0x1F && raw[1] == 0x8B)) {
              // Strip any HTTP-level compression that may have been cached.
              final cleaned = _stripHttpCompression(raw);
              if (cleaned != raw) {
                try {
                  await file.writeAsBytes(cleaned, flush: true);
                } catch (_) {}
              }
              return cleaned;
            }
            // Old format (ZIP or something else) — delete and re-download.
            await file.delete();
          } else {
            await file.delete();
          }
        } else {
          await file.delete();
        }
      }

      final response = await Dio().get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 15),
          // Ask server NOT to apply transport-level compression — we want
          // the raw SVGA file (which is already zlib-compressed internally).
          headers: {'Accept-Encoding': 'identity'},
          validateStatus: (status) => status != null && status >= 200 && status < 300,
        ),
      );

      final contentEncoding = response.headers.value('content-encoding');
      final contentType = response.headers.value('content-type');
      final data = response.data;
      Log.d('SvgaCacheManager',
          'HTTP $url — Content-Encoding: $contentEncoding, '
          'Content-Type: $contentType, body: ${data?.length ?? 0} bytes');

      if (data == null ||
          data.isEmpty ||
          data.length > _maxFileBytes ||
          data.length < _kMinSvgaBytes) {
        Log.e('SvgaCacheManager',
            'Invalid SVGA response length for $url: ${data?.length ?? 0}');
        return null;
      }

      // Strip HTTP-level compression if the CDN applied it despite our
      // Accept-Encoding: identity header. The result should be the raw
      // zlib-compressed SVGA protobuf (starting with 0x78).
      var bytes = Uint8List.fromList(data);
      bytes = _stripHttpCompression(bytes);

      Log.d('SvgaCacheManager',
          'SVGA bytes ready for parser — first: '
          '${bytes.length >= 4 ? bytes.sublist(0, 4) : bytes}, len=${bytes.length}');

      if (file != null) {
        try {
          await file.writeAsBytes(bytes, flush: true);
        } catch (e) {
          Log.e('SvgaCacheManager', 'Failed to persist SVGA: $url', e);
        }
      }
      return bytes;
    } on DioException catch (e) {
      Log.e('SvgaCacheManager', 'Dio error loading SVGA: $url', e);
      if (file != null) {
        try {
          if (await file.exists() && await file.length() == 0) await file.delete();
        } catch (_) {}
      }
      return null;
    } catch (e) {
      Log.e('SvgaCacheManager', 'Failed to load SVGA: $url', e);
      if (file != null) {
        try {
          if (await file.exists() && await file.length() == 0) await file.delete();
        } catch (_) {}
      }
      return null;
    }
  }

  static Future<void> _invalidate(String url) async {
    _bytesCache.remove(url);
    _inFlight.remove(url);
    if (_cacheDir == null) return;
    final file = File('${_cacheDir!.path}/${url.hashCode}_${url.length}.svga');
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static void preload(List<String> urls) {
    for (final url in urls.take(_maxMemoryEntries)) {
      _getBytes(url.trim());
    }
  }
}

/// Reusable SVGA animation widget with Disk Caching and optimized playback.
class SvgaPlayer extends StatefulWidget {
  const SvgaPlayer({
    super.key,
    this.url,
    this.fallbackImage,
    this.width = 200,
    this.height = 200,
    this.allowAnimation = true,
    this.repeat = false,
    this.fit = BoxFit.contain,
    this.playEmbeddedAudio = false,
    this.onLoaded,
  });

  final String? url;
  final String? fallbackImage;
  final double width;
  final double height;
  final bool allowAnimation;
  /// Loop only persistent decorative assets. Entry and gift animations should
  /// play once so their GPU resources can be released with the overlay.
  final bool repeat;
  final BoxFit fit;
  /// When true, embedded audio inside the SVGA file is played on load.
  /// Disabled by default so profile frames/badges never trigger gift sounds.
  /// The `svgaplayer_flutter` package parses but never plays the audio; we do
  /// it here via [GiftSoundService].
  final bool playEmbeddedAudio;
  /// Called when the SVGA file is loaded with the total animation duration
  /// in milliseconds. Used by entry overlays to time the entrance.
  final ValueChanged<int>? onLoaded;

  @override
  State<SvgaPlayer> createState() => _SvgaPlayerState();
}

class _SvgaPlayerState extends State<SvgaPlayer>
    with SingleTickerProviderStateMixin {
  SVGAAnimationController? _controller;
  String? _loadedUrl;
  bool _hasError = false;
  bool _isLoading = true;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadSvga();
  }

  @override
  void didUpdateWidget(SvgaPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.allowAnimation != widget.allowAnimation ||
        oldWidget.repeat != widget.repeat ||
        oldWidget.playEmbeddedAudio != widget.playEmbeddedAudio) {
      _loadSvga();
    }
  }

  Future<void> _loadSvga() async {
    final generation = ++_loadGeneration;
    final url = widget.url?.trim();
    if (url == null || url.isEmpty) {
      _controller?.stop();
      _loadedUrl = null;
      if (mounted) {
        setState(() {
          _hasError = false;
          _isLoading = false;
        });
      }
      return;
    }

    // If the same URL is already loaded, just restart the animation. This
    // keeps the experience smooth when the same gift is sent repeatedly.
    if (_loadedUrl == url && _controller?.videoItem != null) {
      _updateAnimationState();
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _controller?.stop();
    if (mounted) {
      setState(() {
        _hasError = false;
        _isLoading = true;
      });
    }

    MovieEntity? video;
    try {
      video = await SvgaCacheManager.load(url).timeout(
        const Duration(seconds: 20),
      );
    } on TimeoutException catch (e) {
      Log.e('SvgaPlayer', 'SVGA load timed out: $url', e);
    } catch (e) {
      Log.e('SvgaPlayer', 'SVGA load failed: $url', e);
    }
    if (!mounted || generation != _loadGeneration || widget.url?.trim() != url) return;

    if (video == null) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
      return;
    }

    final oldController = _controller;
    final controller = SVGAAnimationController(vsync: this);
    controller.videoItem = video;
    _controller = controller;
    _loadedUrl = url;
    oldController?.dispose();
    // Listen for animation completion — stop embedded audio so it doesn't
    // keep playing after the SVGA animation finishes (non-repeat mode).
    if (widget.playEmbeddedAudio && !widget.repeat) {
      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          GiftSoundService.instance.stopSvgaAudio();
        }
      });
    }
    _updateAnimationState();

    if (widget.playEmbeddedAudio) {
      _playEmbeddedAudio(video);
    }

    if (widget.onLoaded != null) {
      try {
        final params = video.params;
        final frames = params.frames;
        final fps = params.fps;
        widget.onLoaded!(fps > 0 ? ((frames / fps) * 1000).round() : 3000);
      } catch (_) {
        widget.onLoaded!(3000);
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Extract & play audio tracks embedded in the SVGA file.
  ///
  /// SVGA stores audio payloads in the `images` map (keyed by `audioKey`),
  /// referenced by `audios` entries. The `svgaplayer_flutter` parser exposes
  /// both but never plays them — we hand the raw bytes to [GiftSoundService].
  void _playEmbeddedAudio(MovieEntity video) {
    try {
      final audios = video.audios;
      final images = video.images;
      bool hasAudio = false;
      if (audios.isNotEmpty && images.isNotEmpty) {
        for (final a in audios) {
          final key = a.audioKey;
          if (key.isEmpty) continue;
          final raw = images[key];
          if (raw == null || raw.isEmpty) continue;
          GiftSoundService.instance
              .playSvgaAudio(Uint8List.fromList(raw));
          hasAudio = true;
        }
      }
      if (!hasAudio) {
        GiftSoundService.instance.playDefault();
      }
    } catch (e) {
      Log.e('SvgaPlayer', 'embedded audio extract failed', e);
      GiftSoundService.instance.playDefault();
    }
  }

  void _updateAnimationState() {
    final controller = _controller;
    if (controller == null) return;
    controller.stop();
    if (!widget.allowAnimation) {
      controller.value = 0.0;
    } else if (widget.repeat) {
      controller.repeat();
    } else {
      // Ensure we always restart from the first frame, even if the controller
      // was previously used for the same animation.
      controller.value = 0.0;
      controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _controller?.stop();
    _controller?.dispose();
    _controller = null;
    // Stop embedded audio when this player is disposed so the sound
    // doesn't keep playing after the overlay/widget is removed.
    if (widget.playEmbeddedAudio) {
      GiftSoundService.instance.stopSvgaAudio();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _placeholder();
    }

    if (_controller == null || _controller!.videoItem == null) {
      return _placeholder();
    }

    // Handle double.infinity / unbounded dimensions — SVGAImage needs a
    // bounded box. When the caller passes infinity (e.g. full-screen big
    // gift overlay), use SizedBox.expand so the animation fills the parent.
    if (widget.width == double.infinity || widget.height == double.infinity) {
      return SizedBox.expand(
        child: SVGAImage(
          _controller!,
          fit: widget.fit,
          filterQuality: FilterQuality.high,
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: SVGAImage(
        _controller!,
        fit: widget.fit,
        filterQuality: FilterQuality.high,
      ),
    );
  }

  Widget _placeholder() {
    // Never pass SVGA URLs to CachedNetworkImage — Android's ImageDecoder
    // cannot decode SVGA files and will crash the app.
    final fallback = widget.fallbackImage;
    final canUseFallback = fallback != null &&
        fallback.isNotEmpty &&
        !fallback.toLowerCase().contains('.svga') &&
        !fallback.toLowerCase().contains('/svga');

    // Show fallback ONLY on error, NOT during loading. During loading,
    // show a transparent placeholder so the user doesn't see a static
    // thumbnail before the SVGA plays. On error, the fallback image is
    // shown so the user sees SOMETHING instead of a broken image icon.
    if (canUseFallback && _hasError) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: CachedNetworkImage(
          imageUrl: fallback,
          fit: widget.fit,
          placeholder: (_, __) => _loadingBox(),
          errorWidget: (_, __, ___) => _errorBox(),
        ),
      );
    }

    // During loading: transparent placeholder (no static thumbnail).
    // On error without fallback: broken image icon.
    return _hasError ? _errorBox() : _loadingBox();
  }

  Widget _errorBox() {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white24,
          size: 22,
        ),
      ),
    );
  }

  Widget _loadingBox() {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: Preloader(strokeWidth: 2, color: Colors.white54),
        ),
      ),
    );
  }
}
