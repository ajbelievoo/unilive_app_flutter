/// CP Requests screen — full incoming + outgoing request lists
/// (Bigo-style premium redesign with gradient avatars, accept/reject buttons).
///
/// Reachable from the CP hub tab and via route. Provides accept/reject
/// for incoming and cancel for outgoing requests.
library cp_requests;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../models/cp_models.dart';
import '../../providers/cp_provider.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../widgets/premium_ui.dart';
import 'package:belive/widgets/preloader.dart';

class CPRequestsScreen extends StatefulWidget {
  const CPRequestsScreen({super.key});

  @override
  State<CPRequestsScreen> createState() => _CPRequestsScreenState();
}

class _CPRequestsScreenState extends State<CPRequestsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionManager>();
    context.read<CpProvider>().loadRequests(session.userId);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CpProvider>();
    final incoming = cp.incomingRequests;
    final outgoing = cp.outgoingRequests;
    return Scaffold(
      backgroundColor: AppTheme.cpDarkBg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.cpHeaderGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    _iconBtn(Icons.arrow_back_rounded, () => Navigator.pop(context)),
                    const SizedBox(width: 8),
                    const Text('CP Requests',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              // Tab bar
              TabBar(
                controller: _tabCtrl,
                indicatorColor: Colors.white,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                tabs: [
                  Tab(text: 'Incoming (${incoming.where((r) => r.status == 'pending').length})'),
                  Tab(text: 'Outgoing (${outgoing.where((r) => r.status == 'pending').length})'),
                ],
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.cpDarkBg,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    child: TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _IncomingList(requests: incoming),
                        _OutgoingList(requests: outgoing),
                      ],
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
// Incoming list — pending + history sections
// ===========================================================================
class _IncomingList extends StatelessWidget {
  const _IncomingList({required this.requests});
  final List<CPRequest> requests;

  @override
  Widget build(BuildContext context) {
    final pending = requests.where((r) => r.status == 'pending').toList();
    final others = requests.where((r) => r.status != 'pending').toList();
    if (pending.isEmpty && others.isEmpty) {
      return const EmptyState(
          icon: Icons.mail_outline,
          title: 'No Incoming Requests',
          subtitle: 'When someone invites you to become a couple, it will appear here.');
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (pending.isNotEmpty) ...[
          const SectionHeader(title: 'Pending'),
          ...pending.map((r) => _IncomingTile(request: r)),
        ],
        if (others.isNotEmpty) ...[
          const SizedBox(height: 8),
          const SectionHeader(title: 'History'),
          ...others.map((r) => _PastTile(request: r)),
        ],
      ],
    );
  }
}

// ===========================================================================
// Incoming tile — Bigo-style with gradient avatar ring, accept/reject buttons
// ===========================================================================
class _IncomingTile extends StatefulWidget {
  const _IncomingTile({required this.request});
  final CPRequest request;

  @override
  State<_IncomingTile> createState() => _IncomingTileState();
}

class _IncomingTileState extends State<_IncomingTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final cp = context.read<CpProvider>();
    final session = context.read<SessionManager>();
    final r = widget.request;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cpDarkCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cpAccent.withValues(alpha: 0.12), width: 1),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          // Gradient avatar ring
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppTheme.cpAccent, Color(0xFF6A5AE0)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.cpAccent.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(2.5),
              child: CircleAvatar(
                radius: 25,
                backgroundColor: AppTheme.cpDarkSurfaceLight,
                backgroundImage: (r.fromUser?.image != null && r.fromUser!.image!.isNotEmpty)
                    ? CachedNetworkImageProvider(r.fromUser!.image!)
                    : null,
                child: (r.fromUser?.image == null) ? const Icon(Icons.person, color: Colors.white) : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.fromUser?.name ?? 'Unknown',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                if (r.message != null && r.message!.isNotEmpty)
                  Text('"${r.message}"',
                      style: const TextStyle(fontSize: 12, color: AppTheme.cpDarkTextSecondary, fontStyle: FontStyle.italic),
                      maxLines: 2, overflow: TextOverflow.ellipsis)
                else
                  const Text('wants to be your CP',
                      style: TextStyle(fontSize: 12, color: AppTheme.cpDarkTextSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_busy)
            const SizedBox(width: 24, height: 24, child: Preloader(strokeWidth: 2))
          else ...[
            // Accept button
            GestureDetector(
              onTap: () async {
                setState(() => _busy = true);
                final res = await cp.acceptRequest(requestId: r.id ?? '', userId: session.userId);
                if (context.mounted) {
                  Fluttertoast.showToast(
                    msg: res.ok
                        ? 'You are now a couple!'
                        : (res.message ?? 'Failed to accept request'),
                  );
                }
                if (mounted) setState(() => _busy = false);
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppTheme.pinkGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.cpAccent.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: 8),
            // Reject button
            GestureDetector(
              onTap: () async {
                setState(() => _busy = true);
                await cp.rejectRequest(requestId: r.id ?? '', userId: session.userId);
                if (mounted) setState(() => _busy = false);
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppTheme.cpDarkSurfaceLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: AppTheme.cpDarkTextSecondary, size: 22),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// Outgoing list — pending + history sections
// ===========================================================================
class _OutgoingList extends StatelessWidget {
  const _OutgoingList({required this.requests});
  final List<CPRequest> requests;

  @override
  Widget build(BuildContext context) {
    final pending = requests.where((r) => r.status == 'pending').toList();
    final others = requests.where((r) => r.status != 'pending').toList();
    if (pending.isEmpty && others.isEmpty) {
      return const EmptyState(
          icon: Icons.send_outlined,
          title: 'No Outgoing Requests',
          subtitle: 'Send a CP request from any user profile or the Discover tab.');
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (pending.isNotEmpty) ...[
          const SectionHeader(title: 'Pending'),
          ...pending.map((r) => _OutgoingTile(request: r)),
        ],
        if (others.isNotEmpty) ...[
          const SizedBox(height: 8),
          const SectionHeader(title: 'History'),
          ...others.map((r) => _PastTile(request: r)),
        ],
      ],
    );
  }
}

// ===========================================================================
// Outgoing tile — Bigo-style with gradient avatar ring, cancel button
// ===========================================================================
class _OutgoingTile extends StatefulWidget {
  const _OutgoingTile({required this.request});
  final CPRequest request;

  @override
  State<_OutgoingTile> createState() => _OutgoingTileState();
}

class _OutgoingTileState extends State<_OutgoingTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final cp = context.read<CpProvider>();
    final session = context.read<SessionManager>();
    final r = widget.request;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cpDarkCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cpAccent.withValues(alpha: 0.12), width: 1),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppTheme.cpAccent, Color(0xFF6A5AE0)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.cpAccent.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(2.5),
              child: CircleAvatar(
                radius: 25,
                backgroundColor: AppTheme.cpDarkSurfaceLight,
                backgroundImage: (r.toUser?.image != null && r.toUser!.image!.isNotEmpty)
                    ? CachedNetworkImageProvider(r.toUser!.image!)
                    : null,
                child: (r.toUser?.image == null) ? const Icon(Icons.person, color: Colors.white) : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.toUser?.name ?? 'Unknown',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.yellow,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('Waiting for response...',
                        style: TextStyle(fontSize: 12, color: AppTheme.cpDarkTextTertiary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_busy)
            const SizedBox(width: 24, height: 24, child: Preloader(strokeWidth: 2))
          else
            GestureDetector(
              onTap: () async {
                setState(() => _busy = true);
                await cp.cancelRequest(requestId: r.id ?? '', userId: session.userId);
                if (mounted) setState(() => _busy = false);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: AppTheme.cpDarkSurfaceLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('Cancel',
                    style: TextStyle(fontSize: 13, color: AppTheme.cpDarkTextSecondary, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Past tile — Bigo-style with status badge
// ===========================================================================
class _PastTile extends StatelessWidget {
  const _PastTile({required this.request});
  final CPRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final user = r.status == 'accepted' ? r.toUser : r.fromUser;
    final statusColor = r.status == 'accepted' ? AppTheme.green : AppTheme.cpDarkTextTertiary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cpDarkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cpDarkSurfaceLight, width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.cpDarkSurfaceLight,
            backgroundImage: (user?.image?.isNotEmpty == true) ? CachedNetworkImageProvider(user!.image!) : null,
            child: (user?.image == null) ? const Icon(Icons.person, color: Colors.white) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(user?.name ?? 'Unknown',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              r.status == 'accepted' ? 'Accepted' : (r.status == 'rejected' ? 'Rejected' : r.status),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }
}
