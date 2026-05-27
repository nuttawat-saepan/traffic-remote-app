import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ProtocolMode { hex, text }

const defaultBaudRate = 115200;

class TrafficSettings {
  const TrafficSettings({
    required this.baudRate,
    required this.timeoutSeconds,
    required this.protocolMode,
    required this.isPaired,
  });

  factory TrafficSettings.defaults() {
    return const TrafficSettings(
      baudRate: defaultBaudRate,
      timeoutSeconds: 3,
      protocolMode: ProtocolMode.hex,
      isPaired: false,
    );
  }

  final int baudRate;
  final int timeoutSeconds;
  final ProtocolMode protocolMode;
  final bool isPaired;

  Duration get timeout => Duration(seconds: timeoutSeconds);

  TrafficSettings copyWith({
    int? baudRate,
    int? timeoutSeconds,
    ProtocolMode? protocolMode,
    bool? isPaired,
  }) {
    return TrafficSettings(
      baudRate: baudRate ?? this.baudRate,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      protocolMode: protocolMode ?? this.protocolMode,
      isPaired: isPaired ?? this.isPaired,
    );
  }
}

class SettingsService extends ChangeNotifier {
  static const _baudRateKey = 'baud_rate';
  static const _timeoutSecondsKey = 'timeout_seconds';
  static const _protocolModeKey = 'protocol_mode';
  static const _pairedKey = 'paired';

  TrafficSettings _settings = TrafficSettings.defaults();

  TrafficSettings get settings => _settings;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final protocolName = prefs.getString(_protocolModeKey);
    _settings = TrafficSettings(
      baudRate: prefs.getInt(_baudRateKey) ?? defaultBaudRate,
      timeoutSeconds: prefs.getInt(_timeoutSecondsKey) ?? 3,
      protocolMode: ProtocolMode.values.firstWhere(
        (mode) => mode.name == protocolName,
        orElse: () => ProtocolMode.hex,
      ),
      isPaired: prefs.getBool(_pairedKey) ?? false,
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

  Future<void> setPaired(bool paired) async {
    await _persist(_settings.copyWith(isPaired: paired));
  }

  Future<void> _persist(TrafficSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_baudRateKey, settings.baudRate);
    await prefs.setInt(_timeoutSecondsKey, settings.timeoutSeconds);
    await prefs.setString(_protocolModeKey, settings.protocolMode.name);
    await prefs.setBool(_pairedKey, settings.isPaired);
    _settings = settings;
    notifyListeners();
  }
}
