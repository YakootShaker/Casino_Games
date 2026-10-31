import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_buzzer/features/game/domain/game_engine.dart';
import 'package:quiz_buzzer/features/game/domain/game_models.dart';
import 'package:quiz_buzzer/features/game/domain/game_state.dart';
import 'package:quiz_buzzer/core/errors/app_exception.dart';
import 'package:quiz_buzzer/core/constants/game_constants.dart';

// ── Test fixtures ─────────────────────────────────────────────────────────

List<Player> _testPlayers() => [
      Player(id: 'p1', name: 'Alice', colorValue: kPlayer1ColorValue, createdAt: DateTime(2024)),
      Player(id: 'p2', name: 'Bob',   colorValue: kPlayer2ColorValue, createdAt: DateTime(2024)),
      Player(id: 'p3', name: 'Carol', colorValue: kPlayer3ColorValue, createdAt: DateTime(2024)),
    ];

List<Question> _testQuestions({int count = 3}) => List.generate(
      count,
      (i) => Question(
        id: 'q${i + 1}',
        text: 'Question ${i + 1}?',
        answer: 'Answer ${i + 1}',
        category: 'Test',
        difficulty: 'easy',
        createdAt: DateTime(2024),
      ),
    );

const _sessionId = 'session-test';

void main() {
  group('GameEngine', () {
    late GameEngine engine;

    setUp(() {
      engine = GameEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    // ── Initial state ────────────────────────────────────────────────────

    test('initial state is disconnected', () {
      expect(engine.state.phase, GamePhase.disconnected);
      expect(engine.state.questions, isEmpty);
      expect(engine.state.players, isEmpty);
      expect(engine.state.scores, isEmpty);
    });

    // ── startGame ────────────────────────────────────────────────────────

    test('startGame transitions to ready', () {
      final state = engine.startGame(
        questions: _testQuestions(),
        players: _testPlayers(),
        sessionId: _sessionId,
      );
      expect(state.phase, GamePhase.ready);
      expect(state.questions.length, 3);
      expect(state.players.length, 3);
      expect(state.scores, {'p1': 0, 'p2': 0, 'p3': 0});
      expect(state.questionIndex, 0);
      expect(state.sessionId, _sessionId);
    });

    test('startGame with empty questions throws', () {
      expect(
        () => engine.startGame(questions: [], players: _testPlayers(), sessionId: _sessionId),
        throwsA(isA<GameStateException>()),
      );
    });

    test('startGame with empty players throws', () {
      expect(
        () => engine.startGame(questions: _testQuestions(), players: [], sessionId: _sessionId),
        throwsA(isA<GameStateException>()),
      );
    });

    // ── pressBuzzer ──────────────────────────────────────────────────────

    test('valid buzzer press in ready state transitions to answering', () {
      engine.startGame(
          questions: _testQuestions(), players: _testPlayers(), sessionId: _sessionId);

      final state = engine.pressBuzzer(
        playerId: 'p1',
        attemptId: 'attempt-1',
        now: DateTime.now().toUtc(),
      );

      expect(state.phase, GamePhase.answering);
      expect(state.activeAttempt?.playerId, 'p1');
      expect(state.activeAttempt?.id, 'attempt-1');
      expect(state.activeAttempt?.isExpired, isFalse);
    });

    test('buzzer press before game starts throws InvalidTransitionException', () {
      expect(
        () => engine.pressBuzzer(playerId: 'p1', attemptId: 'a1', now: DateTime.now()),
        throwsA(isA<InvalidTransitionException>()),
      );
    });

    test('duplicate buzzer press (same attemptId) throws DuplicateAttemptException', () {
      engine.startGame(
          questions: _testQuestions(), players: _testPlayers(), sessionId: _sessionId);
      // First press — move to answering
      engine.pressBuzzer(
          playerId: 'p1', attemptId: 'attempt-1', now: DateTime.now().toUtc());

      // Resolve the attempt (correct)
      engine.correctAnswer('attempt-1', DateTime.now().toUtc());

      // Move back to ready (with 2 questions)
      engine.startGame(
          questions: _testQuestions(count: 2),
          players: _testPlayers(),
          sessionId: _sessionId);
      engine.pressBuzzer(
          playerId: 'p1', attemptId: 'attempt-1-new', now: DateTime.now().toUtc());
      engine.correctAnswer('attempt-1-new', DateTime.now().toUtc());
      engine.applyCorrectResultTransition(DateTime.now().toUtc());

      // Now attempt with already-processed ID should throw
      expect(
        () => engine.pressBuzzer(playerId: 'p2', attemptId: 'attempt-1', now: DateTime.now()),
        throwsA(isA<DuplicateAttemptException>()),
      );
    });

    test('second buzzer press while answering throws InvalidTransitionException', () {
      engine.startGame(
          questions: _testQuestions(), players: _testPlayers(), sessionId: _sessionId);
      engine.pressBuzzer(
          playerId: 'p1', attemptId: 'attempt-1', now: DateTime.now().toUtc());

      expect(
        () => engine.pressBuzzer(
            playerId: 'p2', attemptId: 'attempt-2', now: DateTime.now()),
        throwsA(isA<InvalidTransitionException>()),
      );
    });

    // ── correctAnswer ────────────────────────────────────────────────────

    test('correct answer awards +1 and transitions to correctResult', () {
      engine.startGame(
          questions: _testQuestions(), players: _testPlayers(), sessionId: _sessionId);
      engine.pressBuzzer(
          playerId: 'p1', attemptId: 'attempt-1', now: DateTime.now().toUtc());

      final state = engine.correctAnswer('attempt-1', DateTime.now().toUtc());

      expect(state.scores['p1'], 1);
      expect(state.scores['p2'], 0);
      expect(state.scores['p3'], 0);
      expect(state.phase, GamePhase.correctResult);
      expect(state.activeAttempt, isNull);
    });

    test('correct answer with wrong attemptId throws GameStateException', () {
      engine.startGame(
          questions: _testQuestions(), players: _testPlayers(), sessionId: _sessionId);
      engine.pressBuzzer(
          playerId: 'p1', attemptId: 'attempt-1', now: DateTime.now().toUtc());

      expect(
        () => engine.correctAnswer('wrong-attempt', DateTime.now().toUtc()),
        throwsA(isA<GameStateException>()),
      );
    });

    // ── wrongAnswer ──────────────────────────────────────────────────────

    test('wrong answer deducts 1 and returns to ready (same question)', () {
      engine.startGame(
          questions: _testQuestions(), players: _testPlayers(), sessionId: _sessionId);
      final qIndex = engine.state.questionIndex;
      engine.pressBuzzer(
          playerId: 'p2', attemptId: 'attempt-1', now: DateTime.now().toUtc());

      final state = engine.wrongAnswer('attempt-1', DateTime.now().toUtc());

      expect(state.scores['p2'], -1);
      expect(state.phase, GamePhase.ready);
      expect(state.questionIndex, qIndex); // Same question
      expect(state.activeAttempt, isNull);
    });

    test('same player can buzz again after wrong answer', () {
      engine.startGame(
          questions: _testQuestions(), players: _testPlayers(), sessionId: _sessionId);
      engine.pressBuzzer(
          playerId: 'p1', attemptId: 'attempt-1', now: DateTime.now().toUtc());
      engine.wrongAnswer('attempt-1', DateTime.now().toUtc());

      // p1 can buzz again
      final state = engine.pressBuzzer(
          playerId: 'p1', attemptId: 'attempt-2', now: DateTime.now().toUtc());
      expect(state.phase, GamePhase.answering);
      expect(state.activeAttempt?.playerId, 'p1');
    });

    // ── timeout ──────────────────────────────────────────────────────────

    test('timeout deducts 1 and returns to ready', () {
      engine.startGame(
          questions: _testQuestions(), players: _testPlayers(), sessionId: _sessionId);
      engine.pressBuzzer(
          playerId: 'p3', attemptId: 'attempt-1', now: DateTime.now().toUtc());

      final state = engine.timeout('attempt-1', DateTime.now().toUtc());

      expect(state.scores['p3'], -1);
      expect(state.phase, GamePhase.ready);
      expect(state.activeAttempt, isNull);
    });

    test('same player can buzz again after timeout', () {
      engine.startGame(
          questions: _testQuestions(), players: _testPlayers(), sessionId: _sessionId);
      engine.pressBuzzer(
          playerId: 'p1', attemptId: 'attempt-1', now: DateTime.now().toUtc());
      engine.timeout('attempt-1', DateTime.now().toUtc());

      final state = engine.pressBuzzer(
          playerId: 'p1', attemptId: 'attempt-2', now: DateTime.now().toUtc());
      expect(state.phase, GamePhase.answering);
    });

    test('stale timeout (wrong attemptId) is ignored', () {
      engine.startGame(
          questions: _testQuestions(), players: _testPlayers(), sessionId: _sessionId);
      engine.pressBuzzer(
          playerId: 'p1', attemptId: 'attempt-1', now: DateTime.now().toUtc());

      final prevVersion = engine.state.stateVersion;

      // Fire timeout with old attemptId
      final state = engine.timeout('old-attempt', DateTime.now().toUtc());

      // State unchanged
      expect(state.stateVersion, prevVersion);
      expect(state.scores['p1'], 0);
    });

    // ── Race condition ────────────────────────────────────────────────────

    test('correctAnswer then timeout on same attempt — only +1 applied', () {
      engine.startGame(
          questions: _testQuestions(), players: _testPlayers(), sessionId: _sessionId);
      engine.pressBuzzer(
          playerId: 'p1', attemptId: 'attempt-race', now: DateTime.now().toUtc());

      engine.correctAnswer('attempt-race', DateTime.now().toUtc());
      final state = engine.timeout('attempt-race', DateTime.now().toUtc());

      // Only +1 applied (correct wins, timeout is ignored)
      expect(state.scores['p1'], 1);
    });

    test('timeout then correctAnswer on same attempt — only -1 applied', () {
      engine.startGame(
          questions: _testQuestions(), players: _testPlayers(), sessionId: _sessionId);
      engine.pressBuzzer(
          playerId: 'p1', attemptId: 'attempt-race', now: DateTime.now().toUtc());

      engine.timeout('attempt-race', DateTime.now().toUtc());

      // Judge tries to award correct after timeout — should throw
      expect(
        () => engine.correctAnswer('attempt-race', DateTime.now().toUtc()),
        throwsA(isA<GameStateException>()),
      );

      // Score stays at -1
      expect(engine.state.scores['p1'], -1);
    });

    // ── Scoring ──────────────────────────────────────────────────────────

    test('scores can go negative', () {
      engine.startGame(
          questions: _testQuestions(count: 5),
          players: _testPlayers(),
          sessionId: _sessionId);

      for (int i = 0; i < 3; i++) {
        engine.pressBuzzer(
            playerId: 'p1', attemptId: 'attempt-$i', now: DateTime.now().toUtc());
        engine.wrongAnswer('attempt-$i', DateTime.now().toUtc());
      }

      expect(engine.state.scores['p1'], -3);
    });

    // ── Question progression ──────────────────────────────────────────────

    test('correct answer on last question transitions to finished', () {
      engine.startGame(
          questions: _testQuestions(count: 1),
          players: _testPlayers(),
          sessionId: _sessionId);
      engine.pressBuzzer(
          playerId: 'p1', attemptId: 'attempt-1', now: DateTime.now().toUtc());
      final state = engine.correctAnswer('attempt-1', DateTime.now().toUtc());

      // With only 1 question, should go straight to finished
      expect(state.phase, GamePhase.finished);
    });

    test('applyCorrectResultTransition advances to next question then ready', () {
      engine.startGame(
          questions: _testQuestions(count: 2),
          players: _testPlayers(),
          sessionId: _sessionId);
      engine.pressBuzzer(
          playerId: 'p1', attemptId: 'attempt-1', now: DateTime.now().toUtc());
      engine.correctAnswer('attempt-1', DateTime.now().toUtc());

      final state = engine.applyCorrectResultTransition(DateTime.now().toUtc());
      expect(state.phase, GamePhase.ready);
      expect(state.questionIndex, 1);
    });

    // ── Skip ────────────────────────────────────────────────────────────

    test('skip question advances without penalty', () {
      engine.startGame(
          questions: _testQuestions(count: 3),
          players: _testPlayers(),
          sessionId: _sessionId);

      final state = engine.skipQuestion(DateTime.now().toUtc());

      expect(state.phase, GamePhase.ready);
      expect(state.questionIndex, 1);
      expect(state.scores.values.every((s) => s == 0), isTrue);
    });

    test('skip during answering cancels attempt without penalty', () {
      engine.startGame(
          questions: _testQuestions(count: 3),
          players: _testPlayers(),
          sessionId: _sessionId);
      engine.pressBuzzer(
          playerId: 'p1', attemptId: 'attempt-1', now: DateTime.now().toUtc());

      final state = engine.skipQuestion(DateTime.now().toUtc());

      expect(state.scores['p1'], 0); // No penalty
      expect(state.phase, GamePhase.ready);
    });

    // ── Pause / Resume ───────────────────────────────────────────────────

    test('pause and resume game', () {
      engine.startGame(
          questions: _testQuestions(), players: _testPlayers(), sessionId: _sessionId);

      final paused = engine.pauseGame(DateTime.now().toUtc());
      expect(paused.phase, GamePhase.paused);

      final resumed = engine.resumeGame(DateTime.now().toUtc());
      expect(resumed.phase, GamePhase.ready);
    });

    test('cannot pause during answering', () {
      engine.startGame(
          questions: _testQuestions(), players: _testPlayers(), sessionId: _sessionId);
      engine.pressBuzzer(
          playerId: 'p1', attemptId: 'attempt-1', now: DateTime.now().toUtc());

      expect(
        () => engine.pauseGame(DateTime.now().toUtc()),
        throwsA(isA<GameStateException>()),
      );
    });

    // ── endGame / resetGame ──────────────────────────────────────────────

    test('endGame transitions to finished', () {
      engine.startGame(
          questions: _testQuestions(), players: _testPlayers(), sessionId: _sessionId);

      final state = engine.endGame(DateTime.now().toUtc());
      expect(state.phase, GamePhase.finished);
    });

    test('resetGame returns to disconnected with clean state', () {
      engine.startGame(
          questions: _testQuestions(), players: _testPlayers(), sessionId: _sessionId);
      engine.pressBuzzer(
          playerId: 'p1', attemptId: 'attempt-1', now: DateTime.now().toUtc());
      engine.correctAnswer('attempt-1', DateTime.now().toUtc());

      final state = engine.resetGame();
      expect(state.phase, GamePhase.disconnected);
      expect(state.scores, isEmpty);
      expect(state.questions, isEmpty);
    });

    // ── Invalid transitions ──────────────────────────────────────────────

    test('correctAnswer without active attempt throws', () {
      engine.startGame(
          questions: _testQuestions(), players: _testPlayers(), sessionId: _sessionId);

      expect(
        () => engine.correctAnswer('no-attempt', DateTime.now().toUtc()),
        throwsA(isA<GameStateException>()),
      );
    });

    test('wrongAnswer without active attempt throws', () {
      engine.startGame(
          questions: _testQuestions(), players: _testPlayers(), sessionId: _sessionId);

      expect(
        () => engine.wrongAnswer('no-attempt', DateTime.now().toUtc()),
        throwsA(isA<GameStateException>()),
      );
    });

    test('canEvaluate is false when no attempt is active', () {
      engine.startGame(
          questions: _testQuestions(), players: _testPlayers(), sessionId: _sessionId);
      expect(engine.canEvaluate, isFalse);
    });

    test('canEvaluate is true when attempt is active and not expired', () {
      engine.startGame(
          questions: _testQuestions(), players: _testPlayers(), sessionId: _sessionId);
      engine.pressBuzzer(
          playerId: 'p1', attemptId: 'attempt-1', now: DateTime.now().toUtc());
      expect(engine.canEvaluate, isTrue);
    });

    // ── Display connection ────────────────────────────────────────────────

    test('connectDisplay sets isDisplayConnected to true', () {
      final state = engine.connectDisplay();
      expect(state.isDisplayConnected, isTrue);
    });

    test('disconnectDisplay sets isDisplayConnected to false', () {
      engine.connectDisplay();
      final state = engine.disconnectDisplay();
      expect(state.isDisplayConnected, isFalse);
    });
  });
}
