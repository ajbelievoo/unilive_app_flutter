/// Medal selection screen â€” ported from native `WearMedalActivity.java`.
///
/// Shows 10 medal slots in a 5x2 grid. Available medals (VIP badge, host level
/// badge) appear in a horizontal strip below. Tapping an available medal adds
/// it to the next empty slot; tapping a filled slot removes it.
library medal;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';

class MedalScreen extends StatefulWidget {
  const MedalScreen({super.key});

  @override
  State<MedalScreen> createState() => _MedalScreenState();
}

class _MedalScreenState extends State<MedalScreen> {
  final _slots = List<String?>.filled(10, null);

  List<_AvailableMedal> _availableMedals() {
    final user = context.read<SessionManager>().getUser();
    final list = <_AvailableMedal>[];

    // Hardcoded legacy medals (VIP, host level). User level is NOT a medal.
    if (user?.vipBadgeUrl?.isNotEmpty == true) {
      list.add(_AvailableMedal(label: 'VIP Badge', url: user!.vipBadgeUrl!));
    }
    if (user?.hostLevel?.image?.isNotEmpty == true) {
      list.add(_AvailableMedal(label: 'Host Level', url: user!.hostLevel!.image!));
    }

    // Backend-supplied medals and achievements.
    for (final url in user?.medals ?? <String>[]) {
      if (url.isNotEmpty && !list.any((m) => m.url == url)) {
        list.add(_AvailableMedal(label: 'Medal', url: url));
      }
    }
    for (final url in user?.achievements ?? <String>[]) {
      if (url.isNotEmpty && !list.any((m) => m.url == url)) {
        list.add(_AvailableMedal(label: 'Achievement', url: url));
      }
    }
    return list;
  }

  void _toggleSlot(String url) {
    final idx = _slots.indexOf(url);
    if (idx >= 0) {
      setState(() => _slots[idx] = null);
    } else {
      final empty = _slots.indexWhere((s) => s == null);
      if (empty >= 0) {
        setState(() => _slots[empty] = url);
      } else {
        Fluttertoast.showToast(msg: 'All slots filled');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final medals = _availableMedals();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Medals'),
        actions: [
          TextButton(
            onPressed: () {
              final selected = _slots.whereType<String>().toList();
              Navigator.pop(context, selected);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Medal Slots',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap an available medal to add it. Tap a filled slot to remove.',
              style: TextStyle(fontSize: 13, color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: 10,
              itemBuilder: (_, i) => _SlotTile(
                url: _slots[i],
                isDark: isDark,
                onTap: () {
                  if (_slots[i] != null) _toggleSlot(_slots[i]!);
                },
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Available Medals',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (medals.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No medals available. Become VIP or level up to unlock medals.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary),
                  ),
                ),
              )
            else
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: medals.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _AvailableTile(
                    medal: medals[i],
                    isDark: isDark,
                    isSelected: _slots.contains(medals[i].url),
                    onTap: () => _toggleSlot(medals[i].url),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.url, required this.isDark, required this.onTap});

  final String? url;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceLight : AppTheme.lightBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: url != null ? AppTheme.primary.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08),
            width: url != null ? 1.5 : 1,
          ),
        ),
        child: url != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.military_tech)),
              )
            : Icon(Icons.add, color: isDark ? AppTheme.textTertiary : Colors.grey.shade400, size: 20),
      ),
    );
  }
}

class _AvailableTile extends StatelessWidget {
  const _AvailableTile({required this.medal, required this.isDark, required this.isSelected, required this.onTap});

  final _AvailableMedal medal;
  final bool isDark;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppTheme.green : Colors.transparent,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(imageUrl: medal.url, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.military_tech)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            medal.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppTheme.green : (isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailableMedal {
  _AvailableMedal({required this.label, required this.url});

  final String label;
  final String url;
}

