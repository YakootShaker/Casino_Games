// ignore_for_file: constant_identifier_names

/// WebSocket message type constants
class WsMessageType {
  WsMessageType._();

  // Connection
  static const String joinRequest = 'JOIN_REQUEST';
  static const String joinAccepted = 'JOIN_ACCEPTED';
  static const String joinRejected = 'JOIN_REJECTED';
  static const String connectionStatus = 'CONNECTION_STATUS';
  static const String ping = 'PING';
  static const String pong = 'PONG';

  // State sync
  static const String stateSnapshot = 'STATE_SNAPSHOT';

  // Buzzer
  static const String buzzerPress = 'BUZZER_PRESS';
  static const String buzzerAccepted = 'BUZZER_ACCEPTED';
  static const String buzzerRejected = 'BUZZER_REJECTED';

  // Answer results
  static const String answeringStarted = 'ANSWERING_STARTED';
  static const String correctAnswer = 'CORRECT_ANSWER';
  static const String wrongAnswer = 'WRONG_ANSWER';
  static const String timeout = 'TIMEOUT';

  // Score
  static const String scoreUpdate = 'SCORE_UPDATE';

  // Question
  static const String questionUpdate = 'QUESTION_UPDATE';

  // Game control
  static const String gamePaused = 'GAME_PAUSED';
  static const String gameResumed = 'GAME_RESUMED';
  static const String gameFinished = 'GAME_FINISHED';
  static const String gameStarted = 'GAME_STARTED';
  static const String skipQuestion = 'SKIP_QUESTION';
  static const String resetGame = 'RESET_GAME';

  // Error
  static const String error = 'ERROR';
}
