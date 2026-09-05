import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/session_manager.dart';
import '../../services/socket_service.dart';
import '../../theme/app_theme.dart';

/// Ban screen shown when the backend reports the user's *account* is blocked
/// (`You are blocked by admin!`). Unlike [DeviceBannedScreen], the device
/// itself is fine, so the user is allowed to log out and try a different
/// account.
///
/// Matches `docs/FLUTTER_DEVICE_BLOCK_INTEGRATION.md` §5: "Account permanent
/// block: same [red warning], with no option to retry [on this account]."
class AccountBannedScreen extends StatelessWidget {
  const AccountBannedScreen({super.key, this.message, this.reason});

  final String? message;
  /// Admin-supplied block reason (from `userBlock` socket payload or login
  /// response `reason` field). Rendered below the main message when present.
  final String? reason;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white24,
                    ),
                    padding: const EdgeInsets.all(24),
                    child: const Icon(Icons.block,
                        color: Colors.white, size: 64),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Account Blocked',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message ??
                        'Your account has been blocked by admin. '
                            'Contact support for more information.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (reason != null && reason!.trim().isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.info_outline,
                              color: Colors.white70, size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Reason: ${reason!.trim()}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26)),
                      ),
                      onPressed: () => _logout(context),
                      child: const Text('Logout',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _logout(BuildContext context) {
    try {
      SessionManager.instance?.logout();
      ApiClient.setAuthToken(null);
      SocketService.instance.disconnect();
    } catch (_) {}
    context.goNamed(AppRoutes.login);
  }
}
