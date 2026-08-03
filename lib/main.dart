import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_medicine_cabinet/screens/alarm_ring_screen.dart';
import 'package:smart_medicine_cabinet/services/notification_service.dart';

import 'providers/dose_log_provider.dart';
import 'providers/medicine_provider.dart';
import 'providers/reminder_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'services/reminder_api_service.dart';
import 'utils/app_theme.dart';
import 'utils/constants.dart';

final navigatorKey = GlobalKey<NavigatorState>();

String? _activeAlarmMedicineId;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ReminderApiService().init();

  final themeProvider = ThemeProvider();
  await themeProvider.loadThemeMode();

  NotificationService.instance.onAlarmPayload = _onAlarmPayload;

  runApp(SmartMedicineCabinetApp(themeProvider: themeProvider));
}

void _onAlarmPayload(String? payload) {
  if (payload == null || payload.isEmpty) return;

  final parts = payload.split('|');
  final notificationId = int.tryParse(parts[0]) ?? 0;
  final medicineId = parts.length > 1 ? parts[1] : '';
  final medicineName = parts.length > 2 ? parts[2] : 'Medicine';
  final dosageInfo = parts.length > 3 ? parts[3] : '';
  final customSoundPath =
      parts.length > 4 && parts[4].isNotEmpty ? parts[4] : null;
  final isEscalation = parts.length > 5 && parts[5] == '1';
  final reminderId = parts.length > 6 ? parts[6] : '';

  if (medicineId.isNotEmpty && medicineId == _activeAlarmMedicineId) {
    return;
  }

  void doPush() {
    final navState = navigatorKey.currentState;
    if (navState == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => doPush());
      return;
    }

    _activeAlarmMedicineId = medicineId;

    navState
        .push(
      MaterialPageRoute(
        builder: (_) => AlarmRingScreen(
          notificationId: notificationId,
          medicineId: medicineId,
          medicineName: medicineName,
          dosageInfo: dosageInfo,
          customSoundPath: customSoundPath,
          reminderId: reminderId,
          isEscalation: isEscalation,
        ),
        fullscreenDialog: true,
      ),
    )
        .then((_) {
      if (_activeAlarmMedicineId == medicineId) {
        _activeAlarmMedicineId = null;
      }
    });
  }

  doPush();
}

class SmartMedicineCabinetApp extends StatefulWidget {
  const SmartMedicineCabinetApp({super.key, required this.themeProvider});

  final ThemeProvider themeProvider;

  @override
  State<SmartMedicineCabinetApp> createState() =>
      _SmartMedicineCabinetAppState();
}

class _SmartMedicineCabinetAppState extends State<SmartMedicineCabinetApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkOverlayPermission());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkTimezoneChange();
    }
  }

  Future<void> _checkTimezoneChange() async {
    final changed = await NotificationService.instance.refreshLocalTimezone();
    if (!changed || !mounted) return;

    final context = navigatorKey.currentContext;
    if (context == null) return;
    await context.read<ReminderProvider>().rescheduleAllForTimezoneChange();
  }

  Future<void> _checkOverlayPermission() async {
    final granted = await NotificationService.instance.hasOverlayPermission();
    if (granted || !mounted) return;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Allow alarm to appear over other apps'),
        content: const Text(
          'To make sure your medicine alarm shows up full-screen even '
          'while you\'re using another app, please allow "Display over '
          'other apps" for this app in the next screen.\n\n'
          'Without this, you\'ll still get a notification banner, but '
          'you\'ll need to tap it to open the alarm.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              NotificationService.instance.requestOverlayPermission();
            },
            child: const Text('Allow'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => MedicineProvider()..loadMedicines()),
        ChangeNotifierProvider(
            create: (_) => ReminderProvider()..loadReminders()),
        ChangeNotifierProvider(create: (_) => DoseLogProvider()..loadLogs()),
        ChangeNotifierProvider.value(value: widget.themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
