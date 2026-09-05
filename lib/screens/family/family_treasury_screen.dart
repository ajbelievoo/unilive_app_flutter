import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../models/family_models.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../utils/log.dart';
import '../../widgets/premium_ui.dart';
import '../../widgets/user_avatar.dart';
import 'package:belive/widgets/preloader.dart';

class FamilyTreasuryScreen extends StatefulWidget {
  const FamilyTreasuryScreen({super.key, required this.familyId});

  final String familyId;

  @override
  State<FamilyTreasuryScreen> createState() => _FamilyTreasuryScreenState();
}

class _FamilyTreasuryScreenState extends State<FamilyTreasuryScreen> {
  static const String _tag = 'FamilyTreasury';

  FamilyItem? _family;
  bool _loading = true;
  final List<FamilyMember> _topContributors = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getFamilyDetail(widget.familyId);
      if (res.status && res.data.isNotEmpty) {
        _family = res.data.first;
        _topContributors.clear();
        _topContributors.addAll(_family!.members);
        _topContributors.sort(
          (a, b) => b.contribution.compareTo(a.contribution),
        );
      }
    } catch (e) {
      Log.e(_tag, 'load failed', e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showDonateDialog() async {
    final ctrl = TextEditingController();
    final session = context.read<SessionManager>();

    final amount = await showDialog<int>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Support Your Family',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Donate Diamonds to the treasury. This helps in leveling up and purchasing premium perks.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixIcon: const Icon(Icons.diamond, color: Colors.amber),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              GradientButton(
                label: 'Donate',
                onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
                width: 100,
                height: 40,
                borderRadius: 20,
              ),
            ],
          ),
    );

    if (amount == null || amount <= 0) return;

    setState(() => _loading = true);
    final idempotencyKey =
        'family_donation_${session.userId}_${DateTime.now().microsecondsSinceEpoch}';
    try {
      final res = await ApiService.createTransaction(
        userId: session.userId,
        type: 'family_donation',
        coin: amount,
        idempotencyKey: idempotencyKey,
        description: 'Treasury donation',
      );

      if (mounted) {
        if (res.status) {
          Fluttertoast.showToast(msg: 'Thank you for your generous support!');
          _load();
        } else {
          Fluttertoast.showToast(msg: res.message ?? 'Donation failed');
          setState(() => _loading = false);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        title: const Text(
          'Family Treasury',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.receipt_long_outlined,
              color: AppTheme.primary,
            ),
            onPressed: () => Fluttertoast.showToast(msg: 'Transaction History'),
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: Preloader())
              : RefreshIndicator(
                onRefresh: _load,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBalanceCard(),
                      const SizedBox(height: 24),
                      _buildStatsRow(),
                      const SizedBox(height: 24),
                      const Text(
                        'Top Supporters',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_topContributors.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'No contributions yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ..._topContributors
                            .take(5)
                            .map((m) => _buildContributorTile(m)),
                      const SizedBox(height: 24),
                      const Text(
                        'Family Perks',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildPerksList(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6200EA), Color(0xFFC51162)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6200EA).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Total Treasury Fund',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.diamond, color: Colors.amber, size: 30),
              const SizedBox(width: 10),
              Text(
                formatCount(_family?.treasury ?? 0),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Used for level upgrades & rewards',
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _miniStat(
            'Active Members',
            '${_family?.memberCount ?? 0}',
            Icons.people,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _miniStat(
            'Daily Growth',
            '+${(_family?.level ?? 1) * 5}K',
            Icons.trending_up,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String label, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                val,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContributorTile(FamilyMember m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          UserAvatar(size: 40, imageUrl: m.image),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.name ?? 'Anonymous',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  m.role,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Icon(Icons.diamond, color: Colors.amber, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    formatCount(m.contribution),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const Text(
                'Exp Contributed',
                style: TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerksList() {
    final perks = [
      {
        'id': 'p1',
        'name': 'Family Star Badge',
        'price': 100000,
        'icon': Icons.stars,
        'color': Colors.amber,
      },
      {
        'id': 'p2',
        'name': 'Entrance Effect',
        'price': 500000,
        'icon': Icons.bolt,
        'color': Colors.blue,
      },
      {
        'id': 'p3',
        'name': 'Weekly Fund Share',
        'price': 1000000,
        'icon': Icons.account_balance,
        'color': Colors.purple,
      },
    ];

    return Column(
      children:
          perks
              .map(
                (p) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (p['color'] as Color).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          p['icon'] as IconData,
                          color: p['color'] as Color,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['name'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.diamond,
                                  color: Colors.amber,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  formatCount(p['price'] as int),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _confirmPurchase(p),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Unlock',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
    );
  }

  Future<void> _confirmPurchase(Map<String, dynamic> perk) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Confirm Purchase'),
            content: Text('Use family funds to unlock ${perk['name']}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Unlock'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      Fluttertoast.showToast(msg: 'Perk request sent to Leader');
    }
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: GradientButton(
          label: 'Donate Diamonds',
          icon: Icons.add_circle_outline,
          onPressed: _showDonateDialog,
          height: 50,
          borderRadius: 25,
        ),
      ),
    );
  }
}
