import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'features/logs/log_model.dart';
import 'features/pairing/pairing_screen.dart';
import 'features/remote/remote_screen.dart';
import 'features/serial/serial_models.dart';
import 'features/serial/serial_service.dart';
import 'features/settings/settings_service.dart';

enum TopRemoteStatus { ready, sending, success, noResponse }

const appGreen = Color(0xFF00810E);
const appRed = Color(0xFFDC2626);

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
  String? _lastSuccessfulCommandName;
  String? _sendingCommandName;
  int _selectedIndex = 0;
  bool _ready = false;
  Timer? _relativeTimeTimer;

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
      setState(() {
        _ready = true;
        if (!_settingsService.settings.isPaired) {
          _selectedIndex = 1;
        }
      });
    }
  }

  @override
  void dispose() {
    _relativeTimeTimer?.cancel();
    _serialService.dispose();
    super.dispose();
  }

  void _addLog(TrafficLogEntry entry) {
    _startRelativeTimeTimer();
    setState(() {
      _logs.insert(0, entry);
      _latestLog = entry;
      _topStatus = switch (entry.status) {
        final status when status.name == 'success' => TopRemoteStatus.success,
        _ => TopRemoteStatus.noResponse,
      };
      if (_sendingCommandName == entry.action) {
        _sendingCommandName = null;
      }
      if (entry.status == CommandResultStatus.success) {
        _lastSuccessfulCommandName = entry.action;
      }
    });
  }

  void _startCommand(String action) {
    _startRelativeTimeTimer();
    setState(() {
      _latestLog = TrafficLogEntry(
        timestamp: DateTime.now(),
        action: action,
        sentCommand: '',
        receivedText: '',
        receivedRawHex: '',
        status: CommandResultStatus.success,
      );
      _topStatus = TopRemoteStatus.sending;
      _sendingCommandName = action;
    });
  }

  void _startRelativeTimeTimer() {
    _relativeTimeTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _latestLog != null) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Traffic Remote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: appGreen),
        useMaterial3: true,
        fontFamily: GoogleFonts.ibmPlexSansThai().fontFamily,
        fontFamilyFallback: const <String>['Noto Sans Thai', 'Roboto'],
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
        textTheme:
            GoogleFonts.ibmPlexSansThaiTextTheme(
              ThemeData.light().textTheme,
            ).copyWith(
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
                final isConnected = _serialService.isConnected;
                final canUseRemote = _settingsService.settings.isPaired;
                final selectedIndex = _selectedIndex;
                final currentTopStatus = _serialService.isSending
                    ? TopRemoteStatus.sending
                    : _topStatus;
                final pages = <Widget>[
                  RemoteScreen(
                    serialService: _serialService,
                    settings: _settingsService.settings,
                    onLog: _addLog,
                    onCommandStarted: _startCommand,
                    lastSuccessfulCommandName: _lastSuccessfulCommandName,
                    sendingCommandName: _sendingCommandName,
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
                        Expanded(child: pages[selectedIndex]),
                      ],
                    ),
                  ),
                  bottomNavigationBar: _BottomNav(
                    selectedIndex: selectedIndex,
                    canUseRemote: canUseRemote,
                    onSelected: (index) {
                      if (index == 0 && !canUseRemote) {
                        final message = !isConnected
                            ? 'กรุณาเชื่อมต่ออุปกรณ์ก่อนใช้งานรีโมท'
                            : 'กรุณา pair อุปกรณ์ก่อนใช้งานรีโมท';
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(message),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        return;
                      }
                      setState(() => _selectedIndex = index);
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.selectedIndex,
    required this.canUseRemote,
    required this.onSelected,
  });

  final int selectedIndex;
  final bool canUseRemote;
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
              enabled: canUseRemote,
              allowDisabledTap: true,
              onTap: () => onSelected(0),
            ),
            _BottomNavItem(
              icon: Icons.sync,
              selectedIcon: Icons.sync,
              label: 'เชื่อมต่อ',
              selected: selectedIndex == 1,
              enabled: true,
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
    required this.enabled,
    required this.onTap,
    this.allowDisabledTap = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final bool allowDisabledTap;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? const Color(0xFF94A3B8)
        : selected
        ? const Color(0xFF0D4EAE)
        : const Color(0xFF1F2933);

    return Expanded(
      child: InkWell(
        onTap: enabled || allowDisabledTap ? onTap : null,
        child: Column(
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 80,
              height: 5,
              color: selected && enabled
                  ? const Color(0xFF0D4EAE)
                  : Colors.transparent,
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(selected ? selectedIcon : icon, color: color, size: 30),
                  Transform.translate(
                    offset: const Offset(0, -2),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 17,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionHeader extends StatefulWidget {
  const _ConnectionHeader({
    required this.serialService,
    required this.isPaired,
  });

  final SerialService serialService;
  final bool isPaired;

  @override
  State<_ConnectionHeader> createState() => _ConnectionHeaderState();
}

class _ConnectionHeaderState extends State<_ConnectionHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    if (widget.isPaired) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _ConnectionHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPaired && !_pulseController.isAnimating) {
      _pulseController.repeat();
    } else if (!widget.isPaired && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.isPaired;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: connected ? appGreen : appRed,
        border: Border(
          bottom: BorderSide(color: connected ? appGreen : appRed, width: 2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Transform.translate(
            offset: const Offset(0, 2),
            child: _ConnectionDot(
              connected: connected,
              pulseController: _pulseController,
            ),
          ),
          const SizedBox(width: 10),
          Transform.translate(
            offset: const Offset(0, 2),
            child: Text(
              connected ? 'เชื่อมต่อแล้ว' : 'ยังไม่เชื่อมต่อ',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionDot extends StatelessWidget {
  const _ConnectionDot({
    required this.connected,
    required this.pulseController,
  });

  final bool connected;
  final Animation<double> pulseController;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: connected ? Colors.white : const Color(0xFFFFCDD2),
        border: Border.all(color: const Color(0xAAFFFFFF), width: 4),
      ),
    );

    if (!connected) {
      return dot;
    }

    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          FadeTransition(
            opacity: Tween<double>(begin: 0.55, end: 0).animate(
              CurvedAnimation(parent: pulseController, curve: Curves.easeOut),
            ),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.75, end: 1.35).animate(
                CurvedAnimation(parent: pulseController, curve: Curves.easeOut),
              ),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
          ),
          dot,
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
    final isReady = status == TopRemoteStatus.ready;
    final details = entry == null
        ? 'พร้อมส่งคำสั่ง'
        : 'คำสั่ง ${_formatActionLabel(entry.action)}';
    final relativeTime = entry == null
        ? null
        : _formatRelativeTime(DateTime.now().difference(entry.timestamp));

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
              child: isReady
                  ? Text(
                      'พร้อมส่งคำสั่ง',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: visual.foreground,
                        fontSize: 20,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
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
                      ],
                    ),
            ),
            if (relativeTime != null) ...[
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'Operation time',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: visual.foreground,
                      fontSize: 13,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    relativeTime,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: visual.foreground,
                      fontSize: 30,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatActionLabel(String action) {
    final numericAction = int.tryParse(action);
    if (numericAction != null && numericAction >= 1 && numericAction <= 8) {
      return 'โปรแกรม $action';
    }
    return action;
  }

  _StatusVisual _statusVisual(TopRemoteStatus status) {
    switch (status) {
      case TopRemoteStatus.ready:
        return const _StatusVisual(
          label: 'พร้อมส่งคำสั่ง',
          background: Color(0xFFE8F6ED),
          foreground: appGreen,
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
          foreground: appGreen,
          iconBackground: Color(0xFFDFF2E5),
          icon: Icons.check,
        );
      case TopRemoteStatus.noResponse:
        return const _StatusVisual(
          label: 'ยังไม่ตอบกลับ',
          background: Color(0xFFFFE4E6),
          foreground: Color(0xFFB91C1C),
          iconBackground: Color(0xFFFFF1F2),
          icon: Icons.close,
        );
    }
  }

  String _formatRelativeTime(Duration elapsed) {
    if (elapsed.isNegative) {
      return '00:00:00';
    }

    final cappedSeconds = elapsed.inSeconds.clamp(0, 359999);
    final hours = cappedSeconds ~/ 3600;
    final minutes = (cappedSeconds % 3600) ~/ 60;
    final seconds = cappedSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
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
