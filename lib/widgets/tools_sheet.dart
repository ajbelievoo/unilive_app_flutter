/// Tools bottom sheet for live room.
///
/// Shows: Store, Effect, My Items.
library tools_sheet;

import 'package:flutter/material.dart';

void showToolsSheet(
  BuildContext context, {
    required VoidCallback onStore,
    required VoidCallback onEffect,
    required VoidCallback onMyItems,
  }) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ToolsSheet(
      onStore: onStore,
      onEffect: onEffect,
      onMyItems: onMyItems,
    ),
  );
}

class _ToolsSheet extends StatelessWidget {
  const _ToolsSheet({
    required this.onStore,
    required this.onEffect,
    required this.onMyItems,
  });

  final VoidCallback onStore;
  final VoidCallback onEffect;
  final VoidCallback onMyItems;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text(
              'Tools',
              style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _toolTile(context, 'Store', Icons.store, onStore, const Color(0xFFFFAB91)),
                  _toolTile(context, 'Effect', Icons.auto_fix_high, onEffect, const Color(0xFF80CBC4)),
                  _toolTile(context, 'My Items', Icons.checkroom, onMyItems, const Color(0xFF90CAF9)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _toolTile(BuildContext context, String title, IconData icon, VoidCallback onTap, Color bgColor) {
    return GestureDetector(
      onTap: () { Navigator.pop(context); onTap(); },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: bgColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(icon, color: bgColor, size: 32),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
