import 'package:flutter/material.dart';

import '../logs/log_model.dart';
import '../serial/serial_models.dart';
import '../serial/serial_service.dart';
import '../settings/settings_service.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({
    super.key,
    required this.serialService,
    required this.settings,
    required this.settingsService,
    required this.onLog,
  });

  final SerialService serialService;
  final TrafficSettings settings;
  final SettingsService settingsService;
  final ValueChanged<TrafficLogEntry> onLog;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  Future<void> _connectAndPair() async {
    if (!widget.serialService.isConnected) {
      await widget.serialService.refreshDevices();
      if (widget.serialService.selectedDevice == null) {
        widget.onLog(
          TrafficLogEntry(
            timestamp: DateTime.now(),
            action: 'Connect',
            sentCommand: '',
            receivedText: 'No USB serial device connected.',
            receivedRawHex: '',
            status: CommandResultStatus.error,
          ),
        );
        return;
      }

      await widget.serialService.connect(baudRate: widget.settings.baudRate);
      if (!widget.serialService.isConnected) {
        widget.onLog(
          TrafficLogEntry(
            timestamp: DateTime.now(),
            action: 'Connect',
            sentCommand: '',
            receivedText: widget.serialService.statusMessage,
            receivedRawHex: '',
            status: CommandResultStatus.error,
          ),
        );
        return;
      }
    }

    await _startPairing();
  }

  Future<void> _startPairing() async {
    final result = await widget.serialService.sendTextCommand(
      textCommand: 'PAIR',
      timeout: widget.settings.timeout,
    );

    if (result.status == CommandResultStatus.success ||
        result.status == CommandResultStatus.unexpected) {
      await widget.settingsService.setPaired(true);
    }

    widget.onLog(
      TrafficLogEntry(
        timestamp: DateTime.now(),
        action: 'Start Pairing',
        sentCommand: result.sentHex,
        receivedText: result.errorMessage ?? result.responseText,
        receivedRawHex: result.responseRawHex,
        status: result.status,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = widget.serialService.isSending;
    final isReady =
        widget.serialService.isConnected && widget.settings.isPaired;
    final buttonLabel = isBusy
        ? 'กำลังเชื่อมต่อ'
        : isReady
        ? 'เชื่อมต่อแล้ว'
        : 'เชื่อมต่อ';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: FilledButton.icon(
              onPressed: isBusy ? null : _connectAndPair,
              style: FilledButton.styleFrom(
                backgroundColor: isReady
                    ? const Color(0xFF078215)
                    : const Color(0xFF0F766E),
                disabledBackgroundColor: const Color(0xFFCBD5E1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: Icon(isReady ? Icons.check_circle : Icons.link, size: 58),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontSize: 78,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
