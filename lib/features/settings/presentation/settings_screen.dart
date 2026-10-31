import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _sound = true;
  bool _vibration = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = ref.read(databaseServiceProvider);
    final soundVal = await db.getSetting('sound_enabled');
    final vibVal = await db.getSetting('vibration_enabled');
    if (mounted) {
      setState(() {
        _sound = soundVal != 'false';
        _vibration = vibVal != 'false';
        _loading = false;
      });
    }
  }

  Future<void> _saveSetting(String key, bool value) async {
    final db = ref.read(databaseServiceProvider);
    await db.setSetting(key, value.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const _SectionHeader('Feedback'),
                SwitchListTile(
                  title: const Text('Sound Effects'),
                  subtitle: const Text('Buzzer, correct/wrong, countdown'),
                  value: _sound,
                  onChanged: (v) {
                    setState(() => _sound = v);
                    ref.read(soundEnabledProvider.notifier).state = v;
                    _saveSetting('sound_enabled', v);
                  },
                ),
                SwitchListTile(
                  title: const Text('Vibration'),
                  subtitle: const Text('Haptic feedback on buzzer press'),
                  value: _vibration,
                  onChanged: (v) {
                    setState(() => _vibration = v);
                    ref.read(vibrationEnabledProvider.notifier).state = v;
                    _saveSetting('vibration_enabled', v);
                  },
                ),
                const Divider(),
                const _SectionHeader('About'),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Quiz Buzzer'),
                  subtitle: const Text('Version 1.0.0 — Offline Multiplayer Quiz'),
                ),
                ListTile(
                  leading: const Icon(Icons.security_rounded),
                  title: const Text('Local Network Only'),
                  subtitle: const Text(
                    'This app works on trusted local Wi-Fi only. '
                    'No data is sent to the internet.',
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
