// lib/screens/alarm_ring_screen.dart
//
// Full-screen "alarm clock" style screen shown when a medicine reminder
// fires. Loops an alarm tone until the user taps Taken or Not Taken.
//
// ADD THIS DEPENDENCY to pubspec.yaml (flutter_tts is no longer needed):
//   audioplayers: ^6.1.0
//
// You will also need a looping alarm sound bundled as an asset, e.g.
//   assets/sounds/alarm_tone.mp3
// registered under `flutter: assets:` in pubspec.yaml.
//
// Playback is explicitly routed through the Android ALARM stream / iOS
// playback category in _startAlarm() below - NOT the audioplayers
// default (media/notification) - so the tone survives Do Not Disturb,
// Silent mode, and a zeroed media volume slider.

import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/dose_log.dart';
import '../providers/dose_log_provider.dart';
import '../providers/medicine_provider.dart';
import '../services/app_settings_service.dart';
import '../services/notification_service.dart';

class AlarmRingScreen extends StatefulWidget {
  final int notificationId;
  final String medicineId;
  final String medicineName;
  final String dosageInfo;
  final String? customSoundPath;
  final String reminderId;
  final bool isEscalation;

  const AlarmRingScreen({
    super.key,
    required this.notificationId,
    required this.medicineId,
    required this.medicineName,
    this.dosageInfo = '',
    this.customSoundPath,
    this.reminderId = '',
    this.isEscalation = false,
  });

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _resolved = false;
  final DateTime _firedAt = DateTime.now();

  EmergencyContact? _emergencyContact;
  static const Duration _autoDismissTimeout = Duration(minutes: 2);
  Timer? _autoDismissTimer;

  static const MethodChannel _alarmChannel =
      MethodChannel('com.example.med_reminder/alarm');

  Future<void> _dismissScreen() async {
    try {
      await _alarmChannel.invokeMethod('dismissAlarmScreen');
    } catch (e) {
      debugPrint('AlarmRingScreen: dismissAlarmScreen failed: $e');
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    _startAlarm();
    _loadEmergencyContact();
    _scheduleEscalationsIfNeeded();
    _autoDismissTimer = Timer(_autoDismissTimeout, _autoDismiss);
  }

  Future<void> _autoDismiss() async {
    if (_resolved) return;
    _resolved = true;
    await _stopAlarm();
    await NotificationService.instance
        .dismissActiveNotification(widget.notificationId);
    await _dismissScreen();
  }

  Future<void> _loadEmergencyContact() async {
    final contact = await AppSettingsService.instance.getEmergencyContact();
    if (mounted) setState(() => _emergencyContact = contact);
  }

  Future<void> _scheduleEscalationsIfNeeded() async {
    if (widget.isEscalation) return;

    final settings = AppSettingsService.instance;
    final enabled = await settings.isEscalationEnabled();
    if (!enabled) return;

    final intervalMinutes = await settings.getEscalationIntervalMinutes();
    final maxCount = await settings.getEscalationMaxCount();
    if (maxCount <= 0) return;

    final payload = '${widget.notificationId}|${widget.medicineId}|'
        '${widget.medicineName}|${widget.dosageInfo}|'
        '${widget.customSoundPath ?? ''}|1|${widget.reminderId}';

    try {
      await NotificationService.instance.scheduleEscalations(
        baseId: widget.notificationId,
        title: 'Medicine Reminder',
        body: widget.dosageInfo.isNotEmpty
            ? 'Still waiting - ${widget.medicineName} · ${widget.dosageInfo}'
            : 'Still waiting - time to take ${widget.medicineName}',
        payload: payload,
        intervalMinutes: intervalMinutes,
        maxCount: maxCount,
      );
    } catch (e) {
      debugPrint('AlarmRingScreen: scheduleEscalations failed: $e');
    }
  }

  Future<void> _logDose(DoseStatus status) async {
    if (!mounted) return;
    try {
      await context.read<DoseLogProvider>().logDose(
            medicineId: widget.medicineId,
            medicineName: widget.medicineName,
            reminderId: widget.reminderId,
            scheduledTime: _firedAt,
            status: status,
          );
    } catch (e) {
      debugPrint('AlarmRingScreen: logDose failed: $e');
    }
  }

  Future<void> _startAlarm() async {
    try {
      await _player.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      ));

      await _player.setReleaseMode(ReleaseMode.loop);

      final customPath = widget.customSoundPath;
      if (customPath != null && await File(customPath).exists()) {
        await _player.play(DeviceFileSource(customPath), volume: 0.8);
      } else {
        if (customPath != null) {
          debugPrint('AlarmRingScreen: custom sound file missing at '
              '$customPath, falling back to default tone.');
        }
        await _player.play(AssetSource('sounds/alarm_tone.mp3'), volume: 0.8);
      }
    } catch (e, st) {
      debugPrint('AlarmRingScreen: alarm tone playback failed: $e\n$st');
    }
  }

  Future<void> _stopAlarm() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('AlarmRingScreen: stopping alarm tone failed: $e');
    }
  }

  Future<void> _onTaken() async {
    if (_resolved) return;
    _resolved = true;
    _autoDismissTimer?.cancel();
    await _stopAlarm();
    await NotificationService.instance.cancelEscalations(widget.notificationId);
    await _logDose(DoseStatus.taken);

    if (mounted) {
      final provider = context.read<MedicineProvider>();
      final matches =
          provider.medicines.where((m) => m.id == widget.medicineId);
      if (matches.isNotEmpty) {
        await provider.decrementQuantity(matches.first);
      } else {
        debugPrint('AlarmRingScreen: medicine ${widget.medicineId} not found, '
            'quantity not decremented.');
      }
    }

    await NotificationService.instance
        .dismissActiveNotification(widget.notificationId);
    await _dismissScreen();
  }

  Future<void> _onNotTaken() async {
    if (_resolved) return;
    _resolved = true;
    _autoDismissTimer?.cancel();
    await _stopAlarm();
    await NotificationService.instance.cancelEscalations(widget.notificationId);
    await _logDose(DoseStatus.missed);

    await NotificationService.instance
        .dismissActiveNotification(widget.notificationId);
    await _dismissScreen();
  }

  Future<void> _onSnooze(int minutes) async {
    if (_resolved) return;
    _resolved = true;
    _autoDismissTimer?.cancel();
    await _stopAlarm();
    await NotificationService.instance.cancelEscalations(widget.notificationId);
    await _logDose(DoseStatus.snoozed);

    await NotificationService.instance
        .dismissActiveNotification(widget.notificationId);

    final payload = '${widget.notificationId}|${widget.medicineId}|'
        '${widget.medicineName}|${widget.dosageInfo}|'
        '${widget.customSoundPath ?? ''}|0|${widget.reminderId}';
    try {
      await NotificationService.instance.scheduleOneTime(
        id: widget.notificationId,
        title: 'Medicine Reminder',
        body: widget.dosageInfo.isNotEmpty
            ? '${widget.medicineName} · ${widget.dosageInfo}'
            : 'Time to take ${widget.medicineName}',
        dateTime: DateTime.now().add(Duration(minutes: minutes)),
        payload: payload,
      );
    } catch (e, st) {
      debugPrint('AlarmRingScreen: snooze scheduling failed: $e\n$st');
    }

    await _dismissScreen();
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF1B1B2F),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),
                const Icon(Icons.alarm, color: Colors.white, size: 72),
                const SizedBox(height: 24),
                Text(
                  'Medicine Reminder',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 18,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.medicineName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.dosageInfo.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.dosageInfo,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 20,
                    ),
                  ),
                ],
                const Spacer(flex: 3),
                _bigButton(
                  label: 'TAKEN',
                  color: const Color(0xFF2ECC71),
                  icon: Icons.check_circle,
                  onTap: _onTaken,
                ),
                const SizedBox(height: 20),
                _bigButton(
                  label: 'NOT TAKEN',
                  color: const Color(0xFFE74C3C),
                  icon: Icons.cancel,
                  onTap: _onNotTaken,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _snoozeButton(
                          label: 'Snooze 5 min', onTap: () => _onSnooze(5)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _snoozeButton(
                          label: 'Snooze 10 min', onTap: () => _onSnooze(10)),
                    ),
                  ],
                ),
                if (_emergencyContact != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emergency_outlined,
                            color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'In case of emergency: ${_emergencyContact!.name} '
                            '· ${_emergencyContact!.phoneNumber}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bigButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 84,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 32),
        label: Text(
          label,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 6,
        ),
      ),
    );
  }

  Widget _snoozeButton({required String label, required VoidCallback onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.snooze, size: 18, color: Colors.white70),
      label: Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.white.withOpacity(0.3)),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
