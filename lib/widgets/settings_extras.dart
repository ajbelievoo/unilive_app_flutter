/// Settings extras â€” helper dialogs used by the settings screen.
///
/// Provides `showChangePasswordDialog` and `showLanguageSelector` used by
/// `SettingsScreen`.
library settings_extras;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';

/// Shows a bottom sheet with a simple change-password form.
void showChangePasswordDialog(BuildContext context) {
  final oldCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Change Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: oldCtrl,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Current password', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: newCtrl,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'New password', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: confirmCtrl,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Confirm new password', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                if (newCtrl.text != confirmCtrl.text) {
                  Fluttertoast.showToast(msg: 'Passwords do not match');
                  return;
                }
                if (newCtrl.text.isEmpty) {
                  Fluttertoast.showToast(msg: 'Enter a new password');
                  return;
                }
                Navigator.pop(ctx);
                try {
                  final session = context.read<SessionManager>();
                  final res = await ApiService.changePassword(
                    userId: session.userId,
                    oldPassword: oldCtrl.text,
                    newPassword: newCtrl.text,
                  );
                  Fluttertoast.showToast(msg: res.message ?? 'Password changed successfully');
                } catch (e) {
                  Fluttertoast.showToast(msg: 'Failed to change password');
                }
              },
              child: const Text('Update Password'),
            ),
          ),
        ],
      ),
    ),
  );
}

const String kAppLanguageKey = 'app_language';

/// Returns the user's saved app language (defaults to English).
Future<String> getSavedAppLanguage() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(kAppLanguageKey) ?? 'English';
}

/// Shows a bottom sheet with available languages for selection.
Future<void> showLanguageSelector(BuildContext context) async {
  // Urdu included for Pakistani users.
  const languages = ['English', 'Urdu', 'Arabic', 'Hindi', 'Spanish', 'French', 'Portuguese'];
  String selected = await getSavedAppLanguage();
  if (!context.mounted) return;

  showModalBottomSheet(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Select Language', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: languages
                  .map((l) => RadioListTile<String>(
                        value: l,
                        groupValue: selected,
                        onChanged: (v) async {
                          if (v == null) return;
                          setState(() => selected = v);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString(kAppLanguageKey, v);
                          if (ctx.mounted) Navigator.pop(ctx);
                          Fluttertoast.showToast(msg: 'Language: $v');
                        },
                        title: Text(l),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    ),
  );
}

