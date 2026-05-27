import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ProtocolMode { hex, text }

const defaultBaudRate = 115200;

class TrafficSettings {
  const TrafficSettings({
    required this.baudRate,
    required this.timeoutSeconds,
    required this.protocolMode,
    required this.appUuid,
    required this.boardUuid,
  });

  factory TrafficSettings.defaults() {
    return const TrafficSettings(
      baudRate: defaultBaudRate,
      timeoutSeconds: 3,
      protocolMode: ProtocolMode.hex,
      appUuid: '',
      boardUuid: null,
    );
  }

  final int baudRate;
  final int timeoutSeconds;
  final ProtocolMode protocolMode;
  final String appUuid;
  final String? boardUuid;

  bool get isPaired => boardUuid != null && boardUuid!.isNotEmpty;
  Duration get timeout => Duration(seconds: timeoutSeconds);

  TrafficSettings copyWith({
    int? baudRate,
    int? timeoutSeconds,
    ProtocolMode? protocolMode,
    String? appUuid,
    Object? boardUuid = _unchanged,
  }) {
    return TrafficSettings(
      baudRate: baudRate ?? this.baudRate,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      protocolMode: protocolMode ?? this.protocolMode,
      appUuid: appUuid ?? this.appUuid,
      boardUuid: boardUuid == _unchanged
          ? this.boardUuid
          : boardUuid as String?,
    );
  }
}

const _unchanged = Object();

class SettingsService extends ChangeNotifier {
  static const _baudRateKey = 'baud_rate';
  static const _timeoutSecondsKey = 'timeout_seconds';
  static const _protocolModeKey = 'protocol_mode';
  static const _appUuidKey = 'app_uuid';
  static const _boardUuidKey = 'board_uuid';
  static const _pairedKey = 'paired';

  TrafficSettings _settings = TrafficSettings.defaults();

  TrafficSettings get settings => _settings;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final protocolName = prefs.getString(_protocolModeKey);
    final appUuid = prefs.getString(_appUuidKey) ?? _generateUuidV4();
    final boardUuid = prefs.getString(_boardUuidKey);

    if (!prefs.containsKey(_appUuidKey)) {
      await prefs.setString(_appUuidKey, appUuid);
    }

    _settings = TrafficSettings(
      baudRate: prefs.getInt(_baudRateKey) ?? defaultBaudRate,
      timeoutSeconds: prefs.getInt(_timeoutSecondsKey) ?? 3,
      protocolMode: ProtocolMode.values.firstWhere(
        (mode) => mode.name == protocolName,
        orElse: () => ProtocolMode.hex,
      ),
      appUuid: appUuid,
      boardUuid: boardUuid,
    );
    notifyListeners();
  }

  Future<void> save({
    required int baudRate,
    required int timeoutSeconds,
    required ProtocolMode protocolMode,
  }) async {
    final next = _settings.copyWith(
      baudRate: baudRate,
      timeoutSeconds: timeoutSeconds,
      protocolMode: protocolMode,
    );
    await _persist(next);
  }

  Future<void> setBoardUuid(String boardUuid) async {
    await _persist(_settings.copyWith(boardUuid: boardUuid));
  }

  Future<void> clearPairing() async {
    await _persist(_settings.copyWith(boardUuid: null));
  }

  Future<void> setPaired(bool paired) async {
    if (!paired) {
      await clearPairing();
    }
  }

  Future<void> _persist(TrafficSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_baudRateKey, settings.baudRate);
    await prefs.setInt(_timeoutSecondsKey, settings.timeoutSeconds);
    await prefs.setString(_protocolModeKey, settings.protocolMode.name);
    await prefs.setString(_appUuidKey, settings.appUuid);
    if (settings.boardUuid == null || settings.boardUuid!.isEmpty) {
      await prefs.remove(_boardUuidKey);
      await prefs.setBool(_pairedKey, false);
    } else {
      await prefs.setString(_boardUuidKey, settings.boardUuid!);
      await prefs.setBool(_pairedKey, true);
    }
    _settings = settings;
    notifyListeners();
  }

  static String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final chars = bytes.map(hex).join();
    return '${chars.substring(0, 8)}-'
        '${chars.substring(8, 12)}-'
        '${chars.substring(12, 16)}-'
        '${chars.substring(16, 20)}-'
        '${chars.substring(20)}';
  }
}
