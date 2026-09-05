/// VIP Tier Comparison screen — Bigo-style feature × tier matrix.
///
/// Shows all VIP features in a table with checkmarks per tier, so users
/// can easily compare what each VIP level offers.
library vip_tier_comparison;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/vip_extended_models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

class VipTierComparisonScreen extends StatefulWidget {
  const VipTierComparisonScreen({super.key});

  @override
  State<VipTierComparisonScreen> createState() => _VipTierComparisonScreenState();
}

class _VipTierComparisonScreenState extends State<VipTierComparisonScreen> {
  static const String _tag = 'VipComparison';
  VipTierComparison? _matrix;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getVipTierComparison();
      if (res.status && res.matrix != null) {
        _matrix = res.matrix;
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
                    : (_matrix == null || _matrix!.features.isEmpty)
                        ? _buildEmpty()
                        : _buildTable(),
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
              child: Text('Compare VIP Tiers', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
          const Icon(Icons.compare_arrows, color: Colors.white38, size: 64),
          const SizedBox(height: 16),
          const Text('No comparison data', style: TextStyle(color: Colors.white54, fontSize: 16)),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildTable() {
    final features = _matrix!.features;
    final tiers = _matrix!.tiers;
    final screenWidth = MediaQuery.of(context).size.width;
    final firstColWidth = 120.0;
    final tierColWidth = (screenWidth - firstColWidth - 32) / tiers.length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              SizedBox(
                width: firstColWidth,
                child: const Text('Feature', style: TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.bold)),
              ),
              ...tiers.map((t) => SizedBox(
                    width: tierColWidth,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: AppTheme.goldGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          t.name ?? 'VIP${t.level}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  )),
            ],
          ),
          const SizedBox(height: 8),
          // Feature rows
          ...features.map((f) => Container(
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: firstColWidth,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(f.name ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                    ),
                    ...tiers.map((t) {
                      final hasFeature = t.values[f.key] == true || t.values[f.name] == true;
                      return SizedBox(
                        width: tierColWidth,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              hasFeature ? Icons.check_circle : Icons.remove_circle_outline,
                              color: hasFeature ? const Color(0xFF27AE60) : Colors.white24,
                              size: 18,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
