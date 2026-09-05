/// Game bottom sheet — shows available mini-games in live rooms.
///
/// Ports native `BottomSheetGameList.java` — displays a grid of games
/// from settings that hosts/viewers can launch during a live stream.
/// Each game opens in a WebView (matching native Casino/Dialog/TeenPatti).
library game_bottom;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../screens/games/game_webview_screen.dart';
import '../utils/log.dart';
import '../utils/media_utils.dart';

/// Game item shown in the game list sheet.
class GameItem {
  const GameItem({this.id, this.name, this.icon, this.link, this.type});
  final String? id;
  final String? name;
  final String? icon;
  final String? link;
  final String? type;
}

/// Shows the game list bottom sheet.
void showGameListSheet(BuildContext context, {List<dynamic>? games}) {
  Log.d('GameSheet', 'showGameListSheet: games=${games?.length ?? 0} items');
  if (games != null && games.isNotEmpty) {
    Log.d('GameSheet', 'first game: ${games.first}');
  }
  final items = <GameItem>[];
  if (games != null && games.isNotEmpty) {
    for (final g in games) {
      if (g is Map<String, dynamic>) {
        final link = (g['link'] ?? g['url'] ?? g['gameLink'] ?? g['gameUrl'] ??
                g['game_link'] ?? g['game_url'] ?? g['linkUrl'] ?? g['webUrl'])
            ?.toString();
        final name = (g['name'] ?? g['gameName'] ?? g['game_name'] ?? g['title'])
            ?.toString();
        final icon = (g['image'] ?? g['icon'] ?? g['gameImage'] ??
                g['game_image'] ?? g['gameIcon'] ?? g['game_icon'] ?? g['logo'])
            ?.toString();
        final type = (g['type'] ?? g['gameType'] ?? g['game_type'])?.toString();
        // Skip games with no link — they can't be opened
        if (link == null || link.isEmpty) {
          Log.w('GameSheet', 'Skipping game with no link: $name (id=${g['_id'] ?? g['id']})');
          continue;
        }
        items.add(GameItem(
          id: g['_id']?.toString() ?? g['id']?.toString(),
          name: name,
          icon: icon,
          link: link,
          type: type,
        ));
      }
    }
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1A1A2E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Container(
      height: MediaQuery.of(context).size.height * 0.40,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7E3FF2), Color(0xFFE91E63)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sports_esports, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Text('Games',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Game grid
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sports_esports, size: 48, color: Colors.white24),
                        SizedBox(height: 8),
                        Text('No games available',
                            style: TextStyle(color: Colors.white54, fontSize: 14)),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final g = items[i];
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          final link = g.link ?? '';
                          if (link.isNotEmpty) {
                            // Use the game's type field if provided by backend;
                            // fall back to index-based detection (native behavior:
                            // 0 = casino, 1 = dialog, else = teen patti).
                            final String gameType = (g.type != null && g.type!.isNotEmpty)
                                ? g.type!.toLowerCase()
                                : (i == 0
                                    ? 'casino'
                                    : (i == 1 ? 'dialog' : 'teenpatti'));
                            Log.d('GameSheet', 'Opening game: ${g.name} | type=$gameType | link=$link');
                            openGameWebView(
                              context,
                              gameName: g.name ?? 'Game',
                              gameUrl: link,
                              gameType: gameType,
                            );
                          } else {
                            Log.w('GameSheet', 'Game link empty for: ${g.name} (id=${g.id})');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Game link not available'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                            child: Column(
                              children: [
                                Expanded(
                                  child: (g.icon ?? '').isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: CachedNetworkImage(
                                            imageUrl: VideoUtil.getFullImageUrl(g.icon),
                                            fit: BoxFit.contain,
                                            fadeInDuration: Duration.zero,
                                            memCacheWidth: 256,
                                            memCacheHeight: 256,
                                            placeholder: (_, __) => Container(
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF7E3FF2).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Icon(Icons.sports_esports,
                                                  color: Color(0xFF7E3FF2), size: 36),
                                            ),
                                            errorWidget: (_, __, ___) => Container(
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF7E3FF2).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Icon(Icons.sports_esports,
                                                  color: Color(0xFF7E3FF2), size: 36),
                                            ),
                                          ),
                                        )
                                      : Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF7E3FF2).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(Icons.sports_esports,
                                              color: Color(0xFF7E3FF2), size: 36),
                                        ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  g.name ?? 'Game',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}
