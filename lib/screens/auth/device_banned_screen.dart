import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

/// Full-screen ban screen shown when the backend reports the device is
/// permanently blocked (`Your device is blocked by admin!`).
///
/// The user cannot dismiss this screen — the only action is "Exit", which
/// closes the app via [SystemNavigator.pop]. This matches the spec in
/// `docs/FLUTTER_DEVICE_BLOCK_INTEGRATION.md` §5: "Device permanent block:
/// full-screen ban screen with exit button. User ko app ke andar kuch bhi
/// access nahi dena."
class DeviceBannedScreen extends StatelessWidget {
  const DeviceBannedScreen({super.key, this.message, this.reason});

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
                    child: const Icon(Icons.gpp_bad,
                        color: Colors.white, size: 64),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Device Banned',
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
                        'This device has been permanently blocked by admin. '
                            'You cannot use this app on this device anymore.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (reason != null && reason!.trim().isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(top: 4, bottom: 8),
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
                  const Text(
                    'Contact support for more information.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 32),
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
                      onPressed: () {
                        // Close the app fully.
                        SystemNavigator.pop();
                      },
                      child: const Text('Exit',
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
}
