import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../misc/web_view_screen.dart';
import '../../constants/const.dart';
import '../../providers/auth_provider.dart';
import '../../providers/call_config_provider.dart';
import '../../providers/kyc_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../widgets/report_issue_dialog.dart';
import '../../widgets/settings_extras.dart';

/// Ported from native `SettingActivity.java`.
///
/// Phase 22 enhancement: all stubs wired up — privacy, clear cache, FAQ,
/// about, complaints, dark mode, notifications, share app.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _darkMode = false;
  bool _videoCallOptIn = true; // Hosts are visible by default; can opt-out.
  bool _doNotDisturb = false;
  bool _autoAnswerVip = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final session = context.read<SessionManager>();
    setState(() {
      _notifications = session.getNotification();
      _darkMode = context.read<ThemeProvider>().isDark;
      _videoCallOptIn = session.getUser()?.videoCallOptIn ?? true;
      _doNotDisturb = session.getBool(Const.doNotDisturb);
      _autoAnswerVip = session.getBool('autoAnswerVip');
    });
    // Load KYC status so the settings tile shows the correct subtitle.
    if (session.userId.isNotEmpty) {
      context.read<KycProvider>().load(session.userId);
    }
  }

  Future<void> _toggleNotifications(bool v) async {
    final session = context.read<SessionManager>();
    session.saveNotification(v);
    setState(() => _notifications = v);
    Fluttertoast.showToast(msg: v ? 'Notifications enabled' : 'Notifications disabled');
  }

  Future<void> _toggleVideoCallOptIn(bool v) async {
    final session = context.read<SessionManager>();
    final user = session.getUser();
    if (user == null) return;
    setState(() => _videoCallOptIn = v);
    try {
      await ApiService.updateUser(fields: {
        'userId': user.id ?? '',
        'videoCallOptIn': v.toString(),
      });
      Fluttertoast.showToast(msg: v ? 'You are now visible in video call list' : 'Removed from video call list');
    } catch (e) {
      if (mounted) setState(() => _videoCallOptIn = !v);
      Fluttertoast.showToast(msg: 'Failed to update');
    }
  }

  Future<void> _toggleDarkMode(bool v) async {
    await context.read<ThemeProvider>().setMode(v ? ThemeMode.dark : ThemeMode.light);
    setState(() => _darkMode = v);
  }

  Future<void> _toggleDnd(bool v) async {
    final session = context.read<SessionManager>();
    session.saveBool(Const.doNotDisturb, v);
    setState(() => _doNotDisturb = v);
    Fluttertoast.showToast(
      msg: v ? 'Do Not Disturb enabled — incoming calls will be declined' : 'Do Not Disturb disabled',
    );
  }

  Future<void> _toggleAutoAnswerVip(bool v) async {
    final session = context.read<SessionManager>();
    session.saveBool('autoAnswerVip', v);
    setState(() => _autoAnswerVip = v);
    Fluttertoast.showToast(
      msg: v ? 'Auto-answer for VIP callers enabled' : 'Auto-answer disabled',
    );
  }

  Future<void> _clearCache() async {
    try {
      final cache = DefaultCacheManager();
      await cache.emptyCache();
      Fluttertoast.showToast(msg: 'Cache cleared');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to clear cache');
    }
  }

  void _shareApp() {
    final session = context.read<SessionManager>();
    final userName = session.userName;
    Share.share(
      'Check out Belive! Live streaming, video calls, and more. Download now and follow $userName.',
      subject: 'Belive App',
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Belive',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2026 Belive. All rights reserved.',
      applicationIcon: const FlutterLogo(size: 48),
    );
  }

  void _showFaq() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('FAQ & Help', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _faqItem('How to go live?', 'Tap the Live tab, then press the "Go Live" button. Make sure you have host permissions.'),
            _faqItem('How to recharge?', 'Go to Wallet > Recharge and select a diamond plan.'),
            _faqItem('How to withdraw earnings?', 'Go to Wallet > Cash Out and submit a redeem request.'),
            _faqItem('How to become a host?', 'Go to Profile > Become a Host and submit your application.'),
            _faqItem('How to send gifts?', 'Tap the gift icon in a live room or chat, select a gift, and send it.'),
            _faqItem('How to block someone?', 'Go to their profile, tap the menu, and select Block.'),
          ],
        ),
      ),
    );
  }

  void _showReportIssue() {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final userId = context.read<SessionManager>().userId;
    showReportIssueDialog(context, currentRoute: currentRoute, userId: userId);
  }

  Widget _faqItem(String q, String a) {
    return ExpansionTile(
      title: Text(q, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Text(a, style: const TextStyle(fontSize: 13, color: Colors.grey)))],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _section('Account'),
          _tile(Icons.shield, 'Account Status',
              (user?.isPhoneBound ?? false) || (user?.isGoogleBound ?? false) ? 'Protected' : 'Unprotected',
              onTap: () => context.pushNamed(AppRoutes.accountBinding)),
          if (context.read<KycProvider>().isEnabled)
            _tile(Icons.verified_user, 'KYC Verification', _kycStatusText(), onTap: () {
              context.pushNamed(AppRoutes.kyc);
            }),
          _tile(Icons.lock, 'Privacy Settings', '', onTap: () => _showPrivacySettings()),
          _tile(Icons.block, 'Blocked Users', '', onTap: () {
            context.pushNamed(AppRoutes.blockedUsers);
          }),
          _tile(Icons.notifications_active, 'Notifications', '', onTap: () {
            context.pushNamed(AppRoutes.notifications);
          }),
          _tile(Icons.password, 'Change Password', '', onTap: () => showChangePasswordDialog(context)),
          SwitchListTile(
            secondary: const Icon(Icons.notifications, color: Color(0xFF7E3FF2)),
            title: const Text('Notifications'),
            value: _notifications,
            onChanged: _toggleNotifications,
          ),
          if (context.read<SessionManager>().getUser()?.isHost ?? false) ...[
            SwitchListTile(
              secondary: const Icon(Icons.videocam, color: Color(0xFF7E3FF2)),
              title: const Text('Video Call Listing'),
              subtitle: const Text('Show in video call hosts list', style: TextStyle(fontSize: 12)),
              value: _videoCallOptIn,
              onChanged: _toggleVideoCallOptIn,
            ),
          ],
          SwitchListTile(
            secondary: const Icon(Icons.do_not_disturb_on, color: Color(0xFF7E3FF2)),
            title: const Text('Do Not Disturb'),
            subtitle: const Text('Auto-decline incoming 1-on-1 calls', style: TextStyle(fontSize: 12)),
            value: _doNotDisturb,
            onChanged: _toggleDnd,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.star, color: Color(0xFFFFD700)),
            title: const Text('Auto-Answer VIP Calls'),
            subtitle: const Text('Automatically accept calls from VIP users', style: TextStyle(fontSize: 12)),
            value: _autoAnswerVip,
            onChanged: _toggleAutoAnswerVip,
          ),
          Consumer<CallConfigProvider>(
            builder: (_, cfg, __) => SwitchListTile(
              secondary: const Icon(Icons.face_retouching_natural, color: Color(0xFF7E3FF2)),
              title: const Text('Call Face Privacy Guard'),
              subtitle: const Text('Hide remote video if your face is not visible', style: TextStyle(fontSize: 12)),
              value: cfg.privacyGuardEnabled,
              onChanged: (v) => cfg.setPrivacyGuardEnabled(v),
            ),
          ),
          _section('General'),
          _tile(Icons.cleaning_services, 'Clear Cache', '', onTap: _clearCache),
          _tile(Icons.language, 'Language', 'English', onTap: () => showLanguageSelector(context)),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode, color: Color(0xFF7E3FF2)),
            title: const Text('Dark Mode'),
            value: _darkMode,
            onChanged: _toggleDarkMode,
          ),
          _tile(Icons.share, 'Share App', '', onTap: _shareApp),
          _section('Support'),
          _tile(Icons.help, 'FAQ / Help', '', onTap: _showFaq),
          _tile(Icons.bug_report_outlined, 'Report Issue', '', onTap: _showReportIssue),
          _tile(Icons.privacy_tip, 'Privacy Policy', '', onTap: () => _openWebView('Privacy Policy', 'privacyPolicyLink')),
          _tile(Icons.description, 'Terms of Service', '', onTap: () => _openWebView('Terms of Service', 'termsConditionLink')),
          _tile(Icons.info, 'About Us', '', onTap: _showAboutDialog),
          _section('Complaints'),
          _tile(Icons.report, 'My Complaints', '', onTap: () => context.pushNamed(AppRoutes.complaints)),
          _tile(Icons.add_circle, 'Create Complaint', '', onTap: () => context.pushNamed(AppRoutes.createComplaint)),
          _tile(Icons.feedback, 'Feedback', '', onTap: () => context.pushNamed(AppRoutes.feedback)),
          _section('Extras'),
          _tile(Icons.history, 'Call History', '', onTap: () => context.pushNamed(AppRoutes.callHistory)),
          _tile(Icons.diamond, 'Call Rate & Host Guide', '', onTap: () => context.pushNamed(AppRoutes.callRateSettings)),
          _tile(Icons.notifications_active, 'Activity Center', '', onTap: () => context.pushNamed(AppRoutes.activityCenter)),
          _tile(Icons.emoji_events, 'Levels', '', onTap: () => context.pushNamed(AppRoutes.levels)),
          _tile(Icons.group_add, 'Invite & Earn', '', onTap: () => context.pushNamed(AppRoutes.referral)),
          _section('Account'),
          _tile(Icons.delete_forever, 'Delete Account', 'Permanently delete account and data', onTap: _confirmDeleteAccount),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _confirmLogout(context),
              child: const Text('Logout'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showPrivacySettings() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Text('Privacy Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('Profile Visitors'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                context.pushNamed(AppRoutes.visitors);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Followers'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                context.pushNamed(AppRoutes.followers);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Blocked Users'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                context.pushNamed(AppRoutes.blockedUsers);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
    );
  }

  /// Returns a short KYC status string for the settings tile subtitle.
  String _kycStatusText() {
    final kyc = context.read<KycProvider>();
    if (!kyc.isEnabled) return 'Not available';
    final s = kyc.status;
    if (s.isVerified) return 'Verified · Level ${s.kycLevel}';
    if (s.isPending) return 'In progress';
    if (s.isRejected) return 'Rejected';
    return 'Required for withdrawals';
  }

  Widget _tile(IconData icon, String title, String subtitle, {required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF7E3FF2)),
      title: Text(title),
      subtitle: subtitle.isEmpty ? null : Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _openWebView(String title, String? settingKey) {
    final session = context.read<SessionManager>();
    String url = '';
    final setting = session.getSetting();
    if (settingKey == 'privacyPolicyLink') {
      url = setting?.privacyPolicy ?? '';
    } else if (settingKey == 'termsConditionLink') {
      url = setting?.termsCondition ?? '';
    }
    if (url.isEmpty) {
      Fluttertoast.showToast(msg: '$title link not available');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WebViewScreen(title: title, url: url)),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AuthProvider>().logout(context);
      if (context.mounted) {
        context.goNamed(AppRoutes.splash);
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all associated data (profile, wallet, posts, chats, live history). This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final session = context.read<SessionManager>();
    final router = GoRouter.of(context);
    final userId = session.userId;
    if (userId.isEmpty) {
      Fluttertoast.showToast(msg: 'Not logged in');
      return;
    }

    try {
      final res = await ApiService.deleteAccount(userId);
      if (res.status == true) {
        Fluttertoast.showToast(msg: res.message ?? 'Account deletion requested');
        session.logout();
        ApiClient.setAuthToken(null);
        router.goNamed(AppRoutes.splash);
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Account deletion failed');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Account deletion failed. Please contact support.');
    }
  }
}
