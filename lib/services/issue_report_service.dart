import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/const.dart';
import '../utils/log.dart';

/// Non-blocking bug/crash reporting service.
///
/// Collects device/app metadata and sends the issue payload to the backend
/// `/api/v1/report-issue` endpoint. The backend responds immediately and then
/// triggers the Devin AI pipeline in the background.
class IssueReportService {
  static const String _tag = 'IssueReportService';
  static const String _endpoint = '/api/v1/report-issue';

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: Const.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      headers: {'key': Const.apiKey},
      contentType: 'application/json',
      responseType: ResponseType.json,
    ),
  );

  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Fire-and-forget issue report. This method never throws; failures are
  /// only logged so the app never crashes because of a failed report.
  static Future<void> reportIssue({
    required String title,
    String description = '',
    String screenRoute = '',
    String stackTrace = '',
    String? userId,
  }) async {
    try {
      final deviceInfo = await _collectDeviceInfo();
      deviceInfo['screenRoute'] = screenRoute;

      final body = <String, dynamic>{
        'title': title,
        'description': description,
        'screenRoute': screenRoute,
        'appVersion': deviceInfo['appVersion'],
        'osVersion': deviceInfo['osVersion'],
        'deviceModel': deviceInfo['model'],
        'deviceInfo': deviceInfo,
        'stackTrace': stackTrace,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      };

      await _postWithRetry(body);
      Log.d(_tag, 'Issue report sent: $title');
    } catch (e, st) {
      Log.d(_tag, 'Failed to send issue report: $e\n$st');
    }
  }

  static Future<Map<String, dynamic>> _collectDeviceInfo() async {
    String appVersion = '';
    String buildNumber = '';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.version;
      buildNumber = packageInfo.buildNumber;
    } catch (e, st) {
      Log.d(_tag, 'PackageInfo failed: $e\n$st');
    }

    String brand = 'unknown';
    String model = 'unknown';
    String osVersion = '';
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        brand = androidInfo.brand.isNotEmpty ? androidInfo.brand : 'unknown';
        model = androidInfo.model.isNotEmpty ? androidInfo.model : 'unknown';
        osVersion = 'Android ${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        brand = 'Apple';
        model =
            iosInfo.utsname.machine.isNotEmpty
                ? iosInfo.utsname.machine
                : iosInfo.model.isNotEmpty
                ? iosInfo.model
                : 'unknown';
        osVersion = 'iOS ${iosInfo.systemVersion}';
      }
    } catch (e, st) {
      Log.d(_tag, 'DeviceInfo failed: $e\n$st');
    }

    return <String, dynamic>{
      'brand': brand,
      'model': model,
      'os': Platform.operatingSystem,
      'osVersion': osVersion,
      'appVersion': appVersion,
      'buildNumber': buildNumber,
    };
  }

  static Future<void> _postWithRetry(
    Map<String, dynamic> body, {
    int maxAttempts = 3,
  }) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await _dio.post(_endpoint, data: body);
        return;
      } on DioException catch (e) {
        Log.d(_tag, 'Issue report attempt $attempt failed: ${e.message}');
        if (attempt == maxAttempts) rethrow;
        await Future.delayed(Duration(seconds: attempt));
      }
    }
  }
}
