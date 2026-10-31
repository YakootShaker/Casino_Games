import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_buzzer/core/constants/game_constants.dart';
import 'package:quiz_buzzer/features/game/domain/game_models.dart';
import 'package:quiz_buzzer/features/game/domain/game_state.dart';

void main() {
  group('Game Models and State', () {
    test('Player model serialization and defaults', () {
      final defaults = Player.defaults();
      expect(defaults.length, 3);
      expect(defaults[0].name, kPlayer1DefaultName);
      expect(defaults[0].colorHex, kPlayer1ColorHex);
      expect(defaults[0].colorValue, kPlayer1ColorHex);

      final p = defaults[0];
      final map = p.toMap();
      final fromMap = Player.fromMap(map);
      expect(fromMap.id, p.id);
      expect(fromMap.name, p.name);
      expect(fromMap.colorHex, p.colorHex);

      final json = p.toJson();
      final fromJson = Player.fromJson(json);
      expect(fromJson.id, p.id);
      expect(fromJson.name, p.name);

      final updated = p.copyWith(name: 'Updated');
      expect(updated.name, 'Updated');
      expect(updated.id, p.id);
    });

    test('Question model serialization', () {
      final q = Question(
        id: 'q1',
        text: 'What is 2+2?',
        answer: '4',
        category: 'Math',
        difficulty: 'easy',
        createdAt: DateTime.now().toUtc(),
      );

      final map = q.toMap();
      final fromMap = Question.fromMap(map);
      expect(fromMap.id, 'q1');
      expect(fromMap.text, 'What is 2+2?');
      expect(fromMap.answer, '4');

      final displayJson = q.toDisplayJson();
      expect(displayJson.containsKey('answer'), isFalse);
      expect(displayJson['text'], 'What is 2+2?');
    });

    test('ScoreEvent model serialization and delta calculation', () {
      final now = DateTime.now().toUtc();
      final event = ScoreEvent(
        id: 'ev-1',
        sessionId: 's-1',
        questionId: 'q-1',
        playerId: 'p-1',
        eventType: ScoreEventType.correct,
        delta: 1,
        attemptId: 'a-1',
        createdAt: now,
      );

      expect(event.delta, 1);
      expect(event.eventType, ScoreEventType.correct);

      final map = event.toMap();
      final fromMap = ScoreEvent.fromMap(map);
      expect(fromMap.id, 'ev-1');
      expect(fromMap.delta, 1);
      expect(fromMap.eventType, ScoreEventType.correct);

      final penalty = ScoreEvent(
        id: 'ev-2',
        sessionId: 's-1',
        questionId: 'q-1',
        playerId: 'p-1',
        eventType: ScoreEventType.wrong,
        delta: -1,
        createdAt: now,
      );
      expect(penalty.delta, -1);
      expect(penalty.eventType, ScoreEventType.wrong);
    });

    test('GameAttempt model active and expiry calculation', () {
      final deadline = DateTime.now().toUtc().add(const Duration(seconds: 10));
      final attempt = GameAttempt(
        id: 'att-1',
        playerId: 'p1',
        questionId: 'q1',
        deadline: deadline,
        startedAt: DateTime.now().toUtc(),
      );

      expect(attempt.isExpired, isFalse);

      final expiredAttempt = GameAttempt(
        id: 'att-2',
        playerId: 'p1',
        questionId: 'q1',
        deadline: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
        startedAt: DateTime.now().toUtc().subtract(const Duration(seconds: 11)),
      );

      expect(expiredAttempt.isExpired, isTrue);
    });

    test('GameState leader and winner getters', () {
      final p1 = Player(
        id: 'p1',
        name: 'Player 1',
        colorHex: 0xFF000000,
        createdAt: DateTime.now(),
      );
      final p2 = Player(
        id: 'p2',
        name: 'Player 2',
        colorHex: 0xFF111111,
        createdAt: DateTime.now(),
      );

      final state = GameState(
        phase: GamePhase.ready,
        players: [p1, p2],
        scores: {'p1': 3, 'p2': 5},
      );

      expect(state.leader?.id, 'p2');
      expect(state.winner, isNull); // Not finished yet

      final finishedState = state.copyWith(phase: GamePhase.finished);
      expect(finishedState.winner?.id, 'p2');
    });

    test('GameState serialization and snapshot parsing', () {
      final p1 = Player(
        id: 'p1',
        name: 'Player 1',
        colorHex: 0xFF000000,
        createdAt: DateTime.now(),
      );
      final q1 = Question(
        id: 'q1',
        text: 'Q?',
        answer: 'A',
        category: 'General',
        difficulty: 'easy',
        createdAt: DateTime.now(),
      );

      final state = GameState(
        phase: GamePhase.ready,
        players: [p1],
        questions: [q1],
        scores: {'p1': 2},
        sessionId: 'session-xyz',
      );

      final json = state.toJson();
      final fromSnapshot = GameState.fromSnapshotJson(json);

      expect(fromSnapshot.phase, GamePhase.ready);
      expect(fromSnapshot.sessionId, 'session-xyz');
      expect(fromSnapshot.scores['p1'], 2);
    });
  });
}
