# Traffic Remote

Traffic Remote is a Flutter Android POC that turns a Samsung/Android phone into a USB Serial remote controller for a LoRa module.

## Run

```bash
flutter pub get
flutter run -d <android-device-id>
```

Build a debug APK:

```bash
flutter build apk --debug
```

The APK is generated at `build/app/outputs/flutter-apk/app-debug.apk`.

## USB Serial Setup

1. Connect the phone to the USB serial adapter or LoRa module using an OTG cable.
2. Open Traffic Remote.
3. Tap Scan if the device is not listed.
4. Select the USB device and tap Connect.
5. Android should show a USB permission prompt. Allow it.
6. Default serial configuration is `9600 8N1`:
   - baud rate: configurable in Settings
   - data bits: 8
   - stop bits: 1
   - parity: none

The Android USB device filter is in `android/app/src/main/res/xml/device_filter.xml`. Add the exact VID/PID for your LoRa USB serial hardware after testing.

## Commands

The six predefined HEX commands live in:

`lib/features/remote/command_model.dart`

Current commands:

- Command 1: `7B 04 01 C2 D9 7D`, expected `KEY 1 OK`
- Command 2: `7B 04 02 82 D8 7D`, expected `KEY 2 OK`
- Command 3: `7B 04 03 43 18 7D`, expected `KEY 3 OK`
- Command 4: `7B 04 04 02 DA 7D`, expected `KEY 4 OK`
- Command 5: `7B 04 05 C3 1A 7D`, expected `KEY 5 OK`
- Command 6: `7B 04 06 83 1B 7D`, expected `KEY 6 OK`

Placeholder text commands:

- Pairing: `PAIR`
- Find Remote: `FIND`

## App Structure

```text
lib/
  main.dart
  app.dart
  features/
    serial/
      serial_service.dart
      serial_models.dart
    remote/
      remote_screen.dart
      command_model.dart
    logs/
      log_model.dart
      log_panel.dart
    settings/
      settings_screen.dart
      settings_service.dart
    pairing/
      pairing_screen.dart
```

## Real Device Testing Needed

- Confirm the selected USB serial package supports the exact LoRa module chipset.
- Add exact USB vendor/product IDs to `device_filter.xml`.
- Confirm Android permission flow on target Samsung phones.
- Verify serial open/write/read behavior at the required baud rate.
- Confirm whether LoRa responses arrive in one frame or multiple chunks. The current POC completes a command on the first received chunk.
- Replace `PAIR` and `FIND` placeholders when the final hardware protocol is defined.
