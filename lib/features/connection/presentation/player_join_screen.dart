import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/router.dart';
import '../../../core/constants/game_constants.dart';

class PlayerJoinScreen extends StatefulWidget {
  const PlayerJoinScreen({super.key});

  @override
  State<PlayerJoinScreen> createState() => _PlayerJoinScreenState();
}

class _PlayerJoinScreenState extends State<PlayerJoinScreen> {
  bool _manualEntry = false;
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '$kDefaultPort');
  final _tokenController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _onQrDetected(BarcodeCapture capture) {
    final raw = capture.barcodes.first.rawValue;
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final host = data['host'] as String?;
      final port = data['port'] as int?;
      final token = data['token'] as String?;

      if (host == null || port == null || token == null) {
        setState(() => _error = 'Invalid QR code format.');
        return;
      }

      _navigateToDisplay(host: host, port: port, token: token);
    } catch (_) {
      setState(() => _error = 'Could not parse QR code.');
    }
  }

  void _connectManually() {
    final host = _hostController.text.trim();
    final portStr = _portController.text.trim();
    final token = _tokenController.text.trim();

    if (host.isEmpty || portStr.isEmpty || token.isEmpty) {
      setState(() => _error = 'All fields are required.');
      return;
    }

    final port = int.tryParse(portStr);
    if (port == null) {
      setState(() => _error = 'Invalid port number.');
      return;
    }

    _navigateToDisplay(host: host, port: port, token: token);
  }

  void _navigateToDisplay({
    required String host,
    required int port,
    required String token,
  }) {
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.playerDisplay,
      arguments: {'host': host, 'port': port, 'token': token, 'players': []},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Game'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _manualEntry = !_manualEntry),
            child: Text(_manualEntry ? 'Scan QR' : 'Manual Entry'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              color: Colors.red.shade900,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.white))),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => setState(() => _error = null),
                  ),
                ],
              ),
            ),

          if (!_manualEntry)
            Expanded(child: _buildScanner())
          else
            Expanded(child: _buildManualEntry()),
        ],
      ),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          onDetect: _onQrDetected,
        ),
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                'Point camera at the QR code on the Judge\'s phone',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualEntry() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Enter connection details shown on the Judge\'s phone:',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: 'IP Address',
              hintText: '192.168.1.100',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.wifi_rounded),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _portController,
            decoration: const InputDecoration(
              labelText: 'Port',
              hintText: '8765',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lan_rounded),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tokenController,
            decoration: const InputDecoration(
              labelText: 'Session Token',
              hintText: 'From the Judge\'s screen',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.key_rounded),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _connectManually,
            icon: const Icon(Icons.connect_without_contact_rounded),
            label: const Text('Connect'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
