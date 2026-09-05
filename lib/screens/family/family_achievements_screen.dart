import 'package:flutter/material.dart';

class FamilyAchievementsScreen extends StatelessWidget {
  const FamilyAchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0B21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text('Family Glory', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildWallOfHonor(),
            const SizedBox(height: 24),
            _buildMedalCategories(),
          ],
        ),
      ),
    );
  }

  Widget _buildWallOfHonor() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1E5C), Color(0xFF1A1240)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha:0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.amber.withValues(alpha:0.1), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.workspace_premium, color: Colors.amber, size: 60),
          const SizedBox(height: 16),
          const Text(
            'Family Achievements',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Collect medals by participating in events and climbing the rankings.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('0', 'Active Medals'),
              _buildStat('0', 'Event Trophies'),
              _buildStat('0', 'Battle Wins'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildMedalCategories() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _category('Ranking Medals', [
            _medal('Weekly Top 1', 'Highest honor for family ranking.', 'assets/family/tag_family_top1.png', locked: true),
            _medal('Weekly Top 2', 'Family rank 2 globally.', 'assets/family/tag_family_top2.png', locked: true),
            _medal('Weekly Top 3', 'Family rank 3 globally.', 'assets/family/tag_family_top3.png', locked: true),
          ]),
          const SizedBox(height: 24),
          _category('Battle Medals', [
            _medal('War Lord', 'Win 50 Family PK Battles.', null, icon: Icons.flash_on, locked: true),
            _medal('Unstoppable', '10-win streak in Family battles.', null, icon: Icons.trending_up, locked: true),
          ]),
          const SizedBox(height: 24),
          _category('Activity Medals', [
            _medal('Super Active', 'All members checked in for 7 days.', null, icon: Icons.timer, locked: true),
            _medal('Golden Treasury', 'Reach 1M diamonds in Treasury.', null, icon: Icons.account_balance_wallet, locked: true),
          ]),
        ],
      ),
    );
  }

  Widget _category(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...items,
      ],
    );
  }

  Widget _medal(String name, String desc, String? asset, {IconData? icon, bool locked = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.1),
              shape: BoxShape.circle,
            ),
            child: asset != null 
                ? Opacity(opacity: locked ? 0.3 : 1.0, child: Image.asset(asset))
                : Icon(icon ?? Icons.shield, color: locked ? Colors.white24 : Colors.amber, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(color: locked ? Colors.white38 : Colors.white, fontWeight: FontWeight.bold)),
                Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          if (locked)
            const Icon(Icons.lock_outline, color: Colors.white24, size: 20)
          else
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
        ],
      ),
    );
  }
}
