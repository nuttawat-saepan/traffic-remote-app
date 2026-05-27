import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'features/logs/log_model.dart';
import 'features/pairing/pairing_screen.dart';
import 'features/remote/remote_screen.dart';
import 'features/serial/serial_service.dart';
import 'features/settings/settings_service.dart';

enum TopRemoteStatus { ready, sending, success, noResponse }

class TrafficRemoteApp extends StatefulWidget {
  const TrafficRemoteApp({super.key});

  @override
  State<TrafficRemoteApp> createState() => _TrafficRemoteAppState();
}

class _TrafficRemoteAppState extends State<TrafficRemoteApp> {
  late final SettingsService _settingsService;
  late final SerialService _serialService;
  final List<TrafficLogEntry> _logs = <TrafficLogEntry>[];
  TrafficLogEntry? _latestLog;
  TopRemoteStatus _topStatus = TopRemoteStatus.ready;
  int _selectedIndex = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _settingsService = SettingsService();
    _serialService = SerialService();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _settingsService.load();
    await _serialService.refreshDevices();
    if (mounted) {
      setState(() => _ready = true);
    }
  }

  @override
  void dispose() {
    _serialService.dispose();
    super.dispose();
  }

  void _addLog(TrafficLogEntry entry) {
    setState(() {
      _logs.insert(0, entry);
      _latestLog = entry;
      _topStatus = switch (entry.status) {
        final status when status.name == 'success' => TopRemoteStatus.success,
        _ => TopRemoteStatus.noResponse,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Traffic Remote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF126C59)),
        useMaterial3: true,
        fontFamily: GoogleFonts.chakraPetch().fontFamily,
        fontFamilyFallback: const <String>['Noto Sans Thai', 'Roboto'],
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
        textTheme: GoogleFonts.chakraPetchTextTheme(ThemeData.light().textTheme)
            .copyWith(
              bodyLarge: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                height: 1.2,
                letterSpacing: 0,
              ),
              bodyMedium: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                height: 1.25,
                letterSpacing: 0,
              ),
              titleLarge: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1.1,
                letterSpacing: 0,
              ),
              labelLarge: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: !_ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[
                _serialService,
                _settingsService,
              ]),
              builder: (context, _) {
                final currentTopStatus = _serialService.isSending
                    ? TopRemoteStatus.sending
                    : _topStatus;
                final pages = <Widget>[
                  RemoteScreen(
                    serialService: _serialService,
                    settings: _settingsService.settings,
                    onLog: _addLog,
                  ),
                  PairingScreen(
                    serialService: _serialService,
                    settings: _settingsService.settings,
                    settingsService: _settingsService,
                    onLog: _addLog,
                  ),
                ];

                return Scaffold(
                  body: SafeArea(
                    child: Column(
                      children: <Widget>[
                        _ConnectionHeader(
                          serialService: _serialService,
                          isPaired: _settingsService.settings.isPaired,
                        ),
                        _CommandStatusCard(
                          status: currentTopStatus,
                          entry: _latestLog,
                        ),
                        Expanded(child: pages[_selectedIndex]),
                      ],
                    ),
                  ),
                  bottomNavigationBar: _BottomNav(
                    selectedIndex: _selectedIndex,
                    onSelected: (index) =>
                        setState(() => _selectedIndex = index),
                  ),
                );
              },
            ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 86,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFB5BBC3), width: 1.5)),
        ),
        child: Row(
          children: <Widget>[
            _BottomNavItem(
              icon: Icons.gamepad_outlined,
              selectedIcon: Icons.gamepad,
              label: 'รีโมท',
              selected: selectedIndex == 0,
              onTap: () => onSelected(0),
            ),
            _BottomNavItem(
              icon: Icons.bluetooth,
              selectedIcon: Icons.bluetooth,
              label: 'เชื่อมต่อ',
              selected: selectedIndex == 1,
              onTap: () => onSelected(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF0D4EAE) : const Color(0xFF1F2933);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 80,
              height: 5,
              color: selected ? const Color(0xFF0D4EAE) : Colors.transparent,
            ),
            const SizedBox(height: 18),
            Icon(selected ? selectedIcon : icon, color: color, size: 31),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 17,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionHeader extends StatelessWidget {
  const _ConnectionHeader({
    required this.serialService,
    required this.isPaired,
  });

  final SerialService serialService;
  final bool isPaired;

  @override
  Widget build(BuildContext context) {
    final connected = serialService.isConnected || isPaired;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: const BoxDecoration(
        color: Color(0xFF078215),
        border: Border(bottom: BorderSide(color: Color(0xFF0A6214), width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 23,
            height: 23,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected ? Colors.white : const Color(0xFFFFCDD2),
              border: Border.all(color: const Color(0xAAFFFFFF), width: 4),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            connected ? 'เชื่อมต่อแล้ว' : 'ยังไม่เชื่อมต่อ',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandStatusCard extends StatelessWidget {
  const _CommandStatusCard({required this.status, required this.entry});

  final TopRemoteStatus status;
  final TrafficLogEntry? entry;

  @override
  Widget build(BuildContext context) {
    final visual = _statusVisual(status);
    final entry = this.entry;
    final details = entry == null
        ? 'พร้อมส่งคำสั่ง'
        : 'คำสั่ง ${entry.action} • ${_formatTime(entry.timestamp)}';
    final sentCommand = entry?.sentCommand;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
        decoration: BoxDecoration(
          color: visual.background,
          border: Border.all(color: visual.foreground, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: visual.iconBackground,
                border: Border.all(color: visual.foreground, width: 1.5),
              ),
              child: Icon(visual.icon, color: visual.foreground, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    visual.label,
                    style: TextStyle(
                      color: visual.foreground,
                      fontSize: 20,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: visual.foreground,
                      fontSize: 15,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  if (sentCommand != null && sentCommand.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'TX: $sentCommand',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: visual.foreground,
                        fontSize: 13,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _StatusVisual _statusVisual(TopRemoteStatus status) {
    switch (status) {
      case TopRemoteStatus.ready:
        return const _StatusVisual(
          label: 'พร้อม',
          background: Color(0xFFE8F6ED),
          foreground: Color(0xFF078215),
          iconBackground: Color(0xFFE8F6ED),
          icon: Icons.check,
        );
      case TopRemoteStatus.sending:
        return const _StatusVisual(
          label: 'กำลังส่ง',
          background: Color(0xFFFFF4CC),
          foreground: Color(0xFF9A6500),
          iconBackground: Color(0xFFFFF8DF),
          icon: Icons.sync,
        );
      case TopRemoteStatus.success:
        return const _StatusVisual(
          label: 'สำเร็จ',
          background: Color(0xFFDFF2E5),
          foreground: Color(0xFF078215),
          iconBackground: Color(0xFFDFF2E5),
          icon: Icons.check,
        );
      case TopRemoteStatus.noResponse:
        return const _StatusVisual(
          label: 'ไม่ตอบกลับ',
          background: Color(0xFFFFE4E6),
          foreground: Color(0xFFB91C1C),
          iconBackground: Color(0xFFFFF1F2),
          icon: Icons.close,
        );
    }
  }

  String _formatTime(DateTime timestamp) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(timestamp.hour)}:${twoDigits(timestamp.minute)}:${twoDigits(timestamp.second)}';
  }
}

class _StatusVisual {
  const _StatusVisual({
    required this.label,
    required this.background,
    required this.foreground,
    required this.iconBackground,
    required this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color iconBackground;
  final IconData icon;
}
