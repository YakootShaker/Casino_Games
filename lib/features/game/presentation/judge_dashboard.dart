import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../features/game/domain/game_models.dart';
import '../../../features/game/domain/game_state.dart';
import '../../../services/providers.dart';

class JudgeDashboard extends ConsumerStatefulWidget {
  const JudgeDashboard({super.key});

  @override
  ConsumerState<JudgeDashboard> createState() => _JudgeDashboardState();
}

class _JudgeDashboardState extends ConsumerState<JudgeDashboard> {
  GameState? _gameState;
  StreamSubscription? _sub;
  int _remainingSeconds = 0;
  Timer? _uiTimer;
  bool _evaluating = false; // prevent double-tap

  @override
  void initState() {
    super.initState();
    _subscribeToState();
  }

  void _subscribeToState() {
    final server = ref.read(localServerProvider);
    // Seed with current state
    _gameState = server.currentState;
    _sub = server.stateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _gameState = state;
        _evaluating = false;
      });
      _updateTimer(state);
    });
    _updateTimer(server.currentState);
  }

  void _updateTimer(GameState state) {
    _uiTimer?.cancel();
    if (state.phase == GamePhase.answering && state.activeAttempt != null) {
      _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _remainingSeconds = state.activeAttempt!.remaining.inSeconds;
        });
      });
      _remainingSeconds = state.activeAttempt!.remaining.inSeconds;
    } else {
      _remainingSeconds = 0;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _uiTimer?.cancel();
    super.dispose();
  }

  Future<void> _confirmAction(String title, String message, Future<void> Function() action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed == true) await action();
  }

  @override
  Widget build(BuildContext context) {
    final state = _gameState;
    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Judge Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context, AppRoutes.home, (_) => false),
        ),
        actions: [
          // Connection status
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  state.isDisplayConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  color: state.isDisplayConnected ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  state.isDisplayConnected ? 'Display' : 'No Display',
                  style: TextStyle(
                    fontSize: 12,
                    color: state.isDisplayConnected ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Game phase banner
          _PhaseBanner(phase: state.phase),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Question card
                  _QuestionCard(state: state),
                  const SizedBox(height: 12),

                  // Scores
                  _ScoreBoard(state: state),
                  const SizedBox(height: 12),

                  // Answer evaluation (only in answering phase)
                  if (state.phase == GamePhase.answering) ...[
                    _AnsweringPanel(
                      state: state,
                      remainingSeconds: _remainingSeconds,
                      evaluating: _evaluating,
                      onCorrect: _onCorrect,
                      onWrong: _onWrong,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Controls
                  _ControlsPanel(
                    state: state,
                    onPause: _onPause,
                    onResume: _onResume,
                    onSkip: _onSkip,
                    onEnd: _onEnd,
                    onReset: _onReset,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onCorrect() async {
    if (_evaluating) return;
    setState(() => _evaluating = true);
    await ref.read(localServerProvider).handleCorrectAnswer();
  }

  Future<void> _onWrong() async {
    if (_evaluating) return;
    setState(() => _evaluating = true);
    await ref.read(localServerProvider).handleWrongAnswer();
  }

  Future<void> _onSkip() => _confirmAction(
        'Skip Question',
        'Skip this question? No penalty will be applied.',
        () => ref.read(localServerProvider).handleSkipQuestion(),
      );

  Future<void> _onPause() =>
      ref.read(localServerProvider).handlePause();

  Future<void> _onResume() =>
      ref.read(localServerProvider).handleResume();

  Future<void> _onEnd() => _confirmAction(
        'End Game',
        'End the game now? This cannot be undone.',
        () => ref.read(localServerProvider).handleEndGame(),
      );

  Future<void> _onReset() => _confirmAction(
        'Reset Game',
        'This will reset the current game. Historical records are preserved. Are you sure?',
        () async {
          ref.read(gameEngineProvider).resetGame();
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
                context, AppRoutes.home, (_) => false);
          }
        },
      );
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _PhaseBanner extends StatelessWidget {
  final GamePhase phase;
  const _PhaseBanner({required this.phase});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (phase) {
      GamePhase.ready => ('Ready — Buzzers Open', Colors.green),
      GamePhase.answering => ('Player Answering', Colors.orange),
      GamePhase.correctResult => ('Correct! ✓', Colors.green),
      GamePhase.paused => ('Game Paused', Colors.blue),
      GamePhase.finished => ('Game Finished', Colors.purple),
      GamePhase.lobby => ('Waiting for Display', Colors.blue),
      _ => ('Disconnected', Colors.red),
    };

    return Container(
      color: color.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final GameState state;
  const _QuestionCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final q = state.currentQuestion;
    if (q == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No question loaded.', style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text('Q${state.questionIndex + 1}/${state.questions.length}'),
                  backgroundColor: Colors.blue.shade900,
                  labelStyle: const TextStyle(fontSize: 12),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(q.category),
                  backgroundColor: Colors.purple.shade900,
                  labelStyle: const TextStyle(fontSize: 12),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(q.difficulty),
                  backgroundColor: Colors.teal.shade900,
                  labelStyle: const TextStyle(fontSize: 12),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              q.text,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            if (q.answer != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade900.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade700),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Answer: ${q.answer}',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScoreBoard extends StatelessWidget {
  final GameState state;
  const _ScoreBoard({required this.state});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Scores',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: state.players.map((p) {
                final score = state.scores[p.id] ?? 0;
                final isActive =
                    state.activeAttempt?.playerId == p.id;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? p.color.withValues(alpha: 0.3)
                          : p.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive ? p.color : p.color.withValues(alpha: 0.4),
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: p.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.name,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          score >= 0 ? '+$score' : '$score',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: score >= 0 ? Colors.greenAccent : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnsweringPanel extends StatelessWidget {
  final GameState state;
  final int remainingSeconds;
  final bool evaluating;
  final VoidCallback onCorrect;
  final VoidCallback onWrong;

  const _AnsweringPanel({
    required this.state,
    required this.remainingSeconds,
    required this.evaluating,
    required this.onCorrect,
    required this.onWrong,
  });

  @override
  Widget build(BuildContext context) {
    final player = state.activePlayer;
    if (player == null) return const SizedBox.shrink();

    final isExpired = state.activeAttempt?.isExpired ?? true;
    final canEval = !isExpired && !evaluating;

    return Card(
      color: player.color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: player.color, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '${player.name} is answering',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            // Countdown
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: remainingSeconds <= 3 ? Colors.red : player.color,
                  width: 4,
                ),
              ),
              child: Center(
                child: Text(
                  '$remainingSeconds',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: remainingSeconds <= 3 ? Colors.red : Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canEval ? onCorrect : null,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Correct +1'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canEval ? onWrong : null,
                    icon: const Icon(Icons.cancel_rounded),
                    label: const Text('Wrong -1'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlsPanel extends StatelessWidget {
  final GameState state;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onSkip;
  final VoidCallback onEnd;
  final VoidCallback onReset;

  const _ControlsPanel({
    required this.state,
    required this.onPause,
    required this.onResume,
    required this.onSkip,
    required this.onEnd,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final isAnswering = state.phase == GamePhase.answering;
    final isPaused = state.phase == GamePhase.paused;
    final isFinished = state.phase == GamePhase.finished;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Controls',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),

            if (!isFinished) ...[
              // Skip
              OutlinedButton.icon(
                onPressed: onSkip,
                icon: const Icon(Icons.skip_next_rounded),
                label: const Text('Skip Question'),
              ),
              const SizedBox(height: 8),

              // Pause / Resume
              if (!isPaused && !isAnswering)
                OutlinedButton.icon(
                  onPressed: onPause,
                  icon: const Icon(Icons.pause_rounded),
                  label: const Text('Pause Game'),
                )
              else if (isPaused)
                FilledButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Resume Game'),
                ),
              const SizedBox(height: 8),

              // End
              OutlinedButton.icon(
                onPressed: onEnd,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('End Game'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
              const SizedBox(height: 8),
            ],

            // Reset
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reset / New Game'),
            ),

            if (isFinished) ...[
              const SizedBox(height: 16),
              _FinalResultCard(state: state),
            ],
          ],
        ),
      ),
    );
  }
}

class _FinalResultCard extends StatelessWidget {
  final GameState state;
  const _FinalResultCard({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.scores.isEmpty) return const SizedBox.shrink();

    Player? winner;
    int maxScore = -999;
    for (final p in state.players) {
      final s = state.scores[p.id] ?? 0;
      if (s > maxScore) {
        maxScore = s;
        winner = p;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: winner != null
              ? [
                  winner.color.withValues(alpha: 0.3),
                  winner.color.withValues(alpha: 0.05),
                ]
              : [Colors.grey.shade800, Colors.grey.shade900],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text('🏆 Final Results',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (winner != null)
            Text(
              '${winner.name} wins!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: winner.color,
              ),
            ),
        ],
      ),
    );
  }
}
