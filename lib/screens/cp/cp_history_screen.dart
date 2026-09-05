/// CP/Friend History screen — list of past (broken) couples or friendships
/// (Bigo-style premium redesign with gradient avatars, broken heart badges).
library cp_history;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../utils/media_utils.dart';
import 'package:provider/provider.dart';

import '../../models/cp_models.dart';
import '../../models/friend_models.dart';
import '../../providers/cp_provider.dart';
import '../../providers/friend_provider.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../widgets/cp_widgets.dart';
import '../../widgets/premium_ui.dart';

class CPHistoryScreen extends StatefulWidget {
  const CPHistoryScreen({super.key, this.isFriend = false});
  final bool isFriend;

  @override
  State<CPHistoryScreen> createState() => _CPHistoryScreenState();
}

class _CPHistoryScreenState extends State<CPHistoryScreen> {
  @override
  void initState() {
    super.initState();
    final session = context.read<SessionManager>();
    if (widget.isFriend) {
      context.read<FriendProvider>().loadHistory(session.userId);
    } else {
      context.read<CpProvider>().loadHistory(session.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFriend = widget.isFriend;
    final history =
        isFriend
            ? context.watch<FriendProvider>().history
            : context.watch<CpProvider>().history;
    final headerGradient =
        isFriend ? AppTheme.friendHeaderGradient : AppTheme.cpHeaderGradient;
    final accentColor = isFriend ? AppTheme.friendAccent : AppTheme.cpAccent;

    return Scaffold(
      backgroundColor: AppTheme.cpDarkBg,
      body: Container(
        decoration: BoxDecoration(gradient: headerGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    _iconBtn(
                      Icons.arrow_back_rounded,
                      () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isFriend ? 'Friend History' : 'CP History',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.cpDarkBg,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    child:
                        history.isEmpty
                            ? EmptyState(
                              icon: Icons.history,
                              title:
                                  isFriend
                                      ? 'No Past Friends'
                                      : 'No Past Couples',
                              subtitle:
                                  isFriend
                                      ? 'Your past Friend relationships will be remembered here.'
                                      : 'Your past CP relationships will be remembered here.',
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: history.length,
                              itemBuilder:
                                  (_, i) => _HistoryTile(
                                    item: history[i],
                                    isFriend: isFriend,
                                    accentColor: accentColor,
                                  ),
                            ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

// ===========================================================================
// History tile — Bigo-style with gradient avatar ring, broken heart badge,
// level badge, intimacy, days, end reason
// ===========================================================================
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.item,
    required this.isFriend,
    required this.accentColor,
  });
  final Object item;
  final bool isFriend;
  final Color accentColor;

  String? get _image {
    if (isFriend) return (item as FriendHistoryItem).partner?.image;
    return (item as CPHistoryItem).partner?.image;
  }

  String get _name {
    if (isFriend) return (item as FriendHistoryItem).partner?.name ?? 'Unknown';
    return (item as CPHistoryItem).partner?.name ?? 'Unknown';
  }

  int get _level {
    if (isFriend) return (item as FriendHistoryItem).level;
    return (item as CPHistoryItem).level;
  }

  int get _intimacy {
    if (isFriend) return (item as FriendHistoryItem).intimacy;
    return (item as CPHistoryItem).intimacy;
  }

  int get _days {
    if (isFriend) return (item as FriendHistoryItem).daysTogether;
    return (item as CPHistoryItem).daysTogether;
  }

  String? get _endedAt {
    if (isFriend) return (item as FriendHistoryItem).endedAt;
    return (item as CPHistoryItem).endedAt;
  }

  String? get _reason {
    if (isFriend) return (item as FriendHistoryItem).reason;
    return (item as CPHistoryItem).reason;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cpDarkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          // Avatar with broken heart badge
          Stack(
            alignment: Alignment.topLeft,
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.4),
                      accentColor.withValues(alpha: 0.2),
                    ],
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.all(2.5),
                  child: CircleAvatar(
                    radius: 25,
                    backgroundColor: AppTheme.cpDarkSurfaceLight,
                    backgroundImage:
                        (_image != null && _image!.isNotEmpty)
                            ? CachedNetworkImageProvider(_image!)
                            : null,
                    child:
                        (_image == null)
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                  ),
                ),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppTheme.cpDarkCard,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.heart_broken,
                    size: 16,
                    color: AppTheme.cpDarkTextTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    CPLevelBadge(level: _level, size: 18, isFriend: isFriend),
                    const SizedBox(width: 6),
                    Text(
                      'Lv.$_level',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.cpDarkTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.favorite,
                      size: 12,
                      color: accentColor.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      formatCount(_intimacy),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 11,
                      color: AppTheme.cpDarkTextTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_days days together',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.cpDarkTextTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_endedAt != null)
                Text(
                  _endedAt!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.cpDarkTextTertiary,
                  ),
                ),
              if (_reason != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.cpDarkSurfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _reasonLabel(_reason!),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.cpDarkTextSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _reasonLabel(String r) {
    switch (r) {
      case 'mutual':
        return 'Mutual';
      case 'by_user1':
      case 'by_user2':
        return 'Ended';
      default:
        return r;
    }
  }
}
