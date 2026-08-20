import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/reminder.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../services/reminder_api_service.dart';

class ReminderProvider extends ChangeNotifier {
  final DatabaseService _localDb = DatabaseService.instance;
  final FirestoreService _firestore = FirestoreService.instance;
  final ReminderApiService _reminderApi = ReminderApiService();
  final _uuid = const Uuid();

  List<Reminder> _reminders = [];
  bool _isLoading = false;

  List<Reminder> get reminders => List.unmodifiable(_reminders);
  bool get isLoading => _isLoading;

  List<Reminder> remindersForMedicine(String medicineId) =>
      _reminders.where((r) => r.medicineId == medicineId).toList();

  /// Returns the current user's UID, or null if the user is a guest.
  String? get _uid => AuthService.instance.currentUser?.uid;

  Future<void> loadReminders() async {
    _isLoading = true;
    notifyListeners();
    await _reminderApi.init();
    final uid = _uid;
    if (uid != null) {
      _reminders = await _firestore.getAllReminders(uid);
    } else {
      _reminders = await _localDb.getAllReminders();
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Clears the in-memory list (called on sign-out so guest sees a clean slate).
  void clear() {
    _reminders = [];
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
    final notificationId = await _localDb.getNextNotificationIdBase();
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

    final uid = _uid;
    if (uid != null) {
      await _firestore.insertReminder(uid, reminder);
    } else {
      await _localDb.insertReminder(reminder);
    }

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

    final uid = _uid;
    if (uid != null) {
      await _firestore.updateReminder(uid, updated);
    } else {
      await _localDb.updateReminder(updated);
    }

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
    final uid = _uid;
    if (uid != null) {
      await _firestore.deleteReminder(uid, reminder.id);
    } else {
      await _localDb.deleteReminder(reminder.id);
    }
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

    final uid = _uid;
    if (uid != null) {
      await _firestore.deleteRemindersForMedicine(uid, medicineId);
    } else {
      for (final reminder in toRemove) {
        await _localDb.deleteReminder(reminder.id);
      }
    }

    for (final reminder in toRemove) {
      try {
        await _reminderApi.cancelReminder(reminder);
      } catch (e) {
        debugPrint('deleteRemindersForMedicine: cancelReminder failed for '
            '${reminder.id}: $e');
      }
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
