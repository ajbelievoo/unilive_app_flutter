import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../services/issue_report_service.dart';
import '../services/session_manager.dart';
import '../utils/log.dart';

class CrashHandler {
  static const String _tag = 'CrashHandler';

  static void initialize() {
    FlutterError.onError = (details) async {
      FlutterError.presentError(details);
      Log.e(
        _tag,
        'Flutter uncaught error: ${details.summary}',
        details.exception,
        details.stack,
      );
      await _sendReport(
        title: 'Flutter uncaught error',
        description: details.summary.toString(),
        screenRoute: details.context?.toString() ?? '',
        stackTrace: details.stack?.toString() ?? details.exceptionAsString(),
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      Log.e(_tag, 'Async/platform error: $error', error, stack);
      unawaited(_sendReport(
        title: 'Flutter async/platform error',
        description: error.toString(),
        screenRoute: '',
        stackTrace: stack.toString(),
      ));
      return true;
    };

    if (!kReleaseMode) {
      Log.d(_tag, 'Crash handler initialized (debug mode)');
    }
  }

  static Future<void> _sendReport({
    required String title,
    required String description,
    String screenRoute = '',
    required String stackTrace,
  }) async {
    try {
      final userId = SessionManager.instance?.userId;
      await IssueReportService.reportIssue(
        title: title,
        description: description,
        screenRoute: screenRoute,
        stackTrace: stackTrace,
        userId: userId,
      );
    } catch (e, st) {
      Log.e(_tag, 'Failed to report crash', e, st);
    }
  }
}

class NetworkChangeReceiver {
  static const String _tag = 'NetworkChangeReceiver';
  static const _channel = MethodChannel('com.believoo.app/network');

  static final StreamController<bool> _controller = StreamController<bool>.broadcast();
  static Stream<bool> get connectionStream => _controller.stream;

  static bool _isConnected = true;
  static bool get isConnected => _isConnected;

  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onConnectivityChanged') {
        _isConnected = call.arguments as bool? ?? true;
        _controller.add(_isConnected);
        debugPrint('[$_tag] Network changed: ${_isConnected ? "online" : "offline"}');
      }
    });
  }

  void dispose() {
    _controller.close();
  }
}
