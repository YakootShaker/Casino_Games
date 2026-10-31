import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/constants/game_constants.dart';
import '../../../core/constants/ws_message_types.dart';
import '../../../features/game/domain/game_engine.dart';
import '../../../features/game/domain/game_models.dart';
import '../../../features/game/domain/game_state.dart';
import '../../../features/game/data/game_repository.dart';
import '../domain/ws_message.dart';

const _uuid = Uuid();

/// Callback type for state change events.
typedef StateChangeCallback = void Function(GameState state, ScoreEvent? event);

/// Judge-side local HTTP + WebSocket server.
///
/// Starts a server on a local port. The player display connects via WebSocket.
/// All game state changes are driven through [GameEngine].
class LocalServer {
  final GameEngine engine;
  final GameRepository gameRepo;
  final int port;

  GameEngine get _engine => engine;
  GameRepository get _gameRepo => gameRepo;

  HttpServer? _httpServer;
  WebSocketChannel? _displayChannel;
  StreamSubscription? _displaySub;

  String? _sessionToken; // Simple local auth token

  final StreamController<GameState> _stateController =
      StreamController<GameState>.broadcast();

  /// Subscribe to receive state updates (for the judge UI).
  Stream<GameState> get stateStream => _stateController.stream;

  GameState get currentState => _engine.state;

  LocalServer({
    required this.engine,
    required this.gameRepo,
    this.port = kDefaultPort,
  }) {
    _engine.onTimeout = _handleTimeout;
  }

  bool get isRunning => _httpServer != null;
  bool get hasDisplay => _displayChannel != null;

  // ── Server lifecycle ──────────────────────────────────────────────────────

  Future<String> start() async {
    if (_httpServer != null) return _getLocalIp();

    _sessionToken = _uuid.v4();

    final handler = webSocketHandler(
      _handleWebSocket,
      pingInterval: const Duration(seconds: 20),
    );

    final pipeline = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(handler);

    _httpServer = await io.serve(pipeline, InternetAddress.anyIPv4, port);
    return _getLocalIp();
  }

  Future<void> stop() async {
    _displaySub?.cancel();
    await _displayChannel?.sink.close();
    _displayChannel = null;
    await _httpServer?.close(force: true);
    _httpServer = null;
  }

  String _getLocalIp() {
    // We bind to 0.0.0.0, so we need to find a real interface IP
    return '0.0.0.0'; // Overridden by NetworkInfoPlus in the UI layer
  }

  // ── WebSocket handling ────────────────────────────────────────────────────

  void _handleWebSocket(WebSocketChannel channel, [String? protocol]) {
    // Only allow one display at a time
    if (_displayChannel != null) {
      channel.sink.add(WsMessage.error(
        'Server already has a connected display.',
      ).toJsonString());
      channel.sink.close();
      return;
    }

    _displaySub?.cancel();
    _displayChannel = channel;

    _displaySub = channel.stream.listen(
      _onDisplayMessage,
      onDone: _onDisplayDisconnected,
      onError: (_) => _onDisplayDisconnected(),
      cancelOnError: false,
    );
  }

  void _onDisplayMessage(dynamic raw) {
    WsMessage msg;
    try {
      msg = WsMessage.fromString(raw as String);
    } catch (_) {
      _sendToDisplay(WsMessage.error('Malformed message.'));
      return;
    }

    switch (msg.type) {
      case WsMessageType.joinRequest:
        _handleJoinRequest(msg);
      case WsMessageType.buzzerPress:
        _handleBuzzerPress(msg);
      case WsMessageType.ping:
        _sendToDisplay(WsMessage.pong());
      default:
        _sendToDisplay(WsMessage.error(
          'Unknown message type: ${msg.type}',
          sessionId: msg.sessionId,
        ));
    }
  }

  void _handleJoinRequest(WsMessage msg) {
    final token = msg.payload['token'] as String?;
    if (token != _sessionToken) {
      _sendToDisplay(WsMessage(
        type: WsMessageType.joinRejected,
        payload: {'reason': 'Invalid session token.'},
      ));
      _displayChannel?.sink.close();
      _displayChannel = null;
      return;
    }

    // Update engine — display connected
    final newState = _engine.connectDisplay();
    _emit(newState);

    _sendToDisplay(WsMessage(
      type: WsMessageType.joinAccepted,
      sessionId: newState.sessionId,
      payload: {'message': 'Connected to Quiz Buzzer server.'},
    ));

    // Send full state snapshot
    _sendStateSnapshot();
  }

  void _handleBuzzerPress(WsMessage msg) {
    if (_engine.state.phase != GamePhase.ready) {
      _sendToDisplay(WsMessage(
        type: WsMessageType.buzzerRejected,
        sessionId: msg.sessionId,
        payload: {'reason': 'Game is not in ready state.'},
      ));
      return;
    }

    final playerId = msg.payload['playerId'] as String?;
    if (playerId == null) {
      _sendToDisplay(WsMessage.error('Missing playerId in buzzerPress.'));
      return;
    }

    final attemptId = _uuid.v4();
    final now = DateTime.now().toUtc();

    try {
      final newState = _engine.pressBuzzer(
        playerId: playerId,
        attemptId: attemptId,
        now: now,
      );
      _emit(newState);

      _sendToDisplay(WsMessage(
        type: WsMessageType.buzzerAccepted,
        sessionId: newState.sessionId,
        payload: {
          'attemptId': attemptId,
          'playerId': playerId,
          'deadlineMs': newState.activeAttempt?.deadline.millisecondsSinceEpoch,
        },
      ));

      // Broadcast answering started
      _broadcast(WsMessage(
        type: WsMessageType.answeringStarted,
        sessionId: newState.sessionId,
        payload: newState.toJson(),
      ));
    } catch (e) {
      _sendToDisplay(WsMessage(
        type: WsMessageType.buzzerRejected,
        sessionId: msg.sessionId,
        payload: {'reason': e.toString()},
      ));
    }
  }

  void _onDisplayDisconnected() {
    _displaySub?.cancel();
    _displayChannel = null;
    final newState = _engine.disconnectDisplay();
    _emit(newState);
  }

  // ── Judge actions (called from judge UI) ──────────────────────────────────

  Future<void> handleCorrectAnswer() async {
    final attempt = _engine.state.activeAttempt;
    if (attempt == null) return;

    final now = DateTime.now().toUtc();
    try {
      final newState = _engine.correctAnswer(attempt.id, now);

      // Persist score event
      if (_engine.state.sessionId != null) {
        final event = ScoreEvent(
          id: _uuid.v4(),
          sessionId: _engine.state.sessionId!,
          questionId: attempt.questionId,
          playerId: attempt.playerId,
          eventType: ScoreEventType.correct,
          delta: kCorrectScore,
          attemptId: attempt.id,
          createdAt: now,
        );
        await _gameRepo.recordScoreEvent(event);
        await _gameRepo.markQuestionAnswered(
          sessionId: _engine.state.sessionId!,
          questionId: attempt.questionId,
          correct: true,
          answeredBy: attempt.playerId,
        );
      }

      _emit(newState);
      _broadcast(WsMessage(
        type: WsMessageType.correctAnswer,
        sessionId: newState.sessionId,
        payload: newState.toJson(),
      ));

      // Schedule the 2-second transition
      if (newState.phase == GamePhase.correctResult) {
        Timer(const Duration(milliseconds: kCorrectResultDisplayMs), () {
          final transState = _engine.applyCorrectResultTransition(
              DateTime.now().toUtc());
          _emit(transState);
          _broadcast(WsMessage(
            type: newState.hasMoreQuestions
                ? WsMessageType.questionUpdate
                : WsMessageType.gameFinished,
            sessionId: transState.sessionId,
            payload: transState.toJson(),
          ));
          if (transState.phase == GamePhase.finished) {
            _finalizeSession(transState);
          }
        });
      }
    } catch (e) {
      // Likely duplicate or expired — ignore
    }
  }

  Future<void> handleWrongAnswer() async {
    final attempt = _engine.state.activeAttempt;
    if (attempt == null) return;

    final now = DateTime.now().toUtc();
    try {
      final newState = _engine.wrongAnswer(attempt.id, now);

      if (newState.sessionId != null) {
        final event = ScoreEvent(
          id: _uuid.v4(),
          sessionId: newState.sessionId!,
          questionId: attempt.questionId,
          playerId: attempt.playerId,
          eventType: ScoreEventType.wrong,
          delta: kWrongScore,
          attemptId: attempt.id,
          createdAt: now,
        );
        await _gameRepo.recordScoreEvent(event);
      }

      _emit(newState);
      _broadcast(WsMessage(
        type: WsMessageType.wrongAnswer,
        sessionId: newState.sessionId,
        payload: newState.toJson(),
      ));
    } catch (_) {}
  }

  Future<void> _handleTimeout(String attemptId) async {
    final now = DateTime.now().toUtc();
    final prevState = _engine.state;

    final newState = _engine.timeout(attemptId, now);
    if (newState.stateVersion == prevState.stateVersion) return; // No change

    if (newState.sessionId != null && prevState.activeAttempt != null) {
      final attempt = prevState.activeAttempt!;
      final event = ScoreEvent(
        id: _uuid.v4(),
        sessionId: newState.sessionId!,
        questionId: attempt.questionId,
        playerId: attempt.playerId,
        eventType: ScoreEventType.timeout,
        delta: kTimeoutScore,
        attemptId: attemptId,
        createdAt: now,
      );
      await _gameRepo.recordScoreEvent(event);
    }

    _emit(newState);
    _broadcast(WsMessage(
      type: WsMessageType.timeout,
      sessionId: newState.sessionId,
      payload: newState.toJson(),
    ));
  }

  Future<void> handleSkipQuestion() async {
    final now = DateTime.now().toUtc();
    try {
      final newState = _engine.skipQuestion(now);
      _emit(newState);
      _broadcast(WsMessage(
        type: newState.phase == GamePhase.finished
            ? WsMessageType.gameFinished
            : WsMessageType.skipQuestion,
        sessionId: newState.sessionId,
        payload: newState.toJson(),
      ));
      if (newState.phase == GamePhase.finished) _finalizeSession(newState);
    } catch (_) {}
  }

  Future<void> handlePause() async {
    try {
      final newState = _engine.pauseGame(DateTime.now().toUtc());
      _emit(newState);
      _broadcast(WsMessage(
        type: WsMessageType.gamePaused,
        sessionId: newState.sessionId,
        payload: newState.toJson(),
      ));
    } catch (_) {}
  }

  Future<void> handleResume() async {
    try {
      final newState = _engine.resumeGame(DateTime.now().toUtc());
      _emit(newState);
      _broadcast(WsMessage(
        type: WsMessageType.gameResumed,
        sessionId: newState.sessionId,
        payload: newState.toJson(),
      ));
    } catch (_) {}
  }

  Future<void> handleEndGame() async {
    final now = DateTime.now().toUtc();
    final newState = _engine.endGame(now);
    _emit(newState);
    _broadcast(WsMessage(
      type: WsMessageType.gameFinished,
      sessionId: newState.sessionId,
      payload: newState.toJson(),
    ));
    _finalizeSession(newState);
  }

  Future<void> _finalizeSession(GameState state) async {
    if (state.sessionId == null) return;
    await _gameRepo.updateSessionStatus(state.sessionId!, 'finished');
    // Determine winner
    String? winnerId;
    if (state.scores.isNotEmpty) {
      final maxEntry = state.scores.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      winnerId = maxEntry.key;
    }
    await _gameRepo.updateFinalScores(state.sessionId!, state.scores, winnerId);
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  void _sendStateSnapshot() {
    _sendToDisplay(WsMessage(
      type: WsMessageType.stateSnapshot,
      sessionId: _engine.state.sessionId,
      payload: _engine.state.toJson(),
    ));
  }

  void _sendToDisplay(WsMessage msg) {
    try {
      _displayChannel?.sink.add(msg.toJsonString());
    } catch (_) {}
  }

  void _broadcast(WsMessage msg) {
    _sendToDisplay(msg);
  }

  void _emit(GameState state) {
    _stateController.add(state);
  }

  String get sessionToken => _sessionToken ?? '';

  void dispose() {
    stop();
    _stateController.close();
  }
}
