import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';

class AuthTokenResult {
  const AuthTokenResult({required this.token, required this.expiresAt});

  final String token;
  final DateTime expiresAt;
}

/// Calls the app's own backend's login endpoint ([ApiConstants.authLogin],
/// same host as [ApiConstants.baseUrl] — this used to be a direct call to
/// online.travelcompositor.com on a separate host, replaced per the BE
/// team's 2026-09-08 change). Still uses its own plain [Dio] rather than
/// the shared [ApiClient], even though the host is now the same: the login
/// call needs no auth header (there's no token yet, and attaching a stale
/// one would be meaningless), and keeping a separate instance preserves
/// the password-redacting debug logger below — [ApiClient]'s own logger
/// isn't safe to reuse here since it doesn't redact request bodies.
class AuthRemoteDataSource {
  AuthRemoteDataSource() : _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl)) {
    // Debug-only call logging. Not Dio's default LogInterceptor: the
    // request body carries the user's plaintext password and the response
    // body carries the bearer token, neither of which should land in the
    // device log even in a debug build — so this logs method/URL/status
    // only, with the request body's password field redacted.
    if (kDebugMode) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final body = options.data is Map<String, dynamic>
                ? {...options.data as Map<String, dynamic>, 'password': '••••••'}
                : options.data;
            debugPrint('[API] --> ${options.method} ${options.uri} $body');
            handler.next(options);
          },
          onResponse: (response, handler) {
            debugPrint('[API] <-- ${response.statusCode} ${response.requestOptions.uri}');
            handler.next(response);
          },
          onError: (error, handler) {
            debugPrint(
              '[API] <-- ERROR ${error.response?.statusCode} '
              '${error.requestOptions.uri}: ${error.message}',
            );
            handler.next(error);
          },
        ),
      );
    }
  }

  final Dio _dio;

  Future<AuthTokenResult> authenticate({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.authLogin,
        data: {'username': username, 'password': password},
        options: Options(contentType: Headers.jsonContentType),
      );
      final data = response.data;
      final token = data?['token'] as String?;
      final expirationInSeconds = data?['expirationInSeconds'] as int?;
      if (token == null) {
        throw const ServerException('Unexpected response from the login server.');
      }
      return AuthTokenResult(
        token: token,
        expiresAt: DateTime.now().add(Duration(seconds: expirationInSeconds ?? 7200)),
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Exception _mapDioException(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401 || status == 403) {
      return const UnauthorizedException('Incorrect username or password.');
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return const NetworkException();
    }
    return ServerException(
      'Could not sign in right now — try again in a moment.',
      statusCode: status,
    );
  }
}
