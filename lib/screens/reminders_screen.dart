import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reminder.dart';
import '../providers/reminder_provider.dart';
import '../widgets/reminder_tile.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReminderProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.reminders.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No reminders yet. Open a medicine\'s detail page to '
                      'add one.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.reminders.length,
                  itemBuilder: (context, index) {
                    final reminder = provider.reminders[index];
                    return ReminderTile(
                      reminder: reminder,
                      onToggle: (v) => context
                          .read<ReminderProvider>()
                          .toggleReminder(reminder, v),
                      onDelete: () => _confirmDelete(context, reminder),
                    );
                  },
                ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Reminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: const Text(
          'This reminder will be permanently deleted and will no longer '
          'notify you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<ReminderProvider>().deleteReminder(reminder);
    }
  }
}
