/// Shared "KYC Verified" dashboard shown on the KYC form screen and on the
/// KYC status screen once the user is fully verified.
///
/// It gives one-tap access to the actions the user actually wants after KYC:
/// Go Live, Host Center, Wallet, Earnings, Withdraw and Support.
library kyc_verified_dashboard;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/kyc_models.dart';
import '../../providers/kyc_provider.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';

class KycVerifiedDashboard extends StatelessWidget {
  const KycVerifiedDashboard({
    super.key,
    required this.provider,
    this.onNeedHelp,
    this.statusCardTopPadding = 22.0,
  });

  final KycProvider provider;
  final VoidCallback? onNeedHelp;
  final double statusCardTopPadding;

  @override
  Widget build(BuildContext context) {
    final status = provider.status;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Top status card.
        _statusCard(status),
        const SizedBox(height: 20),

        // Congratulations message.
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.celebration, color: AppTheme.green, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Congratulations!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Your identity is verified. You can now go live and withdraw earnings.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Primary CTA: Go Live.
        _primaryButton(
          onTap: () => context.pushNamed(AppRoutes.goLive),
          icon: Icons.videocam,
          label: 'Go Live',
          sublabel: 'Start streaming now',
          color: AppTheme.green,
        ),
        const SizedBox(height: 24),

        // Quick actions grid.
        _sectionTitle('Quick Actions'),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.35,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _actionTile(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Wallet',
              sublabel: 'Balance & Beans',
              onTap: () => context.pushNamed(AppRoutes.wallet),
            ),
            _actionTile(
              icon: Icons.account_balance_outlined,
              label: 'Withdraw',
              sublabel: 'Cash out earnings',
              onTap: () => context.pushNamed(AppRoutes.cashOut),
            ),
            _actionTile(
              icon: Icons.receipt_long_outlined,
              label: 'Earnings',
              sublabel: 'Income history',
              onTap: () => context.pushNamed(AppRoutes.transactionHistory),
            ),
            _actionTile(
              icon: Icons.stars_outlined,
              label: 'Host Center',
              sublabel: 'Host dashboard',
              onTap: () => context.pushNamed(AppRoutes.hostCenter),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Need help / support.
        _sectionTitle('Need Help?'),
        const SizedBox(height: 12),
        _supportCard(context),
      ],
    );
  }

  Widget _statusCard(KycUserStatus status) {
    final level = status.kycLevel;
    final levelName = status.currentLevelName;
    final hasLimit = status.currentLevelLimit > 0;

    return Container(
      padding: EdgeInsets.fromLTRB(22, statusCardTopPadding, 22, 22),
      decoration: BoxDecoration(
        gradient: AppTheme.greenGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.green.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 14),
          const Text(
            'Verified',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Level $level ${levelName != null ? '· $levelName' : ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            hasLimit
                ? 'Daily withdrawal limit: ${status.currentLevelLimit} RCoins'
                : 'Unlimited withdrawals',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          if (status.kycVerifiedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Verified on: ${status.kycVerifiedAt}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _primaryButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required String sublabel,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(color: AppTheme.surfaceVariant, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primary, size: 28),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _supportCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.surfaceVariant, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.headset_mic_outlined, color: AppTheme.primary, size: 28),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report or ask why KYC was rejected',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Our support team will review and get back to you.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: () {
              if (onNeedHelp != null) {
                onNeedHelp!();
              } else {
                context.pushNamed(AppRoutes.feedback);
              }
            },
            child: const Text('Help', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

}
