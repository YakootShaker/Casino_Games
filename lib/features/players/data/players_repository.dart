import 'package:quiz_buzzer/services/database_service.dart';
import 'package:quiz_buzzer/features/game/domain/game_models.dart';

/// Repository managing players persistence and default player profiles.
class PlayersRepository {
  final DatabaseService _dbService;

  PlayersRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService.instance;

  Future<List<Player>> getAllPlayers() => _dbService.getAllPlayers();

  Future<Player?> getPlayerById(String id) => _dbService.getPlayer(id);

  Future<void> addPlayer(Player player) => _dbService.insertPlayer(player);

  Future<void> updatePlayer(Player player) => _dbService.updatePlayer(player);

  Future<void> deletePlayer(String id) => _dbService.deletePlayer(id);

  /// Retrieves the 3 default players. If the database has fewer than 3 players,
  /// seeds the default players and returns them.
  Future<List<Player>> getDefaultPlayers() async {
    final existing = await getAllPlayers();
    if (existing.length >= 3) {
      return existing.take(3).toList();
    }

    final defaults = Player.defaults();
    for (final player in defaults) {
      await addPlayer(player);
    }
    return getAllPlayers();
  }
}
