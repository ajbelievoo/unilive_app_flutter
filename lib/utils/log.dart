import 'package:flutter/foundation.dart';

/// Centralised logging utility — thin wrapper around [debugPrint].
///
/// Debug/info logs are silently dropped in release builds to avoid logcat
/// spam and keep release APKs clean. Errors and warnings are always logged
/// so that crashes and failures can still be diagnosed.
class Log {
  Log._();

  static void _print(String line) {
    // Always print errors/warnings; debugPrint will be a no-op in release
    // mode when the app is built without the observatory, but it is still
    // useful for debug/profile builds.
    debugPrint(line);
  }

  static void d(String tag, Object? message) {
    // TEMPORARY: enabled in release mode for PK debugging.
    // TODO: revert to `if (kReleaseMode) return;` after PK fix is verified.
    _print('[$tag] $message');
  }

  static void i(String tag, Object? message) {
    // TEMPORARY: enabled in release mode for PK debugging.
    // TODO: revert to `if (kReleaseMode) return;` after PK fix is verified.
    _print('[$tag][INFO] $message');
  }

  static void w(String tag, Object? message) {
    _print('[$tag][WARN] $message');
  }

  static void e(String tag, Object? message, [Object? error, StackTrace? stack]) {
    _print('[$tag][ERROR] $message');
    if (error != null) _print('  cause: $error');
    if (stack != null) _print('  stack: $stack');
  }
}
