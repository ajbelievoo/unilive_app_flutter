import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/visitors_root.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../utils/log.dart';
import '../../widgets/user_avatar.dart';
import 'package:belive/widgets/preloader.dart';

/// Ported from native `VisitorsActivity.java`.
///
/// Shows the list of users who visited the given user's profile.
/// Displays last visit time (relative format: "5 min ago", "2 h ago", etc.)
/// If a visitor visited multiple times, only the most recent visit time is shown.
class VisitorsScreen extends StatefulWidget {
  const VisitorsScreen({super.key, required this.userId});

  final String userId;

  @override
  State<VisitorsScreen> createState() => _VisitorsScreenState();
}

class _VisitorsScreenState extends State<VisitorsScreen> {
  static const String _tag = 'Visitors';
  final _visitors = <Visitor>[];
  bool _loading = true;
  bool _loadingMore = false;
  int _skip = 0;
  static const int _limit = 20;
  bool _hasMore = true;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.visitorsList(userId: widget.userId, skip: 0, limit: _limit);
      _visitors
        ..clear()
        ..addAll(_deduplicate(res.visitors));
      _skip = res.visitors.length;
      _hasMore = res.visitors.length >= _limit;
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final res = await ApiService.visitorsList(userId: widget.userId, skip: _skip, limit: _limit);
      _visitors.addAll(_deduplicate(res.visitors));
      _skip += res.visitors.length;
      _hasMore = res.visitors.length >= _limit;
    } catch (e, s) {
      Log.e(_tag, 'loadMore failed', e, s);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// Deduplicate visitors by ID — keep only the most recent visit per user.
  List<Visitor> _deduplicate(List<Visitor> raw) {
    final byId = <String, Visitor>{};
    for (final v in raw) {
      final key = v.id ?? v.uniqueId ?? v.name ?? '';
      if (key.isEmpty) continue;
      final existing = byId[key];
      if (existing == null) {
        byId[key] = v;
      } else {
        // Keep the one with the more recent visit time
        final existingTime = _parseTime(existing.lastVisitedAt ?? existing.visitedAt);
        final newTime = _parseTime(v.lastVisitedAt ?? v.visitedAt);
        if (newTime.isAfter(existingTime)) {
          byId[key] = v;
        }
      }
    }
    return byId.values.toList();
  }

  DateTime _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return DateTime(2000);
    return DateTime.tryParse(timeStr) ?? DateTime(2000);
  }

  /// Format visit time as relative: "just now", "5 min ago", "2 h ago", "3 d ago", or date.
  String _formatVisitTime(String? visitedAt, String? lastVisitedAt) {
    final timeStr = lastVisitedAt ?? visitedAt;
    if (timeStr == null || timeStr.isEmpty) return '';
    final dt = DateTime.tryParse(timeStr);
    if (dt == null) return timeStr;
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    // Fall back to date
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visitors')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: Preloader());
    if (_visitors.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.visibility_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('No visitors yet', style: TextStyle(color: Colors.grey.shade600)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scrollController,
        itemCount: _visitors.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
        itemBuilder: (_, i) {
          if (i >= _visitors.length) {
            return const Padding(padding: EdgeInsets.all(16), child: Center(child: Preloader(strokeWidth: 2)));
          }
          final v = _visitors[i];
          final visitTime = _formatVisitTime(v.visitedAt, v.lastVisitedAt);
          return ListTile(
            onTap: () => context.pushNamed(AppRoutes.guestProfile, extra: {'userId': v.id}),
            leading: UserAvatar(imageUrl: v.avatar, size: 48, isVIP: v.isVIP),
            title: Row(children: [
              Flexible(child: Text(v.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (v.isVIP) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.star, size: 14, color: Color(0xFFFFA000))),
            ]),
            subtitle: Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(visitTime, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                if (v.visitCount24h > 1) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFFFF6B9D).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text('${v.visitCount24h}x today', style: const TextStyle(fontSize: 10, color: Color(0xFFFF6B9D), fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          );
        },
      ),
    );
  }
}
