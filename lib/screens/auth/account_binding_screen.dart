import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

/// Ported from native `AccountActivity.java` + `BindPhoneActivity.java`.
///
/// Lets a logged-in user bind a Google account or phone number to their profile.
/// Facebook login has been removed because no real Facebook App ID / Client
/// Token were configured; the SDK was crashing on startup.
class AccountBindingScreen extends StatefulWidget {
  const AccountBindingScreen({super.key});

  @override
  State<AccountBindingScreen> createState() => _AccountBindingScreenState();
}

class _AccountBindingScreenState extends State<AccountBindingScreen> {
  static const String _tag = 'AccountBinding';
  bool _loadingGoogle = false;
  GoogleSignIn? _googleSignIn;

  @override
  void initState() {
    super.initState();
    _googleSignIn = GoogleSignIn(
      serverClientId: '759752024135-qfm2fahpo2bpcn5baceoijtoh1gp74n5.apps.googleusercontent.com',
      scopes: ['email', 'profile'],
      signInOption: SignInOption.standard,
    );
  }

  Future<void> _bindGoogle() async {
    final user = context.read<SessionManager>().getUser();
    if (user == null) return;
    if ((user.googleEmail?.isNotEmpty ?? false) || user.isGoogleBound) {
      Fluttertoast.showToast(msg: 'Google account already linked');
      return;
    }
    setState(() => _loadingGoogle = true);
    try {
      final googleUser = await _googleSignIn?.signIn();
      if (googleUser == null) {
        Fluttertoast.showToast(msg: 'Google sign-in cancelled');
        return;
      }
      final res = await ApiService.bindAccount({
        'userId': user.id,
        'googleEmail': googleUser.email,
        'type': 'google',
      });
      if (res.status && res.user != null) {
        var updated = res.user!;
        updated.googleEmail = googleUser.email;
        updated.isGoogleBound = true;
        if (!mounted) return;
        context.read<AuthProvider>().setUser(updated);
        Fluttertoast.showToast(msg: 'Google linked successfully');
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Failed to link Google');
      }
    } catch (e, s) {
      Log.e(_tag, 'bind google failed', e, s);
      Fluttertoast.showToast(msg: 'Google link failed: $e');
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  void _bindPhone() {
    final user = context.read<SessionManager>().getUser();
    if (user == null) return;
    if ((user.mobileNumber?.isNotEmpty ?? false) || user.isPhoneBound) {
      Fluttertoast.showToast(msg: 'Phone number already linked');
      return;
    }
    context.pushNamed(AppRoutes.bindPhone);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final phoneBound = (user?.mobileNumber?.isNotEmpty ?? false) || (user?.isPhoneBound ?? false);
    final googleBound = (user?.googleEmail?.isNotEmpty ?? false) || (user?.isGoogleBound ?? false);

    return Scaffold(
      appBar: AppBar(title: const Text('Account & Security')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone, color: Color(0xFF7E3FF2)),
              title: const Text('Mobile Number'),
              subtitle: Text(phoneBound ? (user?.mobileNumber ?? 'Linked') : 'Not linked'),
              trailing: phoneBound
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Text('Link', style: TextStyle(color: Color(0xFF7E3FF2))),
              onTap: phoneBound ? null : _bindPhone,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.email, color: Colors.red),
              title: const Text('Google Account'),
              subtitle: Text(googleBound ? (user?.googleEmail ?? 'Linked') : 'Not linked'),
              trailing: _loadingGoogle
                  ? const SizedBox(width: 22, height: 22, child: Preloader(strokeWidth: 2))
                  : googleBound
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Text('Link', style: TextStyle(color: Color(0xFF7E3FF2))),
              onTap: googleBound ? null : _bindGoogle,
            ),
          ),
        ],
      ),
    );
  }
}
