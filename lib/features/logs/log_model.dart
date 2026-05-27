import '../serial/serial_models.dart';

class TrafficLogEntry {
  const TrafficLogEntry({
    required this.timestamp,
    required this.action,
    required this.sentCommand,
    required this.receivedText,
    required this.receivedRawHex,
    required this.status,
  });

  final DateTime timestamp;
  final String action;
  final String sentCommand;
  final String receivedText;
  final String receivedRawHex;
  final CommandResultStatus status;
}
