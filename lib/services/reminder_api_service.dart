import '../models/medicine.dart';
import '../models/reminder.dart';
import 'notification_service.dart';

class ReminderApiService {
  final NotificationService _notifications = NotificationService.instance;

  Future<void> init() => _notifications.init();

  Future<void> scheduleReminder(Reminder reminder) async {
    if (!reminder.isActive) {
      await cancelReminder(reminder);
      return;
    }

    final title = _titleFor(reminder);
    final body = reminder.note.isNotEmpty
        ? reminder.note
        : 'Time to take ${reminder.medicineName}';

    final payload = '${reminder.notificationId}|${reminder.medicineId}|'
        '${reminder.medicineName}|${reminder.note}|'
        '${reminder.customSoundPath ?? ''}|0|${reminder.id}';

    switch (reminder.frequency) {
      case ReminderFrequency.daily:
        final dailyPayload =
            '$payload|daily|${reminder.hour}|${reminder.minute}|0';
        await _notifications.scheduleDailyReminder(
          id: reminder.notificationId,
          title: title,
          body: body,
          hour: reminder.hour,
          minute: reminder.minute,
          payload: dailyPayload,
        );
        break;
      case ReminderFrequency.specificDays:
        await _notifications.scheduleOnSpecificDays(
          id: reminder.notificationId,
          title: title,
          body: body,
          hour: reminder.hour,
          minute: reminder.minute,
          daysOfWeek: reminder.daysOfWeek,
          payload: payload,
        );
        break;
      case ReminderFrequency.once:
        if (reminder.specificDate != null) {
          final dt = DateTime(
            reminder.specificDate!.year,
            reminder.specificDate!.month,
            reminder.specificDate!.day,
            reminder.hour,
            reminder.minute,
          );
          final oncePayload =
              '$payload|once|${reminder.hour}|${reminder.minute}|0';
          await _notifications.scheduleOneTime(
            id: reminder.notificationId,
            title: title,
            body: body,
            dateTime: dt,
            payload: oncePayload,
          );
        }
        break;
    }
  }

  Future<void> cancelReminder(Reminder reminder) async {
    await _notifications.cancel(reminder.notificationId);
    await _notifications.cancelEscalations(reminder.notificationId);
  }

  Future<void> scheduleExpiryAlerts(Medicine medicine) async {
    final alertOffsets = [30, 7, 1];
    for (final daysBefore in alertOffsets) {
      final alertDate =
          medicine.expiryDate.subtract(Duration(days: daysBefore));
      if (alertDate.isBefore(DateTime.now())) continue;

      final id = ('expiry_${medicine.id}_$daysBefore').hashCode & 0x7fffffff;
      await _notifications.scheduleOneTime(
        id: id,
        title: 'Expiry Notice: ${medicine.name}',
        body: daysBefore == 1
            ? '${medicine.name} expires tomorrow.'
            : '${medicine.name} expires in $daysBefore days.',
        dateTime: DateTime(
          alertDate.year,
          alertDate.month,
          alertDate.day,
          9,
          0,
        ),
      );
    }
  }

  Future<void> cancelExpiryAlerts(Medicine medicine) async {
    for (final daysBefore in [30, 7, 1]) {
      final id = ('expiry_${medicine.id}_$daysBefore').hashCode & 0x7fffffff;
      await _notifications.cancel(id);
    }
  }

  Future<void> triggerRefillReminder(Medicine medicine) async {
    final id = ('refill_${medicine.id}').hashCode & 0x7fffffff;
    await _notifications.scheduleOneTime(
      id: id,
      title: 'Refill Reminder: ${medicine.name}',
      body:
          'Only ${medicine.quantity} left. Consider refilling your prescription.',
      dateTime: DateTime.now().add(const Duration(seconds: 2)),
    );
  }

  String _titleFor(Reminder reminder) {
    switch (reminder.type) {
      case ReminderType.dose:
        return 'Medicine Reminder';
      case ReminderType.refill:
        return 'Refill Reminder';
      case ReminderType.expiry:
        return 'Expiry Notice';
    }
  }
}
