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
import 'package:belive/widgets/preloader.dart';

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
                    // Avatars with cp_moda decoration
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _avatar(f.self, 50),
                            Transform.translate(
                              offset: const Offset(-14, 0),
                              child: _avatar(f.partner, 50),
                            ),
                          ],
                        ),
                        // cp_moda glow behind avatars
                        Image.asset(
                          'assets/cp_friend/cp_moda.png',
                          width: 60,
                          height: 60,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${f.self?.name ?? ''} & ${partner?.name ?? ''}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_alt, size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text('Lv.${f.level}  •  ${f.daysTogether} days',
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2054), Color(0xFF0F1230)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/cp_friend/bg_freind_star.png',
                width: 26,
                height: 26,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.star, size: 20, color: AppTheme.primary),
              ),
              const SizedBox(width: 8),
              const Text('Friendship Bond', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('Level', style: TextStyle(fontSize: 13, color: Colors.white70)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Lv.${f.level}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Intimacy', style: TextStyle(fontSize: 13, color: Colors.white70)),
              const Spacer(),
              Text('${f.intimacy}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Days Together', style: TextStyle(fontSize: 13, color: Colors.white70)),
              const Spacer(),
              Text('${f.daysTogether} days', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 18),
          _friendBondProgress(f: f),
        ],
      ),
    );
  }

  Widget _friendBondProgress({required FriendItem f}) {
    final levels = context.watch<FriendProvider>().levels;
    final nextLevel = levels.where((l) => l.level == f.level + 1).firstOrNull;
    final target = nextLevel?.requiredIntimacy ?? (f.level * 500) + 500;
    final pct = target == 0 ? 0.0 : (f.intimacy / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Progress', style: TextStyle(fontSize: 13, color: Colors.white70)),
            Text('${f.intimacy} / $target', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 10,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.friendAccent),
          ),
        ),
      ],
    );
  }

  Widget _statsCard(FriendItem f) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Stats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(
            children: [
              _statTile(Icons.card_giftcard, '${f.totalGift}', 'Gifts'),
              _statTile(Icons.call, '${f.totalCall}', 'Calls'),
              _statTile(Icons.mic, '${f.totalLive}', 'Live min'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: AppTheme.primary),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
          ],
        ),
      ),
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
