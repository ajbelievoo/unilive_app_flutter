/// Party Game bottom sheet.
///
/// Shows the native "Party Game" grid from the live room: Lucky Bag, PK,
/// Video/Music, Ludo.
library party_game_sheet;

import 'package:flutter/material.dart';

void showPartyGameSheet(
  BuildContext context, {
  required bool isHost,
    required String liveStreamingId,
    required String userId,
    required VoidCallback onLuckyBag,
    required VoidCallback onPK,
    required VoidCallback onVideoMusic,
    required VoidCallback onLudo,
  }) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PartyGameSheet(
      isHost: isHost,
      liveStreamingId: liveStreamingId,
      userId: userId,
      onLuckyBag: onLuckyBag,
      onPK: onPK,
      onVideoMusic: onVideoMusic,
      onLudo: onLudo,
    ),
  );
}

class _PartyGameSheet extends StatelessWidget {
  const _PartyGameSheet({
    required this.isHost,
    required this.liveStreamingId,
    required this.userId,
    required this.onLuckyBag,
    required this.onPK,
    required this.onVideoMusic,
    required this.onLudo,
  });

  final bool isHost;
  final String liveStreamingId;
  final String userId;
  final VoidCallback onLuckyBag;
  final VoidCallback onPK;
  final VoidCallback onVideoMusic;
  final VoidCallback onLudo;

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
              'Party Game',
              style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _gameTile(context, 'Lucky Bag', 'assets/game/lucky_bag.webp', onLuckyBag, icon: Icons.redeem),
                  _gameTile(context, 'PK', 'assets/game/pk.webp', onPK, icon: Icons.sports_kabaddi),
                  _gameTile(context, 'Video/Music', 'assets/game/video_music.webp', onVideoMusic, icon: Icons.music_video),
                  _gameTile(context, 'Ludo', 'assets/game/ludo.webp', onLudo, icon: Icons.casino),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _gameTile(BuildContext context, String title, String asset, VoidCallback onTap, {required IconData icon}) {
    return GestureDetector(
      onTap: () { Navigator.pop(context); onTap(); },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Image.asset(
              asset,
              errorBuilder: (_, __, ___) => Icon(icon, color: Colors.orange, size: 32),
            ),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
