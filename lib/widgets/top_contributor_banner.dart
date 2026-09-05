/// Top contributor banner + controller for live/audio rooms.
///
/// Tracks the top gifters in real-time and renders a Bigo-style top
/// contributor banner at the top of the room.
library top_contributor_banner;

import 'package:flutter/material.dart';

/// A single top contributor entry.
class Contributor {
  Contributor({
    required this.userId,
    required this.name,
    this.avatar,
    this.coins = 0,
    this.count = 0,
  });

  final String userId;
  final String name;
  final String? avatar;
  final int coins;
  final int count;

  /// Alias for [coins] used by some ranking UI components.
  int get totalCoins => coins;
}

/// Controller that tracks top gifters in real-time.
class TopContributorController extends ChangeNotifier {
  final Map<String, Contributor> _contributors = {};

  /// Sorted list of top contributors (by coins, descending).
  List<Contributor> get top {
    final list = _contributors.values.toList();
    list.sort((a, b) => b.coins.compareTo(a.coins));
    return list.take(3).toList();
  }

  /// Record a gift from a user.
  void recordGift({
    required String userId,
    required String name,
    String? avatar,
    required int coins,
    required int count,
  }) {
    final existing = _contributors[userId];
    if (existing != null) {
      _contributors[userId] = Contributor(
        userId: userId,
        name: name,
        avatar: avatar ?? existing.avatar,
        coins: existing.coins + coins,
        count: existing.count + count,
      );
    } else {
      _contributors[userId] = Contributor(
        userId: userId,
        name: name,
        avatar: avatar,
        coins: coins,
        count: count,
      );
    }
    notifyListeners();
  }

  /// Clear all contributors.
  void clear() {
    _contributors.clear();
    notifyListeners();
  }
}

/// Bigo-style top contributor banner shown at the top of the room.
class TopContributorBanner extends StatelessWidget {
  const TopContributorBanner({
    super.key,
    required this.controller,
    this.maxVisible = 3,
  });

  final TopContributorController controller;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final items = controller.top;
        if (items.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, size: 14, color: Color(0xFFFFD700)),
              const SizedBox(width: 4),
              ...items.take(maxVisible).map((c) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (c.avatar != null)
                      ClipOval(
                        child: Image.network(
                          c.avatar!,
                          width: 18,
                          height: 18,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 16, color: Colors.white54),
                        ),
                      )
                    else
                      const Icon(Icons.person, size: 16, color: Colors.white54),
                    const SizedBox(width: 3),
                    Text(
                      c.name,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              )),
            ],
          ),
        );
      },
    );
  }
}
