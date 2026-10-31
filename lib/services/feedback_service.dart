import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

/// Manages sound effects and vibration for the quiz buzzer.
///
/// All feedback methods are fire-and-forget and never block game logic.
class FeedbackService {
  static FeedbackService? _instance;
  final AudioPlayer _player = AudioPlayer();

  bool soundEnabled;
  bool vibrationEnabled;

  FeedbackService._({this.soundEnabled = true, this.vibrationEnabled = true});

  factory FeedbackService({
    bool soundEnabled = true,
    bool vibrationEnabled = true,
  }) {
    _instance ??= FeedbackService._(
      soundEnabled: soundEnabled,
      vibrationEnabled: vibrationEnabled,
    );
    return _instance!;
  }

  // ── Sound effects ─────────────────────────────────────────────────────────

  Future<void> playBuzzerAccepted() async => _play('buzzer_accepted');
  Future<void> playBuzzerRejected() async => _play('buzzer_rejected');
  Future<void> playCorrectAnswer() async => _play('correct_answer');
  Future<void> playWrongAnswer() async => _play('wrong_answer');
  Future<void> playTimeout() async => _play('timeout');
  Future<void> playCountdownWarning() async => _play('countdown_warning');
  Future<void> playGameFinished() async => _play('game_finished');

  Future<void> _play(String name) async {
    if (!soundEnabled) return;
    try {
      // Assets are bundled at assets/audio/<name>.mp3
      // Falls back silently if asset is missing (MVP: no audio assets bundled)
      await _player.play(AssetSource('audio/$name.mp3'));
    } catch (_) {
      // Audio not available — ignore silently
    }
  }

  // ── Vibration ─────────────────────────────────────────────────────────────

  Future<void> vibrateShort() async => _vibrate([100]);
  Future<void> vibrateLong() async => _vibrate([300]);
  Future<void> vibratePattern({List<int>? pattern}) async =>
      _vibrate(pattern ?? [50, 100, 50]);

  Future<void> _vibrate(List<int> pattern) async {
    if (!vibrationEnabled) return;
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (!hasVibrator) return;
      if (pattern.length == 1) {
        await Vibration.vibrate(duration: pattern.first);
      } else {
        await Vibration.vibrate(pattern: pattern);
      }
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _player.dispose();
    _instance = null;
  }
}
