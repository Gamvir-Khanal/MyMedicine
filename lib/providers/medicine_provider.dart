import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/medicine.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../services/reminder_api_service.dart';

class MedicineProvider extends ChangeNotifier {
  final DatabaseService _localDb = DatabaseService.instance;
  final FirestoreService _firestore = FirestoreService.instance;
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

  /// Returns the current user's UID, or null if the user is a guest.
  String? get _uid => AuthService.instance.currentUser?.uid;

  Future<void> loadMedicines() async {
    _isLoading = true;
    notifyListeners();
    final uid = _uid;
    if (uid != null) {
      _medicines = await _firestore.getAllMedicines(uid);
    } else {
      _medicines = await _localDb.getAllMedicines();
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Clears the in-memory list (called on sign-out so guest sees a clean slate).
  void clear() {
    _medicines = [];
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

    final uid = _uid;
    if (uid != null) {
      await _firestore.insertMedicine(uid, medicine);
    } else {
      await _localDb.insertMedicine(medicine);
    }

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

    final uid = _uid;
    if (uid != null) {
      await _firestore.updateMedicine(uid, updated);
    } else {
      await _localDb.updateMedicine(updated);
    }

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
    final uid = _uid;
    if (uid != null) {
      await _firestore.deleteMedicine(uid, medicine.id);
    } else {
      await _localDb.deleteMedicine(medicine.id);
    }
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
