import 'game_models.dart';

/// All possible phases of the game.
enum GamePhase {
  disconnected,
  lobby,
  ready,
  answering,
  correctResult,
  wrongResult,
  timeoutResult,
  paused,
  finished,
}

extension GamePhaseExt on GamePhase {
  String get value => name;
  static GamePhase fromString(String s) => GamePhase.values.firstWhere(
        (e) => e.name.toLowerCase() == s.toLowerCase(),
        orElse: () => GamePhase.disconnected,
      );
}

/// Immutable snapshot of the authoritative game state.
class GameState {
  final GamePhase phase;
  final Question? currentQuestion;
  final Player? activePlayer;
  final String? activeAttemptId;
  final DateTime? answeringDeadline; // UTC absolute deadline
  final Map<String, int> scores; // playerId -> score
  final int questionIndex;
  final List<Question> questions;
  final List<Player> players;
  final int stateVersion;
  final String? sessionId;
  final GamePhase? previousPhase;
  final bool isDisplayConnected;

  const GameState({
    required this.phase,
    this.currentQuestion,
    this.activePlayer,
    this.activeAttemptId,
    this.answeringDeadline,
    this.scores = const {},
    this.questionIndex = 0,
    this.questions = const [],
    this.players = const [],
    this.stateVersion = 0,
    this.sessionId,
    this.previousPhase,
    this.isDisplayConnected = false,
  });

  /// Initial disconnected state.
  factory GameState.initial() => const GameState(
        phase: GamePhase.disconnected,
        currentQuestion: null,
        activePlayer: null,
        activeAttemptId: null,
        answeringDeadline: null,
        scores: {},
        questionIndex: 0,
        questions: [],
        players: [],
        stateVersion: 0,
        sessionId: null,
        previousPhase: null,
        isDisplayConnected: false,
      );

  bool get isDisconnected => phase == GamePhase.disconnected;
  bool get isLobby => phase == GamePhase.lobby;
  bool get isReady => phase == GamePhase.ready;
  bool get isAnswering => phase == GamePhase.answering;
  bool get isCorrectResult => phase == GamePhase.correctResult;
  bool get isWrongResult => phase == GamePhase.wrongResult;
  bool get isTimeoutResult => phase == GamePhase.timeoutResult;
  bool get isPaused => phase == GamePhase.paused;
  bool get isFinished => phase == GamePhase.finished;

  int get totalQuestions => questions.length;
  bool get isLastQuestion =>
      questions.isNotEmpty && questionIndex >= questions.length - 1;
  bool get hasMoreQuestions => questionIndex < questions.length - 1;

  /// Returns the currently active attempt as a [GameAttempt], or null if not answering.
  GameAttempt? get activeAttempt {
    if (phase != GamePhase.answering ||
        activeAttemptId == null ||
        activePlayer == null) {
      return null;
    }
    return GameAttempt(
      id: activeAttemptId!,
      playerId: activePlayer!.id,
      questionId: currentQuestion?.id ?? '',
      deadline: answeringDeadline ?? DateTime.now().toUtc(),
      startedAt: DateTime.now().toUtc(),
    );
  }

  /// Alternative factory constructor for WebSocket snapshot deserialization.
  factory GameState.fromSnapshotJson(Map<String, dynamic> json) =>
      GameState.fromJson(json);

  Map<String, dynamic> toSnapshotJson() => toJson();

  /// Returns the player currently in first place, or null if no players.
  Player? get leader {
    if (players.isEmpty) return null;
    Player? topPlayer;
    int topScore = -999999;
    for (final p in players) {
      final score = scores[p.id] ?? 0;
      if (score > topScore) {
        topScore = score;
        topPlayer = p;
      }
    }
    return topPlayer;
  }

  /// Returns the winning player when the game is finished.
  Player? get winner => isFinished ? leader : null;

  GameState copyWith({
    GamePhase? phase,
    Question? currentQuestion,
    bool clearCurrentQuestion = false,
    Player? activePlayer,
    bool clearActivePlayer = false,
    String? activeAttemptId,
    bool clearActiveAttempt = false,
    DateTime? answeringDeadline,
    bool clearAnsweringDeadline = false,
    Map<String, int>? scores,
    int? questionIndex,
    List<Question>? questions,
    List<Player>? players,
    int? stateVersion,
    String? sessionId,
    bool clearSessionId = false,
    GamePhase? previousPhase,
    bool clearPreviousPhase = false,
    bool? isDisplayConnected,
  }) {
    return GameState(
      phase: phase ?? this.phase,
      currentQuestion: clearCurrentQuestion
          ? null
          : (currentQuestion ?? this.currentQuestion),
      activePlayer:
          clearActivePlayer ? null : (activePlayer ?? this.activePlayer),
      activeAttemptId: clearActiveAttempt
          ? null
          : (activeAttemptId ?? this.activeAttemptId),
      answeringDeadline: clearAnsweringDeadline
          ? null
          : (answeringDeadline ?? this.answeringDeadline),
      scores: scores != null ? Map.unmodifiable(scores) : this.scores,
      questionIndex: questionIndex ?? this.questionIndex,
      questions: questions != null ? List.unmodifiable(questions) : this.questions,
      players: players != null ? List.unmodifiable(players) : this.players,
      stateVersion: stateVersion ?? this.stateVersion,
      sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
      previousPhase: clearPreviousPhase
          ? null
          : (previousPhase ?? this.previousPhase),
      isDisplayConnected: isDisplayConnected ?? this.isDisplayConnected,
    );
  }

  Map<String, dynamic> toJson() => {
        'phase': phase.value,
        'currentQuestion': currentQuestion?.toDisplayJson(),
        'activePlayer': activePlayer?.toJson(),
        'activeAttemptId': activeAttemptId,
        'answeringDeadline': answeringDeadline?.toUtc().toIso8601String(),
        'scores': scores,
        'questionIndex': questionIndex,
        'totalQuestions': totalQuestions,
        'players': players.map((p) => p.toJson()).toList(),
        'stateVersion': stateVersion,
        'sessionId': sessionId,
        'previousPhase': previousPhase?.value,
        'isDisplayConnected': isDisplayConnected,
      };

  factory GameState.fromJson(Map<String, dynamic> j) {
    final playersList = (j['players'] as List<dynamic>?)
            ?.map((p) => Player.fromJson(p as Map<String, dynamic>))
            .toList() ??
        const [];

    final scoresMap = (j['scores'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v as int),
        ) ??
        const {};

    return GameState(
      phase: GamePhaseExt.fromString(j['phase'] as String? ?? 'disconnected'),
      currentQuestion: j['currentQuestion'] != null
          ? Question.fromJson(j['currentQuestion'] as Map<String, dynamic>)
          : null,
      activePlayer: j['activePlayer'] != null
          ? Player.fromJson(j['activePlayer'] as Map<String, dynamic>)
          : null,
      activeAttemptId: j['activeAttemptId'] as String?,
      answeringDeadline: j['answeringDeadline'] != null
          ? DateTime.parse(j['answeringDeadline'] as String).toUtc()
          : null,
      scores: scoresMap,
      questionIndex: j['questionIndex'] as int? ?? 0,
      players: playersList,
      stateVersion: j['stateVersion'] as int? ?? 0,
      sessionId: j['sessionId'] as String?,
      previousPhase: j['previousPhase'] != null
          ? GamePhaseExt.fromString(j['previousPhase'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameState &&
          runtimeType == other.runtimeType &&
          other.phase == phase &&
          other.questionIndex == questionIndex &&
          other.stateVersion == stateVersion &&
          other.activeAttemptId == activeAttemptId;

  @override
  int get hashCode =>
      phase.hashCode ^
      questionIndex.hashCode ^
      stateVersion.hashCode ^
      (activeAttemptId?.hashCode ?? 0);

  @override
  String toString() =>
      'GameState(phase: ${phase.value}, qIndex: $questionIndex, v: $stateVersion, scores: $scores)';
}
