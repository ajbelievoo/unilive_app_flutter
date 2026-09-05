import 'package:flutter/material.dart';

import 'marquee_text.dart';

/// Scrolling room announcement banner shown at the top of live/audio rooms.
///
/// Displays the host-set room announcement and live-pushed announcements
/// (next-day gifting events, game schedules, etc.) as a marquee so they
/// stay visible instead of scrolling away in the chat.
class RoomAnnouncementMarquee extends StatelessWidget {
  const RoomAnnouncementMarquee({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFB800).withValues(alpha: 0.85),
            const Color(0xFFFF6B00).withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: SizedBox(
              height: 16,
              child: MarqueeText(
                text: text,
                velocity: 45,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
