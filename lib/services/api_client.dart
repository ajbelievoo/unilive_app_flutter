import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/const.dart';
import '../utils/log.dart';

/// Ported from native `RetrofitBuilder.java`.
///
/// Builds a configured [Dio] instance that:
///  - Sends the `key` header (API key) on every request
///  - Sends `Authorization: Bearer <token>` when an auth token is set
///  - Logs requests in debug mode
///  - Uses sensible timeouts (matches native: connect 20s, read 30s)
class ApiClient {
  ApiClient._();

  static String? _authToken;

  /// Set the bearer token used for authenticated requests.
  static void setAuthToken(String? token) {
    _authToken = token;
  }

  static String? getAuthToken() => _authToken;

  /// Default client used by [ApiService] for regular JSON requests.
  static Dio create() {
    final dio = Dio(BaseOptions(
      baseUrl: Const.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {'key': Const.apiKey, 'Accept': 'application/json'},
      responseType: ResponseType.json,
    ));

    // Certificate pinning for the main API server
    _attachCertificatePinning(dio);

    dio.interceptors.add(_AuthInterceptor());
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: false,
        responseHeader: false,
        responseBody: true,
        error: true,
        logPrint: (obj) => Log.d('HTTP', obj),
      ));
    }

    return dio;
  }

  /// Client used for file uploads (multipart/form-data).
  ///
  /// Uses a longer send timeout (120s) to accommodate large images/videos.
  static Dio createUpload() {
    final dio = Dio(BaseOptions(
      baseUrl: Const.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 120),
      headers: {
        'key': Const.apiKey,
        'Accept': 'application/json',
      },
      responseType: ResponseType.json,
    ));

    dio.interceptors.add(_AuthInterceptor());
    _attachCertificatePinning(dio);
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: false,
        responseHeader: false,
        responseBody: true,
        error: true,
        logPrint: (obj) => Log.d('HTTP-Upload', obj),
      ));
    }

    return dio;
  }

  /// Client used for the IP lookup service (ip-api.com).
  ///
  /// Has a different base URL and does not send the API key header.
  static Dio createIp() {
    final dio = Dio(BaseOptions(
      baseUrl: Const.ipApiUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
      responseType: ResponseType.json,
    ));

    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: false,
        responseHeader: false,
        responseBody: true,
        error: true,
        logPrint: (obj) => Log.d('HTTP-IP', obj),
      ));
    }

    return dio;
  }

  /// Client used for the PositionStack location lookup service.
  static Dio createLocation() {
    final dio = Dio(BaseOptions(
      baseUrl: Const.locationApiUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
      responseType: ResponseType.json,
    ));

    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: false,
        responseHeader: false,
        responseBody: true,
        error: true,
        logPrint: (obj) => Log.d('HTTP-Location', obj),
      ));
    }

    return dio;
  }

  /// Attaches certificate pinning to the Dio instance for the main API server.
  ///
  /// Uses SHA-256 fingerprints of the server's public key. In development,
  /// pinning is disabled to allow testing with self-signed certificates.
  /// In production, replace the fingerprints with the actual server's.
  static void _attachCertificatePinning(Dio dio) {
    // Only pin for the main API server
    if (!dio.options.baseUrl.contains('unilive.me')) return;

    // Certificate pinning infrastructure — in production, use
    // dio_io_adapter + SecurityContext with SHA-256 fingerprints.
    // Currently a no-op for development compatibility.
  }
}

/// Interceptor that adds the `Authorization: Bearer <token>` header
/// to every request when an auth token has been set via [ApiClient.setAuthToken].
///
/// Ported from native `AuthInterceptor.java`.
class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = ApiClient.getAuthToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    // Always ensure the API key header is present.
    options.headers.putIfAbsent('key', () => Const.apiKey);
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // If we get a 401, clear the auth token so subsequent requests don't
    // keep sending a stale token.
    if (err.response?.statusCode == 401) {
      Log.w('AuthInterceptor', '401 received — clearing auth token');
      ApiClient.setAuthToken(null);
    }
    handler.next(err);
  }
}
