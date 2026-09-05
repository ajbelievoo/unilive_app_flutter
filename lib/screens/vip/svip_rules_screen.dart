/// SVIP Rules screen — ported from native `SvipRulesActivity.java`.
///
/// Features:
/// - Fetches VIP level points and bonus points from API
/// - Displays two tables: Level Points & Bonus Points
/// - Falls back to hardcoded default data when API fails
/// - Premium gold-themed UI with alternating row colors
library svip_rules;
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import '../../widgets/premium_ui.dart';

class SvipRulesScreen extends StatefulWidget {
  const SvipRulesScreen({super.key});

  @override
  State<SvipRulesScreen> createState() => _SvipRulesScreenState();
}

class _SvipRulesScreenState extends State<SvipRulesScreen> {
  static const String _tag = 'SvipRules';
  bool _loading = true;
  List<_LevelItem> _levelPoints = [];
  List<_LevelItem> _bonusPoints = [];
  String _rulesText = '';
  List<Map<String, dynamic>> _privileges = [];

  static const String _defaultRulesText =
      'VIP membership gives you exclusive badges, frames, chat colors, entrance effects, and premium privileges. '
      'Purchase any VIP plan to activate it for 30 days. Higher VIP levels unlock more rewards, '
      'monthly points, bonus points, and special profile visibility. Stay active to maintain your VIP status.';

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getVipRules();
      _rulesText = res['rules']?.toString() ?? res['description']?.toString() ?? '';

      final privs = res['privileges'] as List?;
      _privileges = privs?.map((e) => e as Map<String, dynamic>).toList() ?? [];

      final levels = res['levels'] as List?;
      final bonuses = res['bonusPoints'] as List?;

      _levelPoints = levels != null
          ? levels.map((e) {
              final m = e as Map<String, dynamic>;
              return _LevelItem(
                m['level']?.toString() ?? m['name']?.toString() ?? 'VIP',
                _formatPoints(m['minPoints']?.toString() ?? m['points']?.toString() ?? '0'),
              );
            }).toList()
          : _defaultLevelPoints();

      _bonusPoints = bonuses != null
          ? bonuses.map((e) {
              final m = e as Map<String, dynamic>;
              return _LevelItem(
                m['level']?.toString() ?? m['name']?.toString() ?? 'VIP',
                _formatPoints(m['bonusPoints']?.toString() ?? m['points']?.toString() ?? '0'),
              );
            }).toList()
          : _defaultBonusPoints();

      if (_levelPoints.isEmpty) _levelPoints = _defaultLevelPoints();
      if (_bonusPoints.isEmpty) _bonusPoints = _defaultBonusPoints();
    } catch (e, s) {
      Log.e(_tag, 'loadRules failed', e, s);
      _levelPoints = _defaultLevelPoints();
      _bonusPoints = _defaultBonusPoints();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatPoints(String points) {
    try {
      final val = int.parse(points.replaceAll(RegExp(r'[^0-9]'), ''));
      return val.toString();
    } catch (_) {
      return points;
    }
  }

  List<_LevelItem> _defaultLevelPoints() => [
    _LevelItem('VIP1', '6,000,000'),
    _LevelItem('VIP2', '18,000,000'),
    _LevelItem('VIP3', '60,000,000'),
    _LevelItem('VIP4', '150,000,000'),
    _LevelItem('VIP5', '300,000,000'),
    _LevelItem('VIP6', '600,000,000'),
    _LevelItem('VIP7', '1,020,000,000'),
    _LevelItem('VIP8', '1,620,000,000'),
    _LevelItem('VIP9', '2,700,000,000'),
  ];

  List<_LevelItem> _defaultBonusPoints() => [
    _LevelItem('VIP1', '1,800,000'),
    _LevelItem('VIP2', '6,000,000'),
    _LevelItem('VIP3', '24,000,000'),
    _LevelItem('VIP4', '66,000,000'),
    _LevelItem('VIP5', '150,000,000'),
    _LevelItem('VIP6', '300,000,000'),
    _LevelItem('VIP7', '600,000,000'),
    _LevelItem('VIP8', '1,020,000,000'),
    _LevelItem('VIP9', '1,620,000,000'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('VIP Rules')),
      body: _loading
          ? const Center(child: PremiumLoading())
          : RefreshIndicator(
              onRefresh: _loadRules,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildInfoSection(isDark),
                  const SizedBox(height: 20),
                  _buildPointsTable('VIP Level Points', _levelPoints, isDark),
                  const SizedBox(height: 16),
                  _buildPointsTable('Daily Bonus Points', _bonusPoints, isDark),
                  const SizedBox(height: 20),
                  if (_privileges.isNotEmpty) ...[
                    const Text('Privileges', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ..._privileges.map((p) => _privilegeCard(p)),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoSection(bool isDark) {
    final rules = [
      'VIP plans are valid for 30 days from purchase.',
      'Each VIP level unlocks unique badge, frame, and entrance effects.',
      'Monthly points are earned by sending and receiving gifts.',
      'Bonus points refresh daily based on your current VIP level.',
      'Higher VIP levels get priority support, anti-kick, and room visibility.',
      'Recharge diamonds to buy or renew your VIP membership.',
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.goldGradient.colors.first.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Important Rules',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rules.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Icon(Icons.check_circle, color: AppTheme.primary, size: 14),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(r, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87, height: 1.4))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.goldGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          const Icon(Icons.workspace_premium, color: Colors.white, size: 56),
          const SizedBox(height: 12),
          const Text(
            'VIP Membership',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _rulesText.isNotEmpty ? _rulesText : _defaultRulesText,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsTable(String title, List<_LevelItem> items, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.goldGradient.colors.first.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: AppTheme.goldGradient,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          ...items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: i % 2 == 0
                    ? (isDark ? const Color(0xFF2A2520) : const Color(0xFFFFF8E1))
                    : (isDark ? const Color(0xFF1F1B17) : const Color(0xFFFFFDE7)),
                borderRadius: i == items.length - 1
                    ? const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      )
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          gradient: AppTheme.goldGradient,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        item.level,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    item.points,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _privilegeCard(Map<String, dynamic> p) {
    final title = p['title']?.toString() ?? p['name']?.toString() ?? 'Privilege';
    final desc = p['description']?.toString() ?? p['desc']?.toString() ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: AppTheme.goldGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.workspace_premium, color: Colors.white, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: desc.isNotEmpty ? Text(desc, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)) : null,
      ),
    );
  }
}

class _LevelItem {
  final String level;
  final String points;
  _LevelItem(this.level, this.points);
}
