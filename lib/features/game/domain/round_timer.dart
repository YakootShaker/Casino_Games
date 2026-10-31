import 'dart:async';

typedef VoidCallback = void Function();

/// Manages the 10-second server-side countdown for an answering attempt.
/// Uses UTC [DateTime.now()] and the stored [deadline] for authoritative time.
/// Provides a stream of remaining seconds and calls [onTimeout] when expired.
/// Cancel-safe: canceling after timeout is a safe no-op.
class RoundTimer {
  final String attemptId;
  final DateTime deadline;
  late final VoidCallback _onTimeout;
  final StreamController<int> _secondsController =
      StreamController<int>.broadcast();

  Timer? _periodicTimer;
  bool _isActive = true;
  bool _hasFired = false;
  int _lastEmittedSeconds = -1;

  RoundTimer._({
    required Duration duration,
    required VoidCallback onTimeout,
    required this.attemptId,
    DateTime? now,
  }) : deadline = (now ?? DateTime.now()).toUtc().add(duration) {
    _onTimeout = onTimeout;
    _startTimer();
  }

  /// Starts a new [RoundTimer] for the given [duration] and [attemptId].
  factory RoundTimer.start({
    required Duration duration,
    required VoidCallback onTimeout,
    required String attemptId,
    DateTime? now,
  }) {
    return RoundTimer._(
      duration: duration,
      onTimeout: onTimeout,
      attemptId: attemptId,
      now: now,
    );
  }

  void _startTimer() {
    // Initial emit
    final initialRemaining = remaining.inSeconds;
    _lastEmittedSeconds = initialRemaining;
    _secondsController.add(initialRemaining);

    // High frequency check (100ms) for responsive countdown & precise timeout
    _periodicTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _tick(),
    );
  }

  void _tick() {
    if (!_isActive) return;

    final now = DateTime.now().toUtc();
    if (now.isAfter(deadline) || now.isAtSameMomentAs(deadline)) {
      _fireTimeout();
      return;
    }

    final remSecs = remaining.inSeconds;
    if (remSecs != _lastEmittedSeconds) {
      _lastEmittedSeconds = remSecs;
      if (!_secondsController.isClosed) {
        _secondsController.add(remSecs);
      }
    }
  }

  void _fireTimeout() {
    if (!_isActive || _hasFired) return;
    _isActive = false;
    _hasFired = true;
    _periodicTimer?.cancel();
    _periodicTimer = null;

    if (!_secondsController.isClosed) {
      _secondsController.add(0);
      _secondsController.close();
    }

    _onTimeout();
  }

  /// Cancels the active timer. If the timer has already fired or is inactive,
  /// this is a safe no-op.
  void cancel() {
    if (!_isActive) return;
    _isActive = false;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    if (!_secondsController.isClosed) {
      _secondsController.close();
    }
  }

  bool get isActive => _isActive;
  bool get hasFired => _hasFired;

  /// Remaining duration until deadline. Returns [Duration.zero] if expired.
  Duration get remaining {
    if (!_isActive && _hasFired) return Duration.zero;
    final diff = deadline.difference(DateTime.now().toUtc());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Stream of remaining seconds (e.g. 10, 9, 8... 0).
  Stream<int> get secondsStream => _secondsController.stream;
}
