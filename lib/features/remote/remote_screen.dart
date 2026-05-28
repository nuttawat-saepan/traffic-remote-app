import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../logs/log_model.dart';
import '../serial/serial_models.dart';
import '../serial/serial_service.dart';
import '../settings/settings_service.dart';
import 'command_model.dart';

class RemoteScreen extends StatefulWidget {
  const RemoteScreen({
    super.key,
    required this.serialService,
    required this.settings,
    required this.onLog,
    required this.onCommandStarted,
    required this.lastSuccessfulCommandName,
    required this.sendingCommandName,
  });

  final SerialService serialService;
  final TrafficSettings settings;
  final ValueChanged<TrafficLogEntry> onLog;
  final ValueChanged<String> onCommandStarted;
  final String? lastSuccessfulCommandName;
  final String? sendingCommandName;

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  Future<void> _sendRemoteCommand(RemoteCommand command) async {
    widget.onCommandStarted(command.name);

    if (!widget.serialService.isConnected) {
      await widget.serialService.refreshDevices();
      if (widget.serialService.selectedDevice == null) {
        _logCommandError(command, 'No USB serial device connected.');
        return;
      }

      await widget.serialService.connect(baudRate: widget.settings.baudRate);
      if (!widget.serialService.isConnected) {
        _logCommandError(command, widget.serialService.statusMessage);
        return;
      }
    }

    final result = switch (command.type) {
      RemoteCommandType.hex => await widget.serialService.sendHexCommand(
        hexCommand: command.payload,
        expectedResponse: command.expectedResponse,
        timeout: widget.settings.timeout,
      ),
      RemoteCommandType.text => await widget.serialService.sendTextCommand(
        textCommand: _loraSendCommand(command.payload),
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

  void _logCommandError(RemoteCommand command, String message) {
    widget.onLog(
      TrafficLogEntry(
        timestamp: DateTime.now(),
        action: command.name,
        sentCommand: '',
        receivedText: message,
        receivedRawHex: '',
        status: CommandResultStatus.error,
      ),
    );
  }

  String _loraSendCommand(String protocol) {
    final payload = 'ID:${widget.settings.appUuid},$protocol';
    final length = utf8.encode(payload).length;
    return 'AT+SEND=$loraTargetAddress,$length,$payload';
  }

  @override
  Widget build(BuildContext context) {
    final canSend = widget.settings.isPaired && !widget.serialService.isSending;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
      child: Column(
        children: <Widget>[
          Expanded(
            child: _ModeButtons(
              enabled: canSend,
              lastSuccessfulCommandName: widget.lastSuccessfulCommandName,
              sendingCommandName: widget.sendingCommandName,
              onPressed: _sendRemoteCommand,
            ),
          ),
          const SizedBox(height: 12),
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
              lastSuccessfulCommandName: widget.lastSuccessfulCommandName,
              sendingCommandName: widget.sendingCommandName,
              onPressed: _sendRemoteCommand,
            ),
          ),
        )
        ..add(const SizedBox(height: 12));
    }
    rows.removeLast();
    return rows;
  }
}

class _ModeButtons extends StatelessWidget {
  const _ModeButtons({
    required this.enabled,
    required this.lastSuccessfulCommandName,
    required this.sendingCommandName,
    required this.onPressed,
  });

  final bool enabled;
  final String? lastSuccessfulCommandName;
  final String? sendingCommandName;
  final ValueChanged<RemoteCommand> onPressed;

  @override
  Widget build(BuildContext context) {
    return _CommandRow(
      commands: modeCommands,
      enabled: enabled,
      lastSuccessfulCommandName: lastSuccessfulCommandName,
      sendingCommandName: sendingCommandName,
      isMode: true,
      onPressed: onPressed,
    );
  }
}

class _CommandRow extends StatelessWidget {
  const _CommandRow({
    required this.commands,
    required this.enabled,
    required this.lastSuccessfulCommandName,
    required this.sendingCommandName,
    required this.onPressed,
    this.isMode = false,
  });

  final List<RemoteCommand> commands;
  final bool enabled;
  final String? lastSuccessfulCommandName;
  final String? sendingCommandName;
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
              sending: commands[index].name == sendingCommandName,
              highlighted: commands[index].name == lastSuccessfulCommandName,
              isMode: isMode,
              onPressed: onPressed,
            ),
          ),
          if (index != commands.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _RemoteButton extends StatelessWidget {
  const _RemoteButton({
    required this.command,
    required this.enabled,
    required this.sending,
    required this.highlighted,
    required this.isMode,
    required this.onPressed,
  });

  final RemoteCommand command;
  final bool enabled;
  final bool sending;
  final bool highlighted;
  final bool isMode;
  final ValueChanged<RemoteCommand> onPressed;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = sending
        ? const Color(0xFFFFE4E6)
        : highlighted
        ? const Color(0xFFE7F0FF)
        : const Color(0xFFF7F8FA);
    final foregroundColor = sending
        ? const Color(0xFFB91C1C)
        : highlighted
        ? const Color(0xFF0D4EAE)
        : Colors.black;
    final borderColor = sending
        ? const Color(0xFFDC2626)
        : highlighted
        ? const Color(0xFF0D4EAE)
        : const Color(0xFFB5BBC3);

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
          backgroundColor: backgroundColor,
          disabledBackgroundColor: sending
              ? const Color(0xFFFFE4E6)
              : const Color(0xFFE8EBEF),
          disabledForegroundColor: sending
              ? const Color(0xFFB91C1C)
              : const Color(0xFF94A3B8),
          foregroundColor: foregroundColor,
          overlayColor: const Color(0xFF00810E),
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          side: BorderSide(
            color: borderColor,
            width: sending || highlighted ? 2 : 1.5,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: Center(
          child: Transform.translate(
            offset: const Offset(0, 4),
            child: Text(
              command.name,
              maxLines: 1,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansThai(
                fontSize: isMode ? 32 : 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
