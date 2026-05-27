import 'dart:typed_data';

enum SerialConnectionStatus {
  disconnected,
  connected,
  permissionDenied,
  deviceNotFound,
  error,
}

extension SerialConnectionStatusLabel on SerialConnectionStatus {
  String get label {
    switch (this) {
      case SerialConnectionStatus.disconnected:
        return 'Disconnected';
      case SerialConnectionStatus.connected:
        return 'Connected';
      case SerialConnectionStatus.permissionDenied:
        return 'Permission denied';
      case SerialConnectionStatus.deviceNotFound:
        return 'Device not found';
      case SerialConnectionStatus.error:
        return 'Serial error';
    }
  }
}

enum CommandResultStatus { success, timeout, error, unexpected }

extension CommandResultStatusLabel on CommandResultStatus {
  String get label {
    switch (this) {
      case CommandResultStatus.success:
        return 'success';
      case CommandResultStatus.timeout:
        return 'timeout';
      case CommandResultStatus.error:
        return 'error';
      case CommandResultStatus.unexpected:
        return 'unexpected';
    }
  }
}

class SerialResponse {
  const SerialResponse({
    required this.text,
    required this.rawHex,
    required this.bytes,
  });

  final String text;
  final String rawHex;
  final Uint8List bytes;
}

class CommandResult {
  const CommandResult({
    required this.status,
    required this.sentHex,
    required this.responseText,
    required this.responseRawHex,
    this.errorMessage,
  });

  final CommandResultStatus status;
  final String sentHex;
  final String responseText;
  final String responseRawHex;
  final String? errorMessage;

  bool get isSuccess => status == CommandResultStatus.success;
}
