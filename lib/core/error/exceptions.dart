/// Thrown by data sources (remote/local). Repositories catch these and
/// translate them into [Failure]s before they reach the domain/presentation layers.
class ServerException implements Exception {
  const ServerException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;
}

class NetworkException implements Exception {
  const NetworkException([this.message = 'No internet connection']);

  final String message;
}

class CacheException implements Exception {
  const CacheException([this.message = 'Local cache error']);

  final String message;
}

class UnauthorizedException implements Exception {
  const UnauthorizedException([this.message = 'Session expired']);

  final String message;
}

/// See [AmbiguousOutcomeFailure] — thrown when a send/receive timeout means
/// we can't tell whether the server received/processed the request.
class AmbiguousOutcomeException implements Exception {
  const AmbiguousOutcomeException([
    this.message = "Couldn't confirm whether that went through — check before retrying.",
  ]);

  final String message;
}
