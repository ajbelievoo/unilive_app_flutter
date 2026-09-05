import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class CheerAnimationOverlay extends StatefulWidget {
  const CheerAnimationOverlay({super.key});
  @override
  State<CheerAnimationOverlay> createState() => CheerAnimationOverlayState();
}

class CheerAnimationOverlayState extends State<CheerAnimationOverlay>
    with TickerProviderStateMixin {
  final List<_CheerItem> _items = [];

  @override
  void dispose() {
    for (final item in _items) {
      item.controller.dispose();
    }
    super.dispose();
  }

  /// Add a cheer that rises from the bottom-right corner (where the cheer
  /// button is, matching native: Gravity.END | Gravity.BOTTOM).
  void addCheer({required String name, String? imageUrl}) {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    final item = _CheerItem(
      name: name,
      imageUrl: imageUrl,
      animation: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      ),
      controller: controller,
    );
    _items.add(item);
    if (mounted) setState(() {});
    controller.forward(from: 0).whenComplete(() {
      if (mounted) {
        setState(() {
          _items.remove(item);
          item.controller.dispose();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        alignment: Alignment.topLeft,
        children: _items.map((item) {
          final screenW = MediaQuery.of(context).size.width;
          final screenH = MediaQuery.of(context).size.height;
          // All cheers start from bottom-right corner (where the cheer button is,
          // matching native: Gravity.END | Gravity.BOTTOM, 16dp right, 120dp bottom)
          final startX = screenW - 60; // right edge, offset for item width
          return AnimatedBuilder(
            animation: item.animation,
            builder: (_, child) {
              final v = item.animation.value;
              // Small horizontal drift based on item index so multiple cheers
              // don't perfectly overlap, but they all originate from the same spot
              final drift = (item.id % 3 - 1) * 20.0 * v;
              return Positioned(
                left: startX + drift,
                bottom: 120 + v * (screenH * 0.5),
                child: Opacity(
                  opacity: 1 - v,
                  child: Transform.scale(
                    scale: 0.5 + v * 0.8,
                    child: child,
                  ),
                ),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                  ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite, color: Colors.red, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        item.name,
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CheerItem {
  _CheerItem({required this.name, this.imageUrl, required this.animation, required this.controller});
  static int _nextId = 0;
  final int id = _nextId++;
  final String name;
  final String? imageUrl;
  final Animation<double> animation;
  final AnimationController controller;
}
