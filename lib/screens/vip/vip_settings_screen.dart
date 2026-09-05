/// VIP Settings screen — ported from native `VipSettingsActivity.java`.
///
/// Features:
/// - Toggle items: Hide visitor records, Avoid disturbing, Hide online status
/// - Arrow items: View visitors, Profile background, Customized theme,
///   Special ID, Dynamic avatar, Unban account, Ban account, Dedicated support
/// - VIP level gating: items unlock at specific VIP levels
/// - Plans & Tiers tabs for purchasing VIP
library vip_settings;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/user_root.dart';
import '../../models/vip_models.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../utils/log.dart';
import '../../utils/media_utils.dart';
import '../../widgets/premium_ui.dart';
import '../../widgets/svga_player_widget.dart';
import '../../widgets/theme_picker_sheet.dart';

class VipSettingsScreen extends StatefulWidget {
  const VipSettingsScreen({super.key});

  @override
  State<VipSettingsScreen> createState() => _VipSettingsScreenState();
}

class _VipSettingsScreenState extends State<VipSettingsScreen>
    with SingleTickerProviderStateMixin {
  static const String _tag = 'VipSettings';

  late final TabController _tab;
  List<VipPlanItem> _plans = [];
  List<VipTier> _tiers = [];
  bool _loading = true;
  bool _purchasing = false;
  int _userVipLevel = 0;
  String _vipExpiryText = '';
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _initPrefs();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final session = context.read<SessionManager>();
      final user = session.getUser();
      _userVipLevel = _extractVipLevel(user);
      final vipInfo = user?.vip;
      if (vipInfo?.expiresAt != null && vipInfo!.expiresAt!.isNotEmpty) {
        _vipExpiryText = 'Expires: ${vipInfo.expiresAt}';
      }

      final results = await Future.wait([
        ApiService.getVipPlans(),
        ApiService.getVipTiers(),
      ]);

      _plans = (results[0] as VipPlanRoot).vipPlan;
      _tiers = (results[1] as VipTierRoot).data;

    } catch (e, s) {
      Log.e(_tag, 'loadData failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _extractVipLevel(dynamic user) {
    try {
      final u = user as User?;
      // Prefer vipStatus.currentLevel
      final status = u?.vipStatus;
      if (status != null && status.currentLevel > 0) return status.currentLevel;
      // Fallback to vipInfo tierId
      final vipInfo = u?.vip;
      final tierId = vipInfo?.tierId?.toString() ?? vipInfo?.tier?.toString() ?? '';
      final digits = tierId.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isEmpty) return 0;
      return int.parse(digits);
    } catch (_) {
      return 0;
    }
  }

  Widget _buildVipStatusHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7E3FF2), Color(0xFF9B5FF5)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium, color: Colors.white, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VIP $_userVipLevel',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_vipExpiryText.isNotEmpty)
                  Text(_vipExpiryText, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  bool _hasPrivilegeFlag(String prefKey) {
    if (_userVipLevel == 0) return false;
    final user = context.read<SessionManager>().getUser();
    final vd = user?.vipDetails;
    if (vd == null) return _userVipLevel > 0;
    switch (prefKey) {
      case 'hide_visitor_records':
        return vd.isHideVisitRecordsEnabled || vd.isViewVisitorRecordsEnabled;
      case 'avoid_disturbing':
        return true;
      case 'hide_online_status':
        return true;
      default:
        return true;
    }
  }

  bool _isVip() {
    final user = context.read<SessionManager>().getUser();
    return user?.isVIP == true;
  }

  Future<void> _purchasePlan(VipPlanItem plan) async {
    if (_purchasing) return;
    final session = context.read<SessionManager>();
    final user = session.getUser();
    final diamonds = user?.coin.toInt() ?? 0;
    if (plan.dollar > diamonds) {
      Fluttertoast.showToast(msg: 'Not enough diamonds. Need ${formatCount(plan.dollar)}');
      context.pushNamed(AppRoutes.recharge);
      return;
    }
    setState(() => _purchasing = true);
    try {
      final res = await ApiService.purchaseVip(
        userId: session.userId,
        planId: plan.id ?? '',
        paymentType: 'diamond',
      );
      if (res.status) {
        Fluttertoast.showToast(msg: 'VIP activated!');
        _loadData();
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Purchase failed');
      }
    } catch (e) {
      Log.e(_tag, 'purchasePlan failed', e);
      Fluttertoast.showToast(msg: 'Failed: $e');
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _buyTier(VipTier tier) async {
    if (_purchasing) return;
    final session = context.read<SessionManager>();
    final user = session.getUser();
    final diamonds = user?.coin.toInt() ?? 0;
    if (tier.coinPrice > diamonds) {
      Fluttertoast.showToast(msg: 'Not enough diamonds. Need ${formatCount(tier.coinPrice)}');
      context.pushNamed(AppRoutes.recharge);
      return;
    }
    setState(() => _purchasing = true);
    try {
      final res = await ApiService.buyVipTier(
        userId: session.userId,
        tierId: tier.id ?? '',
      );
      if (res.status) {
        // The buy response may include an updated user object under
        // `user` / `data` / `userData`. Persist it so balances stay in sync.
        final json = res.data;
        final userJson = json?['user'] ?? json?['data'] ?? json?['userData'];
        if (userJson is Map<String, dynamic>) {
          session.saveUser(User.fromJson(userJson));
        } else {
          // No user payload — re-fetch the fresh balance.
          await context.read<AuthProvider>().refreshUser();
        }
        Fluttertoast.showToast(msg: res.message?.isNotEmpty == true ? res.message! : 'VIP tier activated!');
        _loadData();
      } else {
        Fluttertoast.showToast(msg: res.message?.isNotEmpty == true ? res.message! : 'Purchase failed');
      }
    } catch (e) {
      Log.e(_tag, 'buyTier failed', e);
      Fluttertoast.showToast(msg: 'Failed: $e');
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _toggleSetting(String prefKey, bool value) async {
    await _prefs.setBool(prefKey, value);
    if (!mounted) return;
    final session = context.read<SessionManager>();
    try {
      await ApiService.updateVipSetting(
        userId: session.userId,
        settingKey: prefKey,
        value: value,
      );
    } catch (e) {
      Log.e(_tag, 'toggleSetting API failed', e);
    }
  }

  void _showLockedMessage(int requiredLevel, String title) {
    Fluttertoast.showToast(msg: 'Enable VIP $requiredLevel to unlock $title');
  }

  String _getSupportNumber() {
    final setting = context.read<SessionManager>().getSetting();
    if (setting != null) {
      final vipNum = setting.vipSupportNumber ?? '';
      if (vipNum.isNotEmpty) return vipNum.replaceAll(RegExp(r'[^0-9]'), '');
      final waNum = setting.whatsapp ?? '';
      if (waNum.isNotEmpty) return waNum.replaceAll(RegExp(r'[^0-9]'), '');
    }
    return '0000000000';
  }

  // ignore: unused_element
  Future<void> _openWhatsAppSupport() async {
    try {
      final supportNumber = _getSupportNumber();
      final supportUrl = 'https://wa.me/$supportNumber';
      final uri = Uri.parse(supportUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Fluttertoast.showToast(msg: 'Unable to open WhatsApp. Number: $supportNumber');
      }
    } catch (e) {
      Log.e(_tag, 'openWhatsAppSupport failed', e);
      Fluttertoast.showToast(msg: 'Unable to open WhatsApp support');
    }
  }

  Future<void> _fetchAndShowVisitorRecords() async {
    final session = context.read<SessionManager>();
    final userId = session.userId;
    if (userId.isEmpty) {
      Fluttertoast.showToast(msg: 'Please login first');
      return;
    }
    Fluttertoast.showToast(msg: 'Loading visitor records...');
    try {
      final res = await ApiService.getVisitorRecords(userId);
      final data = res['data'];
      if (data is List && data.isNotEmpty) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Visitor Records (${data.length})'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: data.length,
                itemBuilder: (_, i) {
                  final v = data[i] is Map ? data[i] as Map : <String, dynamic>{};
                  final name = v['name']?.toString() ?? v['userId']?['name']?.toString() ?? 'Unknown';
                  final image = v['image']?.toString() ?? v['userId']?['image']?.toString() ?? '';
                  final visitedAt = v['visitedAt']?.toString() ?? v['createdAt']?.toString() ?? '';
                  final count = v['count']?.toString() ?? '';
                  return ListTile(
                    leading: ClipOval(
                      child: image.isNotEmpty
                          ? CachedNetworkImage(imageUrl: image, width: 40, height: 40, fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(width: 40, height: 40, color: Colors.grey.shade300, child: const Icon(Icons.person, size: 20)))
                          : Container(width: 40, height: 40, color: Colors.grey.shade300, child: const Icon(Icons.person, size: 20)),
                    ),
                    title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      visitedAt.isNotEmpty ? visitedAt : (count.isNotEmpty ? 'Visits: $count' : ''),
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          ),
        );
      } else {
        Fluttertoast.showToast(msg: 'No visitor records found');
      }
    } catch (e) {
      Log.e(_tag, 'fetchVisitorRecords failed', e);
      Fluttertoast.showToast(msg: 'Failed to load visitor records');
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
              _buildCustomAppBar(),
              _buildTabBar(),
              Expanded(
                child: _loading
                    ? const Center(child: PremiumLoading())
                    : TabBarView(
                        controller: _tab,
                        children: [
                          _privilegesTab(),
                          _plansTab(),
                          _tiersTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'VIP Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48), // Spacer to balance back button
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: AppTheme.goldGradient,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.black,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(text: 'Privileges'),
          Tab(text: 'Plans'),
          Tab(text: 'Tiers'),
        ],
      ),
    );
  }

  // ---- Privileges Tab -----------------------------------------------------
  Widget _privilegesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildVipStatusHeader(),
        const SizedBox(height: 24),
        const Text('Privacy Settings',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFFD700))),
        const SizedBox(height: 12),
        _buildToggleItem(
          badge: 'VIP 2',
          title: 'Hide Visitor Records',
          desc: 'No visiting records will be left when you visit other people\'s profiles.',
          prefKey: 'hide_visitor_records',
          requiredLevel: 2,
          icon: Icons.visibility_off,
        ),
        _buildToggleItem(
          badge: 'VIP 4',
          title: 'Avoid Disturbing',
          desc: 'Only users you follow can chat with you privately.',
          prefKey: 'avoid_disturbing',
          requiredLevel: 4,
          icon: Icons.do_not_disturb_on,
        ),
        _buildToggleItem(
          badge: 'VIP 6',
          title: 'Hide Online Status',
          desc: 'When you enter a room, others will not be able to see you.',
          prefKey: 'hide_online_status',
          requiredLevel: 6,
          icon: Icons.cloud_off,
        ),
        const SizedBox(height: 24),
        const Text('VIP Features',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFFD700))),
        const SizedBox(height: 12),
        _buildArrowItem(
          badge: 'VIP 2',
          title: 'View Visitor Records',
          requiredLevel: 2,
          icon: Icons.recent_actors,
          onTap: () {
            if (!_isVip() || _userVipLevel < 2) {
              _showLockedMessage(2, 'View Visitor Records');
            } else {
              _fetchAndShowVisitorRecords();
            }
          },
        ),
        _buildArrowItem(
          badge: 'VIP 3',
          title: 'Profile Background',
          requiredLevel: 3,
          icon: Icons.wallpaper,
          onTap: () {
            if (!_isVip() || _userVipLevel < 3) {
              _showLockedMessage(3, 'Profile Background');
            } else {
              context.pushNamed(AppRoutes.profileBackground);
            }
          },
        ),
        _buildArrowItem(
          badge: 'VIP 3',
          title: 'Customized Theme',
          requiredLevel: 3,
          icon: Icons.palette,
          onTap: () {
            if (!_isVip() || _userVipLevel < 3) {
              _showLockedMessage(3, 'Customized Theme');
            } else {
              showThemePickerSheet(context, onSelected: (themeId) {
                Fluttertoast.showToast(msg: 'Theme updated');
              });
            }
          },
        ),
        _buildArrowItem(
          badge: 'VIP 5',
          title: 'Special ID',
          requiredLevel: 5,
          icon: Icons.badge,
          onTap: () {
            if (!_isVip() || _userVipLevel < 5) {
              _showLockedMessage(5, 'Special ID');
            } else {
              context.pushNamed(AppRoutes.specialId);
            }
          },
        ),
        _buildArrowItem(
          badge: 'VIP 5',
          title: 'Dynamic Avatar (Gif)',
          requiredLevel: 5,
          icon: Icons.gif,
          onTap: () {
            if (!_isVip() || _userVipLevel < 5) {
              _showLockedMessage(5, 'Dynamic Avatar');
            } else {
              context.pushNamed(AppRoutes.dynamicAvatar, extra: {'avatars': []});
            }
          },
        ),
        _buildArrowItem(
          badge: 'VIP 7',
          title: 'Unban Account',
          requiredLevel: 7,
          icon: Icons.lock_open,
          onTap: () {
            if (!_isVip() || _userVipLevel < 7) {
              _showLockedMessage(7, 'Unban Account');
            } else {
              context.pushNamed(AppRoutes.unbanAccount);
            }
          },
        ),
        _buildArrowItem(
          badge: 'VIP 9',
          title: 'Ban Account',
          requiredLevel: 9,
          icon: Icons.block,
          onTap: () {
            if (!_isVip() || _userVipLevel < 9) {
              _showLockedMessage(9, 'Ban Account');
            } else {
              context.pushNamed(AppRoutes.banAccount, extra: {
                'onBan': () {},
                'onUnban': () {},
              });
            }
          },
        ),
        // ---- Bigo/Chamet parity additions --------------------------------
        _buildArrowItem(
          badge: 'VIP 1',
          title: 'VIP Leaderboard',
          requiredLevel: 1,
          icon: Icons.leaderboard,
          onTap: () {
            if (!_isVip() || _userVipLevel < 1) {
              _showLockedMessage(1, 'VIP Leaderboard');
            } else {
              context.pushNamed(AppRoutes.vipLeaderboard);
            }
          },
        ),
        _buildArrowItem(
          badge: 'VIP 1',
          title: 'Daily Bonus',
          requiredLevel: 1,
          icon: Icons.card_giftcard,
          onTap: () {
            if (!_isVip() || _userVipLevel < 1) {
              _showLockedMessage(1, 'Daily Bonus');
            } else {
              context.pushNamed(AppRoutes.dailyBonus);
            }
          },
        ),
        _buildArrowItem(
          badge: 'VIP 1',
          title: 'Compare VIP Tiers',
          requiredLevel: 1,
          icon: Icons.compare_arrows,
          onTap: () {
            context.pushNamed(AppRoutes.vipTierComparison);
          },
        ),
        _buildArrowItem(
          badge: 'FREE',
          title: 'VIP Trial',
          requiredLevel: 0,
          icon: Icons.bolt,
          onTap: () {
            context.pushNamed(AppRoutes.vipTrial);
          },
        ),
        _buildArrowItem(
          badge: 'VIP 3',
          title: 'VIP Theme Gallery',
          requiredLevel: 3,
          icon: Icons.palette_outlined,
          onTap: () {
            if (!_isVip() || _userVipLevel < 3) {
              _showLockedMessage(3, 'VIP Theme Gallery');
            } else {
              context.pushNamed(AppRoutes.vipThemeGallery);
            }
          },
        ),
        _buildArrowItem(
          badge: 'VIP 3',
          title: 'VIP Profile Background',
          requiredLevel: 3,
          icon: Icons.wallpaper_outlined,
          onTap: () {
            if (!_isVip() || _userVipLevel < 3) {
              _showLockedMessage(3, 'VIP Profile Background');
            } else {
              context.pushNamed(AppRoutes.vipProfileBackground);
            }
          },
        ),
        _buildArrowItem(
          badge: 'VIP 1',
          title: 'Gifting Cashback',
          requiredLevel: 1,
          icon: Icons.redeem,
          onTap: () {
            if (!_isVip() || _userVipLevel < 1) {
              _showLockedMessage(1, 'Gifting Cashback');
            } else {
              context.pushNamed(AppRoutes.giftingCashback);
            }
          },
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildToggleItem({
    required String badge,
    required String title,
    required String desc,
    required String prefKey,
    required int requiredLevel,
    required IconData icon,
  }) {
    final isUnlocked = _userVipLevel >= requiredLevel;
    // Auto-ON when unlocked (like Bigo Live / Ola Party): VIP buy karte hi
    // saare privileges active ho jaaye. User baad mein OFF kar sakta hai.
    final isOn = _prefs.getBool(prefKey) ?? isUnlocked;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnlocked ? const Color(0x40FFD700) : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: isUnlocked ? AppTheme.goldGradient : null,
                  color: isUnlocked ? null : Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: isUnlocked ? Colors.black : Colors.white24, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PremiumBadge(text: badge, gradient: AppTheme.goldGradient),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isUnlocked ? Colors.white : Colors.white38,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 12,
                        color: isUnlocked ? Colors.white70 : Colors.white24,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isUnlocked && isOn,
                activeTrackColor: const Color(0xFFFFD700),
                onChanged: isUnlocked
                    ? (val) {
                        _toggleSetting(prefKey, val);
                        setState(() {});
                      }
                    : null,
              ),
            ],
          ),
          if (!isUnlocked)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 60),
              child: Text(
                'Unlock at VIP $requiredLevel',
                style: const TextStyle(fontSize: 11, color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArrowItem({
    required String badge,
    required String title,
    required int requiredLevel,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isUnlocked = _userVipLevel >= requiredLevel;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        tileColor: Colors.white.withValues(alpha: 0.05),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: isUnlocked ? AppTheme.purpleGradient : null,
            color: isUnlocked ? null : Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        title: Row(
          children: [
            PremiumBadge(text: badge, gradient: AppTheme.goldGradient),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isUnlocked ? Colors.white : Colors.white38,
                ),
              ),
            ),
          ],
        ),
        trailing: isUnlocked
            ? const Icon(Icons.chevron_right, color: Colors.white54)
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Lv $requiredLevel',
                  style: const TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold),
                ),
              ),
      ),
    );
  }

  // ---- Plans Tab ----------------------------------------------------------
  Widget _plansTab() {
    if (_plans.isEmpty) {
      return const Center(child: Text('No VIP plans available', style: TextStyle(color: AppTheme.textTertiary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _plans.length,
      itemBuilder: (ctx, i) => _planCard(_plans[i]),
    );
  }

  Widget _planCard(VipPlanItem plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name ?? 'VIP Plan',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              if (plan.isTop)
                const PremiumBadge(text: 'POPULAR', gradient: AppTheme.goldGradient),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${plan.validity} ${plan.validityType ?? 'days'}',
            style: const TextStyle(color: Colors.white60, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('💎', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                formatCount(plan.dollar),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFFFD700)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _purchasing ? null : () => _purchasePlan(plan),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Activate',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Tiers Tab ----------------------------------------------------------
  Widget _tiersTab() {
    if (_tiers.isEmpty) {
      return const Center(child: Text('No VIP tiers available', style: TextStyle(color: AppTheme.textTertiary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tiers.length,
      itemBuilder: (ctx, i) => _tierCard(_tiers[i]),
    );
  }

  Widget _tierCard(VipTier tier) {
    final isTagSvga = SvgaHelper.isSvgaUrl(tier.tagUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (tier.tagUrl != null && tier.tagUrl!.isNotEmpty)
                isTagSvga
                    ? SvgaPlayer(url: tier.tagUrl!, width: 32, height: 32, allowAnimation: false)
                    : CachedNetworkImage(
                        imageUrl: tier.tagUrl!,
                        width: 32,
                        height: 32,
                        errorWidget: (_, __, ___) => const Icon(Icons.workspace_premium, color: Colors.amber),
                      )
              else
                const Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tier.name ?? 'VIP Tier',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _privilegeRow('Profile Frame', tier.profileFrameUrl),
          _privilegeRow('Level Badge', tier.levelBadgeUrl),
          _privilegeRow('Entrance Animation', tier.entranceAnimationUrl),
          _privilegeRow('Chat Bubble', tier.chatBubbleUrl),
          _privilegeRow('Room Card', tier.roomCardUrl),
          _privilegeRow('Voice Wave', tier.voiceWaveUrl),
          _privilegeRow('Profile Background', tier.profileBackgroundUrl),
          _privilegeRow('Exclusive Theme', tier.exclusiveThemeUrl),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('💎', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                formatCount(tier.coinPrice),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFFFD700)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _purchasing ? null : () => _buyTier(tier),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Buy',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _privilegeRow(String label, String? url) {
    final has = url != null && url.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(has ? Icons.check_circle : Icons.remove_circle_outline,
              size: 18, color: has ? const Color(0xFF00FF00) : Colors.white24),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: has ? Colors.white : Colors.white38,
                  fontWeight: has ? FontWeight.w500 : FontWeight.normal)),
        ],
      ),
    );
  }
}
