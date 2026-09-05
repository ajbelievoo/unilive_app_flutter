/// AR Face Sticker picker sheet — Bigo-style sticker selection panel.
///
/// Shows a horizontal scrollable grid of AR stickers. Tapping a sticker
/// activates it (overlays on host video). Gated by `ai_ar_face_stickers`.
library ar_face_sticker_sheet;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_feature_model.dart';
import '../providers/ai_feature_manager.dart';
import '../services/ar_face_sticker_service.dart';

/// Shows the AR face sticker picker bottom sheet.
void showArFaceStickerSheet(BuildContext context) {
  final ai = context.read<AIFeatureManager>().isFeatureEnabled(AIFeatureKeys.arFaceStickers);
  if (!ai) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AR Face Stickers are not available.')),
    );
    return;
  }
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ArStickerSheet(),
  );
}

class _ArStickerSheet extends StatefulWidget {
  const _ArStickerSheet();

  @override
  State<_ArStickerSheet> createState() => _ArStickerSheetState();
}

class _ArStickerSheetState extends State<_ArStickerSheet> {
  @override
  Widget build(BuildContext context) {
    final service = ARFaceStickerService.instance;
    final stickers = service.stickers;
    final activeId = service.activeSticker?.id;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.face_retouching_natural, color: Colors.purpleAccent, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'AR Stickers',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (activeId != null)
                  GestureDetector(
                    onTap: () {
                      service.selectSticker(null);
                      setState(() {});
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Remove', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white54, size: 20),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Sticker grid
          Flexible(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.8,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: stickers.length,
              itemBuilder: (ctx, i) {
                final s = stickers[i];
                final isActive = s.id == activeId;
                return GestureDetector(
                  onTap: () {
                    service.selectSticker(isActive ? null : s);
                    setState(() {});
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isActive ? Colors.purple.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: isActive
                          ? Border.all(color: Colors.purpleAccent, width: 2)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _stickerPreview(s),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.name,
                          style: TextStyle(
                            color: isActive ? Colors.purpleAccent : Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (s.isVipExclusive)
                          const Icon(Icons.star, color: Colors.amber, size: 10),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _stickerPreview(ARSticker s) {
    // Try asset first; if not bundled, it'll show a placeholder.
    final iconPath = s.iconUrl;
    if (iconPath.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: iconPath,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _placeholder(s),
      );
    }
    return Image.asset(
      iconPath,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _placeholder(s),
    );
  }

  Widget _placeholder(ARSticker s) {
    return Container(
      color: Colors.purple.withValues(alpha: 0.2),
      child: const Center(
        child: Icon(Icons.face, color: Colors.purpleAccent, size: 32),
      ),
    );
  }
}
