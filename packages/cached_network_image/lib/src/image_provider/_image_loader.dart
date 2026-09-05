import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';
import 'package:cached_network_image_platform_interface'
        '/cached_network_image_platform_interface.dart' as platform
    show ImageLoader;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image/image.dart' as img;

/// ImageLoader class to load images on IO platforms.
class ImageLoader implements platform.ImageLoader {
  @Deprecated('Use loadImageAsync instead')
  @override
  Stream<ui.Codec> loadBufferAsync(
    String url,
    String? cacheKey,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderBufferCallback decode,
    BaseCacheManager cacheManager,
    int? maxHeight,
    int? maxWidth,
    Map<String, String>? headers,
    ImageRenderMethodForWeb imageRenderMethodForWeb,
    VoidCallback evictImage,
  ) {
    return _load(
      url,
      cacheKey,
      chunkEvents,
      (bytes) async {
        final buffer = await ImmutableBuffer.fromUint8List(bytes);
        return decode(buffer);
      },
      cacheManager,
      maxHeight,
      maxWidth,
      headers,
      imageRenderMethodForWeb,
      evictImage,
    );
  }

  @override
  Stream<ui.Codec> loadImageAsync(
    String url,
    String? cacheKey,
    StreamController<ImageChunkEvent> chunkEvents,
    ImageDecoderCallback decode,
    BaseCacheManager cacheManager,
    int? maxHeight,
    int? maxWidth,
    Map<String, String>? headers,
    ImageRenderMethodForWeb imageRenderMethodForWeb,
    VoidCallback evictImage,
  ) {
    return _load(
      url,
      cacheKey,
      chunkEvents,
      (bytes) async {
        final buffer = await ImmutableBuffer.fromUint8List(bytes);
        return decode(buffer);
      },
      cacheManager,
      maxHeight,
      maxWidth,
      headers,
      imageRenderMethodForWeb,
      evictImage,
    );
  }

  Stream<ui.Codec> _load(
    String url,
    String? cacheKey,
    StreamController<ImageChunkEvent> chunkEvents,
    Future<ui.Codec> Function(Uint8List) decode,
    BaseCacheManager cacheManager,
    int? maxHeight,
    int? maxWidth,
    Map<String, String>? headers,
    ImageRenderMethodForWeb imageRenderMethodForWeb,
    VoidCallback evictImage,
  ) async* {
    try {
      assert(
          cacheManager is ImageCacheManager ||
              (maxWidth == null && maxHeight == null),
          'To resize the image with a CacheManager the '
          'CacheManager needs to be an ImageCacheManager. maxWidth and '
          'maxHeight will be ignored when a normal CacheManager is used.');

      final stream = cacheManager is ImageCacheManager
          ? cacheManager.getImageFile(
              url,
              maxHeight: maxHeight,
              maxWidth: maxWidth,
              withProgress: true,
              headers: headers,
              key: cacheKey,
            )
          : cacheManager.getFileStream(
              url,
              withProgress: true,
              headers: headers,
              key: cacheKey,
            );

      await for (final result in stream) {
        if (result is DownloadProgress) {
          chunkEvents.add(
            ImageChunkEvent(
              cumulativeBytesLoaded: result.downloaded,
              expectedTotalBytes: result.totalSize,
            ),
          );
        }
        if (result is FileInfo) {
          final file = result.file;
          final bytes = await file.readAsBytes();
          final decoded = await _safeDecode(bytes, decode);
          yield decoded;
        }
      }
    } on Object catch (error, stackTrace) {
      // Depending on where the exception was thrown, the image cache may not
      // have had a chance to track the key in the cache at all.
      // Schedule a microtask to give the cache a chance to add the key.
      scheduleMicrotask(() {
        evictImage();
      });
      yield* Stream.error(error, stackTrace);
    } finally {
      await chunkEvents.close();
    }
  }

  /// Decode image bytes with a fallback for formats the native ImageDecoder
  /// cannot handle (e.g. GIF, WEBP on some Vivo devices).
  ///
  /// First tries the native [decode] callback. If that throws, re-encodes the
  /// bytes as PNG using the pure-Dart `image` package and decodes the PNG
  /// (which the native decoder always supports). If both fail (e.g. the bytes
  /// are not an image at all — SVGA, video, HTML error page), returns a 1x1
  /// transparent pixel so the app never crashes.
  Future<ui.Codec> _safeDecode(
    Uint8List bytes,
    Future<ui.Codec> Function(Uint8List) decode,
  ) async {
    try {
      return await decode(bytes);
    } catch (_) {
      // Native decoder failed — fall back to the image package.
      try {
        final png = await compute(_decodeToPng, bytes);
        if (png != null) {
          return await decode(png);
        }
      } catch (_) {
        // image package also failed — fall through to blank pixel.
      }
      // Last resort: return a 1x1 transparent PNG so the image provider
      // doesn't crash the app. The errorWidget will show instead.
      return decode(_blankPng);
    }
  }
}

/// 1x1 transparent PNG used as a last-resort fallback when neither the native
/// decoder nor the `image` package can decode the bytes.
final Uint8List _blankPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
  0x00, 0x00, 0x00, 0x0D, // IHDR length
  0x49, 0x48, 0x44, 0x52, // "IHDR"
  0x00, 0x00, 0x00, 0x01, // width = 1
  0x00, 0x00, 0x00, 0x01, // height = 1
  0x08, 0x06, 0x00, 0x00, 0x00, // bit depth 8, color type 6 (RGBA)
  0x1F, 0x15, 0xC4, 0x89, // CRC
  0x00, 0x00, 0x00, 0x0A, // IDAT length
  0x49, 0x44, 0x41, 0x54, // "IDAT"
  0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, // compressed data
  0x0D, 0x0A, 0x20, 0xD4, // CRC
  0x00, 0x00, 0x00, 0x00, // IEND length
  0x49, 0x45, 0x4E, 0x44, // "IEND"
  0xAE, 0x42, 0x60, 0x82, // CRC
]);

/// Top-level function used by [compute] to decode image bytes in a separate
/// isolate using the pure-Dart `image` package, then re-encode as PNG.
Uint8List? _decodeToPng(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return Uint8List.fromList(img.encodePng(decoded, level: 1));
  } catch (_) {
    return null;
  }
}
