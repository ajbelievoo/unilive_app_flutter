/// "Enable Notifications?" pre-permission dialog.
///
/// Shown once on the home screen before the OS permission prompt — the user
/// taps "Yes, Enable Notification" and only then do we fire the real system
/// permission request. "No, I'm good" snoozes the prompt for 7 days.
library notification_prompt;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../utils/log.dart';

class NotificationPrompt {
  static const String _tag = 'NotifPrompt';
  static const String _prefKey = 'notif_prompt_snooze_until';

  /// Show the pre-prompt if the OS permission isn't granted and the snooze
  /// window (7 days after "No, I'm good") has elapsed.
  static Future<void> maybeShow(BuildContext context) async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) return;

      final prefs = await SharedPreferences.getInstance();
      final snoozeUntil = prefs.getInt(_prefKey) ?? 0;
      if (DateTime.now().millisecondsSinceEpoch < snoozeUntil) return;

      if (!context.mounted) return;
      final allow = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _NotificationPromptDialog(),
      );

      if (allow == true) {
        await requestNow();
      } else {
        // Snooze for 7 days.
        await prefs.setInt(
          _prefKey,
          DateTime.now().millisecondsSinceEpoch + const Duration(days: 7).inMilliseconds,
        );
      }
    } catch (e, s) {
      Log.e(_tag, 'maybeShow failed', e, s);
    }
  }

  /// Fire the real OS permission request. On Android 13+ firebase_messaging
  /// requests POST_NOTIFICATIONS; on iOS it requests alert/badge/sound.
  static Future<void> requestNow() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e, s) {
      Log.e(_tag, 'requestNow failed', e, s);
    }
  }
}

class _NotificationPromptDialog extends StatelessWidget {
  const _NotificationPromptDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(
          color: AppTheme.themed(context, 0xFF1C1C30, 0xFFFFFFFF),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Megaphone illustration
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 56),
            ),
            const SizedBox(height: 20),
            Text(
              'Enable Notifications?',
              style: TextStyle(
                color: AppTheme.fg(context),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Stay updated with amazing offers, calls,\nlive streams and messages.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.fg(context, 0.6), fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  child: const Text(
                    'Yes, Enable Notification',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                "No, I'm good",
                style: TextStyle(
                  color: AppTheme.fg(context, 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
