import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/call_rate_provider.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import 'package:belive/widgets/preloader.dart';

class CallRateSettingsScreen extends StatefulWidget {
  const CallRateSettingsScreen({super.key});

  @override
  State<CallRateSettingsScreen> createState() => _CallRateSettingsScreenState();
}

class _CallRateSettingsScreenState extends State<CallRateSettingsScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<CallRateProvider>();
    final userId = SessionManager.instance?.getUser()?.id ?? '';
    await provider.loadConfig();
    if (userId.isNotEmpty) {
      await provider.loadHostRate(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Rate & Host Guide'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
        ),
      ),
      body: Consumer<CallRateProvider>(
        builder: (context, provider, _) {
          if (provider.loading) {
            return const Center(child: Preloader());
          }

          if (provider.error != null && provider.hostRate == null) {
            return _ErrorView(
              message: provider.error!,
              onRetry: _loadData,
            );
          }

          final hostRate = provider.hostRate;
          if (hostRate == null) {
            return const Center(child: Text('No rate data available'));
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _CurrentRateCard(hostRate: hostRate),
                const SizedBox(height: 16),
                _LevelRatesList(
                  levels: provider.levels,
                  hostLevel: hostRate.hostLevel,
                ),
                const SizedBox(height: 16),
                _RateSelectorCard(
                  availableRates: hostRate.availableRates,
                  currentRate: hostRate.customRate,
                  effectiveRate: hostRate.effectiveRate,
                  maxAllowedRate: hostRate.maxAllowedRate,
                  onSelect: _setRate,
                ),
                const SizedBox(height: 16),
                if (hostRate.customRate != null)
                  _ResetButton(onReset: _resetRate),
                const SizedBox(height: 16),
                _HostGuideSection(),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _setRate(int rate) async {
    final provider = context.read<CallRateProvider>();
    final userId = SessionManager.instance?.getUser()?.id ?? '';
    if (userId.isEmpty) return;

    final success = await provider.setRate(userId, rate);
    if (!mounted) return;
    _showResult(success, provider.error, success ? 'Rate updated successfully' : null);
  }

  Future<void> _resetRate() async {
    final provider = context.read<CallRateProvider>();
    final userId = SessionManager.instance?.getUser()?.id ?? '';
    if (userId.isEmpty) return;

    final success = await provider.resetRate(userId);
    if (!mounted) return;
    _showResult(success, provider.error, success ? 'Rate reset to default' : null);
  }

  void _showResult(bool success, String? error, String? successMsg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? (successMsg ?? 'Done') : (error ?? 'Failed')),
        backgroundColor: success ? AppTheme.green : Colors.red,
      ),
    );
  }
}

class _CurrentRateCard extends StatelessWidget {
  final dynamic hostRate;
  const _CurrentRateCard({required this.hostRate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Call Rate',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${hostRate.effectiveRate}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 6, left: 4),
                child: Text('diamonds/min', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoChip(label: 'Level ${hostRate.hostLevel}'),
              const SizedBox(width: 8),
              if (hostRate.customRate != null)
                _InfoChip(label: 'Custom: ${hostRate.customRate}/min')
              else
                const _InfoChip(label: 'Default rate'),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}

class _LevelRatesList extends StatelessWidget {
  final List<dynamic> levels;
  final int hostLevel;
  const _LevelRatesList({required this.levels, required this.hostLevel});

  @override
  Widget build(BuildContext context) {
    if (levels.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Level Rates', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...levels.map((level) {
          final isCurrent = level.level == hostLevel;
          final isUnlocked = level.level <= hostLevel;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isCurrent
                  ? AppTheme.primary.withValues(alpha: 0.1)
                  : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: isCurrent ? Border.all(color: AppTheme.primary, width: 1.5) : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isUnlocked ? AppTheme.primary : AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${level.level}',
                      style: TextStyle(
                        color: isUnlocked ? Colors.white : AppTheme.textTertiary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        level.label ?? 'Level ${level.level}',
                        style: TextStyle(
                          color: isUnlocked ? AppTheme.textPrimary : AppTheme.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${level.rate} diamonds/min',
                        style: TextStyle(
                          color: isUnlocked ? AppTheme.textSecondary : AppTheme.textTertiary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  const Icon(Icons.check_circle, color: AppTheme.primary, size: 20)
                else if (!isUnlocked)
                  const Icon(Icons.lock, color: AppTheme.textTertiary, size: 18),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _RateSelectorCard extends StatelessWidget {
  final List<int> availableRates;
  final int? currentRate;
  final int effectiveRate;
  final int maxAllowedRate;
  final Function(int) onSelect;
  const _RateSelectorCard({
    required this.availableRates,
    required this.currentRate,
    required this.effectiveRate,
    required this.maxAllowedRate,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (availableRates.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Set Your Rate', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          'Choose from rates up to your current level',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: availableRates.map((rate) {
            final isSelected = rate == (currentRate ?? effectiveRate);
            return GestureDetector(
              onTap: () => onSelect(rate),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppTheme.brandGradient : null,
                  color: isSelected ? null : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected ? null : Border.all(color: AppTheme.surfaceVariant),
                ),
                child: Text(
                  '$rate/min',
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ResetButton extends StatelessWidget {
  final VoidCallback onReset;
  const _ResetButton({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onReset,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Reset to Default Rate'),
      ),
    );
  }
}

class _HostGuideSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Host Call Guide', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        const _GuideCard(
          title: 'Host Roles & Earnings',
          icon: Icons.workspace_premium,
          children: [
            _GuideBullet(
              title: 'Host Levels',
              body: 'Each host level unlocks higher per-minute rates, more visibility, and bigger earnings. Level up by hosting regularly and receiving calls.',
            ),
            _GuideBullet(
              title: 'Commission & Perks',
              body: 'Earn diamonds for every minute of video call. Higher-level hosts keep a larger share and get priority placement in the host list.',
            ),
            _GuideBullet(
              title: 'Responsibilities',
              body: 'Be online when your Video Call Listing is active, answer calls promptly, and follow community guidelines to maintain good standing.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _GuideCard(
          title: 'How to Rank on Top',
          icon: Icons.emoji_events,
          children: [
            _GuideBullet(
              title: 'Keep Your Response Rate High',
              body: 'Never miss incoming video calls. A high pick-up rate is the biggest factor in ranking higher.',
            ),
            _GuideBullet(
              title: 'Maintain High Ratings',
              body: 'Provide engaging and friendly conversations to get 5-star ratings from callers.',
            ),
            _GuideBullet(
              title: 'Level Up',
              body: 'Complete daily goals to increase your Host Level for higher listing visibility.',
            ),
            _GuideBullet(
              title: 'Quick Pick-up',
              body: 'Answer calls within 5 seconds to boost your profile score and appear at the top.',
            ),
          ],
        ),
      ],
    );
  }
}

class _GuideCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _GuideCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.surfaceVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _GuideBullet extends StatelessWidget {
  final String title;
  final String body;
  const _GuideBullet({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: AppTheme.primary, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
