/// Gifting Cashback screen — VIP-exclusive gifting rewards.
///
/// Bigo-style cashback — VIP users get a percentage of their gifting
/// spending back as points or coins, with monthly caps.
library gifting_cashback;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/vip_extended_models.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

class GiftingCashbackScreen extends StatefulWidget {
  const GiftingCashbackScreen({super.key});

  @override
  State<GiftingCashbackScreen> createState() => _GiftingCashbackScreenState();
}

class _GiftingCashbackScreenState extends State<GiftingCashbackScreen> {
  static const String _tag = 'GiftingCashback';
  VipCashback? _cashback;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = context.read<SessionManager>();
    setState(() => _loading = true);
    try {
      final res = await ApiService.getVipCashback(session.userId);
      if (res.status && res.data != null) {
        _cashback = res.data;
      }
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
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
              Expanded(
                child: _loading
                    ? const Center(child: Preloader())
                    : (_cashback == null)
                        ? _buildEmpty()
                        : _buildBody(),
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
              child: Text('Gifting Cashback', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.redeem_outlined, color: Colors.white38, size: 64),
          const SizedBox(height: 16),
          const Text('Cashback not available', style: TextStyle(color: Colors.white54, fontSize: 16)),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final cb = _cashback!;
    final monthlyProgress = cb.maxMonthlyCashback > 0
        ? (cb.monthlyCashbackEarned / cb.maxMonthlyCashback).clamp(0.0, 1.0)
        : 0.0;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Hero
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: AppTheme.goldGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 8))],
          ),
          child: Column(
            children: [
              const Icon(Icons.redeem, color: Colors.white, size: 56),
              const SizedBox(height: 16),
              const Text('Gifting Cashback', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                '${cb.cashbackPercent}% back on every gift',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${formatCount(cb.monthlyCashbackEarned)} ${cb.cashbackType ?? 'points'}',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text('earned this month', style: TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Monthly cap progress
        if (cb.maxMonthlyCashback > 0) ...[
          const Text('Monthly Cap Progress', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: monthlyProgress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${formatCount(cb.monthlyCashbackEarned)} earned', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              Text('${formatCount(cb.maxMonthlyCashback)} max', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 24),
        ],
        // Stats
        Row(
          children: [
            Expanded(child: _statCard('Cashback Rate', '${cb.cashbackPercent}%', Icons.percent)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Total Earned', formatCount(cb.totalCashbackEarned), Icons.savings)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Status', cb.enabled ? 'Active' : 'Inactive', cb.enabled ? Icons.check_circle : Icons.pause_circle)),
          ],
        ),
        const SizedBox(height: 24),
        // How it works
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('How It Works', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const _HowItWorksRow(icon: Icons.card_giftcard, text: 'Send gifts to hosts in live rooms'),
              const SizedBox(height: 8),
              const _HowItWorksRow(icon: Icons.percent, text: 'Get a percentage back as points or coins'),
              const SizedBox(height: 8),
              const _HowItWorksRow(icon: Icons.savings, text: 'Cashback is credited automatically'),
              const SizedBox(height: 8),
              const _HowItWorksRow(icon: Icons.timer, text: 'Monthly cap resets on the 1st of each month'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFFFD700), size: 20),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _HowItWorksRow extends StatelessWidget {
  const _HowItWorksRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFFD700), size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13))),
      ],
    );
  }
}
