/// CP Milestones screen — anniversaries and unlockable couple milestones.
library cp_milestones;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/cp_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/premium_ui.dart';

class CPMilestonesScreen extends StatefulWidget {
  const CPMilestonesScreen({super.key, required this.cpId});
  final String cpId;

  @override
  State<CPMilestonesScreen> createState() => _CPMilestonesScreenState();
}

class _CPMilestonesScreenState extends State<CPMilestonesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<CpProvider>().loadMilestones(widget.cpId);
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CpProvider>();
    final ms = cp.milestones;
    final unlocked = ms.where((m) => m.isUnlocked).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Milestones', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              background: Container(
                decoration: const BoxDecoration(gradient: AppTheme.pinkGradient),
                child: const Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Opacity(
                      opacity: 0.35,
                      child: Image(
                        image: AssetImage('assets/cp_friend/heart_tow.png'),
                        width: 80,
                        height: 50,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(20), boxShadow: AppTheme.cardShadow),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat('Unlocked', '$unlocked', AppTheme.green),
                    Container(width: 1, height: 30, color: AppTheme.surfaceVariant),
                    _stat('Total', '${ms.length}', AppTheme.primary),
                    Container(width: 1, height: 30, color: AppTheme.surfaceVariant),
                    _stat('Progress', ms.isEmpty ? '0%' : '${(unlocked / ms.length * 100).round()}%', const Color(0xFFE84B8A)),
                  ],
                ),
              ),
            ),
          ),
          if (ms.isEmpty)
            const SliverFillRemaining(child: EmptyState(icon: Icons.celebration_outlined, title: 'No Milestones Yet', subtitle: 'Celebrate your 7-day, 30-day, 100-day and 1-year anniversaries together!'))
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _MilestoneTile(m: ms[i], isLast: i == ms.length - 1),
                childCount: ms.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({required this.m, required this.isLast});
  final dynamic m;
  final bool isLast;

  bool get unlocked => m.isUnlocked as bool;
  String get title => m.title as String? ?? 'Milestone';
  String? get description => m.description as String?;
  String? get date => m.date as String?;
  String? get icon => m.icon as String?;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot + line
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: unlocked ? AppTheme.pinkGradient : null,
                    color: unlocked ? null : AppTheme.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(unlocked ? Icons.favorite : Icons.lock_outline, color: unlocked ? Colors.white : AppTheme.textTertiary, size: 16),
                ),
                if (!isLast) Container(width: 2, height: 50, color: unlocked ? const Color(0xFFE84B8A).withValues(alpha: 0.3) : AppTheme.surfaceVariant),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: unlocked ? Border.all(color: const Color(0xFFE84B8A).withValues(alpha: 0.3), width: 1) : null,
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                      if (unlocked)
                        const Icon(Icons.check_circle, color: AppTheme.green, size: 18),
                    ],
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 4),
                    Text(description!, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                  if (date != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 12, color: AppTheme.textTertiary),
                        const SizedBox(width: 4),
                        Text(date!, style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
