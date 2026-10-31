import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/router.dart';
import '../../../core/constants/game_constants.dart';
import '../../../features/game/domain/game_models.dart';
import '../../../services/providers.dart';

class JudgeLobbyScreen extends ConsumerStatefulWidget {
  const JudgeLobbyScreen({super.key});

  @override
  ConsumerState<JudgeLobbyScreen> createState() => _JudgeLobbyScreenState();
}

class _JudgeLobbyScreenState extends ConsumerState<JudgeLobbyScreen> {
  String? _localIp;
  bool _serverStarting = false;
  bool _serverRunning = false;
  String? _error;
  late List<Player> _players;
  late List<Question> _questions;
  bool _loading = true;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final playersRepo = ref.read(playersRepositoryProvider);
      final questionsRepo = ref.read(questionsRepositoryProvider);

      _players = await playersRepo.getDefaultPlayers();
      _questions = await questionsRepo.getActiveQuestions();

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _startServer() async {
    setState(() { _serverStarting = true; _error = null; });

    try {
      final server = ref.read(localServerProvider);
      final ip = await server.start();

      // Get real local IP
      final networkInfo = NetworkInfo();
      final wifiIp = await networkInfo.getWifiIP();
      final resolvedIp = wifiIp ?? ip;

      // Create game session
      final gameRepo = ref.read(gameRepositoryProvider);
      final sessionId = await gameRepo.createSession(
        _players,
        _questions,
      );

      // Start the game engine
      final engine = ref.read(gameEngineProvider);
      engine.startGame(
        questions: _questions,
        players: _players,
        sessionId: sessionId,
      );

      setState(() {
        _localIp = resolvedIp;
        _serverRunning = true;
        _serverStarting = false;
      });

      // Listen for display connection
      _stateSub = server.stateStream.listen((state) {
        if (state.isDisplayConnected && mounted) {
          // Navigate to dashboard when display connects
          Navigator.pushReplacementNamed(context, AppRoutes.judgeDashboard);
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _serverStarting = false;
      });
    }
  }

  String _buildQrData() {
    return jsonEncode({
      'host': _localIp,
      'port': kDefaultPort,
      'token': ref.read(localServerProvider).sessionToken,
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Judge Setup'),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward_rounded),
            tooltip: 'Skip to Dashboard',
            onPressed: _serverRunning
                ? () => Navigator.pushReplacementNamed(
                    context, AppRoutes.judgeDashboard)
                : null,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            _ErrorCard(message: _error!),
            const SizedBox(height: 16),
          ],

          // Setup summary
          _SummaryCard(
            playerCount: _players.length,
            questionCount: _questions.length,
          ),
          const SizedBox(height: 16),

          // Player name editor
          _PlayersCard(
            players: _players,
            onChanged: (updated) => setState(() => _players = updated),
          ),
          const SizedBox(height: 16),

          if (!_serverRunning) ...[
            FilledButton.icon(
              onPressed: _serverStarting ? null : _startServer,
              icon: _serverStarting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(_serverStarting ? 'Starting...' : 'Start Game Server'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ] else ...[
            _ServerInfoCard(
              localIp: _localIp!,
              port: kDefaultPort,
              qrData: _buildQrData(),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, AppRoutes.judgeDashboard),
              icon: const Icon(Icons.dashboard_rounded),
              label: const Text('Open Dashboard (without display)'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int playerCount;
  final int questionCount;
  const _SummaryCard(
      {required this.playerCount, required this.questionCount});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _StatItem(
                value: '$playerCount',
                label: 'Players',
                icon: Icons.people_rounded,
                color: Colors.blue,
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _StatItem(
                value: '$questionCount',
                label: 'Questions',
                icon: Icons.quiz_rounded,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _StatItem(
      {required this.value,
      required this.label,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: Colors.white54)),
      ],
    );
  }
}

class _PlayersCard extends StatelessWidget {
  final List<Player> players;
  final ValueChanged<List<Player>> onChanged;
  const _PlayersCard({required this.players, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Player Names',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...players.asMap().entries.map((e) {
              final i = e.key;
              final p = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: p.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: p.name,
                        decoration: InputDecoration(
                          labelText: 'Player ${i + 1}',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          final updated = List<Player>.from(players);
                          updated[i] = p.copyWith(name: val.isEmpty ? 'Player ${i + 1}' : val);
                          onChanged(updated);
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ServerInfoCard extends StatelessWidget {
  final String localIp;
  final int port;
  final String qrData;
  const _ServerInfoCard(
      {required this.localIp, required this.port, required this.qrData});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.wifi_rounded, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Text('Server Active',
                    style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '$localIp:$port',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Scan QR code on the Player Display phone:',
                style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Waiting for player display to connect...',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 8),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade900,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
                child: Text(message,
                    style: const TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }
}
