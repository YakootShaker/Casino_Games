import 'package:quiz_buzzer/core/constants/game_constants.dart';
import 'package:quiz_buzzer/core/errors/app_exception.dart';
import 'game_models.dart';
import 'game_state.dart';

/// Pure authoritative state machine for the Quiz Buzzer game.
/// Contains no Flutter or WebSocket dependencies.
class GameEngine {
  GameState _state;
  final Set<String> _processedAttemptIds = <String>{};
  void Function(String attemptId)? onTimeout;

  GameEngine([GameState? initialState])
      : _state = initialState ?? GameState.initial();

  /// Current immutable snapshot of the authoritative game state.
  GameState get state => _state;

  /// Returns true if an attempt is actively underway and not expired.
  bool get canEvaluate {
    if (_state.phase != GamePhase.answering) return false;
    if (_state.activeAttemptId == null) return false;
    if (_processedAttemptIds.contains(_state.activeAttemptId)) return false;
    final deadline = _state.answeringDeadline;
    if (deadline != null && DateTime.now().toUtc().isAfter(deadline)) {
      return false;
    }
    return true;
  }

  /// Starts a new game session with the given questions and players.
  GameState startGame({
    required List<Question> questions,
    required List<Player> players,
    required String sessionId,
  }) {
    if (_state.phase == GamePhase.answering) {
      throw InvalidTransitionException(
        fromState: _state.phase.value,
        event: 'startGame',
      );
    }
    if (questions.isEmpty) {
      throw const GameStateException('Questions list cannot be empty');
    }
    if (players.isEmpty) {
      throw const GameStateException('Players list cannot be empty');
    }

    final initialScores = <String, int>{};
    for (final p in players) {
      initialScores[p.id] = 0;
    }

    _state = GameState(
      phase: GamePhase.ready,
      currentQuestion: questions.first,
      questionIndex: 0,
      questions: List.unmodifiable(questions),
      players: List.unmodifiable(players),
      scores: Map.unmodifiable(initialScores),
      sessionId: sessionId,
      isDisplayConnected: _state.isDisplayConnected,
      stateVersion: _state.stateVersion + 1,
    );

    return _state;
  }

  /// Claims turn on first valid buzzer press during [GamePhase.ready].
  GameState pressBuzzer({
    required String playerId,
    required String attemptId,
    required DateTime now,
  }) {
    if (_state.phase != GamePhase.ready) {
      throw InvalidTransitionException(
        fromState: _state.phase.value,
        event: 'pressBuzzer',
      );
    }
    if (_processedAttemptIds.contains(attemptId)) {
      throw DuplicateAttemptException(attemptId);
    }

    final player = _state.players.firstWhere(
      (p) => p.id == playerId,
      orElse: () => throw GameStateException('Player not found: $playerId'),
    );

    final deadline =
        now.toUtc().add(const Duration(seconds: kAnswerTimeSeconds));

    _state = _state.copyWith(
      phase: GamePhase.answering,
      activePlayer: player,
      activeAttemptId: attemptId,
      answeringDeadline: deadline,
      stateVersion: _state.stateVersion + 1,
    );

    return _state;
  }

  /// Judge evaluates the answer as correct.
  /// Exactly one outcome (correct, wrong, timeout) can apply per attempt.
  GameState correctAnswer(String attemptId, DateTime now) {
    if (_state.phase != GamePhase.answering ||
        _state.activeAttemptId != attemptId) {
      throw GameStateException(
        'Cannot evaluate correct answer: no active attempt matching $attemptId in phase ${_state.phase.value}',
      );
    }
    if (_state.answeringDeadline != null &&
        now.toUtc().isAfter(_state.answeringDeadline!)) {
      throw const ExpiredAttemptException();
    }

    _processedAttemptIds.add(attemptId);

    final player = _state.activePlayer;
    final newScores = Map<String, int>.from(_state.scores);
    if (player != null) {
      newScores[player.id] = (newScores[player.id] ?? 0) + kCorrectScore;
    }

    final isLast = _state.questionIndex >= _state.questions.length - 1;

    _state = _state.copyWith(
      phase: isLast ? GamePhase.finished : GamePhase.correctResult,
      scores: Map.unmodifiable(newScores),
      clearActivePlayer: true,
      clearActiveAttempt: true,
      clearAnsweringDeadline: true,
      stateVersion: _state.stateVersion + 1,
    );

    return _state;
  }

  /// Judge evaluates the answer as wrong.
  /// Re-enables all buzzers on the same question with -1 penalty.
  GameState wrongAnswer(String attemptId, DateTime now) {
    if (_state.phase != GamePhase.answering ||
        _state.activeAttemptId != attemptId) {
      throw GameStateException(
        'Cannot evaluate wrong answer: no active attempt matching $attemptId in phase ${_state.phase.value}',
      );
    }

    _processedAttemptIds.add(attemptId);

    final player = _state.activePlayer;
    final newScores = Map<String, int>.from(_state.scores);
    if (player != null) {
      newScores[player.id] = (newScores[player.id] ?? 0) + kWrongScore;
    }

    // Return to ready phase for the same question
    _state = _state.copyWith(
      phase: GamePhase.ready,
      scores: Map.unmodifiable(newScores),
      clearActivePlayer: true,
      clearActiveAttempt: true,
      clearAnsweringDeadline: true,
      stateVersion: _state.stateVersion + 1,
    );

    return _state;
  }

  /// Countdown expired without an answer.
  /// Re-enables buzzers on the same question with -1 penalty.
  GameState timeout(String attemptId, DateTime now) {
    // Race condition guard: ignore stale or duplicate timeout
    if (_processedAttemptIds.contains(attemptId) ||
        _state.phase != GamePhase.answering ||
        _state.activeAttemptId != attemptId) {
      return _state;
    }

    _processedAttemptIds.add(attemptId);

    final player = _state.activePlayer;
    final newScores = Map<String, int>.from(_state.scores);
    if (player != null) {
      newScores[player.id] = (newScores[player.id] ?? 0) + kTimeoutScore;
    }

    // Return to ready phase for the same question
    _state = _state.copyWith(
      phase: GamePhase.ready,
      scores: Map.unmodifiable(newScores),
      clearActivePlayer: true,
      clearActiveAttempt: true,
      clearAnsweringDeadline: true,
      stateVersion: _state.stateVersion + 1,
    );

    return _state;
  }

  /// Called after the 2-second correctResult presentation window passes.
  /// Advances to the next question or finishes the game.
  GameState applyCorrectResultTransition(DateTime now) {
    if (_state.phase != GamePhase.correctResult) {
      throw GameStateException(
        'Cannot apply correct result transition in phase ${_state.phase.value}',
      );
    }

    final nextIndex = _state.questionIndex + 1;
    if (nextIndex >= _state.questions.length) {
      _state = _state.copyWith(
        phase: GamePhase.finished,
        clearActivePlayer: true,
        clearActiveAttempt: true,
        clearAnsweringDeadline: true,
        stateVersion: _state.stateVersion + 1,
      );
    } else {
      _state = _state.copyWith(
        phase: GamePhase.ready,
        questionIndex: nextIndex,
        currentQuestion: _state.questions[nextIndex],
        clearActivePlayer: true,
        clearActiveAttempt: true,
        clearAnsweringDeadline: true,
        stateVersion: _state.stateVersion + 1,
      );
    }

    return _state;
  }

  /// Judge skips the current question without score change.
  GameState skipQuestion(DateTime now) {
    if (_state.phase != GamePhase.ready &&
        _state.phase != GamePhase.answering) {
      throw GameStateException(
        'Cannot skip question in phase ${_state.phase.value}',
      );
    }

    if (_state.activeAttemptId != null) {
      _processedAttemptIds.add(_state.activeAttemptId!);
    }

    final nextIndex = _state.questionIndex + 1;
    if (nextIndex >= _state.questions.length) {
      _state = _state.copyWith(
        phase: GamePhase.finished,
        clearActivePlayer: true,
        clearActiveAttempt: true,
        clearAnsweringDeadline: true,
        stateVersion: _state.stateVersion + 1,
      );
    } else {
      _state = _state.copyWith(
        phase: GamePhase.ready,
        questionIndex: nextIndex,
        currentQuestion: _state.questions[nextIndex],
        clearActivePlayer: true,
        clearActiveAttempt: true,
        clearAnsweringDeadline: true,
        stateVersion: _state.stateVersion + 1,
      );
    }

    return _state;
  }

  /// Pauses the game (e.g. for judge dispute or break).
  GameState pauseGame(DateTime now) {
    if (_state.phase == GamePhase.answering) {
      throw const GameStateException('Cannot pause during answering phase');
    }
    if (_state.phase == GamePhase.finished ||
        _state.phase == GamePhase.disconnected ||
        _state.phase == GamePhase.paused) {
      throw GameStateException('Cannot pause game in phase ${_state.phase.value}');
    }

    _state = _state.copyWith(
      phase: GamePhase.paused,
      previousPhase: _state.phase,
      stateVersion: _state.stateVersion + 1,
    );

    return _state;
  }

  /// Resumes from paused state back to the previous active phase.
  GameState resumeGame(DateTime now) {
    if (_state.phase != GamePhase.paused) {
      throw GameStateException(
        'Cannot resume game when not paused: ${_state.phase.value}',
      );
    }

    final targetPhase = _state.previousPhase ?? GamePhase.ready;
    _state = _state.copyWith(
      phase: targetPhase,
      clearPreviousPhase: true,
      stateVersion: _state.stateVersion + 1,
    );

    return _state;
  }

  /// Manually ends the game.
  GameState endGame(DateTime now) {
    _state = _state.copyWith(
      phase: GamePhase.finished,
      clearActivePlayer: true,
      clearActiveAttempt: true,
      clearAnsweringDeadline: true,
      stateVersion: _state.stateVersion + 1,
    );

    return _state;
  }

  /// Resets the engine back to disconnected with clean state.
  GameState resetGame() {
    _processedAttemptIds.clear();
    _state = GameState.initial().copyWith(
      isDisplayConnected: _state.isDisplayConnected,
      stateVersion: _state.stateVersion + 1,
    );

    return _state;
  }

  /// Handles player display connection.
  GameState connectDisplay() {
    _state = _state.copyWith(
      isDisplayConnected: true,
      stateVersion: _state.stateVersion + 1,
    );
    return _state;
  }

  /// Handles player display disconnection.
  GameState disconnectDisplay() {
    _state = _state.copyWith(
      isDisplayConnected: false,
      stateVersion: _state.stateVersion + 1,
    );
    return _state;
  }

  /// Disposes any engine resources.
  void dispose() {}
}
