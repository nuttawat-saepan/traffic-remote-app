import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:usb_serial/usb_serial.dart';

import 'serial_models.dart';

class SerialService extends ChangeNotifier {
  List<UsbDevice> _devices = <UsbDevice>[];
  UsbDevice? _selectedDevice;
  UsbPort? _port;
  StreamSubscription<Uint8List>? _inputSubscription;
  StreamSubscription<UsbEvent>? _usbEventSubscription;
  SerialConnectionStatus _status = SerialConnectionStatus.disconnected;
  String _statusMessage = 'No USB serial device connected.';
  String _lastSent = '';
  String _lastReceivedText = '';
  String _lastReceivedHex = '';
  bool _isSending = false;
  bool _disposed = false;
  Completer<SerialResponse>? _pendingResponse;
  String? _pendingExpectedResponse;
  final StringBuffer _pendingTextBuffer = StringBuffer();
  final StringBuffer _pendingHexBuffer = StringBuffer();

  SerialService() {
    _usbEventSubscription = UsbSerial.usbEventStream?.listen((event) async {
      await refreshDevices();
      if (event.event == UsbEvent.ACTION_USB_DETACHED) {
        await disconnect(message: 'USB device disconnected.');
      }
    });
  }

  List<UsbDevice> get devices => List.unmodifiable(_devices);
  UsbDevice? get selectedDevice => _selectedDevice;
  SerialConnectionStatus get status => _status;
  String get statusMessage => _statusMessage;
  String get lastSent => _lastSent;
  String get lastReceivedText => _lastReceivedText;
  String get lastReceivedHex => _lastReceivedHex;
  bool get isConnected =>
      _port != null && _status == SerialConnectionStatus.connected;
  bool get isSending => _isSending;

  String get connectedDeviceLabel {
    final device = _selectedDevice;
    if (device == null) {
      return 'No device';
    }
    return _deviceLabel(device);
  }

  Future<void> refreshDevices() async {
    _devices = await UsbSerial.listDevices();
    if (_devices.isEmpty) {
      _selectedDevice = null;
      if (!isConnected) {
        _setStatus(
          SerialConnectionStatus.deviceNotFound,
          'No USB serial device connected.',
        );
      }
    } else {
      _selectedDevice ??= _devices.first;
      if (!_devices.contains(_selectedDevice)) {
        _selectedDevice = _devices.first;
      }
      if (!isConnected) {
        _setStatus(
          SerialConnectionStatus.disconnected,
          'Select a USB device and connect.',
        );
      }
    }
    _notify();
  }

  void selectDevice(UsbDevice? device) {
    _selectedDevice = device;
    _notify();
  }

  Future<void> connect({required int baudRate}) async {
    final device =
        _selectedDevice ?? (_devices.isNotEmpty ? _devices.first : null);
    if (device == null) {
      _setStatus(
        SerialConnectionStatus.deviceNotFound,
        'No USB serial device connected.',
      );
      return;
    }

    await disconnect(message: 'Reconnecting.');
    _selectedDevice = device;

    try {
      final port = await device.create();
      if (port == null) {
        _setStatus(
          SerialConnectionStatus.error,
          'Failed to create USB serial port.',
        );
        return;
      }

      final opened = await port.open();
      if (!opened) {
        _setStatus(
          SerialConnectionStatus.permissionDenied,
          'Permission denied or failed to open port.',
        );
        return;
      }

      // Confirm DTR/RTS requirements with the real LoRa USB serial module.
      await port.setDTR(true);
      await port.setRTS(true);
      await port.setPortParameters(
        baudRate,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      _port = port;
      _inputSubscription = port.inputStream?.listen(
        _handleIncomingBytes,
        onError: (Object error) {
          _completePendingWithError('Serial read error: $error');
          _setStatus(SerialConnectionStatus.error, 'Serial read error: $error');
        },
        onDone: () {
          _completePendingWithError('Serial port closed.');
          unawaited(disconnect(message: 'Serial port closed.'));
        },
      );
      _setStatus(
        SerialConnectionStatus.connected,
        'Connected to ${_deviceLabel(device)}.',
      );
    } catch (error) {
      await disconnect(message: 'Failed to open serial port.');
      _setStatus(
        SerialConnectionStatus.error,
        'Failed to open serial port: $error',
      );
    }
  }

  Future<void> disconnect({String message = 'Disconnected.'}) async {
    await _inputSubscription?.cancel();
    _inputSubscription = null;
    final port = _port;
    _port = null;
    if (port != null) {
      await port.close();
    }
    _completePendingWithError(message);
    if (_status != SerialConnectionStatus.deviceNotFound) {
      _setStatus(SerialConnectionStatus.disconnected, message);
    }
  }

  Future<CommandResult> sendHexCommand({
    required String hexCommand,
    required String expectedResponse,
    required Duration timeout,
  }) async {
    final bytes = _hexToBytes(hexCommand);
    return _sendBytes(
      bytes: bytes,
      sentDisplay: _formatHex(bytes),
      expectedResponse: expectedResponse,
      timeout: timeout,
    );
  }

  Future<CommandResult> sendTextCommand({
    required String textCommand,
    String? expectedResponse,
    required Duration timeout,
  }) async {
    final command = textCommand.endsWith('\r\n')
        ? textCommand
        : '$textCommand\r\n';
    final bytes = Uint8List.fromList(utf8.encode(command));
    return _sendBytes(
      bytes: bytes,
      sentDisplay: textCommand,
      expectedResponse: expectedResponse,
      timeout: timeout,
    );
  }

  Future<CommandResult> _sendBytes({
    required Uint8List bytes,
    required String sentDisplay,
    required String? expectedResponse,
    required Duration timeout,
  }) async {
    final port = _port;
    _lastSent = sentDisplay;
    _lastReceivedText = '';
    _lastReceivedHex = '';

    if (port == null || !isConnected) {
      _notify();
      return CommandResult(
        status: CommandResultStatus.error,
        sentHex: sentDisplay,
        responseText: '',
        responseRawHex: '',
        errorMessage: 'Serial port is not connected.',
      );
    }

    _isSending = true;
    _notify();

    try {
      _pendingResponse = Completer<SerialResponse>();
      _pendingExpectedResponse = expectedResponse;
      _pendingTextBuffer.clear();
      _pendingHexBuffer.clear();
      await port.write(bytes);

      final response = await _pendingResponse!.future.timeout(timeout);
      final normalizedText = response.text.trim();
      final matchesExpected =
          expectedResponse == null ||
          expectedResponse.isEmpty ||
          normalizedText.contains(expectedResponse);
      return CommandResult(
        status: matchesExpected
            ? CommandResultStatus.success
            : CommandResultStatus.unexpected,
        sentHex: sentDisplay,
        responseText: normalizedText,
        responseRawHex: response.rawHex,
      );
    } on TimeoutException {
      final partialText = _pendingTextBuffer.toString().trim();
      final partialHex = _pendingHexBuffer.toString().trim();
      _pendingResponse = null;
      return CommandResult(
        status: CommandResultStatus.timeout,
        sentHex: sentDisplay,
        responseText: partialText.isEmpty
            ? 'No response within ${timeout.inSeconds}s.'
            : partialText,
        responseRawHex: partialHex,
      );
    } catch (error) {
      return CommandResult(
        status: CommandResultStatus.error,
        sentHex: sentDisplay,
        responseText: '',
        responseRawHex: '',
        errorMessage: error.toString(),
      );
    } finally {
      _pendingResponse = null;
      _pendingExpectedResponse = null;
      _pendingTextBuffer.clear();
      _pendingHexBuffer.clear();
      _isSending = false;
      _notify();
    }
  }

  void _handleIncomingBytes(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final rawHex = _formatHex(bytes);
    _lastReceivedText = text.trim();
    _lastReceivedHex = rawHex;
    final pending = _pendingResponse;
    if (pending != null && !pending.isCompleted) {
      _pendingTextBuffer.write(text);
      if (_pendingHexBuffer.isNotEmpty) {
        _pendingHexBuffer.write(' ');
      }
      _pendingHexBuffer.write(rawHex);

      final accumulatedText = _pendingTextBuffer.toString();
      final expected = _pendingExpectedResponse;
      if (expected == null ||
          expected.isEmpty ||
          accumulatedText.contains(expected)) {
        pending.complete(
          SerialResponse(
            text: accumulatedText,
            rawHex: _pendingHexBuffer.toString(),
            bytes: bytes,
          ),
        );
      }
    }
    _notify();
  }

  void _completePendingWithError(String message) {
    final pending = _pendingResponse;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(StateError(message));
    }
    _pendingResponse = null;
  }

  void _setStatus(SerialConnectionStatus status, String message) {
    _status = status;
    _statusMessage = message;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  static Uint8List _hexToBytes(String hex) {
    final cleaned = hex.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (cleaned.length.isOdd) {
      throw FormatException(
        'HEX command must contain an even number of digits.',
        hex,
      );
    }
    final bytes = <int>[];
    for (var index = 0; index < cleaned.length; index += 2) {
      bytes.add(int.parse(cleaned.substring(index, index + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  static String _formatHex(Uint8List bytes) {
    return bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  static String _deviceLabel(UsbDevice device) {
    final productName = device.productName;
    final manufacturerName = device.manufacturerName;
    if (manufacturerName != null && productName != null) {
      return '$manufacturerName $productName';
    }
    return productName ?? manufacturerName ?? 'USB device ${device.deviceId}';
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_usbEventSubscription?.cancel());
    unawaited(disconnect());
    super.dispose();
  }
}
