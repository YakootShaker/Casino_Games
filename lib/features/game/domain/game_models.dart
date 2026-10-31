import 'package:flutter/material.dart';
import 'package:quiz_buzzer/core/constants/game_constants.dart';

/// Immutable player model.
class Player {
  final String id;
  final String name;
  final int colorHex;
  final DateTime createdAt;

  const Player({
    required this.id,
    required this.name,
    int? colorHex,
    int? colorValue,
    required this.createdAt,
  }) : colorHex = colorHex ?? colorValue ?? 0xFF000000;

  /// Backward-compatible alias for colorHex.
  int get colorValue => colorHex;

  /// Flutter Color object constructed from the ARGB colorHex.
  Color get color => Color(colorHex);

  Player copyWith({
    String? id,
    String? name,
    int? colorHex,
    int? colorValue,
    DateTime? createdAt,
  }) =>
      Player(
        id: id ?? this.id,
        name: name ?? this.name,
        colorHex: colorHex ?? colorValue ?? this.colorHex,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color_hex': colorHex,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Player.fromMap(Map<String, dynamic> m) => Player(
        id: m['id'] as String,
        name: m['name'] as String,
        colorHex: (m['color_hex'] ?? m['colorValue']) as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          m['created_at'] as int,
          isUtc: true,
        ),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorHex': colorHex,
        'colorValue': colorHex,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory Player.fromJson(Map<String, dynamic> j) => Player(
        id: j['id'] as String,
        name: j['name'] as String,
        colorHex: (j['colorHex'] ?? j['colorValue']) as int,
        createdAt: j['createdAt'] != null
            ? DateTime.parse(j['createdAt'] as String).toUtc()
            : DateTime.now().toUtc(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Player &&
          runtimeType == other.runtimeType &&
          other.id == id &&
          other.name == name &&
          other.colorHex == colorHex;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ colorHex.hashCode;

  @override
  String toString() => 'Player(id: $id, name: $name, colorHex: $colorHex)';

  /// Default 3 players for standard match.
  static List<Player> defaults() => [
        Player(
          id: 'player-1',
          name: kPlayer1DefaultName,
          colorHex: kPlayer1ColorHex,
          createdAt: DateTime.now().toUtc(),
        ),
        Player(
          id: 'player-2',
          name: kPlayer2DefaultName,
          colorHex: kPlayer2ColorHex,
          createdAt: DateTime.now().toUtc(),
        ),
        Player(
          id: 'player-3',
          name: kPlayer3DefaultName,
          colorHex: kPlayer3ColorHex,
          createdAt: DateTime.now().toUtc(),
        ),
      ];
}

/// Immutable question model.
class Question {
  final String id;
  final String text;
  final String? answer; // visible to judge only
  final String? explanation;
  final String category;
  final String difficulty; // 'easy', 'medium', 'hard'
  final bool isActive;
  final DateTime createdAt;

  const Question({
    required this.id,
    required this.text,
    this.answer,
    this.explanation,
    required this.category,
    required this.difficulty,
    this.isActive = true,
    required this.createdAt,
  });

  Question copyWith({
    String? id,
    String? text,
    String? answer,
    String? explanation,
    String? category,
    String? difficulty,
    bool? isActive,
    DateTime? createdAt,
  }) =>
      Question(
        id: id ?? this.id,
        text: text ?? this.text,
        answer: answer ?? this.answer,
        explanation: explanation ?? this.explanation,
        category: category ?? this.category,
        difficulty: difficulty ?? this.difficulty,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'answer': answer,
        'explanation': explanation,
        'category': category,
        'difficulty': difficulty,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Question.fromMap(Map<String, dynamic> m) => Question(
        id: m['id'] as String,
        text: m['text'] as String,
        answer: m['answer'] as String?,
        explanation: m['explanation'] as String?,
        category: m['category'] as String? ?? 'General',
        difficulty: m['difficulty'] as String? ?? 'medium',
        isActive: (m['is_active'] as int? ?? 1) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          m['created_at'] as int,
          isUtc: true,
        ),
      );

  /// Sanitized version for display (no answer/explanation).
  Map<String, dynamic> toDisplayJson() => {
        'id': id,
        'text': text,
        'category': category,
        'difficulty': difficulty,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'answer': answer,
        'explanation': explanation,
        'category': category,
        'difficulty': difficulty,
        'isActive': isActive,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'] as String,
        text: j['text'] as String,
        answer: j['answer'] as String?,
        explanation: j['explanation'] as String?,
        category: j['category'] as String? ?? 'General',
        difficulty: j['difficulty'] as String? ?? 'medium',
        isActive: j['isActive'] as bool? ?? true,
        createdAt: j['createdAt'] != null
            ? DateTime.parse(j['createdAt'] as String).toUtc()
            : DateTime.now().toUtc(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Question &&
          runtimeType == other.runtimeType &&
          other.id == id &&
          other.text == text &&
          other.answer == answer;

  @override
  int get hashCode => id.hashCode ^ text.hashCode;

  @override
  String toString() => 'Question(id: $id, text: $text, category: $category)';
}

/// Score event types.
enum ScoreEventType { correct, wrong, timeout, skip }

extension ScoreEventTypeExt on ScoreEventType {
  String get value => name;
  static ScoreEventType fromString(String s) => ScoreEventType.values.firstWhere(
        (e) => e.name.toLowerCase() == s.toLowerCase(),
        orElse: () => ScoreEventType.correct,
      );
}

/// Immutable score event.
class ScoreEvent {
  final String id;
  final String sessionId;
  final String? questionId;
  final String playerId;
  final ScoreEventType eventType;
  final int delta;
  final String? attemptId;
  final DateTime createdAt;

  const ScoreEvent({
    required this.id,
    required this.sessionId,
    this.questionId,
    required this.playerId,
    required this.eventType,
    required this.delta,
    this.attemptId,
    required this.createdAt,
  });

  ScoreEvent copyWith({
    String? id,
    String? sessionId,
    String? questionId,
    String? playerId,
    ScoreEventType? eventType,
    int? delta,
    String? attemptId,
    DateTime? createdAt,
  }) =>
      ScoreEvent(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        questionId: questionId ?? this.questionId,
        playerId: playerId ?? this.playerId,
        eventType: eventType ?? this.eventType,
        delta: delta ?? this.delta,
        attemptId: attemptId ?? this.attemptId,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'session_id': sessionId,
        'question_id': questionId,
        'player_id': playerId,
        'event_type': eventType.value,
        'delta': delta,
        'attempt_id': attemptId,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory ScoreEvent.fromMap(Map<String, dynamic> m) => ScoreEvent(
        id: m['id'] as String,
        sessionId: m['session_id'] as String,
        questionId: m['question_id'] as String?,
        playerId: m['player_id'] as String,
        eventType: ScoreEventTypeExt.fromString(m['event_type'] as String),
        delta: m['delta'] as int,
        attemptId: m['attempt_id'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          m['created_at'] as int,
          isUtc: true,
        ),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'questionId': questionId,
        'playerId': playerId,
        'eventType': eventType.value,
        'delta': delta,
        'attemptId': attemptId,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory ScoreEvent.fromJson(Map<String, dynamic> j) => ScoreEvent(
        id: j['id'] as String,
        sessionId: j['sessionId'] as String,
        questionId: j['questionId'] as String?,
        playerId: j['playerId'] as String,
        eventType: ScoreEventTypeExt.fromString(j['eventType'] as String),
        delta: j['delta'] as int,
        attemptId: j['attemptId'] as String?,
        createdAt: j['createdAt'] != null
            ? DateTime.parse(j['createdAt'] as String).toUtc()
            : DateTime.now().toUtc(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScoreEvent &&
          runtimeType == other.runtimeType &&
          other.id == id &&
          other.sessionId == sessionId &&
          other.attemptId == attemptId;

  @override
  int get hashCode => id.hashCode ^ sessionId.hashCode ^ (attemptId?.hashCode ?? 0);

  @override
  String toString() =>
      'ScoreEvent(id: $id, player: $playerId, type: ${eventType.value}, delta: $delta)';
}

/// Immutable game attempt model.
class GameAttempt {
  final String id;
  final String playerId;
  final String questionId;
  final DateTime deadline; // UTC absolute deadline
  final DateTime startedAt;
  final String? outcome; // 'correct', 'wrong', 'timeout', etc.

  const GameAttempt({
    required this.id,
    required this.playerId,
    required this.questionId,
    required this.deadline,
    required this.startedAt,
    this.outcome,
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(deadline);

  Duration get remaining {
    final r = deadline.difference(DateTime.now().toUtc());
    return r.isNegative ? Duration.zero : r;
  }

  GameAttempt copyWith({
    String? id,
    String? playerId,
    String? questionId,
    DateTime? deadline,
    DateTime? startedAt,
    String? outcome,
  }) =>
      GameAttempt(
        id: id ?? this.id,
        playerId: playerId ?? this.playerId,
        questionId: questionId ?? this.questionId,
        deadline: deadline ?? this.deadline,
        startedAt: startedAt ?? this.startedAt,
        outcome: outcome ?? this.outcome,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'player_id': playerId,
        'question_id': questionId,
        'deadline': deadline.millisecondsSinceEpoch,
        'started_at': startedAt.millisecondsSinceEpoch,
        'outcome': outcome,
      };

  factory GameAttempt.fromMap(Map<String, dynamic> m) => GameAttempt(
        id: m['id'] as String,
        playerId: (m['player_id'] ?? m['playerId']) as String,
        questionId: (m['question_id'] ?? m['questionId']) as String,
        deadline: DateTime.fromMillisecondsSinceEpoch(
          (m['deadline'] ?? m['deadlineMs']) as int,
          isUtc: true,
        ),
        startedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['started_at'] ?? m['startedAtMs']) as int,
          isUtc: true,
        ),
        outcome: m['outcome'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'playerId': playerId,
        'questionId': questionId,
        'deadlineMs': deadline.millisecondsSinceEpoch,
        'startedAtMs': startedAt.millisecondsSinceEpoch,
        if (outcome != null) 'outcome': outcome,
      };

  factory GameAttempt.fromJson(Map<String, dynamic> j) =>
      GameAttempt.fromMap(j);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameAttempt &&
          runtimeType == other.runtimeType &&
          other.id == id &&
          other.playerId == playerId &&
          other.questionId == questionId;

  @override
  int get hashCode => id.hashCode ^ playerId.hashCode ^ questionId.hashCode;

  @override
  String toString() =>
      'GameAttempt(id: $id, player: $playerId, outcome: $outcome)';
}

/// Immutable game session model.
class GameSession {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String status; // 'active', 'finished', 'paused', 'cancelled'
  final String? winnerId;
  final List<String> playerIds;
  final List<String> questionIds;

  const GameSession({
    required this.id,
    required this.startedAt,
    this.endedAt,
    required this.status,
    this.winnerId,
    this.playerIds = const [],
    this.questionIds = const [],
  });

  GameSession copyWith({
    String? id,
    DateTime? startedAt,
    DateTime? endedAt,
    bool clearEndedAt = false,
    String? status,
    String? winnerId,
    bool clearWinnerId = false,
    List<String>? playerIds,
    List<String>? questionIds,
  }) =>
      GameSession(
        id: id ?? this.id,
        startedAt: startedAt ?? this.startedAt,
        endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
        status: status ?? this.status,
        winnerId: clearWinnerId ? null : (winnerId ?? this.winnerId),
        playerIds: playerIds ?? this.playerIds,
        questionIds: questionIds ?? this.questionIds,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'started_at': startedAt.millisecondsSinceEpoch,
        'ended_at': endedAt?.millisecondsSinceEpoch,
        'status': status,
        'winner_id': winnerId,
      };

  factory GameSession.fromMap(
    Map<String, dynamic> m, {
    List<String> playerIds = const [],
    List<String> questionIds = const [],
  }) =>
      GameSession(
        id: m['id'] as String,
        startedAt: DateTime.fromMillisecondsSinceEpoch(
          m['started_at'] as int,
          isUtc: true,
        ),
        endedAt: m['ended_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                m['ended_at'] as int,
                isUtc: true,
              )
            : null,
        status: m['status'] as String,
        winnerId: m['winner_id'] as String?,
        playerIds: playerIds,
        questionIds: questionIds,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt?.toUtc().toIso8601String(),
        'status': status,
        'winnerId': winnerId,
        'playerIds': playerIds,
        'questionIds': questionIds,
      };

  factory GameSession.fromJson(Map<String, dynamic> j) => GameSession(
        id: j['id'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String).toUtc(),
        endedAt: j['endedAt'] != null
            ? DateTime.parse(j['endedAt'] as String).toUtc()
            : null,
        status: j['status'] as String,
        winnerId: j['winnerId'] as String?,
        playerIds: (j['playerIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        questionIds: (j['questionIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameSession &&
          runtimeType == other.runtimeType &&
          other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'GameSession(id: $id, status: $status, winnerId: $winnerId)';
}
