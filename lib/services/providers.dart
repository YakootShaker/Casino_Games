import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/game/domain/game_engine.dart';
import '../features/game/domain/game_state.dart';
import '../features/game/data/game_repository.dart';
import '../features/players/data/players_repository.dart';
import '../features/questions/data/questions_repository.dart';
import '../services/database_service.dart';
import '../features/connection/data/local_server.dart';
import '../features/connection/data/socket_client.dart';

// ── Database ──────────────────────────────────────────────────────────────

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

// ── Repositories ─────────────────────────────────────────────────────────

final playersRepositoryProvider = Provider<PlayersRepository>((ref) {
  return PlayersRepository(ref.read(databaseServiceProvider));
});

final questionsRepositoryProvider = Provider<QuestionsRepository>((ref) {
  return QuestionsRepository(ref.read(databaseServiceProvider));
});

final gameRepositoryProvider = Provider<GameRepository>((ref) {
  return GameRepository(ref.read(databaseServiceProvider));
});

// ── Game Engine ──────────────────────────────────────────────────────────

final gameEngineProvider = Provider<GameEngine>((ref) {
  final engine = GameEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

// ── Local Server ─────────────────────────────────────────────────────────

final localServerProvider = Provider<LocalServer>((ref) {
  final engine = ref.read(gameEngineProvider);
  final gameRepo = ref.read(gameRepositoryProvider);
  final server = LocalServer(engine: engine, gameRepo: gameRepo);
  ref.onDispose(server.dispose);
  return server;
});

final gameStateProvider = StreamProvider<GameState>((ref) {
  final server = ref.read(localServerProvider);
  return server.stateStream;
});

// ── Socket Client (player display side) ──────────────────────────────────

final socketClientProvider = Provider.family<SocketClient, (String, int, String)>(
  (ref, args) {
    final client = SocketClient(host: args.$1, port: args.$2, sessionToken: args.$3);
    ref.onDispose(client.dispose);
    return client;
  },
);

// ── Settings ──────────────────────────────────────────────────────────────

class SoundEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  @override
  set state(bool value) => super.state = value;
}

final soundEnabledProvider =
    NotifierProvider<SoundEnabledNotifier, bool>(SoundEnabledNotifier.new);

class VibrationEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  @override
  set state(bool value) => super.state = value;
}

final vibrationEnabledProvider =
    NotifierProvider<VibrationEnabledNotifier, bool>(
        VibrationEnabledNotifier.new);
