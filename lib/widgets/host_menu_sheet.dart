/// Host / viewer menu bottom sheet for audio room.
///
/// Redesigned with glassmorphism blur, glow effects, half-screen height,
/// and a scrollable 3-column grid of action buttons.
library host_menu_sheet;

import 'dart:ui';

import 'package:flutter/material.dart';

import 'ai_feature_guard.dart';

/// Model for a single menu action.
class MenuItem {
  const MenuItem({
    required this.icon,
    required this.label,
    this.gradient,
    this.glowColor,
    this.featureKey,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Gradient? gradient;
  final Color? glowColor;

  /// Optional AI feature key. When set, the card is wrapped with
  /// [AIFeatureGuard] so it is hidden when disabled and shown with a lock
  /// badge when the current user does not pass the access gate.
  final String? featureKey;
  final VoidCallback onTap;
}

/// Shows the redesigned host menu as a half-screen bottom sheet.
void showHostMenuSheet(
  BuildContext context, {
  required String title,
  required List<MenuItem> items,
}) {
  final size = MediaQuery.of(context).size;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    builder: (_) => _HostMenuSheet(
      title: title,
      items: items,
      maxHeight: size.height * 0.55,
    ),
  );
}

class _HostMenuSheet extends StatelessWidget {
  const _HostMenuSheet({
    required this.title,
    required this.items,
    required this.maxHeight,
  });

  final String title;
  final List<MenuItem> items;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: maxHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.82),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.2,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Drag handle
                Container(
                  width: 48,
                  height: 5,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7E3FF2), Color(0xFF4F8DFD)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7E3FF2).withValues(alpha: 0.45),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.grid_view_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${items.length} options',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Scrollable grid
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 20, top: 4),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final item = items[i];
                        final card = _MenuCard(item: item);
                        if (item.featureKey != null) {
                          return AIFeatureGuard(
                            featureKey: item.featureKey!,
                            child: card,
                          );
                        }
                        return card;
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatefulWidget {
  const _MenuCard({required this.item});

  final MenuItem item;

  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const defaultGradient = LinearGradient(
      colors: [Color(0xFF7E3FF2), Color(0xFF4F8DFD)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final gradient = widget.item.gradient ?? defaultGradient;
    final glowColor = widget.item.glowColor ?? const Color(0xFF7E3FF2);

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.item.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.55),
                    blurRadius: 16,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                widget.item.icon,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.item.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
