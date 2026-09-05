/// Activity center screen â€” shows user activity feed.
///
/// Ports native `ActivityCenterActivity.java`.
library activity_center;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/level_summary_models.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import '../../utils/notification_router.dart';
import 'package:belive/widgets/preloader.dart';

const String _tag = 'ActivityCenter';

class ActivityCenterScreen extends StatefulWidget {
  const ActivityCenterScreen({super.key});

  @override
  State<ActivityCenterScreen> createState() => _ActivityCenterScreenState();
}

class _ActivityCenterScreenState extends State<ActivityCenterScreen> {
  final _items = <ActivityItem>[];
  bool _loading = true;
  bool _loadingMore = false;
  int _start = 0;
  bool _hasMore = true;
  late final String _userId;

  @override
  void initState() {
    super.initState();
    _userId = context.read<SessionManager>().userId;
    _load();
  }

  Future<void> _load() async {
    if (_loadingMore || !_hasMore) return;
    if (_start == 0) {
      setState(() => _loading = true);
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final res = await ApiService.getActivities(userId: _userId, start: _start, limit: 30);
      _items.addAll(res.data);
      _hasMore = res.data.length >= 30;
      _start += 30;
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Activity Center')),
      body: _loading
          ? const Center(child: Preloader())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none_outlined, size: 48, color: isDark ? AppTheme.textTertiary : Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text('No activities yet', style: TextStyle(color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary)),
                    ],
                  ),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n is ScrollEndNotification && n.metrics.pixels >= n.metrics.maxScrollExtent - 100) {
                      _load();
                    }
                    return false;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length + (_loadingMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      if (i >= _items.length) {
                        return const Center(child: Padding(padding: EdgeInsets.all(16), child: Preloader(strokeWidth: 2)));
                      }
                      return _activityCard(isDark, _items[i]);
                    },
                  ),
                ),
    );
  }

  Widget _activityCard(bool isDark, ActivityItem item) {
    return Card(
      color: isDark ? AppTheme.surfaceLight : AppTheme.lightBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _navigateToActivity(item),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (item.image != null && item.image!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: item.image!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 56,
                      height: 56,
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      child: const Icon(Icons.history, color: AppTheme.primary),
                    ),
                  ),
                )
              else
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.history, color: AppTheme.primary),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title ?? '',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                      ),
                    ),
                    if (item.description != null && item.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(item.createdAt),
                      style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToActivity(ActivityItem item) {
    final actionType = (item.actionType ?? item.type ?? '').toLowerCase();
    final actionData = item.actionData ?? '';
    if (actionType.isEmpty) return;
    NotificationRouter.navigate(context, actionType, actionData);
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '';
    try {
      final dt = DateTime.parse(date);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays == 0) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return date;
    }
  }
}

