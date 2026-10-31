import 'dart:async';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/constants/game_constants.dart';
import '../../../core/constants/ws_message_types.dart';
import '../../../features/game/domain/game_state.dart';
import '../domain/ws_message.dart';

enum ConnectionStatus { disconnected, connecting, connected, reconnecting }

/// Player-display-side WebSocket client with exponential-backoff reconnection.
class SocketClient {
  final String host;
  final int port;
  final String sessionToken;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  bool _disposed = false;
  int _reconnectAttempt = 0;

  ConnectionStatus _status = ConnectionStatus.disconnected;

  final StreamController<GameState> _stateController =
      StreamController<GameState>.broadcast();
  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();
  final StreamController<WsMessage> _messageController =
      StreamController<WsMessage>.broadcast();

  Stream<GameState> get stateStream => _stateController.stream;
  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  Stream<WsMessage> get messageStream => _messageController.stream;
  ConnectionStatus get status => _status;

  SocketClient({
    required this.host,
    required this.port,
    required this.sessionToken,
  });

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> connect() async {
    if (_disposed) return;
    _setStatus(ConnectionStatus.connecting);
    _doConnect();
  }

  void _doConnect() async {
    if (_disposed) return;

    final uri = Uri.parse('ws://$host:$port');

    try {
      _channel?.sink.close();
      _sub?.cancel();

      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;

      _sub = _channel!.stream.listen(
        _onMessage,
        onDone: _onDisconnected,
        onError: (_) => _onDisconnected(),
        cancelOnError: false,
      );

      _reconnectAttempt = 0;
      _setStatus(ConnectionStatus.connected);

      // Send join request
      _send(WsMessage(
        type: WsMessageType.joinRequest,
        payload: {'token': sessionToken},
      ));
    } catch (_) {
      _onDisconnected();
    }
  }

  void _onMessage(dynamic raw) {
    WsMessage msg;
    try {
      msg = WsMessage.fromString(raw as String);
    } catch (_) {
      return;
    }

    _messageController.add(msg);

    // State updates contain a full payload with 'phase'
    if (msg.payload.containsKey('phase')) {
      try {
        final state = GameState.fromSnapshotJson(msg.payload);
        _stateController.add(state);
      } catch (_) {}
    }
  }

  void _onDisconnected() {
    if (_disposed) return;
    _setStatus(ConnectionStatus.reconnecting);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempt++;
    final delayMs = min(
      kInitialReconnectDelayMs * pow(2, _reconnectAttempt - 1).toInt(),
      kMaxReconnectDelaySeconds * 1000,
    );
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), _doConnect);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _setStatus(ConnectionStatus.disconnected);
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _stateController.close();
    _statusController.close();
    _messageController.close();
  }

  // ── Sending ───────────────────────────────────────────────────────────────

  void sendBuzzerPress(String playerId) {
    _send(WsMessage(
      type: WsMessageType.buzzerPress,
      payload: {'playerId': playerId},
    ));
  }

  void _send(WsMessage msg) {
    if (_status != ConnectionStatus.connected) return;
    try {
      _channel?.sink.add(msg.toJsonString());
    } catch (_) {}
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setStatus(ConnectionStatus s) {
    _status = s;
    _statusController.add(s);
  }
}
