import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/medicine.dart';
import '../services/database_service.dart';
import '../services/reminder_api_service.dart';

class MedicineProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final ReminderApiService _reminderApi = ReminderApiService();
  final _uuid = const Uuid();

  List<Medicine> _medicines = [];
  bool _isLoading = false;

  List<Medicine> get medicines => List.unmodifiable(_medicines);
  bool get isLoading => _isLoading;

  List<Medicine> get expiredMedicines =>
      _medicines.where((m) => m.isExpired).toList();

  List<Medicine> get expiringSoonMedicines =>
      _medicines.where((m) => m.isExpiringSoon).toList();

  List<Medicine> get lowStockMedicines =>
      _medicines.where((m) => m.isLowStock).toList();

  List<Medicine> recentlyAddedMedicines({int limit = 5}) {
    final sorted = List<Medicine>.from(_medicines)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  Future<void> loadMedicines() async {
    _isLoading = true;
    notifyListeners();
    _medicines = await _db.getAllMedicines();
    _isLoading = false;
    notifyListeners();
  }

  Future<Medicine> addMedicine({
    required String name,
    required String dosage,
    required String form,
    required int quantity,
    required DateTime expiryDate,
    int lowStockThreshold = 5,
    String instructions = '',
  }) async {
    final medicine = Medicine(
      id: _uuid.v4(),
      name: name,
      dosage: dosage,
      form: form,
      quantity: quantity,
      lowStockThreshold: lowStockThreshold,
      expiryDate: expiryDate,
      instructions: instructions,
    );

    await _db.insertMedicine(medicine);
    try {
      await _reminderApi.scheduleExpiryAlerts(medicine);
    } catch (e) {
      debugPrint('scheduleExpiryAlerts failed: $e');
    }
    _medicines.add(medicine);
    _sort();
    notifyListeners();
    return medicine;
  }

  Future<void> updateMedicine(Medicine updated) async {
    final index = _medicines.indexWhere((m) => m.id == updated.id);
    final wasLowStock = index != -1 ? _medicines[index].isLowStock : false;

    await _db.updateMedicine(updated);

    try {
      await _reminderApi.cancelExpiryAlerts(updated);
      await _reminderApi.scheduleExpiryAlerts(updated);
    } catch (e) {
      debugPrint('expiry alert reschedule failed: $e');
    }

    if (index != -1) {
      _medicines[index] = updated;
    } else {
      _medicines.add(updated);
    }
    _sort();
    notifyListeners();

    if (!wasLowStock && updated.isLowStock) {
      try {
        await _reminderApi.triggerRefillReminder(updated);
      } catch (e) {
        debugPrint('triggerRefillReminder failed: $e');
      }
    }
  }

  Future<void> deleteMedicine(Medicine medicine) async {
    await _db.deleteMedicine(medicine.id);
    try {
      await _reminderApi.cancelExpiryAlerts(medicine);
    } catch (e) {
      debugPrint('cancelExpiryAlerts failed: $e');
    }
    _medicines.removeWhere((m) => m.id == medicine.id);
    notifyListeners();
  }

  Future<void> decrementQuantity(Medicine medicine) async {
    if (medicine.quantity <= 0) return;
    final updated = medicine.copyWith(quantity: medicine.quantity - 1);
    await updateMedicine(updated);
  }

  void _sort() {
    _medicines.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
  }
}
