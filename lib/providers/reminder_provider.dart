import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/reminder.dart';
import '../services/database_service.dart';
import '../services/reminder_api_service.dart';

class ReminderProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final ReminderApiService _reminderApi = ReminderApiService();
  final _uuid = const Uuid();

  List<Reminder> _reminders = [];
  bool _isLoading = false;

  List<Reminder> get reminders => List.unmodifiable(_reminders);
  bool get isLoading => _isLoading;

  List<Reminder> remindersForMedicine(String medicineId) =>
      _reminders.where((r) => r.medicineId == medicineId).toList();

  Future<void> loadReminders() async {
    _isLoading = true;
    notifyListeners();
    await _reminderApi.init();
    _reminders = await _db.getAllReminders();
    _isLoading = false;
    notifyListeners();
  }

  Future<Reminder> addReminder({
    required String medicineId,
    required String medicineName,
    ReminderType type = ReminderType.dose,
    ReminderFrequency frequency = ReminderFrequency.daily,
    required int hour,
    required int minute,
    List<int> daysOfWeek = const [],
    DateTime? specificDate,
    String note = '',
    String? customSoundPath,
  }) async {
    final notificationId = await _db.getNextNotificationIdBase();
    final reminder = Reminder(
      id: _uuid.v4(),
      medicineId: medicineId,
      medicineName: medicineName,
      type: type,
      frequency: frequency,
      hour: hour,
      minute: minute,
      daysOfWeek: daysOfWeek,
      specificDate: specificDate,
      note: note,
      notificationId: notificationId,
      customSoundPath: customSoundPath,
    );

    await _db.insertReminder(reminder);
    try {
      await _reminderApi.scheduleReminder(reminder);
    } catch (e) {
      debugPrint('scheduleReminder failed: $e');
    }
    _reminders.add(reminder);
    notifyListeners();
    return reminder;
  }

  Future<void> toggleReminder(Reminder reminder, bool isActive) async {
    final updated = reminder.copyWith(isActive: isActive);
    await _db.updateReminder(updated);
    try {
      if (isActive) {
        await _reminderApi.scheduleReminder(updated);
      } else {
        await _reminderApi.cancelReminder(updated);
      }
    } catch (e) {
      debugPrint('toggleReminder notification update failed: $e');
    }
    _replace(updated);
  }

  Future<void> deleteReminder(Reminder reminder) async {
    await _db.deleteReminder(reminder.id);
    try {
      await _reminderApi.cancelReminder(reminder);
    } catch (e) {
      debugPrint('cancelReminder failed: $e');
    }
    _reminders.removeWhere((r) => r.id == reminder.id);
    notifyListeners();
  }

  Future<void> deleteRemindersForMedicine(String medicineId) async {
    final toRemove =
        _reminders.where((r) => r.medicineId == medicineId).toList();
    if (toRemove.isEmpty) return;

    for (final reminder in toRemove) {
      try {
        await _reminderApi.cancelReminder(reminder);
      } catch (e) {
        debugPrint('deleteRemindersForMedicine: cancelReminder failed for '
            '${reminder.id}: $e');
      }
      await _db.deleteReminder(reminder.id);
    }

    _reminders.removeWhere((r) => r.medicineId == medicineId);
    notifyListeners();
  }

  Future<void> rescheduleAllForTimezoneChange() async {
    for (final reminder in _reminders.where((r) => r.isActive)) {
      try {
        await _reminderApi.cancelReminder(reminder);
        await _reminderApi.scheduleReminder(reminder);
      } catch (e) {
        debugPrint('rescheduleAllForTimezoneChange failed for '
            '${reminder.id}: $e');
      }
    }
  }

  void _replace(Reminder updated) {
    final index = _reminders.indexWhere((r) => r.id == updated.id);
    if (index != -1) {
      _reminders[index] = updated;
    } else {
      _reminders.add(updated);
    }
    notifyListeners();
  }
}
