import 'package:dio/dio.dart';
import '../utils/log.dart';

/// Standardized API error handling and retry logic.
///
/// Ported from native `ApiExceptionHandler.java` + retry interceptor.
class ApiErrorHandler {
  ApiErrorHandler._();

  static const String _tag = 'ApiError';

  /// Execute a Dio request with standardized error handling and optional retry.
  ///
  /// [maxRetries] defaults to 1 (one retry on network errors).
  /// [retryDelay] defaults to 1 second.
  static Future<Response<T>> withRetry<T>(
    Future<Response<T>> Function() request, {
    int maxRetries = 1,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    int attempts = 0;
    DioException? lastError;

    while (attempts <= maxRetries) {
      try {
        final response = await request();
        // Check for non-2xx status codes that Dio might not catch
        if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
          return response;
        }
        // Non-success status code
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: 'HTTP ${response.statusCode}',
        );
      } on DioException catch (e) {
        lastError = e;

        // Don't retry on 4xx errors (client errors)
        if (e.type == DioExceptionType.badResponse) {
          final statusCode = e.response?.statusCode ?? 0;
          if (statusCode >= 400 && statusCode < 500) {
            Log.w(_tag, 'Client error $statusCode, not retrying');
            rethrow;
          }
        }

        attempts++;
        if (attempts <= maxRetries) {
          Log.w(_tag, 'Retry $attempts/$maxRetries after error: ${e.type}');
          await Future.delayed(retryDelay * attempts);
        }
      } catch (e, s) {
        Log.e(_tag, 'Unexpected error', e, s);
        rethrow;
      }
    }

    throw lastError ?? Exception('Request failed after $maxRetries retries');
  }

  /// Convert a DioException into a user-friendly error message.
  static String getErrorMessage(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return 'Connection timed out. Please check your internet.';
        case DioExceptionType.sendTimeout:
          return 'Request timed out. Please try again.';
        case DioExceptionType.receiveTimeout:
          return 'Response timed out. Please try again.';
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode ?? 0;
          final data = error.response?.data;
          if (data is Map<String, dynamic>) {
            return data['message']?.toString() ?? 'Server error ($statusCode)';
          }
          return 'Server error ($statusCode)';
        case DioExceptionType.cancel:
          return 'Request was cancelled';
        case DioExceptionType.connectionError:
          return 'No internet connection. Please check your network.';
        case DioExceptionType.unknown:
          return error.message ?? 'An unexpected error occurred';
        case DioExceptionType.badCertificate:
          return 'Certificate verification failed';
        default:
          return error.message ?? 'An unexpected error occurred';
      }
    }
    return error.toString();
  }

  /// Check if an error is a network connectivity issue.
  static bool isNetworkError(dynamic error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout;
    }
    return false;
  }

  /// Check if an error is an authentication error (401).
  static bool isAuthError(dynamic error) {
    if (error is DioException && error.type == DioExceptionType.badResponse) {
      return error.response?.statusCode == 401;
    }
    return false;
  }
}
