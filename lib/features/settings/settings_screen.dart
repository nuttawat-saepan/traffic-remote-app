import 'package:flutter/material.dart';

import 'settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settingsService});

  final SettingsService settingsService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _baudController;
  late final TextEditingController _timeoutController;
  late ProtocolMode _protocolMode;

  @override
  void initState() {
    super.initState();
    final settings = widget.settingsService.settings;
    _baudController = TextEditingController(text: settings.baudRate.toString());
    _timeoutController = TextEditingController(
      text: settings.timeoutSeconds.toString(),
    );
    _protocolMode = settings.protocolMode;
  }

  @override
  void dispose() {
    _baudController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final baudRate = int.tryParse(_baudController.text.trim()) ?? 9600;
    final timeoutSeconds = int.tryParse(_timeoutController.text.trim()) ?? 3;
    await widget.settingsService.save(
      baudRate: baudRate,
      timeoutSeconds: timeoutSeconds,
      protocolMode: _protocolMode,
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settings saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        TextField(
          controller: _baudController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Baud rate',
            helperText: 'Default 9600',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _timeoutController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Timeout seconds',
            helperText: 'Default 3',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<ProtocolMode>(
          segments: const <ButtonSegment<ProtocolMode>>[
            ButtonSegment(
              value: ProtocolMode.hex,
              icon: Icon(Icons.memory),
              label: Text('HEX'),
            ),
            ButtonSegment(
              value: ProtocolMode.text,
              icon: Icon(Icons.text_fields),
              label: Text('Text'),
            ),
          ],
          selected: <ProtocolMode>{_protocolMode},
          onSelectionChanged: (selection) {
            setState(() => _protocolMode = selection.first);
          },
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: const Text('Save Settings'),
        ),
      ],
    );
  }
}
