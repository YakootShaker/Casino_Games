import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/game_constants.dart';
import '../../../core/constants/ws_message_types.dart';
import '../../../features/connection/data/socket_client.dart';
import '../../../features/connection/domain/ws_message.dart';
import '../../../features/game/domain/game_models.dart';
import '../../../features/game/domain/game_state.dart';
import '../../../services/feedback_service.dart';

class PlayerDisplayScreen extends StatefulWidget {
  final String host;
  final int port;
  final String token;
  final List<dynamic> players;

  const PlayerDisplayScreen({
    super.key,
    required this.host,
    required this.port,
    required this.token,
    required this.players,
  });

  @override
  State<PlayerDisplayScreen> createState() => _PlayerDisplayScreenState();
}

class _PlayerDisplayScreenState extends State<PlayerDisplayScreen>
    with TickerProviderStateMixin {
  late final SocketClient _client;
  late final FeedbackService _feedback;

  GameState? _gameState;
  ConnectionStatus _connectionStatus = ConnectionStatus.connecting;

  StreamSubscription? _stateSub;
  StreamSubscription? _statusSub;
  StreamSubscription? _msgSub;

  bool _buzzLocked = false; // Local UI lock to prevent duplicate presses
  int _countdown = 0;
  Timer? _countdownTimer;
  String? _statusMessage;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _feedback = FeedbackService();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _client = SocketClient(
      host: widget.host,
      port: widget.port,
      sessionToken: widget.token,
    );

    _stateSub = _client.stateStream.listen(_onStateUpdate);
    _statusSub = _client.statusStream.listen(_onStatusUpdate);
    _msgSub = _client.messageStream.listen(_onMessage);

    _client.connect();
  }

  void _onStatusUpdate(ConnectionStatus status) {
    if (!mounted) return;
    setState(() {
      _connectionStatus = status;
      _statusMessage = switch (status) {
        ConnectionStatus.connecting => 'Connecting...',
        ConnectionStatus.reconnecting => 'Reconnecting...',
        ConnectionStatus.connected => null,
        ConnectionStatus.disconnected => 'Disconnected',
      };
    });
  }

  void _onStateUpdate(GameState state) {
    if (!mounted) return;
    setState(() {
      _gameState = state;
    });

    // Update countdown
    if (state.phase == GamePhase.answering && state.activeAttempt != null) {
      _startCountdown(state.activeAttempt!.remaining.inSeconds);
    } else {
      _stopCountdown();
    }

    // Unlock buzz when returning to ready
    if (state.phase == GamePhase.ready) {
      setState(() => _buzzLocked = false);
    }
  }

  void _onMessage(WsMessage msg) {
    switch (msg.type) {
      case WsMessageType.buzzerAccepted:
        _feedback.playBuzzerAccepted();
        _feedback.vibrateShort();
      case WsMessageType.buzzerRejected:
        _feedback.playBuzzerRejected();
      case WsMessageType.correctAnswer:
        _stopCountdown();
        _feedback.playCorrectAnswer();
        _feedback.vibrateLong();
      case WsMessageType.wrongAnswer:
        _stopCountdown();
        _feedback.playWrongAnswer();
        _feedback.vibrateShort();
      case WsMessageType.timeout:
        _stopCountdown();
        _feedback.playTimeout();
      case WsMessageType.gameFinished:
        _feedback.playGameFinished();
      default:
        break;
    }
  }

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    setState(() => _countdown = seconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _countdown = (_countdown - 1).clamp(0, kAnswerTimeSeconds);
      });
      if (_countdown <= 3 && _countdown > 0) {
        _feedback.playCountdownWarning();
      }
      if (_countdown <= 0) t.cancel();
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    if (mounted) setState(() => _countdown = 0);
  }

  void _onBuzzerPress(Player player) {
    if (_buzzLocked) return;
    if (_gameState?.phase != GamePhase.ready) return;
    if (_connectionStatus != ConnectionStatus.connected) return;

    setState(() => _buzzLocked = true);
    _client.sendBuzzerPress(player.id);
    _feedback.vibrateShort();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _countdownTimer?.cancel();
    _stateSub?.cancel();
    _statusSub?.cancel();
    _msgSub?.cancel();
    _client.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show connection overlay if not connected
    if (_connectionStatus != ConnectionStatus.connected) {
      return _buildConnectionScreen();
    }

    final state = _gameState;
    if (state == null) {
      return _buildConnectionScreen();
    }

    return switch (state.phase) {
      GamePhase.answering => _buildAnsweringScreen(state),
      GamePhase.correctResult => _buildCorrectResultScreen(state),
      GamePhase.finished => _buildFinishedScreen(state),
      GamePhase.paused => _buildPausedScreen(),
      _ => _buildReadyScreen(state),
    };
  }

  // ── Ready Screen ──────────────────────────────────────────────────────────

  Widget _buildReadyScreen(GameState state) {
    final players = state.players.isNotEmpty
        ? state.players
        : Player.defaults();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: players.map((p) {
            final score = state.scores[p.id] ?? 0;
            return Expanded(
              child: _BuzzerArea(
                player: p,
                score: score,
                locked: _buzzLocked,
                onPress: () => _onBuzzerPress(p),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Answering Screen ──────────────────────────────────────────────────────

  Widget _buildAnsweringScreen(GameState state) {
    final player = state.activePlayer ?? state.players.first;

    return Scaffold(
      body: GestureDetector(
        onTap: () {}, // Absorb all touches
        child: Container(
          color: player.color,
          child: SafeArea(
            child: Stack(
              children: [
                // Main content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.mic_rounded,
                          color: Colors.white70, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        player.name,
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.playerTextColor(player.color),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'HAS THE FLOOR',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 4,
                          color: AppTheme.playerTextColor(player.color)
                              .withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Countdown circle
                      ScaleTransition(
                        scale: _pulseAnim,
                        child: _CountdownCircle(
                          seconds: _countdown,
                          color: player.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Correct Result Screen ─────────────────────────────────────────────────

  Widget _buildCorrectResultScreen(GameState state) {
    final player = state.activePlayer ?? state.players.first;

    return Scaffold(
      body: Container(
        color: player.color,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 80),
                const SizedBox(height: 16),
                Text(
                  'CORRECT!',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.playerTextColor(player.color),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  player.name,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.playerTextColor(player.color)
                        .withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '+1 point',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.playerTextColor(player.color)
                        .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Finished Screen ───────────────────────────────────────────────────────

  Widget _buildFinishedScreen(GameState state) {
    Player? winner;
    int maxScore = -999;
    for (final p in state.players) {
      final s = state.scores[p.id] ?? 0;
      if (s > maxScore) {
        maxScore = s;
        winner = p;
      }
    }

    return Scaffold(
      body: Container(
        color: winner?.color ?? Colors.grey.shade900,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🏆', style: TextStyle(fontSize: 80)),
                const SizedBox(height: 16),
                const Text(
                  'GAME OVER',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                if (winner != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${winner.name} wins!',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                // Scoreboard
                ...state.players.map((p) {
                  final s = state.scores[p.id] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 4, horizontal: 48),
                    child: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                              color: p.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(p.name,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 16)),
                        ),
                        Text(
                          s >= 0 ? '+$s' : '$s',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Paused Screen ─────────────────────────────────────────────────────────

  Widget _buildPausedScreen() {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pause_circle_rounded, size: 80, color: Colors.white54),
            SizedBox(height: 16),
            Text(
              'Game Paused',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Connection Screen ─────────────────────────────────────────────────────

  Widget _buildConnectionScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                _statusMessage ?? 'Connecting...',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.host}:${widget.port}',
                style: const TextStyle(color: Colors.white38, fontSize: 14),
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Buzzer Area Widget ────────────────────────────────────────────────────

class _BuzzerArea extends StatefulWidget {
  final Player player;
  final int score;
  final bool locked;
  final VoidCallback onPress;

  const _BuzzerArea({
    required this.player,
    required this.score,
    required this.locked,
    required this.onPress,
  });

  @override
  State<_BuzzerArea> createState() => _BuzzerAreaState();
}

class _BuzzerAreaState extends State<_BuzzerArea>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.locked ? widget.player.color.withValues(alpha: 0.4) : widget.player.color;
    final textColor = AppTheme.playerTextColor(widget.player.color);

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) {
          if (!widget.locked) {
            _ctrl.forward();
          }
        },
        onTapUp: (_) {
          _ctrl.reverse();
          if (!widget.locked) widget.onPress();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: Container(
          color: color,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.locked
                      ? Icons.lock_rounded
                      : Icons.touch_app_rounded,
                  color: textColor.withValues(alpha: 0.7),
                  size: 36,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.player.name,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.score >= 0 ? '+${widget.score}' : '${widget.score}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Countdown Circle ──────────────────────────────────────────────────────

class _CountdownCircle extends StatelessWidget {
  final int seconds;
  final Color color;

  const _CountdownCircle({required this.seconds, required this.color});

  @override
  Widget build(BuildContext context) {
    final textColor = AppTheme.playerTextColor(color);
    final progress = seconds / kAnswerTimeSeconds;
    final isWarning = seconds <= 3;

    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 10,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation(
              isWarning ? Colors.red : Colors.white,
            ),
          ),
          Text(
            '$seconds',
            style: TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.w900,
              color: isWarning ? Colors.red : textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// Helper for text contrast
class AppTheme {
  AppTheme._();
  static Color playerTextColor(Color bg) {
    return bg.computeLuminance() > 0.3 ? Colors.black87 : Colors.white;
  }
}
