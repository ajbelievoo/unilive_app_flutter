import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/auth_provider.dart';
import '../../services/deep_link_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';

/// Invite & referral screen — "pro level" refer-and-earn hub.
class ReferralScreen extends StatelessWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().user;
    final referralCode = user?.referralCode ?? user?.id ?? '';
    final referralCount = user?.referralCount ?? 0;
    final link = DeepLinkService.instance.generateProfileShareLink(
      userId: user?.id ?? '',
      name: user?.name,
    );

    return Scaffold(
      backgroundColor: isDark ? AppTheme.background : const Color(0xFFF6F5FB),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Invite Friends',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Share your code & earn rewards when friends join',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            '$referralCount friend${referralCount == 1 ? '' : 's'} joined',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ReferralCodeCard(code: referralCode),
                const SizedBox(height: 20),
                _ShareButton(link: link, code: referralCode),
                const SizedBox(height: 20),
                _HowItWorksCard(),
                const SizedBox(height: 20),
                _ReferralListHeader(),
              ]),
            ),
          ),
          const _ReferralList(),
        ],
      ),
    );
  }
}

class _ReferralCodeCard extends StatelessWidget {
  final String code;

  const _ReferralCodeCard({required this.code});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your referral code',
            style: TextStyle(fontSize: 13, color: AppTheme.textTertiary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  code.isEmpty ? '—' : code,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ),
              if (code.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    Fluttertoast.showToast(msg: 'Referral code copied');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy, color: AppTheme.primary, size: 18),
                        SizedBox(width: 6),
                        Text('Copy', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final String link;
  final String code;

  const _ShareButton({required this.link, required this.code});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Share.share(
                'Join me on Belive! Use my referral code: $code\n$link',
                subject: 'Invite to Belive',
              );
            },
            icon: const Icon(Icons.share, color: Colors.white),
            label: const Text('Invite Friends', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ShareChip(
                icon: Icons.message,
                label: 'SMS',
                onTap: () => Share.share('Join me on Belive! Code: $code\n$link'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ShareChip(
                icon: Icons.send,
                label: 'WhatsApp',
                onTap: () => Share.share('Join me on Belive! Code: $code\n$link'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ShareChip(
                icon: Icons.content_copy,
                label: 'Copy Link',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: link));
                  Fluttertoast.showToast(msg: 'Link copied');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ShareChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShareChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 22),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How it works',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _step('1', 'Share your referral code or link with friends.'),
          const SizedBox(height: 12),
          _step('2', 'Your friend signs up and enters your code.'),
          const SizedBox(height: 12),
          _step('3', 'Both of you earn bonus diamonds & rewards!'),
        ],
      ),
    );
  }

  Widget _step(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
          child: Center(
            child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ),
      ],
    );
  }
}

class _ReferralListHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Text(
      'Your referrals',
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }
}

class _ReferralList extends StatelessWidget {
  const _ReferralList();

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionManager>();
    final user = session.getUser();
    final count = user?.referralCount ?? 0;

    if (count == 0) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_alt_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'No referrals yet\nInvite friends to get started',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Placeholder: real list to be wired once backend provides /referral/list.
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.person, color: AppTheme.primary),
          ),
          title: Text('Referred friend ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Reward pending', style: TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
        ),
        childCount: count,
      ),
    );
  }
}
