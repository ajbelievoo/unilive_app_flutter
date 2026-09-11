/// Friend Detail screen — full friendship profile.
///
/// Shows: friend header (both avatars + names), bond info (level, intimacy,
/// days together), stats (gifts, calls, live), and a Remove button.
library friend_detail;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/friend_models.dart';
import '../../providers/friend_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart';
import 'package:belive/widgets/preloader.dart';
import '../../widgets/cp_widgets.dart';

class FriendDetailScreen extends StatefulWidget {
  const FriendDetailScreen({super.key, required this.friendshipId});
  final String friendshipId;

  @override
  State<FriendDetailScreen> createState() => _FriendDetailScreenState();
}

class _FriendDetailScreenState extends State<FriendDetailScreen> {
  FriendItem? _friend;
  bool _loading = true;
  bool _removing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final friendProv = context.read<FriendProvider>();
      final res = await ApiService.getFriendship(widget.friendshipId);
      if (mounted && res.status && res.data.isNotEmpty) {
        setState(() => _friend = res.data.first);
      }
      if (friendProv.levels.isEmpty) {
        await friendProv.loadLevels();
      }
      await friendProv.loadAnniversaries(widget.friendshipId);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _removeFriend() async {
    final session = context.read<SessionManager>();
    final friendProv = context.read<FriendProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Friend?'),
        content: const Text('After removal, the Friend Exp and accumulated days will be cleared and cannot be restored. Please think twice.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _removing = true);
    final ok = await friendProv.removeFriend(friendshipId: widget.friendshipId, userId: session.userId);
    if (ok) {
      Fluttertoast.showToast(msg: 'Friend removed');
      if (mounted) context.goNamed(AppRoutes.cp);
    } else {
      Fluttertoast.showToast(msg: 'Failed to remove friend');
    }
    if (mounted) setState(() => _removing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _loading
          ? const Center(child: Preloader())
          : _friend == null
              ? const Center(child: Text('Friend not found'))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final f = _friend!;
    final partner = f.partner;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 200,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: const AssetImage('assets/cp_friend/bg_friends_up.png'),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          const Color(0xFF4F8DFD).withValues(alpha: 0.4),
                          BlendMode.srcOver,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF4F8DFD).withValues(alpha: 0.1),
                          const Color(0xFF1A0A4E).withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 130,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.friendAccent.withValues(alpha: 0.18),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.friendAccent.withValues(alpha: 0.35),
                                    blurRadius: 40,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _avatar(f.self, 54),
                                Transform.translate(
                                  offset: const Offset(-16, 0),
                                  child: _avatar(f.partner, 54),
                                ),
                              ],
                            ),
                            Image.asset(
                              'assets/cp_friend/cp_moda.png',
                              width: 64,
                              height: 64,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${f.self?.name ?? ''} & ${partner?.name ?? ''}',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                            boxShadow: [
                              BoxShadow(color: AppTheme.friendAccent.withValues(alpha: 0.2), blurRadius: 18, offset: const Offset(0, 6)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_alt, size: 13, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text('Lv.${f.level}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 10),
                              Container(width: 1, height: 12, color: Colors.white30),
                              const SizedBox(width: 10),
                              const Icon(Icons.calendar_today, size: 13, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text('${f.daysTogether} days', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.history, color: Colors.white),
              onPressed: () => context.pushNamed(AppRoutes.friendHistory),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Bond progress
                _bondCard(f),
                const SizedBox(height: 16),
                // Stats
                _statsCard(f),
                const SizedBox(height: 16),
                // Privileges link
                _linkCard(
                  icon: Icons.military_tech_outlined,
                  title: 'Friend Privileges',
                  subtitle: 'View unlockable perks',
                  onTap: () => context.pushNamed(AppRoutes.friendPrivileges),
                ),
                const SizedBox(height: 8),
                _linkCard(
                  icon: Icons.rule,
                  title: 'Rules',
                  subtitle: 'How Friend system works',
                  onTap: () => context.pushNamed(AppRoutes.friendRules),
                ),
                const SizedBox(height: 8),
                _linkCard(
                  icon: Icons.card_giftcard,
                  title: 'Anniversaries',
                  subtitle: 'Claim time-based rewards',
                  onTap: _showAnniversaries,
                ),
                const SizedBox(height: 24),
                // Remove button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _removing ? null : _removeFriend,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                      shadowColor: Colors.red.withValues(alpha: 0.4),
                    ),
                    icon: _removing
                        ? const SizedBox(width: 18, height: 18, child: Preloader(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.person_remove),
                    label: const Text('Remove Friend', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatar(FriendUser? user, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
      child: ClipOval(
        child: user?.image?.isNotEmpty == true
            ? CachedNetworkImage(imageUrl: user!.image!, fit: BoxFit.cover)
            : Container(color: Colors.white24, child: const Icon(Icons.person, color: Colors.white70)),
      ),
    );
  }

  Widget _bondCard(FriendItem f) {
    final levels = context.watch<FriendProvider>().levels;
    final nextLevel = levels.where((l) => l.level == f.level + 1).firstOrNull;
    final target = nextLevel?.requiredIntimacy ?? (f.level * 500) + 500;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 28,
      borderColor: AppTheme.friendAccent.withValues(alpha: 0.22),
      backgroundColor: AppTheme.cpDarkCard.withValues(alpha: 0.88),
      shadow: [
        BoxShadow(color: AppTheme.friendAccent.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/cp_friend/bg_freind_star.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.star, size: 22, color: AppTheme.primary),
              ),
              const SizedBox(width: 8),
              const Text('Friendship Bond', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: AppTheme.friendAccent.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 3))],
                ),
                child: Text('Lv.${f.level}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          BondProgressBar(
            current: f.intimacy,
            target: target,
            label: 'Intimacy',
            isFriend: true,
          ),
        ],
      ),
    );
  }

  Widget _statsCard(FriendItem f) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 28,
      borderColor: AppTheme.friendAccent.withValues(alpha: 0.15),
      backgroundColor: AppTheme.cpDarkCard.withValues(alpha: 0.88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Stats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: CPStatTile(icon: Icons.card_giftcard, value: formatCount(f.totalGift), label: 'Gifts', color: AppTheme.friendAccent)),
              const SizedBox(width: 10),
              Expanded(child: CPStatTile(icon: Icons.call, value: formatCount(f.totalCall), label: 'Calls', color: AppTheme.secondary)),
              const SizedBox(width: 10),
              Expanded(child: CPStatTile(icon: Icons.mic, value: formatCount(f.totalLive), label: 'Live', color: AppTheme.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showAnniversaries() async {
    await context.pushNamed(
      AppRoutes.friendAnniversaries,
      extra: {'friendshipId': widget.friendshipId},
    );
  }

  Widget _linkCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
            ])),
            const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}
