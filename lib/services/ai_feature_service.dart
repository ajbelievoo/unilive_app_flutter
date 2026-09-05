/// AI Feature service — fetches the active AI feature configuration from the
/// Master Admin AI Control Engine.
///
/// Endpoint: `GET /api/v1/ai-config/get-active-features`
/// Header:   `key: <API key>` (already attached by [ApiClient]).
///
/// The service is intentionally thin: it only knows how to talk to the
/// endpoint and parse the response. Caching, re-fetch-on-room-join and
/// per-user access checks live in [AIFeatureManager] (provider).
library;

import 'package:dio/dio.dart';

import '../models/ai_feature_model.dart';
import '../utils/log.dart';
import 'api_client.dart';

/// Thrown when the AI config endpoint returns a non-success status or an
/// unparseable body. Caught by [AIFeatureManager] so the app can fall back
/// to a safe "everything disabled" state.
class AIFeatureFetchException implements Exception {
  const AIFeatureFetchException(this.message);
  final String message;
  @override
  String toString() => 'AIFeatureFetchException: $message';
}

/// HTTP service for the AI feature config endpoint.
///
/// Uses a dedicated [Dio] instance (built by [ApiClient.create]) so it
/// inherits the `key` header + auth interceptor + certificate pinning
/// behaviour of every other API call in the app.
class AIFeatureService {
  AIFeatureService._();

  static const String _tag = 'AIFeatureService';

  /// Path of the active-features endpoint, relative to [Const.baseUrl].
  static const String activeFeaturesPath = '/api/v1/ai-config/get-active-features';

  static final Dio _dio = ApiClient.create();

  /// Fetch the active AI feature configuration.
  ///
  /// Throws [AIFeatureFetchException] on network/HTTP/parse errors so the
  /// caller can decide whether to retry or fall back to a cached/empty
  /// config.
  static Future<AIFeatureConfigRoot> getActiveFeatures() async {
    try {
      final r = await _dio.get(activeFeaturesPath);
      final data = r.data;
      Map<String, dynamic> map;
      if (data is Map<String, dynamic>) {
        map = data;
      } else if (data is Map) {
        map = Map<String, dynamic>.from(data);
      } else {
        throw AIFeatureFetchException('Unexpected response type: ${data.runtimeType}');
      }
      final root = AIFeatureConfigRoot.fromJson(map)..fetchedAt = DateTime.now().millisecondsSinceEpoch;
      Log.d(_tag, 'fetched ${root.features.length} active AI features (status=${root.status})');
      return root;
    } on DioException catch (e) {
      Log.w(_tag, 'getActiveFeatures DioException: ${e.type} ${e.message}');
      throw AIFeatureFetchException(e.message ?? e.type.toString());
    } catch (e) {
      Log.e(_tag, 'getActiveFeatures failed', e);
      throw AIFeatureFetchException(e.toString());
    }
  }
}
