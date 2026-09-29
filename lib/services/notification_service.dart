import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const MethodChannel _alarmChannel =
      MethodChannel('com.example.med_reminder/alarm');

  bool _initialized = false;

  void Function(String? payload)? onAlarmPayload;

  Future<void> init() async {
    if (_initialized) return;

    try {
      tz_data.initializeTimeZones();

      try {
        final deviceTimeZone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(deviceTimeZone));
        debugPrint('NotificationService: resolved timezone = $deviceTimeZone, '
            'tz.local = ${tz.local.name}');
      } catch (e) {
        debugPrint(
            'Could not resolve device timezone, falling back to UTC: $e');
      }

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings =
          InitializationSettings(android: androidInit, iOS: iosInit);

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            _enableAlarmLockScreenBypass();
          }
          onAlarmPayload?.call(payload);
        },
        onDidReceiveBackgroundNotificationResponse: _onBackgroundResponse,
      );

      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidImpl != null) {
        await androidImpl.requestNotificationsPermission();
        try {
          await androidImpl.requestExactAlarmsPermission();
        } catch (e) {
          debugPrint('requestExactAlarmsPermission failed: $e');
        }
      }

      _alarmChannel.setMethodCallHandler((call) async {
        if (call.method == 'onAlarmLaunch') {
          final payload = call.arguments as String?;
          if (payload != null && payload.isNotEmpty) {
            _enableAlarmLockScreenBypass();
            onAlarmPayload?.call(payload);
          }
        }
      });

      // Check if launched by flutter_local_notifications cold start
      try {
        final launchDetails = await _plugin.getNotificationAppLaunchDetails();
        if (launchDetails?.didNotificationLaunchApp ?? false) {
          final payload = launchDetails?.notificationResponse?.payload;
          if (payload != null && payload.isNotEmpty) {
            _enableAlarmLockScreenBypass();
            onAlarmPayload?.call(payload);
          }
        }
      } catch (e) {
        debugPrint('getNotificationAppLaunchDetails failed: $e');
      }

      // Check if launched by native AlarmService cold start
      try {
        final initialPayload =
            await _alarmChannel.invokeMethod<String>('getInitialAlarmPayload');
        if (initialPayload != null && initialPayload.isNotEmpty) {
          _enableAlarmLockScreenBypass();
          onAlarmPayload?.call(initialPayload);
        }
      } catch (e) {
        debugPrint('getInitialAlarmPayload failed: $e');
      }

      _initialized = true;
    } catch (e, st) {
      debugPrint('NotificationService.init failed: $e\n$st');
    }
  }

  Future<bool> refreshLocalTimezone() async {
    try {
      final deviceTimeZone = await FlutterTimezone.getLocalTimezone();
      if (deviceTimeZone == tz.local.name) return false;
      debugPrint('NotificationService: timezone changed from '
          '${tz.local.name} to $deviceTimeZone');
      tz.setLocalLocation(tz.getLocation(deviceTimeZone));
      return true;
    } catch (e) {
      debugPrint('refreshLocalTimezone failed: $e');
      return false;
    }
  }

  Future<bool> hasOverlayPermission() async {
    try {
      final result =
          await _alarmChannel.invokeMethod<bool>('hasOverlayPermission');
      return result ?? false;
    } catch (e) {
      debugPrint('hasOverlayPermission failed: $e');
      return false;
    }
  }

  Future<void> requestOverlayPermission() async {
    try {
      await _alarmChannel.invokeMethod('requestOverlayPermission');
    } catch (e) {
      debugPrint('requestOverlayPermission failed: $e');
    }
  }

  Future<bool> hasIgnoreBatteryOptimizations() async {
    try {
      final result = await _alarmChannel
          .invokeMethod<bool>('hasIgnoreBatteryOptimizations');
      return result ?? false;
    } catch (e) {
      debugPrint('hasIgnoreBatteryOptimizations failed: $e');
      return false;
    }
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _alarmChannel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      debugPrint('requestIgnoreBatteryOptimizations failed: $e');
    }
  }

  Future<void> requestDisableAutoRevoke() async {
    try {
      await _alarmChannel.invokeMethod('requestDisableAutoRevoke');
    } catch (e) {
      debugPrint('requestDisableAutoRevoke failed: $e');
    }
  }

  Future<void> _enableAlarmLockScreenBypass() async {
    try {
      await _alarmChannel.invokeMethod('enableAlarmLockScreenBypass');
    } catch (e) {
      debugPrint('enableAlarmLockScreenBypass failed: $e');
    }
  }

  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    await init();
    try {
      final scheduledDate = _nextInstanceOf(hour, minute);
      debugPrint('NotificationService: scheduling id=$id for '
          '$scheduledDate (now = ${tz.TZDateTime.now(tz.local)}, '
          'tz.local = ${tz.local.name})');
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        _details(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('NotificationService: zonedSchedule call for id=$id '
          'completed without throwing.');

      await _scheduleNativeAlarm(id, scheduledDate, payload);
    } catch (e, st) {
      debugPrint('scheduleDailyReminder failed: $e\n$st');
    }
  }

  Future<void> scheduleOnSpecificDays({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required List<int> daysOfWeek, // 1=Mon ... 7=Sun
    String? payload,
  }) async {
    await init();
    for (final day in daysOfWeek) {
      try {
        final scheduledDate = _nextInstanceOfWeekday(hour, minute, day);
        final dayPayload = payload != null
            ? '$payload|specificDays|$hour|$minute|$day'
            : null;
        await _plugin.zonedSchedule(
          id + day, // unique id per weekday
          title,
          body,
          scheduledDate,
          _details(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: dayPayload,
        );

        await _scheduleNativeAlarm(id + day, scheduledDate, dayPayload);
      } catch (e, st) {
        debugPrint('scheduleOnSpecificDays failed for day $day: $e\n$st');
      }
    }
  }

  Future<void> scheduleOneTime({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
    String? payload,
  }) async {
    await init();
    if (dateTime.isBefore(DateTime.now())) return;

    try {
      final scheduledDate = tz.TZDateTime.from(dateTime, tz.local);
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        _details(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

      await _scheduleNativeAlarm(id, scheduledDate, payload);
    } catch (e, st) {
      debugPrint('scheduleOneTime failed: $e\n$st');
    }
  }

  Future<String?> testNotificationNow() async {
    try {
      await init();
      await _plugin.show(
        999999,
        'Test Notification',
        'If you see this, notifications work.',
        _details(),
      );
      return null;
    } catch (e, st) {
      debugPrint('testNotificationNow failed: $e\n$st');
      return e.toString();
    }
  }

  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
      await _cancelNativeAlarm(id);
      for (var day = 1; day <= 7; day++) {
        await _plugin.cancel(id + day);
        await _cancelNativeAlarm(id + day);
      }
    } catch (e, st) {
      debugPrint('cancel failed: $e\n$st');
    }
  }

  Future<void> dismissActiveNotification(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (e, st) {
      debugPrint('dismissActiveNotification failed for id=$id: $e\n$st');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e, st) {
      debugPrint('cancelAll failed: $e\n$st');
    }
  }

  static const int _escalationIdOffset = 500000;
  Future<void> scheduleEscalations({
    required int baseId,
    required String title,
    required String body,
    required String payload,
    required int intervalMinutes,
    required int maxCount,
  }) async {
    for (var i = 1; i <= maxCount; i++) {
      final escalationId = baseId + _escalationIdOffset + i;
      await scheduleOneTime(
        id: escalationId,
        title: title,
        body: body,
        dateTime: DateTime.now().add(Duration(minutes: intervalMinutes * i)),
        payload: payload,
      );
    }
  }

  Future<void> cancelEscalations(int baseId, {int maxCount = 10}) async {
    for (var i = 1; i <= maxCount; i++) {
      final escalationId = baseId + _escalationIdOffset + i;
      try {
        await _plugin.cancel(escalationId);
      } catch (e) {
        debugPrint('cancelEscalations: plugin cancel failed for '
            '$escalationId: $e');
      }
      await _cancelNativeAlarm(escalationId);
    }
  }

  Future<void> _scheduleNativeAlarm(
    int id,
    tz.TZDateTime scheduledDate,
    String? payload,
  ) async {
    try {
      await _alarmChannel.invokeMethod('scheduleAlarm', {
        'id': id,
        'triggerAtMillis': scheduledDate.millisecondsSinceEpoch,
        'payload': payload ?? '',
      });
    } catch (e, st) {
      debugPrint('_scheduleNativeAlarm failed for id=$id: $e\n$st');
    }
  }

  Future<void> _cancelNativeAlarm(int id) async {
    try {
      await _alarmChannel.invokeMethod('cancelAlarm', {'id': id});
    } catch (e, st) {
      debugPrint('_cancelNativeAlarm failed for id=$id: $e\n$st');
    }
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'medicine_reminders',
        'Medicine Reminders',
        channelDescription:
            'Notifications for dose reminders, refills, and expiry alerts',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        ongoing: false,
        autoCancel: true,
        playSound: false,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextInstanceOfWeekday(int hour, int minute, int weekday) {
    var scheduled = _nextInstanceOf(hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

@pragma('vm:entry-point')
void _onBackgroundResponse(NotificationResponse response) {
  debugPrint('Notification answered in background: ${response.payload}');
}
