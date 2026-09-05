/// Ban Account screen — VIP 9+ room moderation feature.
///
/// Lets VIP 9+ users ban/unban other users from their rooms or the platform.
/// Ports native `BanAccountActivity.java` with Bigo-style ban management.
library ban_account;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/vip_extended_models.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

class BanAccountScreen extends StatefulWidget {
  const BanAccountScreen({
    super.key,
    this.targetUserId,
    this.targetUserName,
    this.targetUserImage,
    this.onBan,
    this.onUnban,
  });

  final String? targetUserId;
  final String? targetUserName;
  final String? targetUserImage;
  final VoidCallback? onBan;
  final VoidCallback? onUnban;

  @override
  State<BanAccountScreen> createState() => _BanAccountScreenState();
}

class _BanAccountScreenState extends State<BanAccountScreen> {
  static const String _tag = 'BanAccount';
  bool _loading = true;
  bool _actionLoading = false;
  BanInfo? _banInfo;
  final _reasonCtrl = TextEditingController();
  int _userVipLevel = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final session = context.read<SessionManager>();
    final user = session.getUser();
    _userVipLevel = _extractVipLevel(user);
    setState(() => _loading = true);
    try {
      final targetId = widget.targetUserId ?? session.userId;
      final res = await ApiService.getBanInfo(targetId);
      if (res.status && res.data != null) {
        _banInfo = res.data;
      }
    } catch (e, s) {
      Log.e(_tag, 'loadData failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _extractVipLevel(dynamic user) {
    try {
      final u = user as dynamic;
      final status = u?.vipStatus;
      if (status != null && status.currentLevel > 0) return status.currentLevel;
      final vipInfo = u?.vip;
      final tierId = vipInfo?.tierId?.toString() ?? '';
      final digits = tierId.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isEmpty) return 0;
      return int.parse(digits);
    } catch (_) {
      return 0;
    }
  }

  Future<void> _banUser() async {
    if (_actionLoading) return;
    if (widget.targetUserId == null || widget.targetUserId!.isEmpty) {
      Fluttertoast.showToast(msg: 'No target user specified');
      return;
    }
    setState(() => _actionLoading = true);
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.vipBanUser(
        adminUserId: session.userId,
        targetUserId: widget.targetUserId!,
        reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
      );
      if (res.status) {
        Fluttertoast.showToast(msg: 'User banned successfully');
        widget.onBan?.call();
        _loadData();
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Ban failed');
      }
    } catch (e, s) {
      Log.e(_tag, 'banUser failed', e, s);
      Fluttertoast.showToast(msg: 'Ban failed');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _unbanUser() async {
    if (_actionLoading) return;
    if (widget.targetUserId == null || widget.targetUserId!.isEmpty) return;
    setState(() => _actionLoading = true);
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.vipUnbanAccount(widget.targetUserId!);
      if (res.status) {
        Fluttertoast.showToast(msg: 'User unbanned successfully');
        widget.onUnban?.call();
        _loadData();
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Unban failed');
      }
    } catch (e, s) {
      Log.e(_tag, 'unbanUser failed', e, s);
      Fluttertoast.showToast(msg: 'Unban failed');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              if (_userVipLevel < 9)
                _buildVipLockBanner()
              else
                Expanded(
                  child: _loading
                      ? const Center(child: Preloader())
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _buildTargetCard(),
                              const SizedBox(height: 16),
                              if (_banInfo != null) ...[
                                _buildBanStatusCard(),
                                const SizedBox(height: 16),
                                _buildBanStats(),
                                const SizedBox(height: 16),
                                if (_banInfo!.banHistory.isNotEmpty) ...[
                                  _buildHistorySection(),
                                  const SizedBox(height: 16),
                                ],
                              ],
                              _buildActionSection(),
                            ],
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          const Expanded(
            child: Center(
              child: Text('Ban Account', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildVipLockBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.goldGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, color: Colors.white, size: 48),
          SizedBox(height: 16),
          Text('VIP 9 Required', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Upgrade to VIP 9 to ban/unban accounts', style: TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildTargetCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 56, height: 56,
              child: (widget.targetUserImage != null && widget.targetUserImage!.isNotEmpty)
                  ? CachedNetworkImage(imageUrl: widget.targetUserImage!, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: Colors.grey.shade800, child: const Icon(Icons.person, color: Colors.white54)))
                  : Container(color: Colors.grey.shade800, child: const Icon(Icons.person, color: Colors.white54)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.targetUserName ?? 'Unknown User', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('ID: ${widget.targetUserId ?? 'N/A'}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanStatusCard() {
    final isBanned = _banInfo!.isBanned;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isBanned
              ? [const Color(0xFFE74C3C), const Color(0xFF922B21)]
              : [const Color(0xFF27AE60), const Color(0xFF1E8449)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(isBanned ? Icons.block : Icons.check_circle, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBanned ? 'Account is Banned' : 'Account is Active',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (isBanned && _banInfo!.banReason != null) ...[
                  const SizedBox(height: 4),
                  Text('Reason: ${_banInfo!.banReason}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
                if (isBanned && _banInfo!.bannedAt != null) ...[
                  const SizedBox(height: 2),
                  Text('Banned at: ${_banInfo!.bannedAt}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanStats() {
    return Row(
      children: [
        Expanded(child: _statCard('Ban Count', '${_banInfo!.banCount}', Icons.block)),
        const SizedBox(width: 12),
        Expanded(child: _statCard('Unban Used', '${_banInfo!.unbanUsed}/${_banInfo!.unbanLimit}', Icons.lock_open)),
        const SizedBox(width: 12),
        Expanded(child: _statCard('Required VIP', 'VIP ${_banInfo!.requiredVipLevel}', Icons.workspace_premium)),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ban History', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ..._banInfo!.banHistory.map((h) => _historyItem(h)),
      ],
    );
  }

  Widget _historyItem(BanHistoryItem h) {
    final isBan = h.action?.toLowerCase() == 'ban';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(isBan ? Icons.block : Icons.lock_open, color: isBan ? const Color(0xFFE74C3C) : const Color(0xFF27AE60), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.action?.toUpperCase() ?? 'ACTION', style: TextStyle(color: isBan ? const Color(0xFFE74C3C) : const Color(0xFF27AE60), fontSize: 12, fontWeight: FontWeight.bold)),
                if (h.reason != null) Text(h.reason!, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                if (h.date != null) Text(h.date!, style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection() {
    final isBanned = _banInfo?.isBanned ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isBanned) ...[
          TextField(
            controller: _reasonCtrl,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Ban Reason (optional)',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
        ],
        ElevatedButton.icon(
          onPressed: _actionLoading ? null : (isBanned ? _unbanUser : _banUser),
          icon: _actionLoading
              ? const SizedBox(width: 18, height: 18, child: Preloader(strokeWidth: 2, color: Colors.white))
              : Icon(isBanned ? Icons.lock_open : Icons.block),
          label: Text(isBanned ? 'Unban Account' : 'Ban Account'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isBanned ? AppTheme.green : const Color(0xFFE74C3C),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
