/// Call history screen — list of incoming/outgoing/missed calls.
///
/// Ports native `CallHistoryActivity.java`.
library call_history;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/call_history_root.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import 'call_screen.dart';
import 'package:belive/widgets/preloader.dart';

const String _tag = 'CallHistory';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final _items = <CallHistoryItem>[];
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
      final res = await ApiService.getCallHistory(
        userId: _userId,
        start: _start,
        limit: 30,
      );
      _items.addAll(res.history);
      _hasMore = res.history.length >= 30;
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
      appBar: AppBar(title: const Text('Call History')),
      body:
          _loading
              ? const Center(child: Preloader())
              : _items.isEmpty
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 48,
                      color:
                          isDark ? AppTheme.textTertiary : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No call history',
                      style: TextStyle(
                        color:
                            isDark
                                ? AppTheme.textSecondary
                                : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              )
              : NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n is ScrollEndNotification &&
                      n.metrics.pixels >= n.metrics.maxScrollExtent - 100) {
                    _load();
                  }
                  return false;
                },
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _items.length + (_loadingMore ? 1 : 0),
                  separatorBuilder:
                      (_, __) => Divider(
                        height: 1,
                        color:
                            isDark ? AppTheme.surfaceLight : AppTheme.lightBg,
                      ),
                  itemBuilder: (_, i) {
                    if (i >= _items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: Preloader(strokeWidth: 2)),
                      );
                    }
                    final item = _items[i];
                    final isOutgoing = item.callerUserId == _userId;
                    final missed =
                        (item.status ?? '').toLowerCase() == 'missed';
                    return _callTile(isDark, item, isOutgoing, missed);
                  },
                ),
              ),
    );
  }

  Widget _callTile(
    bool isDark,
    CallHistoryItem item,
    bool isOutgoing,
    bool missed,
  ) {
    final iconColor =
        missed
            ? Colors.red
            : isOutgoing
            ? AppTheme.primary
            : Colors.green;
    final directionIcon = isOutgoing ? Icons.call_made : Icons.call_received;
    final typeIcon = item.isAudio ? Icons.phone : Icons.videocam;
    // The other user's ID (whomever we'd call back).
    final otherUserId =
        isOutgoing ? (item.receiverUserId ?? '') : (item.callerUserId ?? '');

    return ListTile(
      leading: Stack(
        alignment: Alignment.topLeft,
        children: [
          ClipOval(
            child: CachedNetworkImage(
              imageUrl: item.image ?? '',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorWidget:
                  (_, __, ___) => Container(
                    width: 48,
                    height: 48,
                    color: isDark ? AppTheme.surfaceLight : AppTheme.lightBg,
                    child: const Icon(Icons.person, size: 24),
                  ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surface : AppTheme.lightSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(typeIcon, size: 12, color: iconColor),
            ),
          ),
        ],
      ),
      title: Text(
        item.name ?? 'Unknown',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color:
              missed
                  ? Colors.red
                  : (isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary),
        ),
      ),
      subtitle: Row(
        children: [
          Icon(directionIcon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Text(
            missed ? 'Missed' : (isOutgoing ? 'Outgoing' : 'Incoming'),
            style: TextStyle(
              fontSize: 12,
              color:
                  isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary,
            ),
          ),
          if (item.duration > 0 && !missed) ...[
            const SizedBox(width: 8),
            Text(
              '· ${_formatDuration(item.duration)}',
              style: TextStyle(
                fontSize: 12,
                color:
                    isDark
                        ? AppTheme.textTertiary
                        : AppTheme.lightTextSecondary,
              ),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatDate(item.date),
            style: TextStyle(
              fontSize: 11,
              color:
                  isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(width: 8),
          // Call-back button
          GestureDetector(
            onTap:
                otherUserId.isEmpty
                    ? null
                    : () => startCall(
                      context,
                      otherUserId: otherUserId,
                      isAudioCall: item.isAudio,
                    ),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.1),
              ),
              child: Icon(
                item.isAudio ? Icons.phone : Icons.videocam,
                size: 18,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m < 60) return '${m}m ${s}s';
    final h = m ~/ 60;
    final rm = m % 60;
    return '${h}h ${rm}m';
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '';
    try {
      final dt = DateTime.parse(date);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      } else {
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    } catch (_) {
      return date;
    }
  }
}
