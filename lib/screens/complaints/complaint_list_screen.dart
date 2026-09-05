import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/leaderboard_complain_models.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

class ComplaintListScreen extends StatefulWidget {
  const ComplaintListScreen({super.key});

  @override
  State<ComplaintListScreen> createState() => _ComplaintListScreenState();
}

class _ComplaintListScreenState extends State<ComplaintListScreen> {
  static const String _tag = 'ComplaintList';
  final _complaints = <ComplainItem>[];
  bool _loading = true;
  bool _loadingMore = false;
  int _start = 0;
  static const int _limit = 20;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _complaints.clear();
      _start = 0;
      _hasMore = true;
    });
    await _fetch();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    _start += _limit;
    await _fetch();
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _fetch() async {
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.getComplaints(session.userId, start: _start);
      if (res.status) {
        _complaints.addAll(res.complain);
        _hasMore = res.complain.length >= _limit;
      }
    } catch (e, s) {
      Log.e(_tag, 'fetch failed', e, s);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Complaints')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushNamed(AppRoutes.createComplaint).then((_) => _load()),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: Preloader())
          : RefreshIndicator(
              onRefresh: _load,
              child: _complaints.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 200),
                        Center(
                          child: Column(
                            children: [
                              const Icon(Icons.feedback_outlined, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text('No complaints yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => context.pushNamed(AppRoutes.createComplaint).then((_) => _load()),
                                child: const Text('Create a complaint'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _complaints.length + (_hasMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i >= _complaints.length) {
                          _loadMore();
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: Preloader(strokeWidth: 2)),
                          );
                        }
                        final c = _complaints[i];
                        return _ComplaintCard(complaint: c, onTap: () {
                          context.pushNamed(AppRoutes.complaintDetail, extra: {'complaint': c});
                        });
                      },
                    ),
            ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({required this.complaint, required this.onTap});

  final ComplainItem complaint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (complaint.status) {
      'resolved' => Colors.green,
      'rejected' => Colors.red,
      _ => Colors.orange,
    };
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: complaint.proofImage != null && complaint.proofImage!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: complaint.proofImage!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(width: 50, height: 50, color: Colors.grey.shade200, child: const Icon(Icons.image)),
                ),
              )
            : Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.feedback, color: AppTheme.primary),
              ),
        title: Text(complaint.issue ?? 'Complaint', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(complaint.createdAt ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
          child: Text(
            (complaint.status ?? 'pending').toUpperCase(),
            style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
