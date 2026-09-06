import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_medicine_cabinet/screens/alarm_ring_screen.dart';
import 'package:smart_medicine_cabinet/services/notification_service.dart';

import 'providers/dose_log_provider.dart';
import 'providers/medicine_provider.dart';
import 'providers/reminder_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/app_settings_service.dart';
import 'services/auth_service.dart';
import 'services/reminder_api_service.dart';
import 'utils/app_theme.dart';
import 'utils/constants.dart';

final navigatorKey = GlobalKey<NavigatorState>();

String? _activeAlarmMedicineId;
String? _pendingAlarmPayload;
Timer? _pendingAlarmRetryTimer;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final themeProvider = ThemeProvider();
  await themeProvider.loadThemeMode();

  NotificationService.instance.onAlarmPayload = _onAlarmPayload;
  await NotificationService.instance.init();
  await ReminderApiService().init();

  runApp(SmartMedicineCabinetApp(themeProvider: themeProvider));
}

void _onAlarmPayload(String? payload) {
  if (payload == null || payload.isEmpty) return;
  _pendingAlarmPayload = payload;
  _processPendingAlarmPayload();
}

void _processPendingAlarmPayload() {
  final payload = _pendingAlarmPayload;
  if (payload == null || payload.isEmpty) return;

  final navState = navigatorKey.currentState;
  if (navState == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _processPendingAlarmPayload());
    _pendingAlarmRetryTimer?.cancel();
    _pendingAlarmRetryTimer = Timer(const Duration(milliseconds: 100), () {
      _processPendingAlarmPayload();
    });
    return;
  }

  _pendingAlarmRetryTimer?.cancel();
  _pendingAlarmRetryTimer = null;
  _pendingAlarmPayload = null;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOverlayPermission();
      _processPendingAlarmPayload();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pendingAlarmRetryTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkTimezoneChange();
      _processPendingAlarmPayload();
    }
  }

  Future<void> _checkTimezoneChange() async {
    final changed = await NotificationService.instance.refreshLocalTimezone();
    if (!changed || !mounted) return;

    final navCtx = navigatorKey.currentContext;
    if (navCtx == null || !navCtx.mounted) return;
    await navCtx.read<ReminderProvider>().rescheduleAllForTimezoneChange();
  }

  Future<void> _checkOverlayPermission() async {
    final granted = await NotificationService.instance.hasOverlayPermission();
    if (!mounted) return;

    if (!granted) {
      final navCtx = navigatorKey.currentContext;
      if (navCtx == null || !navCtx.mounted) return;

      await showDialog(
        context: navCtx,
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

    if (mounted) {
      await _checkBatteryOptimizations();
    }
  }

  Future<void> _checkBatteryOptimizations() async {
    final ignoring =
        await NotificationService.instance.hasIgnoreBatteryOptimizations();
    if (ignoring || !mounted) return;

    final navCtx = navigatorKey.currentContext;
    if (navCtx == null || !navCtx.mounted) return;

    showDialog(
      context: navCtx,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Allow alarm to run without battery restrictions'),
        content: const Text(
          'Some phones delay or silently revoke this app\'s permissions '
          'if it\'s treated as "unused" in the background, which can '
          'stop the medicine alarm from showing.\n\n'
          'Please exclude this app from battery optimization, and if '
          'asked, also turn off "Remove permissions if app isn\'t used".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              NotificationService.instance.requestIgnoreBatteryOptimizations();
              NotificationService.instance.requestDisableAutoRevoke();
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
        ChangeNotifierProvider(create: (_) => MedicineProvider()),
        ChangeNotifierProvider(create: (_) => ReminderProvider()),
        ChangeNotifierProvider(create: (_) => DoseLogProvider()),
        ChangeNotifierProvider.value(value: widget.themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return _AuthStateListener(
            child: MaterialApp(
              navigatorKey: navigatorKey,
              title: AppConstants.appName,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeProvider.themeMode,
              home: const _AppGate(),
            ),
          );
        },
      ),
    );
  }
}

/// Routes the user on cold start:
/// - No active Firebase session  → LoginScreen (guest or sign-in)
/// - Active session              → HomeScreen
///
/// This guarantees the login page is always the first screen on a fresh install.
class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user != null) {
      // Returning logged-in user: go straight to home.
      return const HomeScreen();
    }
    // No session: show login. Once signed-in, LoginScreen pushes HomeScreen.
    return const LoginScreen();
  }
}

/// Listens to Firebase auth state changes and reloads / clears all data
/// providers accordingly.
/// - On sign-in  → reload all providers from Firestore (account data).
/// - On sign-out → clear all providers so the guest session starts fresh.
class _AuthStateListener extends StatefulWidget {
  const _AuthStateListener({required this.child});
  final Widget child;

  @override
  State<_AuthStateListener> createState() => _AuthStateListenerState();
}

class _AuthStateListenerState extends State<_AuthStateListener> {
  StreamSubscription<User?>? _authSub;
  String? _previousUid;

  @override
  void initState() {
    super.initState();
    // Trigger initial load once the widget tree is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadProviders();
    });

    _authSub = AuthService.instance.authStateChanges.listen((user) {
      final newUid = user?.uid;
      if (newUid == _previousUid) return; // no change, skip
      _previousUid = newUid;
      if (!mounted) return;

      if (newUid != null) {
        // User logged in — load their cloud data.
        _reloadProviders();
      } else {
        // User logged out — wipe in-memory state for a clean guest session.
        context.read<MedicineProvider>().clear();
        context.read<ReminderProvider>().clear();
        context.read<DoseLogProvider>().clear();
        AppSettingsService.instance.clearLocalCache();
        // Then load local (SQLite) guest data.
        _reloadProviders();
      }
    });
  }

  void _reloadProviders() {
    if (!mounted) return;
    context.read<MedicineProvider>().loadMedicines();
    context.read<ReminderProvider>().loadReminders();
    context.read<DoseLogProvider>().loadLogs();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
