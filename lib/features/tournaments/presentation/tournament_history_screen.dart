import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_buzzer/features/game/domain/game_models.dart';
import '../../../services/providers.dart';

class TournamentHistoryScreen extends ConsumerStatefulWidget {
  const TournamentHistoryScreen({super.key});

  @override
  ConsumerState<TournamentHistoryScreen> createState() => _TournamentHistoryScreenState();
}

class _TournamentHistoryScreenState extends ConsumerState<TournamentHistoryScreen> {
  List<GameSession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await ref.read(gameRepositoryProvider).getSessionHistory();
    if (mounted) setState(() { _sessions = sessions; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tournament History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_rounded, size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      Text('No games played yet.', style: TextStyle(color: Colors.white38)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sessions.length,
                  itemBuilder: (ctx, i) {
                    final s = _sessions[i];
                    final startedAt = s.startedAt.toLocal();
                    final winner = s.winnerId ?? 'No winner';
                    final status = s.status;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple.shade900,
                          child: const Icon(Icons.emoji_events_rounded, color: Colors.amber),
                        ),
                        title: Text('Game — ${_formatDate(startedAt)}'),
                        subtitle: Text('Winner: $winner • Status: $status'),
                        trailing: Chip(
                          label: Text(status),
                          backgroundColor: status == 'finished'
                              ? Colors.green.shade900
                              : Colors.orange.shade900,
                          labelStyle: const TextStyle(fontSize: 11),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
