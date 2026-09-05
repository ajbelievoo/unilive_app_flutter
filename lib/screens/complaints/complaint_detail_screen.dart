import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/leaderboard_complain_models.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

class ComplaintDetailScreen extends StatefulWidget {
  const ComplaintDetailScreen({super.key, required this.complaint});

  final ComplainItem complaint;

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  static const String _tag = 'ComplaintDetail';
  ComplainItem? _item;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _item = widget.complaint;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.getComplaints(session.userId);
      if (res.status) {
        final match = res.complain.where((c) => c.id == widget.complaint.id).firstOrNull;
        if (match != null && mounted) setState(() => _item = match);
      }
    } catch (e, s) {
      Log.e(_tag, 'refresh failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _item!;
    final statusColor = switch (c.status) {
      'resolved' => Colors.green,
      'rejected' => Colors.red,
      _ => Colors.orange,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Complaint Details')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.circle, color: statusColor, size: 12),
                  const SizedBox(width: 8),
                  Text(
                    (c.status ?? 'pending').toUpperCase(),
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (c.proofImage != null && c.proofImage!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: c.proofImage!,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => Container(height: 200, color: Colors.grey.shade200, child: const Icon(Icons.broken_image, size: 64)),
                ),
              ),
              const SizedBox(height: 20),
            ],
            _section('Issue', c.issue ?? '-'),
            _section('Contact Details', c.contactDetails ?? '-'),
            _section('Submitted', c.createdAt ?? '-'),
            _section('Complaint ID', c.id ?? '-'),
            const SizedBox(height: 24),
            if (_loading) const Center(child: Preloader(strokeWidth: 2)),
          ],
        ),
      ),
    );
  }

  Widget _section(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}
