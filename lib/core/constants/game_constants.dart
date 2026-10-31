// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';

/// Game timing constants
const int kAnswerTimeSeconds = 10;
const int kCorrectResultDisplaySeconds = 2;
const int kCorrectResultDisplayMs = 2000; // 2 seconds
const int kWrongResultDisplayMs = 800;

/// Scoring constants
const int kCorrectScore = 1;
const int kWrongScore = -1;
const int kTimeoutScore = -1;

/// Network constants
const int kDefaultPort = 8765;
const String kProtocolVersion = '1';
const int kMaxReconnectDelaySeconds = 30;
const int kInitialReconnectDelayMs = 500;

/// Players
const int kMaxPlayers = 3;

/// Player colors (ARGB int values)
const int kPlayer1ColorHex = 0xFFE53935; // Red
const int kPlayer2ColorHex = 0xFF1E88E5; // Blue
const int kPlayer3ColorHex = 0xFF43A047; // Green

const int kPlayer1ColorValue = kPlayer1ColorHex;
const int kPlayer2ColorValue = kPlayer2ColorHex;
const int kPlayer3ColorValue = kPlayer3ColorHex;

const Color kPlayer1Color = Color(kPlayer1ColorHex);
const Color kPlayer2Color = Color(kPlayer2ColorHex);
const Color kPlayer3Color = Color(kPlayer3ColorHex);

/// Default player names
const String kPlayer1DefaultName = 'Player 1';
const String kPlayer2DefaultName = 'Player 2';
const String kPlayer3DefaultName = 'Player 3';

/// App and Database
const String kAppName = 'Quiz Buzzer';
const String kDbName = 'quiz_buzzer.db';
const int kDbVersion = 1;
