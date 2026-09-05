import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/family_models.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

class FamilyMembersScreen extends StatefulWidget {
  final String familyId;
  final String? familyName;
  final String? userRole;

  const FamilyMembersScreen({
    super.key,
    required this.familyId,
    this.familyName,
    this.userRole,
  });

  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  static const _tag = 'FamilyMembersScreen';

  bool _loading = true;
  List<FamilyMember> _members = [];
  List<FamilyMember> _filteredMembers = [];
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService.getFamilyMembers(widget.familyId);
      if (res.status) {
        List<FamilyMember> raw = [];
        if (res.data.isNotEmpty) {
          raw = List<FamilyMember>.from(res.data.first.members);
        }

        raw.sort((a, b) {
          int roleScore(String r) => switch (r.toLowerCase()) {
            'leader' => 0,
            'co-leader' => 1,
            _ => 2,
          };
          final rComp = roleScore(a.role).compareTo(roleScore(b.role));
          if (rComp != 0) return rComp;
          return b.contribution.compareTo(a.contribution);
        });
        if (mounted) {
          setState(() {
            _members = raw;
            _applyFilter();
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e, s) {
      Log.e(_tag, 'loadMembers failed', e, s);
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredMembers = List.from(_members);
    } else {
      _filteredMembers = _members
          .where((m) => (m.name ?? '').toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        title: Text(widget.familyName ?? 'Family Members', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: AppTheme.primary),
            onPressed: () => Fluttertoast.showToast(msg: 'Activity Records'),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _loading
                ? const Center(child: Preloader())
                : _filteredMembers.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadMembers,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _filteredMembers.length,
                itemBuilder: (context, index) {
                  final m = _filteredMembers[index];
                  return _buildMemberTile(m, index + 1);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) {
          setState(() {
            _searchQuery = v;
            _applyFilter();
          });
        },
        decoration: InputDecoration(
          hintText: 'Search member by name...',
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(_searchQuery.isNotEmpty ? 'No matches for "$_searchQuery"' : 'No members found',
              style: const TextStyle(color: Colors.grey, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildMemberTile(FamilyMember m, int rank) {
    final isLeader = m.role.toLowerCase() == 'leader';
    final isCoLeader = m.role.toLowerCase() == 'co-leader';
    final isMe = m.userId == context.read<SessionManager>().userId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () {
          context.pushNamed(AppRoutes.guestProfile, extra: {
            'userId': m.userId ?? m.id,
            'username': m.name,
          });
        },
        leading: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isLeader ? Colors.amber : (isCoLeader ? Colors.tealAccent : Colors.transparent),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: m.avatar != null && m.avatar!.isNotEmpty
                    ? CachedNetworkImage(imageUrl: m.avatar!, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.grey))
                    : const Icon(Icons.person, color: Colors.grey),
              ),
            ),
            if (rank <= 3 && _searchQuery.isEmpty)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: rank == 1 ? Colors.amber : (rank == 2 ? Colors.blueGrey : Colors.brown),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Text('$rank', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                (m.name == null || m.name!.isEmpty) ? 'Member' : m.name!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isMe ? AppTheme.primary : Colors.black87),
              ),
            ),
            const SizedBox(width: 6),
            if (isLeader || isCoLeader) _roleBadge(m.role),
            if (isMe) ...[
              const SizedBox(width: 4),
              const Text('(You)', style: TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                _levelBadge(m.level),
                const SizedBox(width: 8),
                const Icon(Icons.diamond, color: Colors.amber, size: 12),
                const SizedBox(width: 2),
                Text(formatCount(m.contribution), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
              ],
            ),
          ],
        ),
        trailing: widget.userRole?.toLowerCase() == 'leader' && !isLeader
            ? IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showMemberActions(m),
        )
            : const Icon(Icons.chevron_right, size: 18, color: Colors.black26),
      ),
    );
  }

  Widget _roleBadge(String role) {
    final isLeader = role.toLowerCase() == 'leader';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: isLeader
            ? const LinearGradient(colors: [Color(0xFFFFC107), Color(0xFFFF8F00)])
            : const LinearGradient(colors: [Color(0xFF26A69A), Color(0xFF00796B)]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isLeader ? 'Leader' : 'Co-Leader',
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _levelBadge(int level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Lv.$level',
        style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showMemberActions(FamilyMember m) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Manage ${m.name ?? "Member"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ),
            if (m.role == 'member')
              ListTile(
                leading: const Icon(Icons.arrow_upward, color: Colors.green),
                title: const Text('Promote to Co-Leader'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ApiService.updateMemberRole(
                      familyId: widget.familyId,
                      leaderId: context.read<SessionManager>().userId,
                      memberId: m.userId ?? '',
                      role: 'co-leader',
                    );
                    Fluttertoast.showToast(msg: 'Promoted!');
                    _loadMembers();
                  } catch (e) { Fluttertoast.showToast(msg: 'Operation failed'); }
                },
              ),
            if (m.role == 'co-leader')
              ListTile(
                leading: const Icon(Icons.arrow_downward, color: Colors.orange),
                title: const Text('Demote to Member'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ApiService.updateMemberRole(
                      familyId: widget.familyId,
                      leaderId: context.read<SessionManager>().userId,
                      memberId: m.userId ?? '',
                      role: 'member',
                    );
                    Fluttertoast.showToast(msg: 'Demoted!');
                    _loadMembers();
                  } catch (e) { Fluttertoast.showToast(msg: 'Operation failed'); }
                },
              ),
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.red),
              title: const Text('Kick from Family', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                final leaderId = context.read<SessionManager>().userId;
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const Text('Kick Member?'),
                    content: Text('Remove ${m.name} from the family?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Kick', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await ApiService.kickMember(
                      familyId: widget.familyId,
                      leaderId: leaderId,
                      memberId: m.userId ?? '',
                    );
                    Fluttertoast.showToast(msg: 'Kicked');
                    _loadMembers();
                  } catch (e) { Fluttertoast.showToast(msg: 'Operation failed'); }
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
