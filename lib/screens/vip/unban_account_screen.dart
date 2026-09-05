/// Unban Account screen — VIP 7+ self-unban feature.
///
/// Upgraded with Bigo/Chamet-style features:
/// - Ban reason display
/// - Ban history with timestamps
/// - Unban limits (e.g. 3/month)
/// - Cooldown timer between unbans
/// - Required VIP level indicator
library unban_account;

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

class UnbanAccountScreen extends StatefulWidget {
  const UnbanAccountScreen({super.key, this.targetUserId});

  final String? targetUserId;

  @override
  State<UnbanAccountScreen> createState() => _UnbanAccountScreenState();
}

class _UnbanAccountScreenState extends State<UnbanAccountScreen> {
  static const String _tag = 'UnbanAccount';
  bool _loading = true;
  bool _unbanning = false;
  BanInfo? _banInfo;
  int _userVipLevel = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
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

  Future<void> _unban() async {
    if (_unbanning) return;
    if (_banInfo != null && !_banInfo!.canUnban) {
      if (_banInfo!.cooldownUntil != null) {
        Fluttertoast.showToast(msg: 'Cooldown active. Try after ${_banInfo!.cooldownUntil}');
      } else if (_banInfo!.unbanUsed >= _banInfo!.unbanLimit) {
        Fluttertoast.showToast(msg: 'Unban limit reached (${_banInfo!.unbanLimit} per period)');
      } else {
        Fluttertoast.showToast(msg: 'Cannot unban at this time');
      }
      return;
    }
    setState(() => _unbanning = true);
    try {
      final session = context.read<SessionManager>();
      final targetId = widget.targetUserId ?? session.userId;
      final res = await ApiService.vipUnbanAccount(targetId);
      if (res.status) {
        Fluttertoast.showToast(msg: 'Account unbanned successfully');
        _loadData();
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Failed to unban');
      }
    } catch (e, s) {
      Log.e(_tag, 'unban failed', e, s);
      Fluttertoast.showToast(msg: 'Error: $e');
    } finally {
      if (mounted) setState(() => _unbanning = false);
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
              if (_userVipLevel < 7)
                _buildVipLockBanner()
              else
                Expanded(
                  child: _loading
                      ? const Center(child: Preloader())
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              _buildStatusCard(),
                              const SizedBox(height: 16),
                              if (_banInfo != null) ...[
                                _buildStatsRow(),
                                const SizedBox(height: 16),
                                if (_banInfo!.banReason != null) _buildReasonCard(),
                                if (_banInfo!.cooldownUntil != null) ...[
                                  const SizedBox(height: 16),
                                  _buildCooldownCard(),
                                ],
                                if (_banInfo!.banHistory.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  _buildHistorySection(),
                                ],
                              ],
                              const SizedBox(height: 24),
                              _buildUnbanButton(),
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
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
          const Expanded(
            child: Center(
              child: Text('Unban Account', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
      decoration: BoxDecoration(gradient: AppTheme.goldGradient, borderRadius: BorderRadius.circular(20)),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, color: Colors.white, size: 48),
          SizedBox(height: 16),
          Text('VIP 7 Required', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Upgrade to VIP 7 to unban your account', style: TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final isBanned = _banInfo?.isBanned ?? false;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isBanned ? [const Color(0xFFE74C3C), const Color(0xFF922B21)] : [const Color(0xFF27AE60), const Color(0xFF1E8449)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(isBanned ? Icons.block : Icons.check_circle, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          Text(
            isBanned ? 'Account is Banned' : 'Account is Active',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isBanned ? 'You can unban your account below' : 'Your account is in good standing',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _statCard('Unban Used', '${_banInfo!.unbanUsed}/${_banInfo!.unbanLimit}', Icons.lock_open)),
        const SizedBox(width: 12),
        Expanded(child: _statCard('Ban Count', '${_banInfo!.banCount}', Icons.block)),
        const SizedBox(width: 12),
        Expanded(child: _statCard('Required VIP', 'VIP ${_banInfo!.requiredVipLevel}', Icons.workspace_premium)),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
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

  Widget _buildReasonCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.warning, color: Colors.red, size: 18), SizedBox(width: 8), Text('Ban Reason', style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 8),
          Text(_banInfo!.banReason!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          if (_banInfo!.bannedAt != null) ...[
            const SizedBox(height: 4),
            Text('Banned at: ${_banInfo!.bannedAt}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _buildCooldownCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
      child: Row(
        children: [
          const Icon(Icons.timer, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cooldown Active', style: TextStyle(color: Colors.orange, fontSize: 14, fontWeight: FontWeight.bold)),
                Text('Try after: ${_banInfo!.cooldownUntil}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
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
        ..._banInfo!.banHistory.map((h) {
          final isBan = h.action?.toLowerCase() == 'ban';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(10)),
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
        }),
      ],
    );
  }

  Widget _buildUnbanButton() {
    final canUnban = _banInfo?.canUnban ?? false;
    final isBanned = _banInfo?.isBanned ?? false;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_unbanning || !isBanned || !canUnban) ? null : _unban,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _unbanning
            ? const SizedBox(height: 20, width: 20, child: Preloader(strokeWidth: 2, color: Colors.white))
            : Text(canUnban ? 'Unban Account' : 'Cannot Unban Now'),
      ),
    );
  }
}
