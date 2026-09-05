import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../utils/format_utils.dart';
import '../../theme/app_theme.dart';

/// Family Level Screen — Shows current family level, progress, identity perks per level,
/// and privileges table (members/co-leaders limits).
class FamilyLevelScreen extends StatelessWidget {
  final int level;
  final int currentExp;
  final int nextLevelExp;
  final String familyName;

  const FamilyLevelScreen({
    super.key,
    this.level = 1,
    this.currentExp = 0,
    this.nextLevelExp = 0,
    this.familyName = 'Family',
  });

  @override
  Widget build(BuildContext context) {
    final progress = nextLevelExp > 0 ? (currentExp / nextLevelExp).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0B21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'Family Growth',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: () => context.pushNamed(AppRoutes.familyLevelRules),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0B6E), Color(0xFF0F0B21)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              // Top Shield & Level Badge
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withValues(alpha:0.2),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.shield, size: 100, color: Color(0xFFFFC107)),
                        ),
                        Positioned(
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: AppTheme.blueGradient,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Text(
                              'Lv.$level',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Family Tag Ribbon
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: AppTheme.purpleGradient,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha:0.5), width: 1),
                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
                      ),
                      child: Text(
                        familyName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Progress Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 18,
                                  backgroundColor: Colors.white12,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                                ),
                              ),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Exp: ${formatCount(currentExp)}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              Text(
                                'Next: ${formatCount(nextLevelExp)}',
                                style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Header text
              const Text(
                'Reach higher levels to unlock premium family features and global recognition.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 30),

              // Section 1: Family Identity
              _buildSectionHeader('Level Rewards'),
              const SizedBox(height: 16),

              _buildIdentityTier(1),
              const SizedBox(height: 12),
              _buildIdentityTier(5),
              const SizedBox(height: 12),
              _buildIdentityTier(10),
              const SizedBox(height: 12),
              _buildIdentityTier(15),
              const SizedBox(height: 24),

              // Section 2: Privileges Table
              _buildSectionHeader('Management Privileges'),
              const SizedBox(height: 16),

              _buildPrivilegesTable(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Colors.white12, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Colors.white12, thickness: 1)),
      ],
    );
  }

  Widget _buildIdentityTier(int tierLevel) {
    bool isUnlocked = level >= tierLevel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isUnlocked ? const Color(0xFFFFD700).withValues(alpha:0.3) : Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Unlock at Lv.$tierLevel',
                style: TextStyle(
                  color: isUnlocked ? const Color(0xFFFFD700) : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (isUnlocked)
                const Icon(Icons.check_circle, color: Colors.green, size: 18)
              else
                const Icon(Icons.lock, color: Colors.white24, size: 16),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPerkItem(Icons.label, 'Family Tag', isUnlocked),
              _buildPerkItem(Icons.filter_vintage, 'Family Frame', isUnlocked),
              _buildPerkItem(Icons.image, 'Custom BG', isUnlocked),
              _buildPerkItem(Icons.military_tech, 'Family Medal', isUnlocked),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerkItem(IconData icon, String label, bool active) {
    return SizedBox(
      width: 70,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF1E1410) : Colors.black26,
              shape: BoxShape.circle,
              border: Border.all(color: active ? const Color(0xFFFFC107).withValues(alpha:0.5) : Colors.white10),
            ),
            child: Icon(icon, color: active ? const Color(0xFFFFC107) : Colors.white12, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(color: active ? Colors.white70 : Colors.white12, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivilegesTable() {
    final privilegesData = [
      {'level': 1, 'members': 50, 'coLeaders': 5},
      {'level': 5, 'members': 300, 'coLeaders': 9},
      {'level': 10, 'members': 900, 'coLeaders': 14},
      {'level': 15, 'members': 1650, 'coLeaders': 24},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.07),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: const Row(
              children: [
                Expanded(child: Text('Level', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 13))),
                Expanded(child: Text('Max Members', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 13))),
                Expanded(child: Text('Co-Leaders', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 13))),
              ],
            ),
          ),
          // Table Rows
          ...privilegesData.map((row) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(child: Text('${row['level']}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14))),
                  Expanded(child: Text('${row['members']}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
                  Expanded(child: Text('${row['coLeaders']}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
