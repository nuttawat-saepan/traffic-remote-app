import 'package:flutter/services.dart';

class KioskService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.traffic_remote_app/kiosk',
  );

  static Future<bool> startKiosk() async {
    try {
      await _channel.invokeMethod<void>('startKiosk');
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> stopKiosk() async {
    try {
      await _channel.invokeMethod<void>('stopKiosk');
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
