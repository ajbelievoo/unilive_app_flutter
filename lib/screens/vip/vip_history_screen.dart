/// VIP History screen â€” points history + purchase records.
///
/// Ports native `VipRecordActivity.java` with two tabs.
library vip_history;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/vip_history_models.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

const String _tag = 'VipHistory';

class VipHistoryScreen extends StatefulWidget {
  const VipHistoryScreen({super.key});

  @override
  State<VipHistoryScreen> createState() => _VipHistoryScreenState();
}

class _VipHistoryScreenState extends State<VipHistoryScreen> with TickerProviderStateMixin {
  late TabController _tabCtrl;

  final _points = <VipPointsHistoryItem>[];
  final _records = <VipPurchaseRecord>[];
  bool _loadingPoints = true;
  bool _loadingRecords = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadPoints();
    _loadRecords();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPoints() async {
    final session = context.read<SessionManager>();
    try {
      final res = await ApiService.getVipPointsHistory(session.userId);
      if (mounted) setState(() => _points.addAll(res.data));
    } catch (e, s) {
      Log.e(_tag, 'points failed', e, s);
    } finally {
      if (mounted) setState(() => _loadingPoints = false);
    }
  }

  Future<void> _loadRecords() async {
    final session = context.read<SessionManager>();
    try {
      final res = await ApiService.getVipPurchaseRecords(session.userId);
      if (mounted) setState(() => _records.addAll(res.data));
    } catch (e, s) {
      Log.e(_tag, 'records failed', e, s);
    } finally {
      if (mounted) setState(() => _loadingRecords = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VIP History'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppTheme.primary,
          unselectedLabelColor: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary,
          indicatorColor: AppTheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [Tab(text: 'VIP Points'), Tab(text: 'Purchase Records')],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_pointsTab(isDark), _recordsTab(isDark)],
      ),
    );
  }

  Widget _pointsTab(bool isDark) {
    if (_loadingPoints) return const Center(child: Preloader());
    if (_points.isEmpty) return _empty(isDark, Icons.stars_outlined, 'No points history');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _points.length,
      itemBuilder: (_, i) {
        final p = _points[i];
        final isEarned = p.type == 'earned' || p.type == 'bonus';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surface : AppTheme.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: isEarned ? AppTheme.goldGradient : AppTheme.pinkGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(isEarned ? Icons.add : Icons.remove, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.description ?? p.type ?? 'VIP Points',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                      ),
                    ),
                    if (p.createdAt != null)
                      Text(
                        p.createdAt!,
                        style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary),
                      ),
                  ],
                ),
              ),
              Text(
                '${isEarned ? '+' : '-'}${formatCount(p.points)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isEarned ? AppTheme.green : Colors.red,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _recordsTab(bool isDark) {
    if (_loadingRecords) return const Center(child: Preloader());
    if (_records.isEmpty) return _empty(isDark, Icons.receipt_long_outlined, 'No purchase records');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _records.length,
      itemBuilder: (_, i) {
        final r = _records[i];
        final isActive = r.status == 'active';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surface : AppTheme.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: AppTheme.goldGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      r.tierName ?? 'VIP',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.green.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      (r.status ?? 'active').toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isActive ? AppTheme.green : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _row(isDark, 'Price', '${formatCount(r.price)} diamonds'),
              _row(isDark, 'Duration', '${r.durationValue} ${r.durationType ?? ''}'),
              if (r.purchaseDate != null) _row(isDark, 'Purchased', r.purchaseDate!),
              if (r.expiryDate != null) _row(isDark, 'Expires', r.expiryDate!),
            ],
          ),
        );
      },
    );
  }

  Widget _row(bool isDark, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary)),
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
      ),
    );
  }

  Widget _empty(bool isDark, IconData icon, String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: isDark ? AppTheme.textTertiary : Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary)),
        ],
      ),
    );
  }
}

