/// Full-screen image preview with pinch-to-zoom.
///
/// Ports native `ImagePreviewActivity.java`.
library image_preview;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'package:belive/widgets/preloader.dart';

class ImagePreviewScreen extends StatefulWidget {
  const ImagePreviewScreen({super.key, required this.url});

  final String url;

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  final _controller = TransformationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: SafeArea(
          child: Stack(
            alignment: Alignment.topLeft,
            children: [
              Center(
                child: InteractiveViewer(
                  transformationController: _controller,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: widget.url,
                    fit: BoxFit.contain,
                    placeholder:
                        (_, __) => const Preloader(color: AppTheme.primary),
                    errorWidget:
                        (_, __, ___) => const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              color: Colors.white54,
                              size: 48,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Failed to load',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
