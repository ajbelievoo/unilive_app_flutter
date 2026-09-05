/// Family Reward screen — shows TOP1 weekly family rewards.
///
/// Items: family frames, medal, tag, page effect, vehicle, poster.
library family_reward;

import 'package:flutter/material.dart';

class FamilyRewardScreen extends StatelessWidget {
  const FamilyRewardScreen({super.key});

  static const List<_RewardItem> _rewards = [
    _RewardItem('Family Frames\n*7 days', '🏆', Color(0xFF7C4DFF)),
    _RewardItem('Medal *7 days', '🏅', Color(0xFF7C4DFF)),
    _RewardItem('Top1 Family\nTag *7 days', '👑', Color(0xFF7C4DFF)),
    _RewardItem('Family Page\nEffect *7 days', '✨', Color(0xFFFFD700)),
    _RewardItem('Vehicle *7\ndays', '🚗', Color(0xFFFFD700)),
    _RewardItem('Family TOP1\nPoster', '⭐', Color(0xFFFFD700)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF050A23), Color(0xFF0A1A4A)],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        children: [
          // Title banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4F8DFD).withValues(alpha: 0.5)),
            ),
            child: const Center(
              child: Text(
                'TOP1 Reward',
                style: TextStyle(color: Color(0xFFFFD700), fontSize: 18, fontWeight: FontWeight.bold, shadows: [
                  Shadow(color: Color(0xFFFFD700), blurRadius: 8),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _rewards.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
              childAspectRatio: 0.7,
            ),
            itemBuilder: (_, i) => _RewardCard(item: _rewards[i]),
          ),
        ],
      ),
    );
  }
}

class _RewardItem {
  final String title;
  final String emoji;
  final Color starColor;
  const _RewardItem(this.title, this.emoji, this.starColor);
}

class _RewardCard extends StatelessWidget {
  final _RewardItem item;
  const _RewardCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A237E), Color(0xFF0D47A1)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4F8DFD).withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon / emoji representation
          Expanded(
            child: Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1A4A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.5)),
                ),
                child: Center(
                  child: Text(item.emoji, style: const TextStyle(fontSize: 32)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // 5 stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (_) => Icon(Icons.star, color: item.starColor, size: 10)),
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.2),
          ),
        ],
      ),
    );
  }
}
