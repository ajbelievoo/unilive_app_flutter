import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../constants/const.dart';
import '../../models/json_annotation_helper.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/deep_link_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/currency_icon.dart';

/// Invite & referral screen — shows the user's referral code, real referral
/// stats and the list of friends who joined via the code.
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  bool _loading = true;
  bool _failed = false;

  int _total = 0;
  int _earnedBeans = 0;
  int _friendBonus = 0;
  int _referrerBonus = 0;
  List<Map<String, dynamic>> _referrals = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().user?.id ?? '';
    if (userId.isEmpty) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    try {
      final results = await Future.wait([
        ApiService.getReferralStats(userId),
        ApiService.getReferralList(userId),
      ]);
      final stats = results[0];
      final list = results[1];
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = !stats.status;
        final s = stats.data ?? const {};
        _total = parseInt(s['total']);
        _earnedBeans = parseInt(s['earned']);
        _friendBonus = parseInt(s['referralBonus']);
        _referrerBonus = parseInt(s['referralCoinBonus']);
        if (list.status && list.data?['data'] is List) {
          _referrals = (list.data!['data'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().user;
    final referralCode = user?.referralCode ?? '';
    final link = DeepLinkService.instance.generateReferralLink();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.background : const Color(0xFFF6F5FB),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                              '$_total friend${_total == 1 ? '' : 's'} joined · $_earnedBeans ${Const.rCoinName} earned',
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
                  _HowItWorksCard(friendBonus: _friendBonus, referrerBonus: _referrerBonus),
                  const SizedBox(height: 20),
                  const Text(
                    'Your referrals',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ]),
              ),
            ),
            _buildList(),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_failed) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text('Could not load referrals', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 12),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    if (_referrals.isEmpty) {
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
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => _ReferralTile(item: _referrals[i]),
        childCount: _referrals.length,
      ),
    );
  }
}

class _ReferralTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _ReferralTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = parseString(item['name']) ?? 'User';
    final image = parseString(item['image']) ?? '';
    final reward = parseInt(item['reward']);
    final date = item['date']?.toString() ?? '';
    final dateLabel = date.length >= 10 ? date.substring(0, 10) : '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
          backgroundImage: image.isNotEmpty ? CachedNetworkImageProvider(image) : null,
          child: image.isEmpty ? const Icon(Icons.person, color: AppTheme.primary) : null,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          dateLabel.isNotEmpty ? 'Joined $dateLabel' : 'Joined',
          style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
        ),
        trailing: reward > 0
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CurrencyIcon(CurrencyType.bean, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '+$reward',
                    style: const TextStyle(
                      color: AppTheme.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : null,
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
            onPressed: link.isEmpty
                ? null
                : () {
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
  final int friendBonus;
  final int referrerBonus;

  const _HowItWorksCard({this.friendBonus = 0, this.referrerBonus = 0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rewardText = (friendBonus > 0 || referrerBonus > 0)
        ? 'Your friend gets $friendBonus ${Const.coinName} and you get $referrerBonus ${Const.rCoinName}!'
        : 'Both of you earn bonus rewards!';
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
          _step('2', 'Your friend installs the app and signs up.'),
          const SizedBox(height: 12),
          _step('3', rewardText),
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
