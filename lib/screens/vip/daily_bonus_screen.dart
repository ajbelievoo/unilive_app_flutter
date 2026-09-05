/// Daily Bonus Claim screen — VIP daily check-in.
///
/// Chamet-style daily bonus — VIP users claim bonus points every day,
/// with streak tracking and increasing rewards.
library daily_bonus;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/vip_extended_models.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

class DailyBonusScreen extends StatefulWidget {
  const DailyBonusScreen({super.key});

  @override
  State<DailyBonusScreen> createState() => _DailyBonusScreenState();
}

class _DailyBonusScreenState extends State<DailyBonusScreen> {
  static const String _tag = 'DailyBonus';
  VipDailyBonus? _bonus;
  bool _loading = true;
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final session = context.read<SessionManager>();
    setState(() => _loading = true);
    try {
      final res = await ApiService.getVipDailyBonus(session.userId);
      if (res.status && res.data != null) {
        _bonus = res.data;
      }
    } catch (e, s) {
      Log.e(_tag, 'loadData failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _claim() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.claimVipDailyBonus(session.userId);
      if (res.status) {
        Fluttertoast.showToast(msg: 'Bonus claimed: ${res.message ?? 'Success!'}');
        _loadData();
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Claim failed');
      }
    } catch (e, s) {
      Log.e(_tag, 'claim failed', e, s);
      Fluttertoast.showToast(msg: 'Claim failed');
    } finally {
      if (mounted) setState(() => _claiming = false);
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
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _buildHeroCard(),
                            const SizedBox(height: 20),
                            _buildStreakCalendar(),
                            const SizedBox(height: 20),
                            if (_bonus?.claimHistory.isNotEmpty == true) ...[
                              _buildHistorySection(),
                              const SizedBox(height: 20),
                            ],
                          ],
                        ),
                      ),
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
              child: Text('Daily Bonus', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    final canClaim = _bonus?.canClaim ?? false;
    final todayClaimed = _bonus?.todayClaimed ?? false;
    final bonusPts = _bonus?.bonusPoints ?? 0;
    final streak = _bonus?.streak ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: canClaim ? AppTheme.goldGradient : LinearGradient(colors: [Colors.grey.shade800, Colors.grey.shade900]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: canClaim
            ? [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 6))]
            : null,
      ),
      child: Column(
        children: [
          ImageIcon(const AssetImage("assets/gift/official_gift.png"), color: canClaim ? Colors.white : Colors.white38, size: 56),
          const SizedBox(height: 16),
          Text(
            todayClaimed ? 'Claimed Today!' : (canClaim ? 'Bonus Available!' : 'Come Back Tomorrow'),
            style: TextStyle(color: canClaim ? Colors.white : Colors.white54, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.stars, color: Color(0xFFFFD700), size: 20),
              const SizedBox(width: 4),
              Text(
                '${formatCount(bonusPts)} points',
                style: const TextStyle(color: Color(0xFFFFD700), fontSize: 24, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (streak > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_fire_department, color: Color(0xFFFF6B35), size: 16),
                const SizedBox(width: 4),
                Text('$streak day streak', style: const TextStyle(color: Color(0xFFFF6B35), fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          const SizedBox(height: 20),
          if (canClaim)
            GestureDetector(
              onTap: _claiming ? null : _claim,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: _claiming
                    ? const SizedBox(width: 20, height: 20, child: Preloader(strokeWidth: 2, color: Colors.black))
                    : const Text('Claim Now', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            )
          else if (todayClaimed)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 6),
                Text('See you tomorrow!', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStreakCalendar() {
    final streak = _bonus?.streak ?? 0;
    final nextBonus = _bonus?.nextBonusPoints ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('7-Day Streak Rewards', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final day = i + 1;
              final isClaimed = i < streak;
              final isToday = i == streak;
              return Column(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isClaimed ? AppTheme.goldGradient : null,
                      color: isClaimed ? null : (isToday ? AppTheme.primary.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05)),
                      border: isToday ? Border.all(color: AppTheme.primary, width: 2) : null,
                    ),
                    child: Center(
                      child: isClaimed
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : Text('$day', style: TextStyle(color: isToday ? AppTheme.primary : Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Day $day', style: TextStyle(color: Colors.white38, fontSize: 9)),
                ],
              );
            }),
          ),
          if (nextBonus > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.arrow_forward, color: AppTheme.primary, size: 16),
                const SizedBox(width: 8),
                Text('Next day bonus: ${formatCount(nextBonus)} points', style: const TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Claim History', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ..._bonus!.claimHistory.map((h) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.redeem, color: Color(0xFFFFD700), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(h.date ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ),
                  Text('+${formatCount(h.points)}', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            )),
      ],
    );
  }
}
