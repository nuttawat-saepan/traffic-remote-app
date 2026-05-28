import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../logs/log_model.dart';
import '../remote/command_model.dart';
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
  // ignore: unused_field
  _PairResponseSnapshot? _lastPairResponse;

  Future<void> _connectAndPair() async {
    await widget.settingsService.clearPairing();
    if (mounted) {
      setState(() => _lastPairResponse = null);
    }

    if (!widget.serialService.isConnected) {
      await widget.serialService.refreshDevices();
      if (widget.serialService.selectedDevice == null) {
        _logPairingError('No USB serial device connected.');
        return;
      }

      await widget.serialService.connect(baudRate: widget.settings.baudRate);
      if (!widget.serialService.isConnected) {
        _logPairingError(widget.serialService.statusMessage);
        return;
      }
    }

    await _startPairing();
  }

  Future<void> _startPairing() async {
    final pairingMessage = 'PAIR:${widget.settings.appUuid}';
    final textCommand = _loraSendCommand(pairingMessage);
    final result = await widget.serialService.sendTextCommand(
      textCommand: textCommand,
      expectedResponse: '+RCV=',
      timeout: widget.settings.timeout,
    );
    final responseText = result.errorMessage ?? result.responseText;
    final pairResponseText = _filterPairResponseText(responseText);
    final boardId = _extractPairBoardId(
      pairResponseText,
      appUuid: widget.settings.appUuid,
    );
    final pairStatus = boardId == null
        ? CommandResultStatus.unexpected
        : result.status;

    if (boardId != null) {
      await widget.settingsService.setBoardUuid(boardId);
    }

    if (mounted) {
      setState(() {
        _lastPairResponse = _PairResponseSnapshot(
          timestamp: DateTime.now(),
          sentCommand: result.sentHex,
          responseText: pairResponseText,
          responseRawHex: result.responseRawHex,
          boardId: boardId,
          status: pairStatus,
        );
      });
    }

    widget.onLog(
      TrafficLogEntry(
        timestamp: DateTime.now(),
        action: 'Pair',
        sentCommand: result.sentHex,
        receivedText: pairResponseText,
        receivedRawHex: result.responseRawHex,
        status: pairStatus,
      ),
    );
  }

  void _logPairingError(String message) {
    if (mounted) {
      setState(() {
        _lastPairResponse = _PairResponseSnapshot(
          timestamp: DateTime.now(),
          sentCommand: '',
          responseText: message,
          responseRawHex: '',
          boardId: null,
          status: CommandResultStatus.error,
        );
      });
    }

    widget.onLog(
      TrafficLogEntry(
        timestamp: DateTime.now(),
        action: 'Pair',
        sentCommand: '',
        receivedText: message,
        receivedRawHex: '',
        status: CommandResultStatus.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = widget.serialService.isSending;
    /*
    final isReady =
        widget.serialService.isConnected && widget.settings.isPaired;
    final connected = widget.serialService.isConnected;
    final statusTitle = isReady
        ? 'เชื่อมต่อแล้ว'
        : connected
        ? 'กำลังจับคู่'
        : 'ยังไม่เชื่อมต่อ';
    final deviceName = widget.settings.boardUuid == null
        ? 'TR-441'
        : 'TR-${widget.settings.boardUuid!.substring(0, 4).toUpperCase()}';
    final signalText = isReady ? 'สัญญาณดี • พร้อมรับคำสั่ง' : 'รอการจับคู่';
    final buttonLabel = isBusy ? 'กำลังเชื่อมต่อ' : 'เชื่อมต่อใหม่';

    */
    final buttonLabel = isBusy ? 'กำลังเชื่อมต่อ' : 'เชื่อมต่อใหม่';
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          /*
          _PairInfoCard(
            connected: isReady,
            title: statusTitle,
            deviceName: deviceName,
            signalText: signalText,
          ),
          const SizedBox(height: 26),
          */
          SizedBox(
            height: 96,
            child: FilledButton(
              onPressed: isBusy ? null : _connectAndPair,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D4EAE),
                disabledBackgroundColor: const Color(0xFFCBD5E1),
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: const Color(0x99000000),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.sync, size: 42),
                  const SizedBox(width: 10),
                  Transform.translate(
                    offset: const Offset(0, 4),
                    child: Text(
                      buttonLabel,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSansThai(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // const SizedBox(height: 12),
          // _PairResponseCard(snapshot: _lastPairResponse),
          const SizedBox(height: 12),
          const _PairSteps(),
        ],
      ),
    );
  }

  String _loraSendCommand(String message) {
    final length = utf8.encode(message).length;
    return 'AT+SEND=$loraTargetAddress,$length,$message';
  }

  String _filterPairResponseText(String response) {
    final normalized = response.trim();
    if (normalized.isEmpty) {
      return normalized;
    }

    final lines = normalized
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    for (final line in lines) {
      if (line.toUpperCase().contains('PAIR')) {
        return line;
      }
    }

    final pairIndex = normalized.toUpperCase().indexOf('PAIR');
    if (pairIndex == -1) {
      return normalized;
    }

    final startIndex = normalized.lastIndexOf('+RCV=', pairIndex);
    final filtered = normalized.substring(
      startIndex == -1 ? pairIndex : startIndex,
    );
    return filtered.split(RegExp(r'[\r\n]+')).first.trim();
  }

  String? _extractPairBoardId(String response, {required String appUuid}) {
    final uuidPattern = RegExp(
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}',
    );
    for (final match in uuidPattern.allMatches(response)) {
      final uuid = match.group(0);
      if (uuid != null && uuid.toLowerCase() != appUuid.toLowerCase()) {
        return uuid;
      }
    }

    final pairOkPattern = RegExp(r'PAIR_OK:([^,\s\r\n]+)');
    final pairOkMatch = pairOkPattern.firstMatch(response);
    final boardId = pairOkMatch?.group(1)?.trim();
    if (boardId != null &&
        boardId.isNotEmpty &&
        boardId.toLowerCase() != appUuid.toLowerCase()) {
      return boardId;
    }

    return null;
  }
}

class _PairSteps extends StatelessWidget {
  const _PairSteps();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB5BBC3), width: 1.5),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PairStepText('วิธีการเชื่อมต่อ', isTitle: true),
          SizedBox(height: 10),
          _PairStepText('1. กดปุ่มบนกล่อง'),
          SizedBox(height: 8),
          _PairStepText('2. กดปุ่มเชื่อมต่อบนแอป'),
          SizedBox(height: 8),
          _PairStepText('3. รอจนระบบแสดง "เชื่อมต่อแล้ว"'),
        ],
      ),
    );
  }
}

class _PairStepText extends StatelessWidget {
  const _PairStepText(this.text, {this.isTitle = false});

  final String text;
  final bool isTitle;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.black,
        fontSize: isTitle ? 19 : 17,
        fontWeight: isTitle ? FontWeight.w900 : FontWeight.w800,
        letterSpacing: 0,
        height: 1.2,
      ),
    );
  }
}

class _PairResponseSnapshot {
  const _PairResponseSnapshot({
    required this.timestamp,
    required this.sentCommand,
    required this.responseText,
    required this.responseRawHex,
    required this.boardId,
    required this.status,
  });

  final DateTime timestamp;
  final String sentCommand;
  final String responseText;
  final String responseRawHex;
  final String? boardId;
  final CommandResultStatus status;
}

// ignore: unused_element
class _PairResponseCard extends StatelessWidget {
  const _PairResponseCard({required this.snapshot});

  final _PairResponseSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final snapshot = this.snapshot;
    final statusColor = switch (snapshot?.status) {
      CommandResultStatus.success => const Color(0xFF00810E),
      CommandResultStatus.timeout => const Color(0xFF965E00),
      CommandResultStatus.unexpected => const Color(0xFF8A5A00),
      CommandResultStatus.error => const Color(0xFFB3261E),
      null => const Color(0xFF475569),
    };
    final statusLabel = snapshot == null
        ? 'WAITING'
        : snapshot.status.label.toUpperCase();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB5BBC3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Pair Response',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (snapshot == null)
            const Text(
              'ยังไม่มี response จากการ pair',
              style: TextStyle(
                color: Color(0xFF475569),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            )
          else ...[
            _PairResponseLine(
              label: 'Time',
              value: _formatTime(snapshot.timestamp),
            ),
            _PairResponseLine(label: 'TX', value: snapshot.sentCommand),
            _PairResponseLine(
              label: 'RX Text',
              value: snapshot.responseText.isEmpty
                  ? '-'
                  : snapshot.responseText,
            ),
            _PairResponseLine(
              label: 'RX HEX',
              value: snapshot.responseRawHex.isEmpty
                  ? '-'
                  : snapshot.responseRawHex,
            ),
            _PairResponseLine(
              label: 'Board ID',
              value: snapshot.boardId ?? 'ยัง parse Board ID ไม่ได้',
              valueColor: snapshot.boardId == null
                  ? const Color(0xFFB3261E)
                  : const Color(0xFF00810E),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatTime(DateTime timestamp) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(timestamp.hour)}:${two(timestamp.minute)}:${two(timestamp.second)}';
  }
}

class _PairResponseLine extends StatelessWidget {
  const _PairResponseLine({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _PairInfoCard extends StatelessWidget {
  const _PairInfoCard({
    required this.connected,
    required this.title,
    required this.deviceName,
    required this.signalText,
  });

  final bool connected;
  final String title;
  final String deviceName;
  final String signalText;

  @override
  Widget build(BuildContext context) {
    final color = connected ? const Color(0xFF00810E) : const Color(0xFFDC2626);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(26, 26, 20, 26),
            color: connected
                ? const Color(0xFFDDF1E2)
                : const Color(0xFFFFE4E6),
            child: Row(
              children: <Widget>[
                Container(
                  width: 70,
                  height: 70,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: connected
                        ? const Color(0xFFE8F6ED)
                        : const Color(0xFFFFF1F2),
                    border: Border.all(
                      color: color.withValues(alpha: 0.45),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    connected ? Icons.check : Icons.close,
                    color: color,
                    size: 44,
                  ),
                ),
                const SizedBox(width: 22),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Container(
          //   padding: const EdgeInsets.fromLTRB(26, 25, 26, 26),
          //   decoration: const BoxDecoration(
          //     color: Color(0xFFF7F8FA),
          //     border: Border(
          //       top: BorderSide(color: Color(0xFFB5BBC3), width: 1.5),
          //     ),
          //   ),
          //   child: Column(
          //     crossAxisAlignment: CrossAxisAlignment.start,
          //     children: <Widget>[
          //       const Text(
          //         'อุปกรณ์ที่เชื่อมต่อ',
          //         style: TextStyle(
          //           color: Colors.black,
          //           fontSize: 15,
          //           fontWeight: FontWeight.w800,
          //           letterSpacing: 0,
          //         ),
          //       ),
          //       const SizedBox(height: 14),
          //       Text(
          //         deviceName,
          //         style: const TextStyle(
          //           color: Colors.black,
          //           fontSize: 30,
          //           fontWeight: FontWeight.w900,
          //           letterSpacing: 0,
          //           height: 1,
          //         ),
          //       ),
          //       const SizedBox(height: 14),
          //       Text(
          //         signalText,
          //         style: const TextStyle(
          //           color: Color(0xFF111827),
          //           fontSize: 20,
          //           fontWeight: FontWeight.w900,
          //           letterSpacing: 0,
          //           height: 1.1,
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }
}
