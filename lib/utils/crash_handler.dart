import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../services/issue_report_service.dart';
import '../services/session_manager.dart';
import '../utils/log.dart';

class CrashHandler {
  static const String _tag = 'CrashHandler';
  static final Map<String, DateTime> _lastReports = {};

  static bool _shouldReport(String signature) {
    final now = DateTime.now();
    final last = _lastReports[signature];
    if (last != null && now.difference(last) < const Duration(seconds: 30)) {
      return false;
    }
    _lastReports[signature] = now;
    if (_lastReports.length > 50) {
      _lastReports.removeWhere(
        (_, time) => now.difference(time) > const Duration(minutes: 5),
      );
    }
    return true;
  }

  static void initialize() {
    FlutterError.onError = (details) async {
      FlutterError.presentError(details);
      final context = details.context?.toDescription() ?? '';
      final library = details.library ?? '';
      final stack = details.stack;
      final flatStack =
          (stack ?? StackTrace.current).toString().split('\n').take(12).join(' <- ');
      Log.e(
        _tag,
        'Flutter error: ${details.exceptionAsString()} '
        'library=$library context=$context stack=$flatStack',
        details.exception,
        stack,
      );
      if (stack != null) {
        debugPrintStack(label: '[$_tag] exact Flutter stack', stackTrace: stack);
      }
      final signature =
          '${details.exceptionAsString()}|$library|$context|${stack?.toString().split('\n').firstOrNull ?? ''}';
      if (_shouldReport(signature)) {
        await _sendReport(
          title: 'Flutter error',
          description:
              '${details.exceptionAsString()}\nlibrary=$library\ncontext=$context',
          screenRoute: context,
          stackTrace: stack?.toString() ?? 'Stack trace unavailable',
        );
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      Log.e(_tag, 'Async/platform error: $error', error, stack);
      final signature = '$error|${stack.toString().split('\n').firstOrNull ?? ''}';
      if (_shouldReport(signature)) {
        unawaited(_sendReport(
          title: 'Flutter async/platform error',
          description: error.toString(),
          screenRoute: '',
          stackTrace: stack.toString(),
        ));
      }
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
