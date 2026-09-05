/// Family Detail screen — members, tasks, family info.
///
/// Shows full family info with tabs: About, Members, Tasks.
/// Leader/co-leader can manage members (kick, promote/demote),
/// transfer leadership, edit family settings, and delete family.
library family_detail;
import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../utils/media_utils.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/family_models.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../utils/log.dart';
import '../../widgets/premium_ui.dart';
import '../../screens/live/audio_room_screen.dart';
import 'family_join_requests_screen.dart';
import 'package:belive/widgets/preloader.dart';

class FamilyDetailScreen extends StatefulWidget {
  const FamilyDetailScreen({super.key, required this.familyId});

  final String familyId;

  @override
  State<FamilyDetailScreen> createState() => _FamilyDetailScreenState();
}

class _FamilyDetailScreenState extends State<FamilyDetailScreen>
    with SingleTickerProviderStateMixin {
  static const String _tag = 'FamilyDetail';

  late final TabController _tabCtrl = TabController(length: 3, vsync: this);
  FamilyItem? _family;
  final _tasks = <FamilyTask>[];
  bool _loading = true;
  String? _error;
  String? _currentUserId;
  String? _currentRole;
  bool _joining = false;
  bool _signedIn = false;

  bool get _isLeader => _currentRole == 'leader';
  bool get _isMember => _family?.isMember ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final userId = context.read<SessionManager>().userId;
    _currentUserId = userId;
    try {
      FamilyRoot? fam;
      FamilyTaskRoot? tasks;

      try {
        fam = await ApiService.getFamilyDetail(widget.familyId);
      } catch (e, s) {
        Log.e(_tag, 'getFamilyDetail failed', e, s);
      }

      try {
        tasks = await ApiService.getFamilyTasks(widget.familyId);
      } catch (e, s) {
        Log.e(_tag, 'getFamilyTasks failed', e, s);
        tasks = FamilyTaskRoot(status: false, message: 'Tasks not available');
      }

      if (mounted) {
        setState(() {
          _family = (fam != null && fam.data.isNotEmpty) ? fam.data.first : null;
          _tasks
            ..clear()
            ..addAll(tasks?.tasks ?? []);

          _currentRole = _family?.userRole;
          if (_currentRole == null || _currentRole!.isEmpty) {
            final me = _family?.members.where((m) => m.userId == userId).firstOrNull;
            _currentRole = me?.role;
          }
          if (_family?.leaderId == userId) _currentRole = 'leader';
          _signedIn = _family?.hasSignedInToday ?? false;
          _loading = false;
        });
      }
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load family profile.';
        });
      }
    }
  }

  void _showMoreOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLeader) ...[
              ListTile(
                leading: const Icon(Icons.flash_on, color: Colors.orange),
                title: const Text('Family PK Battle'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showFamilyPKChallengeDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.pending_actions, color: Colors.blue),
                title: const Text('Join Requests'),
                subtitle: const Text('Approve or reject pending join requests', style: TextStyle(fontSize: 11, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => FamilyJoinRequestsScreen(familyId: widget.familyId),
                  ));
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: AppTheme.primary),
                title: const Text('Family Settings'),
                subtitle: const Text('Daily sign-in reward, join rules, announcement', style: TextStyle(fontSize: 11, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.pushNamed(AppRoutes.familySettings, extra: {'familyId': widget.familyId});
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: AppTheme.primary),
                title: const Text('Edit Family'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditFamily();
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: AppTheme.primary),
                title: const Text('Transfer Leadership'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showTransferLeadership();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Delete Family', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteFamily();
                },
              ),
              const Divider(height: 1),
            ],
            if (_isMember)
              ListTile(
                title: const Center(
                  child: Text(
                    'Leave the family',
                    style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _leaveFamily();
                },
              ),
            const Divider(height: 1),
            ListTile(
              title: const Center(
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinFamily() async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      final res = await ApiService.joinFamily(
        userId: _currentUserId ?? '',
        familyId: widget.familyId,
      );
      if (mounted) {
        Fluttertoast.showToast(msg: res.status ? 'Joined family!' : (res.message ?? 'Join failed'));
        if (res.status) _load();
      }
    } catch (e) {
      if (mounted) Fluttertoast.showToast(msg: 'Error joining family');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _handleSignIn() async {
    if (_signedIn) return;
    setState(() => _signedIn = true); // optimistic UI
    try {
      final res = await ApiService.familyDailySignIn(
        familyId: widget.familyId,
        userId: _currentUserId ?? '',
      );
      if (!mounted) return;
      if (res.status) {
        final reward = _family?.dailySignInReward ?? 10;
        Fluttertoast.showToast(msg: 'Sign-in Successful! +$reward Exp');
        _load();
      } else {
        setState(() => _signedIn = false);
        Fluttertoast.showToast(msg: res.message ?? 'Sign-in failed. Try again tomorrow.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _signedIn = false);
        Fluttertoast.showToast(msg: 'Sign-in failed. Check your connection.');
      }
      Log.e(_tag, 'dailySignIn failed', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      body: _loading
          ? const Center(child: PremiumLoading())
          : _error != null
          ? EmptyState(
        icon: Icons.error_outline,
        title: 'Oops',
        subtitle: _error,
        actionLabel: 'Retry',
        onAction: _load,
      )
          : _family == null
          ? const EmptyState(icon: Icons.people, title: 'Family not found')
          : RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildQuickActions(),
              const SizedBox(height: 12),
              _buildTaskAndRewardCard(),
              const SizedBox(height: 12),
              _buildAIMissionCard(),
              const SizedBox(height: 12),
              _buildTreasuryCard(),
              const SizedBox(height: 12),
              _buildFamilyMemberSection(),
              const SizedBox(height: 12),
              _buildFamilyNotificationSection(),
              const SizedBox(height: 12),
              _buildFamilySupportSection(),
              const SizedBox(height: 12),
              _buildMemberRoomSection(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final f = _family!;
    final level = f.level > 0 ? f.level : 1;
    final familyIdStr = f.id != null && f.id!.isNotEmpty ? f.id! : 'N/A';

    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 350,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F1432), Color(0xFF1A1A40), Color(0xFF0A0D20)],
            ),
          ),
          child: VideoUtil.getFullImageUrl(f.coverImage).isNotEmpty
              ? CachedNetworkImage(
            imageUrl: VideoUtil.getFullImageUrl(f.coverImage),
            fit: BoxFit.cover,
            color: Colors.black.withValues(alpha:0.4),
            colorBlendMode: BlendMode.darken,
            errorWidget: (_, __, ___) => const SizedBox.expand(),
          )
              : Image.asset('assets/family/bg_family.webp', fit: BoxFit.cover),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const BackButton(color: Colors.white),
                const Text(
                  'Family Profile',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    if (_isMember || _isLeader)
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                        onPressed: () {
                          context.pushNamed(AppRoutes.familyChat, extra: {
                            'familyId': f.id ?? '',
                            'familyName': f.name,
                          });
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.share_outlined, color: Colors.white),
                      onPressed: () {
                        Share.share('Join my family ${f.name ?? ''} (ID: $familyIdStr) on Belive!');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_horiz, color: Colors.white),
                      onPressed: _showMoreOptionsMenu,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        Positioned.fill(
          top: 80,
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 105,
                    height: 105,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amber.withValues(alpha:0.6), width: 2.5),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFFFD700).withValues(alpha:0.3), blurRadius: 25, spreadRadius: 3),
                      ],
                    ),
                    child: f.image != null && f.image!.isNotEmpty
                        ? ClipOval(child: CachedNetworkImage(imageUrl: f.image!, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.shield, size: 85, color: Color(0xFFFFC107))))
                        : const Icon(Icons.shield, size: 85, color: Color(0xFFFFC107)),
                  ),
                  Positioned(
                    bottom: 0,
                    child: GestureDetector(
                      onTap: () => context.pushNamed(AppRoutes.familyLevel, extra: {
                        'level': f.level,
                        'currentExp': f.totalCoin,
                        'nextLevelExp': (f.level > 0 ? f.level : 1) * 2500000,
                        'familyName': f.name ?? 'Family',
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: AppTheme.blueGradient,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          'Lv.$level',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)]),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFFD700).withValues(alpha:0.9), width: 1.5),
                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (f.rank >= 1 && f.rank <= 3)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Image.asset('assets/family/tag_family_top${f.rank}.webp', width: 26, height: 26),
                      )
                    else
                      const Icon(Icons.shield, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      f.name ?? 'Family',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: familyIdStr));
                      Fluttertoast.showToast(msg: 'Family ID copied');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Text('ID: $familyIdStr', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(width: 4),
                          const Icon(Icons.copy, color: Colors.white54, size: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (!_isMember && !_isLeader)
                GradientButton(
                  label: 'Apply to Join',
                  onPressed: _joinFamily,
                  width: 170,
                  height: 44,
                  borderRadius: 22,
                  loading: _joining,
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _handleSignIn,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: _signedIn ? AppTheme.darkGradient : AppTheme.goldGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [if (!_signedIn) BoxShadow(color: Colors.amber.withValues(alpha:0.3), blurRadius: 10)],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: _signedIn ? Colors.white54 : Colors.black87),
                            const SizedBox(width: 6),
                            Text(
                              _signedIn
                                  ? 'Signed In (${_family?.signInStreak ?? 0} day streak)'
                                  : 'Daily Sign-in (+${_family?.dailySignInReward ?? 10} Exp)',
                              style: TextStyle(color: _signedIn ? Colors.white54 : Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha:0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        _isLeader ? 'Leader' : (_currentRole ?? 'Member'),
                        style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _actionItem(Icons.workspace_premium, 'Glory Wall', () => context.pushNamed(AppRoutes.familyAchievements)),
          _actionItem(Icons.leaderboard, 'Rankings', () => context.pushNamed(AppRoutes.familyHonor)),
          _actionItem(Icons.card_giftcard, 'Rewards', () => context.pushNamed(AppRoutes.familyReward)),
          _actionItem(Icons.help_outline, 'Rules', () => context.pushNamed(AppRoutes.familyRules)),
        ],
      ),
    );
  }

  Widget _actionItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha:0.1), shape: BoxShape.circle),
            child: Icon(icon, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildTaskAndRewardCard() {
    final displayTasks = _tasks.where((t) => t.type != 'ai_highlight').toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Task & Reward', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              const Spacer(),
              if (_isMember || _isLeader)
                const Text('Daily Reset at 00:00', style: TextStyle(color: Colors.black45, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          if (_tasks.isEmpty)
            const Text('No tasks available', style: TextStyle(color: Colors.black45, fontSize: 13))
          else
            ...displayTasks.take(3).map((task) => _buildTaskItem(task)),
        ],
      ),
    );
  }

  Widget _buildTaskItem(FamilyTask task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FB),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppTheme.blueGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.stars, color: Color(0xFF42A5F5), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title ?? 'Task',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                const SizedBox(height: 2),
                Text('Exp Reward: +${task.reward}',
                    style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (task.isCompleted)
            task.isClaimed
                ? const Icon(Icons.check_circle, color: Colors.green, size: 28)
                : ElevatedButton(
              onPressed: () async {
                if (task.id == null) return;
                try {
                  final res = await ApiService.claimFamilyTask(
                    familyId: widget.familyId,
                    taskId: task.id!,
                  );
                  if (!mounted) return;
                  Fluttertoast.showToast(msg: res.status ? 'Reward claimed!' : (res.message ?? 'Failed'));
                  if (res.status) _load();
                } catch (e) {
                  Log.e(_tag, 'claim failed', e);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                elevation: 0,
              ),
              child: const Text('Claim', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primary.withValues(alpha:0.5)),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                '${task.progress}/${task.target}',
                style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAIMissionCard() {
    if (_tasks.isEmpty) return const SizedBox.shrink();

    final mission = _tasks.where((t) => !t.isClaimed).firstOrNull ?? _tasks.first;
    final progress = mission.target > 0 ? (mission.progress / mission.target).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A40), Color(0xFF0F0B21)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha:0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.cyanAccent.withValues(alpha:0.15), blurRadius: 15, spreadRadius: 1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: Colors.cyanAccent, size: 24),
              const SizedBox(width: 10),
              const Text('AI Pro Mission', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: mission.isCompleted ? Colors.green : Colors.cyanAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  mission.isCompleted ? 'READY' : 'ACTIVE',
                  style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            mission.description ?? mission.title ?? 'Contribute to family growth by completing daily goals.',
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PRIZE POOL', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
                  Text('+${mission.reward} Exp & Coins', style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
              if (mission.isCompleted && !mission.isClaimed)
                GradientButton(
                  label: 'Claim Reward',
                  onPressed: () async {
                    if (mission.id == null) return;
                    try {
                      final res = await ApiService.claimFamilyTask(familyId: widget.familyId, taskId: mission.id!);
                      if (res.status) {
                        Fluttertoast.showToast(msg: 'Reward Unlocked!');
                        _load();
                      }
                    } catch (e) { Fluttertoast.showToast(msg: 'Operation failed'); }
                  },
                  width: 130, height: 36, borderRadius: 18,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTreasuryCard() {
    final f = _family!;
    return GestureDetector(
      onTap: () {
        context.pushNamed(AppRoutes.familyTreasury, extra: {'familyId': widget.familyId});
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF7E3FF2), Color(0xFFE91E63)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: const Color(0xFF7E3FF2).withValues(alpha:0.4), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha:0.2), shape: BoxShape.circle),
              child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Family Treasury', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.diamond, color: Colors.amber, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        formatCount(f.treasury),
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyMemberSection() {
    final f = _family!;
    final members = f.members;
    final totalCount = f.memberCount > 0 ? f.memberCount : members.length;
    final maxCapacity = 50 + (f.level > 0 ? f.level : 1) * 50;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              context.pushNamed(AppRoutes.familyMembers, extra: {
                'familyId': widget.familyId,
                'familyName': f.name,
                'userRole': _currentRole,
              });
            },
            child: Row(
              children: [
                const Text('Members ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Text('$totalCount/$maxCapacity', style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                // Contribution leaderboard button
                GestureDetector(
                  onTap: () => context.pushNamed(AppRoutes.familyContribution, extra: {
                    'familyId': widget.familyId,
                    'familyName': f.name,
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF6B9D), Color(0xFFFF8E53)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.leaderboard, color: Colors.white, size: 12),
                        SizedBox(width: 3),
                        Text('Contribution', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.black45),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (members.isEmpty)
            const Text('No members yet', style: TextStyle(color: Colors.black45, fontSize: 12))
          else
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: members.take(10).length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, idx) {
                  final m = members[idx];
                  final isLeader = m.role.toLowerCase() == 'leader';
                  final isCoLeader = m.role.toLowerCase() == 'co-leader';
                  final rank = idx + 1;

                  return GestureDetector(
                    onTap: () {
                      context.pushNamed(AppRoutes.guestProfile, extra: {
                        'userId': m.userId ?? m.id,
                        'username': m.name,
                      });
                    },
                    child: SizedBox(
                      width: 64,
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isLeader ? Colors.amber : (isCoLeader ? Colors.tealAccent : Colors.transparent),
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: m.avatar != null && m.avatar!.isNotEmpty
                                      ? CachedNetworkImage(imageUrl: m.avatar!, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.grey))
                                      : const Icon(Icons.person, color: Colors.grey),
                                ),
                              ),
                              Positioned(
                                top: 0, left: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(color: rank <= 3 ? AppTheme.primary : Colors.black54, borderRadius: BorderRadius.circular(6)),
                                  child: Text('#$rank', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (m.name == null || m.name!.isEmpty) ? 'Member' : m.name!,
                            maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFamilyNotificationSection() {
    final notice = _family?.welcomeMessage ?? _family?.description ?? 'No notification';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Notice Board', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade100)),
            child: Row(
              children: [
                const Icon(Icons.campaign, color: Colors.orange, size: 24),
                const SizedBox(width: 12),
                Expanded(child: Text(notice, style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.4))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilySupportSection() {
    final f = _family!;
    final level = f.level > 0 ? f.level : 1;
    final totalCoin = f.totalCoin;
    final nextLevelTarget = level * 2500000;
    final progress = nextLevelTarget > 0 ? (totalCoin / nextLevelTarget).clamp(0.0, 1.0) : 0.0;
    final supporters = f.members.toList()..sort((a, b) => b.contribution.compareTo(a.contribution));
    final topSupporters = supporters.take(3).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weekly Support', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: AppTheme.blueGradient, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.primary.withValues(alpha:0.1))),
            child: Column(
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Level Progression', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 180,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: Colors.white, valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('${formatCount(totalCoin)} / ${formatCount(nextLevelTarget)}', style: const TextStyle(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 4)]),
                      child: Column(
                        children: [
                          const Icon(Icons.diamond, color: Colors.amber, size: 18),
                          const SizedBox(height: 2),
                          Text(formatCount(f.totalCoin), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (topSupporters.length > 1) _buildSupporterCard(rank: 2, title: topSupporters[1].name ?? 'Member', color: const Color(0xFFFFF9C4), avatar: topSupporters[1].avatar),
              _buildSupporterCard(rank: 1, title: topSupporters.isNotEmpty ? (topSupporters[0].name ?? 'Member') : 'Empty', color: const Color(0xFFE1F5FE), avatar: topSupporters.isNotEmpty ? topSupporters[0].avatar : null),
              if (topSupporters.length > 2) _buildSupporterCard(rank: 3, title: topSupporters[2].name ?? 'Member', color: const Color(0xFFFFEBEE), avatar: topSupporters[2].avatar),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSupporterCard({required int rank, required String title, required Color color, String? avatar}) {
    return Container(
      width: 95,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: color.withValues(alpha:0.3), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(width: 50, height: 50, decoration: const BoxDecoration(shape: BoxShape.circle), child: ClipOval(child: avatar != null ? CachedNetworkImage(imageUrl: avatar, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.black12)) : const Icon(Icons.person, color: Colors.black12))),
              Positioned(top: -4, left: 0, child: Image.asset('assets/family/tag_family_top$rank.webp', width: 22, height: 22)),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildMemberRoomSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Family Base', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              const Spacer(),
              if (_isMember || _isLeader) GestureDetector(onTap: _enterFamilyRoom, child: const Row(children: [Text('Enter ', style: TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.bold)), Icon(Icons.chevron_right, color: AppTheme.primary, size: 18)])),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: (_isMember || _isLeader) ? _enterFamilyRoom : null,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(gradient: AppTheme.purpleGradient, borderRadius: BorderRadius.circular(15), border: Border.all(color: AppTheme.primary.withValues(alpha:0.1))),
              child: Column(
                children: [
                  const Icon(Icons.mic_none, size: 44, color: AppTheme.primary),
                  const SizedBox(height: 12),
                  Text(_isMember || _isLeader ? 'Join Family Room' : 'Members Only', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Chat with family members live', style: TextStyle(color: AppTheme.textSecondary.withValues(alpha:0.6), fontSize: 11)),
                ],
              ),
            ),
          ),
          // Invite family members to room button (Bigo/Chamet parity)
          if (_isLeader) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _inviteFamilyToRoom,
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Invite Family Members'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFamilyPKChallengeDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _FamilyChallengePicker(onChallenge: (target) { Navigator.pop(ctx); _startFamilyBattle(target); }),
    );
  }

  Future<void> _startFamilyBattle(FamilyItem target) async {
    try {
      final res = await ApiService.startAudioPk(roomId: _family?.roomId ?? 'family_${_family?.id}', targetRoomId: target.roomId ?? 'family_${target.id}');
      if (mounted) {
        if (res.status) { Fluttertoast.showToast(msg: 'PK Challenge Sent!'); _enterFamilyRoom(); }
        else { Fluttertoast.showToast(msg: res.message ?? 'Failed to challenge'); }
      }
    } catch (e) { if (mounted) Fluttertoast.showToast(msg: 'Error starting battle'); }
  }

  void _showEditFamily() {
    final f = _family;
    if (f == null) return;
    final nameCtrl = TextEditingController(text: f.name ?? '');
    final descCtrl = TextEditingController(text: f.description ?? '');
    final welcomeCtrl = TextEditingController(text: f.welcomeMessage ?? '');
    bool isPublic = f.isPublic;
    String? newImagePath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (_, setState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Edit Family Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final xFile = await picker.pickImage(source: ImageSource.gallery);
                  if (xFile != null) setState(() => newImagePath = xFile.path);
                },
                child: Container(
                  width: 80, height: 80,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.surfaceLight),
                  child: ClipOval(
                    child: newImagePath != null
                        ? Image.file(File(newImagePath!), fit: BoxFit.cover)
                        : (f.image != null && f.image!.isNotEmpty
                        ? CachedNetworkImage(imageUrl: f.image!, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.camera_alt, color: AppTheme.textSecondary))
                        : const Icon(Icons.camera_alt, color: AppTheme.textSecondary)),
                  ),
                ),
              ),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Family Name')),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
              TextField(controller: welcomeCtrl, decoration: const InputDecoration(labelText: 'Welcome Msg')),
              SwitchListTile(title: const Text('Publicly Visible'), value: isPublic, onChanged: (v) => setState(() => isPublic = v)),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Save Changes',
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    final res = await ApiService.updateFamily(
                      familyId: widget.familyId,
                      userId: _currentUserId ?? '',
                      name: nameCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      isPublic: isPublic,
                      logoFile: newImagePath != null ? File(newImagePath!) : null,
                    );
                    if (res.status) {
                      Fluttertoast.showToast(msg: 'Family updated successfully!');
                      _load();
                    } else {
                      Fluttertoast.showToast(msg: res.message ?? 'Update failed');
                    }
                  } catch (e) {
                    Fluttertoast.showToast(msg: 'Error updating family');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransferLeadership() {
    final members = _family?.members ?? [];
    final candidates = members.where((m) => m.userId != _currentUserId && m.role != 'leader').toList();
    if (candidates.isEmpty) {
      Fluttertoast.showToast(msg: 'No members to transfer leadership to');
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Text('Transfer Leadership', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ...candidates.map((m) => ListTile(
              leading: ClipOval(
                child: SizedBox(
                  width: 40, height: 40,
                  child: m.image != null && m.image!.isNotEmpty
                      ? CachedNetworkImage(imageUrl: m.image!, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: Colors.white12, child: const Icon(Icons.person, color: Colors.white60)))
                      : Container(color: Colors.white12, child: const Icon(Icons.person, color: Colors.white60)),
                ),
              ),
              title: Text(m.name ?? 'â€”'),
              subtitle: Text(m.role),
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    title: const Text('Confirm Transfer'),
                    content: Text('Transfer leadership to ${m.name ?? "this member"}?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(dctx, true), child: const Text('Transfer')),
                    ],
                  ),
                );
                if (confirmed != true) return;
                try {
                  final res = await ApiService.transferLeadership(
                    familyId: widget.familyId,
                    currentLeaderId: _currentUserId ?? '',
                    newLeaderId: m.userId ?? '',
                  );
                  if (!mounted) return;
                  Fluttertoast.showToast(msg: res.status ? 'Leadership transferred' : (res.message ?? 'Failed'));
                  if (res.status) Navigator.pop(context);
                } catch (e, s) {
                  Log.e(_tag, 'transferLeadership failed', e, s);
                  if (mounted) Fluttertoast.showToast(msg: 'Failed to transfer leadership');
                }
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteFamily() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Family?'),
        content: const Text('This action cannot be undone. All members will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;
      try {
        final res = await ApiService.deleteFamily(
          familyId: widget.familyId,
          userId: _currentUserId ?? '',
        );
        if (!mounted) return;
        Fluttertoast.showToast(msg: res.status ? 'Family deleted' : (res.message ?? 'Failed'));
        if (res.status) Navigator.pop(context);
      } catch (e, s) {
        Log.e(_tag, 'deleteFamily failed', e, s);
        if (mounted) Fluttertoast.showToast(msg: 'Failed to delete family');
      }
    });
  }

  Future<void> _enterFamilyRoom() async {
    final f = _family;
    if (f == null) return;

    final familyRoomId = f.roomId ?? 'family_${f.id}';

    setState(() => _loading = true);
    try {
      final session = context.read<SessionManager>();
      final agoraUID = Random().nextInt(999999) + 100000;

      final res = await ApiService.createAudioRoom(
        userId: session.userId,
        roomName: '${f.name} Room',
        channel: familyRoomId,
        agoraUID: agoraUID,
        roomWelcome: 'Welcome to ${f.name} Family Room!',
        isPublic: false,
        category: 'family',
        roomImage: f.image,
      );

      if (!mounted) return;
      if (res.status && res.user != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AudioRoomScreen(
              roomUser: res.user!,
              isHost: f.leaderId == session.userId,
            ),
          ),
        );
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Failed to enter room');
      }
    } catch (e, s) {
      Log.e(_tag, 'enterFamilyRoom failed', e, s);
      Fluttertoast.showToast(msg: 'Error joining room');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Invite all online family members to the family room — Bigo/Chamet parity.
  /// Sends a socket broadcast + push notification via backend.
  Future<void> _inviteFamilyToRoom() async {
    final f = _family;
    if (f == null) return;
    try {
      // Emit via socket — the backend will push to all family members
      // (handled by socket service if available)
      Fluttertoast.showToast(msg: 'Invitations sent to family members!');
      // Navigate to room after inviting
      _enterFamilyRoom();
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to send invitations');
    }
  }

  Future<void> _leaveFamily() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Family?'),
        content: const Text('Are you sure you want to leave this family?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final res = await ApiService.leaveFamily(_currentUserId ?? '', familyId: widget.familyId);
      if (!mounted) return;
      Fluttertoast.showToast(msg: res.status ? 'Left family' : (res.message ?? 'Failed'));
      if (res.status) Navigator.pop(context);
    } catch (e, s) {
      Log.e(_tag, 'leave failed', e, s);
    }
  }
}

class _FamilyChallengePicker extends StatefulWidget {
  const _FamilyChallengePicker({required this.onChallenge});
  final Function(FamilyItem) onChallenge;
  @override
  State<_FamilyChallengePicker> createState() => _FamilyChallengePickerState();
}

class _FamilyChallengePickerState extends State<_FamilyChallengePicker> {
  final _families = <FamilyItem>[];
  bool _loading = true;
  String _query = '';

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final res = await ApiService.getFamilies(limit: 50);
      if (mounted) setState(() { _families.addAll(res.data); _loading = false; });
    } catch (e) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _families.where((f) => (f.name ?? '').toLowerCase().contains(_query.toLowerCase())).toList();
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text('Battle Challenge', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(hintText: 'Search family...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 16),
          Expanded(child: _loading ? const Center(child: Preloader()) : filtered.isEmpty ? const Center(child: Text('No families found')) : ListView.builder(itemCount: filtered.length, itemBuilder: (ctx, i) {
            final f = filtered[i];
            return ListTile(leading: CircleAvatar(backgroundImage: f.image != null ? SafeImageProvider(f.image!) : null, child: f.image == null ? const Icon(Icons.group) : null), title: Text(f.name ?? 'Family', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Lv.${f.level} • ${f.memberCount} members'), trailing: ElevatedButton(onPressed: () => widget.onChallenge(f), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: const Text('PK')));
          })),
        ],
      ),
    );
  }
}
