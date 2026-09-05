import 'package:flutter/material.dart';

import '../models/user_root.dart';
import '../screens/auth/account_banned_screen.dart';
import '../screens/auth/device_banned_screen.dart';
import '../services/api_client.dart';
import '../services/session_manager.dart';
import '../services/socket_service.dart';

/// Centralised helper for detecting and routing on admin block responses
/// (account block vs. device block) — see
/// `docs/FLUTTER_DEVICE_BLOCK_INTEGRATION.md`.
///
/// The backend rejects login/refresh with one of two messages:
///   - `You are blocked by admin!`           -> account block
///   - `Your device is blocked by admin!`    -> device block (strongest)
///
/// This helper inspects the [UserRoot.message], tears down the current
/// session (logout + clear token + disconnect socket), and pushes the
/// matching full-screen ban route on top of the navigator so the user
/// cannot return to the app.
class BlockHelper {
  static const String deviceBlockedMessage = 'Your device is blocked by admin!';
  static const String accountBlockedMessage = 'You are blocked by admin!';
  static const String _deviceBannedRoute = 'deviceBanned';
  static const String _accountBannedRoute = 'accountBanned';

  static bool isDeviceBlocked(String? message) =>
      message?.toLowerCase().contains('device is blocked') == true;

  static bool isAccountBlocked(String? message) =>
      message?.toLowerCase().contains('blocked by admin') == true &&
      !isDeviceBlocked(message);

  static bool isGlobalBlockEvent(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['deviceBlocked'] == true) return true;
    final message = data['message']?.toString() ?? '';
    return isDeviceBlocked(message) || isAccountBlocked(message);
  }

  static bool isGlobalDeviceBlock(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['deviceBlocked'] == true) return true;
    return isDeviceBlocked(data['message']?.toString());
  }

  /// Inspects a [UserRoot] response. If it represents a block, routes the
  /// user to the appropriate ban screen, tears down the session, and returns
  /// `true`. Otherwise calls [onOther] (if provided) and returns `false`.
  static bool handleResult(BuildContext context, UserRoot res,
      {VoidCallback? onOther}) {
    if (res.status) return false;
    if (isDeviceBlocked(res.message)) {
      _go(context, _deviceBannedRoute, res.message, res.reason);
      return true;
    }
    if (isAccountBlocked(res.message)) {
      _go(context, _accountBannedRoute, res.message, res.reason);
      return true;
    }
    onOther?.call();
    return false;
  }

  /// Handles a real-time `userBlock` socket event payload.
  static void handleSocketBlock(BuildContext? context,
      Map<String, dynamic>? data) {
    if (context == null || data == null) return;
    if (!isGlobalBlockEvent(data)) return;
    final msg = data['message']?.toString();
    final reason = data['reason']?.toString();
    if (isGlobalDeviceBlock(data)) {
      _go(context, _deviceBannedRoute, msg, reason);
    } else {
      _go(context, _accountBannedRoute, msg, reason);
    }
  }

  static void _go(BuildContext context, String route, String? message,
      [String? reason]) {
    try {
      SessionManager.instance?.logout();
      ApiClient.setAuthToken(null);
      SocketService.instance.disconnect();
    } catch (_) {}
    final screen = route == _deviceBannedRoute
        ? DeviceBannedScreen(message: message, reason: reason)
        : AccountBannedScreen(message: message, reason: reason);
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => screen),
      (_) => false,
    );
  }
}
