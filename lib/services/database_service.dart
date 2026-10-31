import 'package:sqflite/sqflite.dart';
import 'package:quiz_buzzer/core/constants/game_constants.dart';
import 'package:quiz_buzzer/features/game/domain/game_models.dart';

/// SQLite database service managing schemas, migrations, transactions, and CRUD.
class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();
  factory DatabaseService() => instance;

  Database? _database;

  /// Get active database instance or throw if not initialized.
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    await initialize();
    return _database!;
  }

  /// Initialize database connection with custom database or default disk storage.
  Future<void> initialize({Database? db}) async {
    if (db != null) {
      _database = db;
      return;
    }
    if (_database != null && _database!.isOpen) {
      return;
    }

    final dbPath = await getDatabasesPath();
    final path = '$dbPath/$kDbName';

    _database = await openDatabase(
      path,
      version: kDbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Close database connection.
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.transaction((txn) async {
      // 1. Players table
      await txn.execute('''
        CREATE TABLE players (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          color_hex INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        );
      ''');

      // 2. Questions table
      await txn.execute('''
        CREATE TABLE questions (
          id TEXT PRIMARY KEY,
          text TEXT NOT NULL,
          answer TEXT,
          explanation TEXT,
          category TEXT,
          difficulty TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL
        );
      ''');

      // 3. Game sessions table
      await txn.execute('''
        CREATE TABLE game_sessions (
          id TEXT PRIMARY KEY,
          started_at INTEGER NOT NULL,
          ended_at INTEGER,
          status TEXT NOT NULL,
          winner_id TEXT
        );
      ''');

      // 4. Game players mapping table
      await txn.execute('''
        CREATE TABLE game_players (
          id TEXT PRIMARY KEY,
          session_id TEXT NOT NULL,
          player_id TEXT NOT NULL,
          final_score INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (session_id) REFERENCES game_sessions(id) ON DELETE CASCADE,
          FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
        );
      ''');

      // 5. Game questions mapping table
      await txn.execute('''
        CREATE TABLE game_questions (
          id TEXT PRIMARY KEY,
          session_id TEXT NOT NULL,
          question_id TEXT NOT NULL,
          order_index INTEGER NOT NULL,
          answered_correctly INTEGER DEFAULT 0,
          answered_by TEXT,
          FOREIGN KEY (session_id) REFERENCES game_sessions(id) ON DELETE CASCADE,
          FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
        );
      ''');

      // 6. Score events table
      await txn.execute('''
        CREATE TABLE score_events (
          id TEXT PRIMARY KEY,
          session_id TEXT NOT NULL,
          question_id TEXT,
          player_id TEXT NOT NULL,
          event_type TEXT NOT NULL,
          delta INTEGER NOT NULL,
          attempt_id TEXT,
          created_at INTEGER NOT NULL,
          UNIQUE(attempt_id, event_type),
          FOREIGN KEY (session_id) REFERENCES game_sessions(id) ON DELETE CASCADE
        );
      ''');

      // 7. Game settings table
      await txn.execute('''
        CREATE TABLE game_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        );
      ''');

      // Indexes for fast lookup
      await txn.execute(
        'CREATE INDEX idx_score_events_session ON score_events(session_id);',
      );
      await txn.execute(
        'CREATE INDEX idx_game_players_session ON game_players(session_id);',
      );
      await txn.execute(
        'CREATE INDEX idx_game_questions_session ON game_questions(session_id);',
      );
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration hooks for future versions
  }

  /// Run an action inside a database transaction.
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction(action);
  }

  // ── Score Events ──────────────────────────────────────────────────────────

  /// Inserts a ScoreEvent safely using INSERT OR IGNORE to prevent duplicate
  /// records on the UNIQUE(attempt_id, event_type) constraint.
  Future<int> insertScoreEventSafe(ScoreEvent event) async {
    final db = await database;
    return db.insert(
      'score_events',
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Retrieve all score events for a given game session.
  Future<List<ScoreEvent>> getScoreEventsForSession(String sessionId) async {
    final db = await database;
    final results = await db.query(
      'score_events',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
    return results.map((m) => ScoreEvent.fromMap(m)).toList();
  }

  // ── Players CRUD ──────────────────────────────────────────────────────────

  Future<void> insertPlayer(Player player) async {
    final db = await database;
    await db.insert(
      'players',
      player.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Player?> getPlayer(String id) async {
    final db = await database;
    final list = await db.query('players', where: 'id = ?', whereArgs: [id]);
    if (list.isEmpty) return null;
    return Player.fromMap(list.first);
  }

  Future<List<Player>> getAllPlayers() async {
    final db = await database;
    final list = await db.query('players', orderBy: 'created_at ASC');
    return list.map((m) => Player.fromMap(m)).toList();
  }

  Future<void> updatePlayer(Player player) async {
    final db = await database;
    await db.update(
      'players',
      player.toMap(),
      where: 'id = ?',
      whereArgs: [player.id],
    );
  }

  Future<void> deletePlayer(String id) async {
    final db = await database;
    await db.delete('players', where: 'id = ?', whereArgs: [id]);
  }

  // ── Questions CRUD ────────────────────────────────────────────────────────

  Future<void> insertQuestion(Question question) async {
    final db = await database;
    await db.insert(
      'questions',
      question.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Question?> getQuestion(String id) async {
    final db = await database;
    final list = await db.query('questions', where: 'id = ?', whereArgs: [id]);
    if (list.isEmpty) return null;
    return Question.fromMap(list.first);
  }

  Future<List<Question>> getAllQuestions() async {
    final db = await database;
    final list = await db.query('questions', orderBy: 'created_at ASC');
    return list.map((m) => Question.fromMap(m)).toList();
  }

  Future<List<Question>> getActiveQuestions() async {
    final db = await database;
    final list = await db.query(
      'questions',
      where: 'is_active = 1',
      orderBy: 'created_at ASC',
    );
    return list.map((m) => Question.fromMap(m)).toList();
  }

  Future<void> updateQuestion(Question question) async {
    final db = await database;
    await db.update(
      'questions',
      question.toMap(),
      where: 'id = ?',
      whereArgs: [question.id],
    );
  }

  Future<void> deleteQuestion(String id) async {
    final db = await database;
    await db.delete('questions', where: 'id = ?', whereArgs: [id]);
  }

  // ── Game Sessions ─────────────────────────────────────────────────────────

  Future<void> insertGameSession(
    GameSession session,
    List<String> playerIds,
    List<String> questionIds,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'game_sessions',
        session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (final pId in playerIds) {
        await txn.insert(
          'game_players',
          {
            'id': '${session.id}_$pId',
            'session_id': session.id,
            'player_id': pId,
            'final_score': 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (int i = 0; i < questionIds.length; i++) {
        final qId = questionIds[i];
        await txn.insert(
          'game_questions',
          {
            'id': '${session.id}_${qId}_$i',
            'session_id': session.id,
            'question_id': qId,
            'order_index': i,
            'answered_correctly': 0,
            'answered_by': null,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<GameSession?> getGameSession(String id) async {
    final db = await database;
    final list =
        await db.query('game_sessions', where: 'id = ?', whereArgs: [id]);
    if (list.isEmpty) return null;

    final playersList = await db.query(
      'game_players',
      where: 'session_id = ?',
      whereArgs: [id],
    );
    final questionsList = await db.query(
      'game_questions',
      where: 'session_id = ?',
      whereArgs: [id],
      orderBy: 'order_index ASC',
    );

    return GameSession.fromMap(
      list.first,
      playerIds: playersList.map((m) => m['player_id'] as String).toList(),
      questionIds:
          questionsList.map((m) => m['question_id'] as String).toList(),
    );
  }

  Future<List<GameSession>> getAllSessions() async {
    final db = await database;
    final list = await db.query(
      'game_sessions',
      orderBy: 'started_at DESC',
    );
    final sessions = <GameSession>[];
    for (final s in list) {
      final sId = s['id'] as String;
      final players = await db.query(
        'game_players',
        where: 'session_id = ?',
        whereArgs: [sId],
      );
      final questions = await db.query(
        'game_questions',
        where: 'session_id = ?',
        whereArgs: [sId],
        orderBy: 'order_index ASC',
      );
      sessions.add(
        GameSession.fromMap(
          s,
          playerIds: players.map((m) => m['player_id'] as String).toList(),
          questionIds:
              questions.map((m) => m['question_id'] as String).toList(),
        ),
      );
    }
    return sessions;
  }

  Future<void> updateGameSession(GameSession session) async {
    final db = await database;
    await db.update(
      'game_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<void> updateGamePlayerScore(
    String sessionId,
    String playerId,
    int score,
  ) async {
    final db = await database;
    await db.update(
      'game_players',
      {'final_score': score},
      where: 'session_id = ? AND player_id = ?',
      whereArgs: [sessionId, playerId],
    );
  }

  // ── Settings CRUD ─────────────────────────────────────────────────────────

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'game_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key, {String? defaultValue}) async {
    final db = await database;
    final list = await db.query(
      'game_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (list.isEmpty) return defaultValue;
    return list.first['value'] as String?;
  }
}
