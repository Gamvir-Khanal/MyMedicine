import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/dose_log.dart';
import '../models/medicine.dart';
import '../models/reminder.dart';

/// Handles all Firestore CRUD for a logged-in user's data.
/// Every method requires the caller to pass the authenticated user's [uid].
/// Guest users should never call these methods — they use DatabaseService instead.
class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Collection references ────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _medicines(String uid) =>
      _db.collection('users').doc(uid).collection('medicines');

  CollectionReference<Map<String, dynamic>> _reminders(String uid) =>
      _db.collection('users').doc(uid).collection('reminders');

  CollectionReference<Map<String, dynamic>> _doseLogs(String uid) =>
      _db.collection('users').doc(uid).collection('dose_logs');

  // ─── Medicines ─────────────────────────────────────────────────────────────

  Future<void> insertMedicine(String uid, Medicine medicine) async {
    await _medicines(uid).doc(medicine.id).set(medicine.toMap());
  }

  Future<void> updateMedicine(String uid, Medicine medicine) async {
    await _medicines(uid).doc(medicine.id).set(medicine.toMap());
  }

  Future<void> deleteMedicine(String uid, String medicineId) async {
    await _medicines(uid).doc(medicineId).delete();
  }

  Future<List<Medicine>> getAllMedicines(String uid) async {
    final snapshot = await _medicines(uid).orderBy('name').get();
    return snapshot.docs.map((doc) => Medicine.fromMap(doc.data())).toList();
  }

  // ─── Reminders ─────────────────────────────────────────────────────────────

  Future<void> insertReminder(String uid, Reminder reminder) async {
    await _reminders(uid).doc(reminder.id).set(reminder.toFirestoreMap());
  }

  Future<void> updateReminder(String uid, Reminder reminder) async {
    await _reminders(uid).doc(reminder.id).set(reminder.toFirestoreMap());
  }

  Future<void> deleteReminder(String uid, String reminderId) async {
    await _reminders(uid).doc(reminderId).delete();
  }

  Future<List<Reminder>> getAllReminders(String uid) async {
    final snapshot = await _reminders(uid).get();
    return snapshot.docs
        .map((doc) => Reminder.fromFirestoreMap(doc.data()))
        .toList();
  }

  /// Removes all reminders whose medicineId matches [medicineId].
  Future<void> deleteRemindersForMedicine(
      String uid, String medicineId) async {
    final snapshot = await _reminders(uid)
        .where('medicineId', isEqualTo: medicineId)
        .get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ─── Dose Logs ─────────────────────────────────────────────────────────────

  Future<void> insertDoseLog(String uid, DoseLog log) async {
    await _doseLogs(uid).doc(log.id).set(log.toMap());
  }

  Future<List<DoseLog>> getAllDoseLogs(String uid) async {
    final snapshot = await _doseLogs(uid)
        .orderBy('scheduledTime', descending: true)
        .get();
    return snapshot.docs.map((doc) => DoseLog.fromMap(doc.data())).toList();
  }

  // ─── Emergency Contact ───────────────────────────────────────────────────

  Future<void> saveEmergencyContact(
      String uid, String name, String phoneNumber) async {
    await _db.collection('users').doc(uid).set({
      'emergencyContact': {
        'name': name,
        'phoneNumber': phoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  Future<Map<String, String>?> getEmergencyContact(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null || !data.containsKey('emergencyContact')) return null;
    final contact = data['emergencyContact'] as Map<String, dynamic>?;
    if (contact == null) return null;
    final name = contact['name'] as String? ?? '';
    final phone = contact['phoneNumber'] as String? ?? '';
    if (name.isEmpty && phone.isEmpty) return null;
    return {'name': name, 'phoneNumber': phone};
  }

  Future<void> deleteEmergencyContact(String uid) async {
    await _db.collection('users').doc(uid).set({
      'emergencyContact': FieldValue.delete(),
    }, SetOptions(merge: true));
  }
}
