/// Coin seller redeem requests screen.
///
/// Ports native `RedeemRequestListActivity.java` with Pending / Accepted / Declined tabs.
/// Coin sellers can accept (with proof image) or decline pending requests.
library redeem_requests;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../models/redeem_request_root.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import '../../widgets/user_avatar.dart';
import 'package:belive/widgets/preloader.dart';

const String _tag = 'RedeemRequests';

class RedeemRequestsScreen extends StatefulWidget {
  const RedeemRequestsScreen({super.key});

  @override
  State<RedeemRequestsScreen> createState() => _RedeemRequestsScreenState();
}

class _RedeemRequestsScreenState extends State<RedeemRequestsScreen> with TickerProviderStateMixin {
  late TabController _tabCtrl;
  final _types = ['pending', 'solved', 'decline'];
  final _labels = ['Pending', 'Accepted', 'Declined'];

  final _data = <String, List<RedeemRequestItem>>{};
  final _loading = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) _load(_types[_tabCtrl.index]);
    });
    _load('pending');
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load(String type) async {
    if (_loading[type] == true) return;
    setState(() => _loading[type] = true);
    final session = context.read<SessionManager>();
    try {
      final res = await ApiService.getRedeemsByCoinSeller(coinSellerId: session.userId);
      if (mounted) setState(() => _data[type] = res.redeem);
    } catch (e, s) {
      Log.e(_tag, 'load $type failed', e, s);
    } finally {
      if (mounted) setState(() => _loading[type] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Redeem Requests'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppTheme.primary,
          unselectedLabelColor: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary,
          indicatorColor: AppTheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: _labels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: _types.map((t) => _body(isDark, t)).toList(),
      ),
    );
  }

  Widget _body(bool isDark, String type) {
    if (_loading[type] == true) {
      return const Center(child: Preloader());
    }
    final list = _data[type] ?? [];
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: isDark ? AppTheme.textTertiary : Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No ${_labels[_types.indexOf(type)].toLowerCase()} requests', style: TextStyle(color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _data.remove(type));
        await _load(type);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (_, i) => _RedeemCard(
          item: list[i],
          isDark: isDark,
          isPending: type == 'pending',
          onAction: () => _load(type),
        ),
      ),
    );
  }
}

class _RedeemCard extends StatelessWidget {
  const _RedeemCard({
    required this.item,
    required this.isDark,
    required this.isPending,
    required this.onAction,
  });

  final RedeemRequestItem item;
  final bool isDark;
  final bool isPending;
  final VoidCallback onAction;

  Future<void> _accept(BuildContext context) async {
    if (context.mounted) {
      try {
        final session = context.read<SessionManager>();
        await ApiService.acceptRedeemRequest(requestId: item.id ?? '', coinSellerId: session.userId);
        Fluttertoast.showToast(msg: 'Request accepted');
        onAction();
      } catch (e, s) {
        Log.e(_tag, 'accept failed', e, s);
        Fluttertoast.showToast(msg: 'Failed to accept');
      }
    }
  }

  Future<void> _decline(BuildContext context) async {
    try {
      final session = context.read<SessionManager>();
      await ApiService.declineRedeemRequest(requestId: item.id ?? '', coinSellerId: session.userId);
      Fluttertoast.showToast(msg: 'Request declined');
      onAction();
    } catch (e, s) {
      Log.e(_tag, 'decline failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to decline');
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text('Are you sure you want to delete this redeem request?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final session = context.read<SessionManager>();
    try {
      await ApiService.deleteRedeemRequest(
        redeemId: item.id ?? '',
        person: session.userId,
        type: 'user',
      );
      Fluttertoast.showToast(msg: 'Request deleted');
      onAction();
    } catch (e, s) {
      Log.e(_tag, 'delete failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to delete');
    }
  }

  Future<void> _updateStatus(BuildContext context, int newStatus) async {
    try {
      final session = context.read<SessionManager>();
      await ApiService.updateRedeemStatus(
        redeemId: item.id ?? '',
        person: session.userId,
        type: 'user',
      );
      Fluttertoast.showToast(msg: 'Status updated');
      onAction();
    } catch (e, s) {
      Log.e(_tag, 'updateStatus failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to update status');
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = item.userId;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(imageUrl: u?.image, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u?.name ?? 'User',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                      ),
                    ),
                    Text(
                      '@${u?.uniqueId ?? ''}',
                      style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary),
                    ),
                  ],
                ),
              ),
              _statusChip(),
            ],
          ),
          const SizedBox(height: 14),
          _infoRow(isDark, 'Amount', '${item.rCoin.toStringAsFixed(0)} Beans'),
          const SizedBox(height: 6),
          _infoRow(isDark, 'Gateway', item.paymentGateway ?? '-'),
          const SizedBox(height: 6),
          _infoRow(isDark, 'Date', item.date ?? item.createdAt ?? '-'),
          if (item.description?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            _infoRow(isDark, 'Note', item.description!),
          ],
          if (item.proof?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: item.proof!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _decline(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _accept(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
          if (!isPending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _delete(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Delete'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateStatus(context, 0),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Mark Pending'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip() {
    final status = item.status ?? 0;
    final (label, gradient) = switch (status) {
      0 => ('Pending', AppTheme.goldGradient),
      1 => ('In Progress', AppTheme.blueGradient),
      2 || 4 => ('Accepted', AppTheme.greenGradient),
      3 => ('Declined', const LinearGradient(colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)])),
      _ => ('Pending', AppTheme.goldGradient),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoRow(bool isDark, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

