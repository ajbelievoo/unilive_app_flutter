import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../models/family_models.dart';
import '../../services/api_service.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

class FamilyBannedUsersScreen extends StatefulWidget {
  final String familyId;

  const FamilyBannedUsersScreen({super.key, required this.familyId});

  @override
  State<FamilyBannedUsersScreen> createState() => _FamilyBannedUsersScreenState();
}

class _FamilyBannedUsersScreenState extends State<FamilyBannedUsersScreen> {
  final List<FamilyBannedUser> _banned = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final list = await ApiService.getFamilyBannedUsers(familyId: widget.familyId);
      if (mounted) {
        setState(() {
          _banned
            ..clear()
            ..addAll(list);
          _loading = false;
        });
      }
    } catch (e, s) {
      Log.e('FamilyBannedUsers', 'load failed', e, s);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unban(FamilyBannedUser user) async {
    final userId = user.userId;
    if (userId == null || userId.isEmpty) return;
    try {
      final res = await ApiService.unbanFamilyMember(
        familyId: widget.familyId,
        userId: userId,
      );
      if (res.status) {
        Fluttertoast.showToast(msg: '${user.userName ?? 'User'} unbanned');
        _load();
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Unban failed');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Unban failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Banned Users'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: Preloader())
          : _banned.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _banned.length,
                    itemBuilder: (_, i) => _buildCard(_banned[i]),
                  ),
                ),
    );
  }

  Widget _buildCard(FamilyBannedUser u) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: ClipOval(
          child: SizedBox(
            width: 48,
            height: 48,
            child: u.userImage != null && u.userImage!.isNotEmpty
                ? CachedNetworkImage(imageUrl: u.userImage!, fit: BoxFit.cover)
                : const Icon(Icons.person, color: Colors.grey),
          ),
        ),
        title: Text(u.userName ?? 'Unknown'),
        subtitle: u.reason != null && u.reason!.isNotEmpty ? Text('Reason: ${u.reason}') : null,
        trailing: TextButton(
          onPressed: () => _unban(u),
          child: const Text('Unban', style: TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No banned users', style: TextStyle(fontSize: 15, color: Colors.grey)),
        ],
      ),
    );
  }
}
