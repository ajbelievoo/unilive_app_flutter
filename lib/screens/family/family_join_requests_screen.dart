import 'package:flutter/material.dart';
import '../../models/family_models.dart';
import '../../services/api_service.dart';
import '../../widgets/user_avatar.dart';

/// Join approval queue screen — leader/co-leader can approve or reject
/// pending join requests. Mirrors Bigo/Chamet's family join approval flow.
class FamilyJoinRequestsScreen extends StatefulWidget {
  const FamilyJoinRequestsScreen({super.key, required this.familyId});

  final String familyId;

  @override
  State<FamilyJoinRequestsScreen> createState() => _FamilyJoinRequestsScreenState();
}

class _FamilyJoinRequestsScreenState extends State<FamilyJoinRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<FamilyJoinRequest> _pending = [];
  List<FamilyJoinRequest> _history = [];
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getFamilyJoinRequests(familyId: widget.familyId);
      final all = res.requests;
      _pending = all.where((r) => r.status == 'pending').toList();
      _history = all.where((r) => r.status != 'pending').toList();
    } catch (e) {
      // Keep empty lists on error
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _approve(FamilyJoinRequest req) async {
    if (_isProcessing || req.id == null) return;
    setState(() => _isProcessing = true);
    try {
      final res = await ApiService.approveFamilyJoinRequest(
        requestId: req.id!,
        familyId: widget.familyId,
      );
      if (res.status) {
        _pending.remove(req);
        _history.insert(0, FamilyJoinRequest(
          id: req.id,
          userId: req.userId,
          userName: req.userName,
          userImage: req.userImage,
          username: req.username,
          level: req.level,
          country: req.country,
          familyId: req.familyId,
          status: 'approved',
          requestedAt: req.requestedAt,
          message: req.message,
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Approved ${req.userName ?? 'user'}'), backgroundColor: Colors.green),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? 'Failed to approve'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to approve'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _reject(FamilyJoinRequest req) async {
    if (_isProcessing || req.id == null) return;
    setState(() => _isProcessing = true);
    try {
      final res = await ApiService.rejectFamilyJoinRequest(
        requestId: req.id!,
        familyId: widget.familyId,
      );
      if (res.status) {
        _pending.remove(req);
        _history.insert(0, FamilyJoinRequest(
          id: req.id,
          userId: req.userId,
          userName: req.userName,
          userImage: req.userImage,
          username: req.username,
          level: req.level,
          country: req.country,
          familyId: req.familyId,
          status: 'rejected',
          requestedAt: req.requestedAt,
          message: req.message,
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rejected ${req.userName ?? 'user'}'), backgroundColor: Colors.orange),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? 'Failed to reject'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to reject'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Requests'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Pending (${_pending.length})'),
            Tab(text: 'History (${_history.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPendingList(),
                _buildHistoryList(),
              ],
            ),
    );
  }

  Widget _buildPendingList() {
    if (_pending.isEmpty) {
      return _buildEmpty('No pending requests', 'When users request to join your family, they\'ll appear here.');
    }
    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _pending.length,
        itemBuilder: (_, i) => _buildRequestCard(_pending[i], isPending: true),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return _buildEmpty('No history', 'Approved and rejected requests will appear here.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _history.length,
      itemBuilder: (_, i) => _buildRequestCard(_history[i], isPending: false),
    );
  }

  Widget _buildRequestCard(FamilyJoinRequest req, {required bool isPending}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            UserAvatar(
              imageUrl: req.userImage,
              size: 48,
              isVIP: false,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          req.userName ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (req.level > 1) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Lv ${req.level}',
                            style: TextStyle(fontSize: 10, color: Colors.orange.shade700, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (req.username != null && req.username!.isNotEmpty)
                    Text('@${req.username}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  if (req.message != null && req.message!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '"${req.message}"',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (!isPending && req.status != 'pending') ...[
                    const SizedBox(height: 4),
                    Text(
                      req.status == 'approved' ? 'Approved' : 'Rejected',
                      style: TextStyle(
                        fontSize: 11,
                        color: req.status == 'approved' ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isPending) ...[
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filled(
                    onPressed: _isProcessing ? null : () => _approve(req),
                    icon: const Icon(Icons.check, size: 18),
                    style: IconButton.styleFrom(backgroundColor: Colors.green),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(height: 4),
                  IconButton.outlined(
                    onPressed: _isProcessing ? null : () => _reject(req),
                    icon: const Icon(Icons.close, size: 18),
                    style: IconButton.styleFrom(foregroundColor: Colors.red),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
