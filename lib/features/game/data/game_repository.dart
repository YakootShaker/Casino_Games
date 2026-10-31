import 'package:uuid/uuid.dart';
import 'package:quiz_buzzer/services/database_service.dart';
import 'package:quiz_buzzer/features/game/domain/game_models.dart';

const _uuid = Uuid();

/// Repository managing game sessions, question/player session mappings,
/// and safe score event tracking.
class GameRepository {
  final DatabaseService _dbService;

  GameRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService.instance;

  /// Creates a new game session with associated player and question IDs.
  /// Returns the generated session ID.
  Future<String> createSession(
    List<Player> players,
    List<Question> questions,
  ) async {
    final sessionId = _uuid.v4();
    final now = DateTime.now().toUtc();
    final playerIds = players.map((p) => p.id).toList();
    final questionIds = questions.map((q) => q.id).toList();

    final session = GameSession(
      id: sessionId,
      startedAt: now,
      status: 'active',
      playerIds: playerIds,
      questionIds: questionIds,
    );

    await _dbService.insertGameSession(session, playerIds, questionIds);
    return sessionId;
  }

  /// Records a score event safely. Prevents duplicate attempts on the unique constraint.
  /// Returns true if recorded, false if duplicate was safely ignored.
  Future<bool> recordScoreEvent(ScoreEvent event) async {
    final insertedId = await _dbService.insertScoreEventSafe(event);
    return insertedId > 0;
  }

  /// Updates status and optional winner / endedAt for a session.
  Future<void> updateSessionStatus(
    String sessionId,
    String status, {
    String? winnerId,
    DateTime? endedAt,
  }) async {
    final session = await _dbService.getGameSession(sessionId);
    if (session == null) return;

    final updated = session.copyWith(
      status: status,
      winnerId: winnerId,
      endedAt: endedAt ?? (status == 'finished' ? DateTime.now().toUtc() : null),
    );

    await _dbService.updateGameSession(updated);
  }

  /// Marks a specific question in a session as answered.
  Future<void> markQuestionAnswered({
    required String sessionId,
    required String questionId,
    required bool correct,
    String? answeredBy,
  }) async {
    final db = await _dbService.database;
    await db.update(
      'game_questions',
      {
        'answered_correctly': correct ? 1 : 0,
        'answered_by': answeredBy,
      },
      where: 'session_id = ? AND question_id = ?',
      whereArgs: [sessionId, questionId],
    );
  }

  /// Updates final scores for players in a session, and optionally records the winner.
  Future<void> updateFinalScores(
    String sessionId,
    Map<String, int> scores, [
    String? winnerId,
  ]) async {
    for (final entry in scores.entries) {
      await _dbService.updateGamePlayerScore(
        sessionId,
        entry.key,
        entry.value,
      );
    }
    if (winnerId != null) {
      await updateSessionStatus(sessionId, 'finished', winnerId: winnerId);
    }
  }

  /// Retrieves past completed or active sessions ordered by start time.
  Future<List<GameSession>> getSessionHistory() =>
      _dbService.getAllSessions();

  /// Retrieves a specific game session by its ID.
  Future<GameSession?> getSessionById(String id) =>
      _dbService.getGameSession(id);

  /// Retrieves all score events logged for a session.
  Future<List<ScoreEvent>> getSessionScoreEvents(String sessionId) =>
      _dbService.getScoreEventsForSession(sessionId);
}
