import 'package:flutter/foundation.dart';

/// Centralised logging utility — thin wrapper around [debugPrint].
///
/// Debug/info/warn logs are silently dropped in release builds to avoid
/// logcat spam and keep release APKs clean. Errors keep a short tag+message
/// line in release (for crash triage) but the error object and stack trace —
/// which can contain request URLs, tokens and user data — are debug-only.
class Log {
  Log._();

  static void _print(String line) {
    debugPrint(line);
  }

  static void d(String tag, Object? message) {
    if (kReleaseMode) return;
    _print('[$tag] $message');
  }

  static void i(String tag, Object? message) {
    if (kReleaseMode) return;
    _print('[$tag][INFO] $message');
  }

  static void w(String tag, Object? message) {
    if (kReleaseMode) return;
    _print('[$tag][WARN] $message');
  }

  static void e(
    String tag,
    Object? message, [
    Object? error,
    StackTrace? stack,
  ]) {
    _print('[$tag][ERROR] $message');
    if (kReleaseMode) return;
    if (error != null) _print('  cause: $error');
    if (stack != null) _print('  stack: $stack');
  }
}
