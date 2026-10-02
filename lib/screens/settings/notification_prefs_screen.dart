import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../routes/app_routes.dart';

import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../widgets/preloader.dart';

/// Per-category notification preferences.
///
/// Each switch maps to a backend `user.notification.<key>` toggle that gates
/// FCM push delivery server-side. The master "All Notifications" switch
/// mutes everything without losing the per-category choices.
class NotificationPrefsScreen extends StatefulWidget {
  const NotificationPrefsScreen({super.key});

  @override
  State<NotificationPrefsScreen> createState() =>
      _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState extends State<NotificationPrefsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  /// key → current value. Backend defaults missing keys to on.
  final Map<String, bool> _prefs = {
    for (final k in _categories) k.key: true,
  };

  static const _categories = <_PrefCategory>[
    _PrefCategory('all', 'All Notifications', 'Master switch — turn off to mute everything', Icons.notifications),
    _PrefCategory('message', 'Messages', 'New chat messages', Icons.chat_bubble_outline),
    _PrefCategory('call', 'Calls', 'Incoming voice & video calls', Icons.call_outlined),
    _PrefCategory('favoriteLive', 'Live Streams', 'When someone you follow goes live', Icons.live_tv_outlined),
    _PrefCategory('newFollow', 'New Followers', 'When someone follows you', Icons.person_add_alt),
    _PrefCategory('likeCommentShare', 'Likes, Comments & Posts', 'Activity on your posts and reels', Icons.favorite_border),
    _PrefCategory('gift', 'Gifts & Rewards', 'Gift received and reward notifications', Icons.card_giftcard),
    _PrefCategory('cp', 'Couple (CP)', 'CP requests, level ups and bond updates', Icons.favorite),
    _PrefCategory('friend', 'Friends', 'Friend requests and bond updates', Icons.people_alt_outlined),
    _PrefCategory('family', 'Family', 'Family invites, tasks and events', Icons.groups_outlined),
    _PrefCategory('system', 'System & Announcements', 'Level ups, VIP, KYC, referrals, admin notices', Icons.campaign_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<SessionManager>().userId;
    if (userId.isEmpty) {
      setState(() {
        _loading = false;
        _loadError = 'Not logged in';
      });
      return;
    }
    try {
      final prefs = await ApiService.getNotificationPrefs(userId: userId);
      if (!mounted) return;
      if (prefs != null) {
        context.read<SessionManager>().saveNotifPrefs(prefs);
        setState(() {
          _prefs.addAll(prefs);
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _loadError = 'Could not load preferences';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load preferences';
      });
    }
  }

  Future<void> _set(String key, bool value) async {
    if (_saving) return;
    final userId = context.read<SessionManager>().userId;
    final previous = _prefs[key] ?? true;
    setState(() {
      _prefs[key] = value;
      _saving = true;
    });
    try {
      final res = await ApiService.updateNotificationPrefs(
        userId: userId,
        prefs: {key: value},
      );
      if (!mounted) return;
      if (res == null) {
        setState(() => _prefs[key] = previous);
        Fluttertoast.showToast(msg: 'Failed to save preference');
      } else {
        setState(() => _prefs.addAll(res));
        final session = context.read<SessionManager>();
        session.saveNotifPrefs(res);
        // Mirror the master switch into the local session flag used by the
        // client-side push handler.
        if (res.containsKey('all')) {
          session.saveNotification(res['all'] ?? true);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _prefs[key] = previous);
        Fluttertoast.showToast(msg: 'Failed to save preference');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final masterOn = _prefs['all'] ?? true;
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences')),
      body: _loading
          ? const Center(child: Preloader())
          : _loadError != null
              ? _errorState()
              : ListView(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.inbox_outlined, color: AppTheme.primary),
                      title: const Text('Notification Inbox'),
                      subtitle: const Text('View all received notifications', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () => context.pushNamed(AppRoutes.notifications),
                    ),
                    Divider(height: 1, color: AppTheme.fg(context, 0.08)),
                    // Master switch pinned at the top.
                    SwitchListTile(
                      secondary: const Icon(Icons.notifications, color: AppTheme.primary),
                      title: Text(
                        _categories.first.label,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(_categories.first.subtitle, style: const TextStyle(fontSize: 12)),
                      value: masterOn,
                      onChanged: (v) => _set('all', v),
                    ),
                    Divider(height: 1, color: AppTheme.fg(context, 0.08)),
                    Opacity(
                      opacity: masterOn ? 1.0 : 0.45,
                      child: Column(
                        children: [
                          for (final c in _categories.skip(1))
                            SwitchListTile(
                              secondary: Icon(c.icon, color: AppTheme.primary),
                              title: Text(c.label),
                              subtitle: Text(c.subtitle, style: const TextStyle(fontSize: 12)),
                              value: masterOn && (_prefs[c.key] ?? true),
                              onChanged: masterOn ? (v) => _set(c.key, v) : null,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(_loadError!, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          TextButton(onPressed: () { setState(() { _loading = true; _loadError = null; }); _load(); }, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _PrefCategory {
  const _PrefCategory(this.key, this.label, this.subtitle, this.icon);
  final String key;
  final String label;
  final String subtitle;
  final IconData icon;
}
