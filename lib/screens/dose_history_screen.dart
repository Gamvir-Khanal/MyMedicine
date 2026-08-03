import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/dose_log.dart';
import '../providers/dose_log_provider.dart';
import '../utils/app_theme.dart';

class DoseHistoryScreen extends StatefulWidget {
  const DoseHistoryScreen({super.key});

  @override
  State<DoseHistoryScreen> createState() => _DoseHistoryScreenState();
}

class _DoseHistoryScreenState extends State<DoseHistoryScreen> {
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  Color _colorFor(DoseStatus status) {
    switch (status) {
      case DoseStatus.taken:
        return AppTheme.primary;
      case DoseStatus.missed:
        return AppTheme.danger;
      case DoseStatus.snoozed:
        return AppTheme.warning;
    }
  }

  String _labelFor(DoseStatus status) {
    switch (status) {
      case DoseStatus.taken:
        return 'Taken';
      case DoseStatus.missed:
        return 'Not taken';
      case DoseStatus.snoozed:
        return 'Snoozed';
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      _selectedDay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DoseLogProvider>();
    final statusesByDay = provider.statusesByDayForMonth(_visibleMonth);

    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday - 1;

    final selectedLogs =
        _selectedDay == null ? <DoseLog>[] : provider.logsForDay(_selectedDay!);

    return Scaffold(
      appBar: AppBar(title: const Text('Dose History')),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _changeMonth(-1),
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(_visibleMonth),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _changeMonth(1),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
                      .map((d) => Expanded(
                            child: Center(
                              child: Text(d,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600)),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 4),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                  ),
                  itemCount: leadingBlanks + daysInMonth,
                  itemBuilder: (context, index) {
                    if (index < leadingBlanks) return const SizedBox.shrink();
                    final day = index - leadingBlanks + 1;
                    final date =
                        DateTime(_visibleMonth.year, _visibleMonth.month, day);
                    final statuses = statusesByDay[day] ?? <DoseStatus>{};
                    final isSelected = _selectedDay != null &&
                        _selectedDay!.year == date.year &&
                        _selectedDay!.month == date.month &&
                        _selectedDay!.day == date.day;
                    final isToday = _isSameDay(date, DateTime.now());

                    return GestureDetector(
                      onTap: () => setState(() => _selectedDay = date),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary.withOpacity(0.15)
                              : null,
                          border: isToday
                              ? Border.all(color: AppTheme.primary, width: 1)
                              : null,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('$day', style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: statuses
                                  .map((s) => Container(
                                        width: 5,
                                        height: 5,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 1),
                                        decoration: BoxDecoration(
                                          color: _colorFor(s),
                                          shape: BoxShape.circle,
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                if (_selectedDay != null) ...[
                  Text(
                    DateFormat('EEEE, MMMM d').format(_selectedDay!),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (selectedLogs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('No dose activity on this day.'),
                    )
                  else
                    ...selectedLogs.map((log) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  _colorFor(log.status).withOpacity(0.12),
                              child: Icon(
                                log.status == DoseStatus.taken
                                    ? Icons.check
                                    : log.status == DoseStatus.missed
                                        ? Icons.close
                                        : Icons.snooze,
                                color: _colorFor(log.status),
                              ),
                            ),
                            title: Text(log.medicineName),
                            subtitle: Text(
                                DateFormat('h:mm a').format(log.scheduledTime)),
                            trailing: Text(
                              _labelFor(log.status),
                              style: TextStyle(
                                color: _colorFor(log.status),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Tap a day to see its dose activity.'),
                  ),
              ],
            ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
