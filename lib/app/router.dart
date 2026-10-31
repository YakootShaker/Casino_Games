import 'package:flutter/material.dart';
import '../features/connection/presentation/judge_lobby_screen.dart';
import '../features/connection/presentation/player_join_screen.dart';
import '../features/game/presentation/judge_dashboard.dart';
import '../features/game/presentation/player_display_screen.dart';
import '../features/questions/presentation/question_bank_screen.dart';
import '../features/players/presentation/player_management_screen.dart';
import '../features/tournaments/presentation/tournament_history_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const home = '/';
  static const judgeLobby = '/judge/lobby';
  static const judgeDashboard = '/judge/dashboard';
  static const playerJoin = '/player/join';
  static const playerDisplay = '/player/display';
  static const questionBank = '/questions';
  static const playerManagement = '/players';
  static const tournamentHistory = '/history';
  static const settings = '/settings';
}

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.home:
      return _fade(const HomeScreen());
    case AppRoutes.judgeLobby:
      return _fade(const JudgeLobbyScreen());
    case AppRoutes.judgeDashboard:
      return _fade(const JudgeDashboard());
    case AppRoutes.playerJoin:
      return _fade(const PlayerJoinScreen());
    case AppRoutes.playerDisplay:
      final args = settings.arguments as Map<String, dynamic>?;
      return _fade(PlayerDisplayScreen(
        host: args?['host'] as String? ?? '',
        port: args?['port'] as int? ?? 8765,
        token: args?['token'] as String? ?? '',
        players: args?['players'] as List? ?? [],
      ));
    case AppRoutes.questionBank:
      return _fade(const QuestionBankScreen());
    case AppRoutes.playerManagement:
      return _fade(const PlayerManagementScreen());
    case AppRoutes.tournamentHistory:
      return _fade(const TournamentHistoryScreen());
    case AppRoutes.settings:
      return _fade(const SettingsScreen());
    default:
      return _fade(const HomeScreen());
  }
}

MaterialPageRoute<T> _fade<T>(Widget child) =>
    MaterialPageRoute<T>(builder: (_) => child);

// ── Home Screen ───────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Logo / Title
              const Icon(Icons.quiz_rounded, size: 80, color: Color(0xFF1E88E5)),
              const SizedBox(height: 16),
              Text(
                'Quiz Buzzer',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Offline Multiplayer Quiz Game',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white54,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),

              // Judge Mode
              FilledButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.judgeLobby),
                icon: const Icon(Icons.admin_panel_settings_rounded),
                label: const Text('Judge Mode'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 16),

              // Player Display Mode
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.playerJoin),
                icon: const Icon(Icons.people_rounded),
                label: const Text('Player Display'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),

              // Bottom navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavButton(
                    icon: Icons.help_outline_rounded,
                    label: 'Questions',
                    route: AppRoutes.questionBank,
                  ),
                  _NavButton(
                    icon: Icons.people_outline_rounded,
                    label: 'Players',
                    route: AppRoutes.playerManagement,
                  ),
                  _NavButton(
                    icon: Icons.history_rounded,
                    label: 'History',
                    route: AppRoutes.tournamentHistory,
                  ),
                  _NavButton(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    route: AppRoutes.settings,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  const _NavButton(
      {required this.icon, required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
