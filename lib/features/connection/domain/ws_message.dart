import 'dart:convert';
import 'package:uuid/uuid.dart';

import 'package:quiz_buzzer/core/constants/ws_message_types.dart';
import 'package:quiz_buzzer/core/constants/game_constants.dart';

const _uuid = Uuid();

/// A versioned WebSocket protocol message.
class WsMessage {
  final String type;
  final String protocolVersion;
  final String messageId;
  final String? sessionId;
  final int timestamp; // milliseconds since epoch (UTC)
  final Map<String, dynamic> payload;

  WsMessage({
    required this.type,
    this.protocolVersion = kProtocolVersion,
    String? messageId,
    this.sessionId,
    int? timestamp,
    Map<String, dynamic>? payload,
  })  : messageId = messageId ?? _uuid.v4(),
        timestamp = timestamp ?? DateTime.now().toUtc().millisecondsSinceEpoch,
        payload = payload ?? {};

  factory WsMessage.fromJson(Map<String, dynamic> json) => WsMessage(
        type: json['type'] as String,
        protocolVersion: json['protocolVersion'] as String? ?? kProtocolVersion,
        messageId: json['messageId'] as String? ?? _uuid.v4(),
        sessionId: json['sessionId'] as String?,
        timestamp: json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
        payload: (json['payload'] as Map<String, dynamic>?) ?? {},
      );

  factory WsMessage.fromString(String raw) => WsMessage.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'protocolVersion': protocolVersion,
        'messageId': messageId,
        if (sessionId != null) 'sessionId': sessionId,
        'timestamp': timestamp,
        'payload': payload,
      };

  String toJsonString() => jsonEncode(toJson());

  // ── Factory helpers ───────────────────────────────────────────────────────

  factory WsMessage.error(String msg, {String? sessionId}) => WsMessage(
        type: WsMessageType.error,
        sessionId: sessionId,
        payload: {'message': msg},
      );

  factory WsMessage.ping() => WsMessage(type: WsMessageType.ping);
  factory WsMessage.pong() => WsMessage(type: WsMessageType.pong);
}
