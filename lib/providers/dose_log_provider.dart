import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/dose_log.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';

class DoseLogProvider extends ChangeNotifier {
  final DatabaseService _localDb = DatabaseService.instance;
  final FirestoreService _firestore = FirestoreService.instance;
  final _uuid = const Uuid();

  List<DoseLog> _logs = [];
  bool _isLoading = false;

  List<DoseLog> get logs => List.unmodifiable(_logs);
  bool get isLoading => _isLoading;

  /// Returns the current user's UID, or null if the user is a guest.
  String? get _uid => AuthService.instance.currentUser?.uid;

  Future<void> loadLogs() async {
    _isLoading = true;
    notifyListeners();
    final uid = _uid;
    if (uid != null) {
      _logs = await _firestore.getAllDoseLogs(uid);
    } else {
      _logs = await _localDb.getAllDoseLogs();
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Clears the in-memory list (called on sign-out so guest sees a clean slate).
  void clear() {
    _logs = [];
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
      final uid = _uid;
      if (uid != null) {
        await _firestore.insertDoseLog(uid, log);
      } else {
        await _localDb.insertDoseLog(log);
      }
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
