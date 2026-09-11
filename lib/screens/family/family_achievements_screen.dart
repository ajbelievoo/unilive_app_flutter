import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/family_models.dart';
import '../../services/api_service.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

class FamilyAchievementsScreen extends StatefulWidget {
  final String? familyId;

  const FamilyAchievementsScreen({super.key, this.familyId});

  @override
  State<FamilyAchievementsScreen> createState() => _FamilyAchievementsScreenState();
}

class _FamilyAchievementsScreenState extends State<FamilyAchievementsScreen> {
  final List<FamilyAchievement> _achievements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final achievements = await ApiService.getFamilyAchievements(
        familyId: widget.familyId ?? '',
      );
      if (mounted) {
        setState(() {
          _achievements.addAll(achievements);
          _loading = false;
        });
      }
    } catch (e, s) {
      Log.e('FamilyAchievements', 'load failed', e, s);
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _achievements.where((a) => a.isUnlocked).length;
    final ranking = _achievements.where((a) => a.category == 'ranking').toList();
    final battle = _achievements.where((a) => a.category == 'battle').toList();
    final activity = _achievements.where((a) => a.category == 'activity').toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0B21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text('Family Glory', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: Preloader())
          : RefreshIndicator(
              onRefresh: _load,
              color: Colors.amber,
              backgroundColor: const Color(0xFF1A1240),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 30),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildWallOfHonor(activeCount),
                    const SizedBox(height: 24),
                    _buildMedalCategories(ranking, battle, activity),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWallOfHonor(int activeCount) {
    final eventCount = _achievements.where((a) => a.category == 'event').length;
    final battleWins = _achievements
        .where((a) => a.category == 'battle' && a.isUnlocked)
        .fold(0, (sum, a) => sum + a.progress);

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
              _buildStat('$activeCount', 'Active Medals'),
              _buildStat('$eventCount', 'Event Trophies'),
              _buildStat('$battleWins', 'Battle Wins'),
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

  Widget _buildMedalCategories(List<FamilyAchievement> ranking, List<FamilyAchievement> battle, List<FamilyAchievement> activity) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _category('Ranking Medals', ranking),
          const SizedBox(height: 24),
          _category('Battle Medals', battle),
          const SizedBox(height: 24),
          _category('Activity Medals', activity),
        ],
      ),
    );
  }

  Widget _category(String title, List<FamilyAchievement> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Text('No medals in this category yet.', style: TextStyle(color: Colors.white38, fontSize: 12))
        else
          ...items.map((a) => _medal(a)),
      ],
    );
  }

  Widget _medal(FamilyAchievement a) {
    final asset = a.iconUrl;
    final icon = asset == null
        ? (a.category == 'battle' ? Icons.flash_on
            : a.category == 'activity' ? Icons.timer
            : Icons.shield)
        : null;

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
            child: asset != null && asset.isNotEmpty
                ? ClipOval(child: CachedNetworkImage(imageUrl: asset, fit: BoxFit.cover))
                : Icon(icon, color: a.isUnlocked ? Colors.amber : Colors.white24, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.name ?? 'Medal', style: TextStyle(color: a.isUnlocked ? Colors.white : Colors.white38, fontWeight: FontWeight.bold)),
                Text(a.description ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                if (a.target > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: a.progressPercent,
                        minHeight: 5,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(a.isUnlocked ? Colors.green : Colors.amber),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!a.isUnlocked)
            const Icon(Icons.lock_outline, color: Colors.white24, size: 20)
          else
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
        ],
      ),
    );
  }
}
