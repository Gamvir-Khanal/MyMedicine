import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/dose_log.dart';
import '../services/database_service.dart';

class DoseLogProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final _uuid = const Uuid();

  List<DoseLog> _logs = [];
  bool _isLoading = false;

  List<DoseLog> get logs => List.unmodifiable(_logs);
  bool get isLoading => _isLoading;

  Future<void> loadLogs() async {
    _isLoading = true;
    notifyListeners();
    _logs = await _db.getAllDoseLogs();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> logDose({
    required String medicineId,
    required String medicineName,
    required String reminderId,
    required DateTime scheduledTime,
    required DoseStatus status,
  }) async {
    final log = DoseLog(
      id: _uuid.v4(),
      medicineId: medicineId,
      medicineName: medicineName,
      reminderId: reminderId,
      scheduledTime: scheduledTime,
      actualTime: DateTime.now(),
      status: status,
    );
    try {
      await _db.insertDoseLog(log);
      _logs.insert(0, log);
      notifyListeners();
    } catch (e) {
      debugPrint('DoseLogProvider.logDose failed: $e');
    }
  }

  List<DoseLog> logsForDay(DateTime day) {
    return _logs.where((l) => _isSameDay(l.scheduledTime, day)).toList()
      ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
  }

  Map<int, Set<DoseStatus>> statusesByDayForMonth(DateTime month) {
    final result = <int, Set<DoseStatus>>{};
    for (final log in _logs) {
      if (log.scheduledTime.year == month.year &&
          log.scheduledTime.month == month.month) {
        result
            .putIfAbsent(log.scheduledTime.day, () => <DoseStatus>{})
            .add(log.status);
      }
    }
    return result;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
