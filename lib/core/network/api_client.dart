import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';

/// Single Dio instance for the app. Remote data sources depend on this,
/// never on `Dio()` directly, so auth/error handling stays in one place.
class ApiClient {
  ApiClient(this._secureStorage)
    : dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: ApiConstants.connectTimeout,
          receiveTimeout: ApiConstants.receiveTimeout,
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Confirmed against the real backend: Authorization: Bearer
          // <token>, same JWT returned by the travelcompositor.com login
          // call. No other auto-attached header is confirmed needed yet —
          // don't invent one speculatively.
          final token = await _secureStorage.getAuthToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          // TODO: map DioException -> app-level exceptions in each
          // remote data source; keep this interceptor auth/logging only.
          handler.next(error);
        },
      ),
    );
    // Request/response logging — debug builds only, never release (would
    // otherwise print auth tokens and lead PII to the device log).
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }
  }

  final Dio dio;
  final SecureStorageService _secureStorage;
}
