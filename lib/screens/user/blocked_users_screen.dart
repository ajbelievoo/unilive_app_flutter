import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../models/follow_models.dart';
import '../../models/missing_models.dart' show BlockedUser;
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../utils/log.dart';
import '../../widgets/user_avatar.dart';
import 'package:belive/widgets/preloader.dart';

/// Ported from native `BlockedUserListActivity.java`.
///
/// Phase 5 implementation: shows blocked users list with unblock action.
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> with SingleTickerProviderStateMixin {
  static const String _tag = 'Blocked';
  late TabController _tabCtrl;
  final _blockedByMe = <FollowUser>[];
  final _whoBlockedMe = <BlockedUser>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.getBlockedUsers(userId: session.userId);
      _blockedByMe
        ..clear()
        ..addAll(res.users);

      // Load who blocked me (native: GET /block/whoBlockUserList)
      try {
        final whoRes = await ApiService.getWhoBlockedList(session.userId);
        _whoBlockedMe
          ..clear()
          ..addAll(whoRes.blockedUsers.map((e) => e.userId).whereType<BlockedUser>());
      } catch (e) {
        Log.e(_tag, 'whoBlockedMe failed', e);
      }
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unblock(int index) async {
    final item = _blockedByMe[index];
    final otherId = item.id ?? '';
    if (otherId.isEmpty) return;
    final session = context.read<SessionManager>();
    try {
      await ApiService.blockUnblock(userId: session.userId, blockUserId: otherId);
      setState(() => _blockedByMe.removeAt(index));
      Fluttertoast.showToast(msg: 'User unblocked');
    } catch (e, s) {
      Log.e(_tag, 'unblock failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to unblock');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Users'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Blocked by me'),
            Tab(text: 'Who blocked me'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: Preloader())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildBlockedByMeTab(),
                _buildWhoBlockedMeTab(),
              ],
            ),
    );
  }

  Widget _buildBlockedByMeTab() {
    return _blockedByMe.isEmpty
        ? Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.block, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text('No blocked users', style: TextStyle(color: Colors.grey.shade600)),
            ]),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              itemCount: _blockedByMe.length,
              itemBuilder: (_, i) {
                final u = _blockedByMe[i];
                return ListTile(
                  leading: UserAvatar(imageUrl: u.image, size: 44),
                  title: Text(u.name ?? 'User', style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: TextButton(
                    onPressed: () => _unblock(i),
                    child: const Text('Unblock', style: TextStyle(color: Color(0xFF7E3FF2))),
                  ),
                );
              },
            ),
          );
  }

  Widget _buildWhoBlockedMeTab() {
    return _whoBlockedMe.isEmpty
        ? Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.shield, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text('Nobody has blocked you', style: TextStyle(color: Colors.grey.shade600)),
            ]),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              itemCount: _whoBlockedMe.length,
              itemBuilder: (_, i) {
                final u = _whoBlockedMe[i];
                return ListTile(
                  leading: UserAvatar(imageUrl: u.image, size: 44),
                  title: Text(u.name ?? 'User', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: u.country != null && u.country!.isNotEmpty ? Text(u.country!) : null,
                );
              },
            ),
          );
  }
}

/// Ported from native `BottomSheetReport_g.java`.
///
/// Shows a bottom sheet for reporting a user with a description field.
class ReportBottomSheet extends StatefulWidget {
  const ReportBottomSheet({super.key, required this.toUserId});

  final String toUserId;

  @override
  State<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends State<ReportBottomSheet> {
  final _ctrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      Fluttertoast.showToast(msg: 'Please describe the issue');
      return;
    }
    setState(() => _submitting = true);
    final session = context.read<SessionManager>();
    try {
      final res = await ApiService.reportUser({
        'fromUserId': session.userId,
        'toUserId': widget.toUserId,
        'description': text,
      });
      if (res.status) {
        Fluttertoast.showToast(msg: 'Report submitted');
        if (mounted) Navigator.pop(context);
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Failed to report');
      }
    } catch (e, s) {
      Log.e('Report', 'submit failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to report');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Report this User', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _ctrl,
          maxLines: 5,
          minLines: 3,
          decoration: const InputDecoration(
            hintText: 'Describe the issue...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7E3FF2)),
            child: _submitting
                ? const SizedBox(width: 18, height: 18, child: Preloader(strokeWidth: 2, color: Colors.white))
                : const Text('Submit Report'),
          ),
        ),
      ]),
    );
  }
}

/// Ported from native `BottomSheetReport_option.java`.
///
/// Shows options: Report, Block, Cancel.
void showUserOptionsSheet(BuildContext context, String otherUserId, String otherUserName) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(otherUserName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        ListTile(
          leading: const Icon(Icons.flag, color: Colors.orange),
          title: const Text('Report'),
          onTap: () {
            Navigator.pop(ctx);
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: ReportBottomSheet(toUserId: otherUserId),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.block, color: Colors.red),
          title: const Text('Block'),
          onTap: () async {
            Navigator.pop(ctx);
            final session = context.read<SessionManager>();
            try {
              await ApiService.blockUnblock(userId: session.userId, blockUserId: otherUserId);
              Fluttertoast.showToast(msg: 'User blocked');
            } catch (e) {
              Log.e('Options', 'block failed', e);
              Fluttertoast.showToast(msg: 'Failed to block');
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.cancel, color: Colors.grey),
          title: const Text('Cancel'),
          onTap: () => Navigator.pop(ctx),
        ),
      ]),
    ),
  );
}
