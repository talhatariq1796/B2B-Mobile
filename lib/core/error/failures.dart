import 'package:equatable/equatable.dart';

/// Base type returned by repositories to the domain layer on failure.
/// Keeps the presentation layer decoupled from Dio/HTTP-specific exceptions.
abstract class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode});

  final int? statusCode;

  @override
  List<Object?> get props => [message, statusCode];
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Local cache error']);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([
    super.message = 'Session expired, please sign in again',
  ]);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something went wrong']);
}

/// The request may or may not have reached the server before the connection
/// dropped (send/receive timeout mid-flight) — unlike [NetworkFailure]
/// (failed before send) or [ServerFailure] (a response was received), we
/// genuinely don't know the outcome. Callers should not blindly auto-retry
/// a mutating call in this state without the user confirming (per
/// ARCHITECTURE.md's "no blind retries" principle).
class AmbiguousOutcomeFailure extends Failure {
  const AmbiguousOutcomeFailure([
    super.message = "Couldn't confirm whether that went through — check before retrying.",
  ]);
}
