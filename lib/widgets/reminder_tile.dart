import 'package:flutter/material.dart';

import '../models/reminder.dart';
import '../utils/app_theme.dart';

class ReminderTile extends StatelessWidget {
  const ReminderTile({
    super.key,
    required this.reminder,
    required this.onToggle,
    required this.onDelete,
  });

  final Reminder reminder;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  String get _timeLabel {
    final hour = reminder.hour % 12 == 0 ? 12 : reminder.hour % 12;
    final period = reminder.hour >= 12 ? 'PM' : 'AM';
    final minute = reminder.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  String get _frequencyLabel {
    switch (reminder.frequency) {
      case ReminderFrequency.daily:
        return 'Every day';
      case ReminderFrequency.specificDays:
        const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return reminder.daysOfWeek.map((d) => names[d - 1]).join(', ');
      case ReminderFrequency.once:
        return reminder.specificDate != null
            ? 'Once on ${reminder.specificDate!.month}/${reminder.specificDate!.day}'
            : 'Once';
    }
  }

  IconData get _icon {
    switch (reminder.type) {
      case ReminderType.dose:
        return Icons.medication_outlined;
      case ReminderType.refill:
        return Icons.refresh_outlined;
      case ReminderType.expiry:
        return Icons.event_busy_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withOpacity(0.1),
          child: Icon(_icon, color: AppTheme.primary),
        ),
        title: Text(reminder.medicineName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$_timeLabel · $_frequencyLabel'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: reminder.isActive,
              activeColor: AppTheme.primary,
              onChanged: onToggle,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
