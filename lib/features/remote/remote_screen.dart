import 'package:flutter/material.dart';

import '../logs/log_model.dart';
import '../serial/serial_service.dart';
import '../settings/settings_service.dart';
import 'command_model.dart';

class RemoteScreen extends StatefulWidget {
  const RemoteScreen({
    super.key,
    required this.serialService,
    required this.settings,
    required this.onLog,
  });

  final SerialService serialService;
  final TrafficSettings settings;
  final ValueChanged<TrafficLogEntry> onLog;

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  Future<void> _sendRemoteCommand(RemoteCommand command) async {
    final result = switch (command.type) {
      RemoteCommandType.hex => await widget.serialService.sendHexCommand(
        hexCommand: command.payload,
        expectedResponse: command.expectedResponse,
        timeout: widget.settings.timeout,
      ),
      RemoteCommandType.text => await widget.serialService.sendTextCommand(
        textCommand: command.payload,
        expectedResponse: command.expectedResponse,
        timeout: widget.settings.timeout,
      ),
    };

    widget.onLog(
      TrafficLogEntry(
        timestamp: DateTime.now(),
        action: command.name,
        sentCommand: result.sentHex,
        receivedText: result.errorMessage ?? result.responseText,
        receivedRawHex: result.responseRawHex,
        status: result.status,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSend =
        widget.serialService.isConnected && !widget.serialService.isSending;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
      child: Column(
        children: <Widget>[
          Expanded(
            child: _ModeButtons(
              enabled: canSend,
              onPressed: _sendRemoteCommand,
            ),
          ),
          const SizedBox(height: 3),
          ..._numberRows(canSend),
        ],
      ),
    );
  }

  List<Widget> _numberRows(bool canSend) {
    final rows = <Widget>[];
    for (var index = 0; index < numberCommands.length; index += 2) {
      rows
        ..add(
          Expanded(
            child: _CommandRow(
              commands: numberCommands.sublist(index, index + 2),
              enabled: canSend,
              onPressed: _sendRemoteCommand,
            ),
          ),
        )
        ..add(const SizedBox(height: 3));
    }
    rows.removeLast();
    return rows;
  }
}

class _ModeButtons extends StatelessWidget {
  const _ModeButtons({required this.enabled, required this.onPressed});

  final bool enabled;
  final ValueChanged<RemoteCommand> onPressed;

  @override
  Widget build(BuildContext context) {
    return _CommandRow(
      commands: modeCommands,
      enabled: enabled,
      accent: const Color(0xFF0753B7),
      isMode: true,
      onPressed: onPressed,
    );
  }
}

class _CommandRow extends StatelessWidget {
  const _CommandRow({
    required this.commands,
    required this.enabled,
    required this.onPressed,
    this.accent = const Color(0xFF111827),
    this.isMode = false,
  });

  final List<RemoteCommand> commands;
  final bool enabled;
  final Color accent;
  final bool isMode;
  final ValueChanged<RemoteCommand> onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (var index = 0; index < commands.length; index++) ...[
          Expanded(
            child: _RemoteButton(
              command: commands[index],
              enabled: enabled,
              accent: accent,
              isMode: isMode,
              onPressed: onPressed,
            ),
          ),
          if (index != commands.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _RemoteButton extends StatelessWidget {
  const _RemoteButton({
    required this.command,
    required this.enabled,
    required this.accent,
    required this.isMode,
    required this.onPressed,
  });

  final RemoteCommand command;
  final bool enabled;
  final Color accent;
  final bool isMode;
  final ValueChanged<RemoteCommand> onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 4,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: enabled ? () => onPressed(command) : null,
        style: FilledButton.styleFrom(
          backgroundColor: isMode
              ? const Color(0xFFD6E3F4)
              : const Color(0xFFF7F8FA),
          disabledBackgroundColor: isMode
              ? const Color(0xFFD7DEE8)
              : const Color(0xFFE8EBEF),
          disabledForegroundColor: const Color(0xFF475569),
          foregroundColor: isMode ? accent : const Color(0xFF050A10),
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          side: BorderSide(
            color: isMode ? const Color(0xFF0753B7) : const Color(0xFFB5BBC3),
            width: isMode ? 2 : 1.5,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            command.name,
            style: TextStyle(
              fontSize: isMode ? 24 : 58,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}
