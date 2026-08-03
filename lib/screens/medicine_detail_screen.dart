import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/medicine.dart';
import '../models/reminder.dart';
import '../providers/medicine_provider.dart';
import '../providers/reminder_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/reminder_tile.dart';
import 'add_edit_medicine_screen.dart';

class _ReminderPick {
  _ReminderPick({
    required this.time,
    required this.frequency,
    this.customSoundPath,
    this.daysOfWeek = const [],
    this.specificDate,
  });
  final TimeOfDay time;
  final ReminderFrequency frequency;
  final String? customSoundPath;
  final List<int> daysOfWeek;
  final DateTime? specificDate;
}

const _weekdayChipLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _frequencyChipLabel(ReminderFrequency f) {
  switch (f) {
    case ReminderFrequency.daily:
      return 'Daily';
    case ReminderFrequency.specificDays:
      return 'Specific days';
    case ReminderFrequency.once:
      return 'Once';
  }
}

class _PickedSound {
  _PickedSound(this.path, this.label);
  final String path;
  final String label;
}

class MedicineDetailScreen extends StatelessWidget {
  const MedicineDetailScreen({super.key, required this.medicine});

  final Medicine medicine;

  Future<void> _addReminder(BuildContext context, Medicine current) async {
    TimeOfDay selectedTime = TimeOfDay.now();
    String? customSoundPath;
    String? customSoundLabel;
    ReminderFrequency selectedFrequency = ReminderFrequency.daily;
    final Set<int> selectedDays = {}; // 1=Mon ... 7=Sun
    DateTime? selectedDate;

    final result = await showDialog<_ReminderPick>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            bool canProceed() {
              switch (selectedFrequency) {
                case ReminderFrequency.daily:
                  return true;
                case ReminderFrequency.specificDays:
                  return selectedDays.isNotEmpty;
                case ReminderFrequency.once:
                  return selectedDate != null;
              }
            }

            return AlertDialog(
              title: const Text('Choose reminder time'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Repeat',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ReminderFrequency.values.map((f) {
                        return ChoiceChip(
                          label: Text(_frequencyChipLabel(f)),
                          selected: selectedFrequency == f,
                          onSelected: (_) =>
                              setDialogState(() => selectedFrequency = f),
                        );
                      }).toList(),
                    ),
                    if (selectedFrequency ==
                        ReminderFrequency.specificDays) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: List.generate(7, (i) {
                          final day = i + 1; // 1=Mon ... 7=Sun
                          final selected = selectedDays.contains(day);
                          return FilterChip(
                            label: Text(_weekdayChipLabels[i]),
                            selected: selected,
                            onSelected: (v) => setDialogState(() {
                              if (v) {
                                selectedDays.add(day);
                              } else {
                                selectedDays.remove(day);
                              }
                            }),
                          );
                        }),
                      ),
                    ],
                    if (selectedFrequency == ReminderFrequency.once) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                        icon:
                            const Icon(Icons.calendar_today_outlined, size: 18),
                        label: Text(
                          selectedDate == null
                              ? 'Pick date'
                              : DateFormat('MMMM d, yyyy')
                                  .format(selectedDate!),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await _pickCustomSound(ctx);
                        if (picked != null) {
                          setDialogState(() {
                            customSoundPath = picked.path;
                            customSoundLabel = picked.label;
                          });
                        }
                      },
                      icon: const Icon(Icons.music_note_outlined, size: 18),
                      label: Text(
                        customSoundLabel ?? 'Use custom ringtone (optional)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (customSoundPath != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setDialogState(() {
                            customSoundPath = null;
                            customSoundLabel = null;
                          }),
                          child: const Text('Use default sound instead'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: !canProceed()
                          ? null
                          : () async {
                              final picked = await showTimePicker(
                                context: ctx,
                                initialTime: selectedTime,
                              );
                              if (picked != null && ctx.mounted) {
                                Navigator.of(ctx).pop(_ReminderPick(
                                  time: picked,
                                  frequency: selectedFrequency,
                                  customSoundPath: customSoundPath,
                                  daysOfWeek: selectedDays.toList()..sort(),
                                  specificDate: selectedDate,
                                ));
                              }
                            },
                      child: const Text('Pick time'),
                    ),
                    if (!canProceed())
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          selectedFrequency == ReminderFrequency.specificDays
                              ? 'Select at least one day'
                              : 'Pick a date first',
                          style: const TextStyle(
                              color: AppTheme.danger, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || !context.mounted) return;

    try {
      await context.read<ReminderProvider>().addReminder(
            medicineId: current.id,
            medicineName: current.name,
            type: ReminderType.dose,
            frequency: result.frequency,
            hour: result.time.hour,
            minute: result.time.minute,
            daysOfWeek: result.daysOfWeek,
            specificDate: result.specificDate,
            customSoundPath: result.customSoundPath,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Reminder added')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add reminder: $e')),
        );
      }
    }
  }

  Future<_PickedSound?> _pickCustomSound(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
      final pickedPath = result?.files.single.path;
      if (pickedPath == null) return null; // user cancelled

      final sourceFile = File(pickedPath);
      final docsDir = await getApplicationDocumentsDirectory();
      final ringtonesDir = Directory('${docsDir.path}/ringtones');
      if (!await ringtonesDir.exists()) {
        await ringtonesDir.create(recursive: true);
      }

      final originalName = result!.files.single.name;
      final ext =
          originalName.contains('.') ? originalName.split('.').last : 'mp3';
      final destPath = '${ringtonesDir.path}/${const Uuid().v4()}.$ext';
      await sourceFile.copy(destPath);

      return _PickedSound(destPath, originalName);
    } catch (e) {
      debugPrint('_pickCustomSound failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not use that audio file')),
        );
      }
      return null;
    }
  }

  Future<void> _confirmDelete(BuildContext context, Medicine current) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete medicine?'),
        content: Text('This will remove ${current.name} and its reminders.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                const Text('Delete', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context
          .read<ReminderProvider>()
          .deleteRemindersForMedicine(current.id);
      await context.read<MedicineProvider>().deleteMedicine(current);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _confirmDeleteReminder(
      BuildContext context, Reminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: const Text(
          'This reminder will be permanently deleted and will no longer '
          'notify you.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                const Text('Delete', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<ReminderProvider>().deleteReminder(reminder);
    }
  }

  Future<void> _confirmTaken(BuildContext context, Medicine current) async {
    if (current.quantity == 1) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Last dose?'),
          content: Text(
            'This is your last ${current.name} in stock. Marking it '
            'taken will bring your quantity to 0.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (context.mounted) {
      await context.read<MedicineProvider>().decrementQuantity(current);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMMM d, yyyy');

    final medicineProvider = context.watch<MedicineProvider>();
    Medicine? current;
    for (final m in medicineProvider.medicines) {
      if (m.id == medicine.id) {
        current = m;
        break;
      }
    }

    if (current == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentMedicine = current;
    final reminders = context
        .watch<ReminderProvider>()
        .remindersForMedicine(currentMedicine.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(currentMedicine.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    AddEditMedicineScreen(existing: currentMedicine),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, currentMedicine),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addReminder(context, currentMedicine),
        icon: const Icon(Icons.alarm_add_outlined),
        label: const Text('Add Reminder'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Dosage',
                      '${currentMedicine.dosage} · ${currentMedicine.form}'),
                  _infoRow('Quantity left', '${currentMedicine.quantity}'),
                  _infoRow('Refill threshold',
                      '${currentMedicine.lowStockThreshold}'),
                  _infoRow('Expiry date',
                      dateFormat.format(currentMedicine.expiryDate)),
                  if (currentMedicine.instructions.isNotEmpty)
                    _infoRow('Instructions', currentMedicine.instructions),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: currentMedicine.quantity <= 0
                      ? null
                      : () => _confirmTaken(context, currentMedicine),
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('I have taken a medicine'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Reminders',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (reminders.isEmpty)
            const Text('No reminders set for this medicine yet.')
          else
            ...reminders.map(
              (r) => ReminderTile(
                reminder: r,
                onToggle: (v) =>
                    context.read<ReminderProvider>().toggleReminder(r, v),
                onDelete: () => _confirmDeleteReminder(context, r),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
