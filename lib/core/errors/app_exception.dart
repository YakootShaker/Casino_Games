/// Application-level exceptions
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic cause;

  const AppException(this.message, {this.code, this.cause});

  @override
  String toString() => 'AppException($code): $message';
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.cause});
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.code, super.cause});
}

class GameStateException extends AppException implements StateError {
  const GameStateException(super.message, {super.code, super.cause});

  @override
  StackTrace? get stackTrace => null;
}

class InvalidTransitionException extends GameStateException {
  final String fromState;
  final String event;
  const InvalidTransitionException({required this.fromState, required this.event})
      : super('Invalid transition: $event in state $fromState');
}

class DuplicateAttemptException extends GameStateException {
  const DuplicateAttemptException(String attemptId)
      : super('Attempt $attemptId already processed', code: 'DUPLICATE_ATTEMPT');
}

class ExpiredAttemptException extends GameStateException {
  const ExpiredAttemptException()
      : super('Answering deadline has expired', code: 'EXPIRED_ATTEMPT');
}
