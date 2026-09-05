import 'package:flutter/material.dart';

/// Family Level Rules Screen — Displays detailed explanation of family levels,
/// how to gain Exp, sign-in bonuses, gifting Exp, and privileges.
class FamilyLevelRulesScreen extends StatelessWidget {
  const FamilyLevelRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1410),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'Family Level Rules',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('1. What is the Family level?'),
            const SizedBox(height: 8),
            _buildSectionBody(
              'Family level represents the strength of a family. The stronger the family, the higher the level.',
            ),
            const SizedBox(height: 20),

            _buildSectionTitle('2. How to improve the Family level?'),
            const SizedBox(height: 8),
            _buildSectionBody(
              'All family members can contribute family Exp by completing daily family tasks. '
              'Accumulated Exp will help level up the family. Click on the Task & Reward module to '
              'participate in daily tasks and earn exclusive rewards.',
            ),
            const SizedBox(height: 20),

            _buildSectionTitle('3. How to increase the Family Exp?'),
            const SizedBox(height: 8),
            _buildBulletPoint('Sign in Family:', '+5Exp, +15Exp for SVIP3+ users'),
            const SizedBox(height: 6),
            _buildBulletPoint(
              'Send gifts :',
              'send to Family member: 600 diamonds = 2 Exp\n'
              'send to non-family member: 600 diamonds = 1 Exp',
            ),
            const SizedBox(height: 6),
            _buildBulletPoint(
              'On mic in Family member room for 5 minutes:',
              '5 mins = 50 Exp, maximum 600 Exp per user per day. '
              'The upper limit of the total Exp added every week is 5,000,000, and the excess will not increase the Family Exp.',
            ),
            const SizedBox(height: 20),

            _buildSectionTitle('4. What can the Family level upgrade bring?'),
            const SizedBox(height: 8),
            _buildSectionBody(
              'As the family level increases, the maximum number of family members and co-leaders will also increase. '
              'At the same time, the family medal, family tag, family frame, and family page background will be updated with the level, '
              'showcasing the family\'s identity.',
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFFFD700), // Gold
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSectionBody(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 14,
        height: 1.5,
      ),
    );
  }

  Widget _buildBulletPoint(String label, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '· $label',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
