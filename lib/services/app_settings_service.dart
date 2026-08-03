import 'package:shared_preferences/shared_preferences.dart';

class EmergencyContact {
  final String name;
  final String phoneNumber;

  const EmergencyContact({required this.name, required this.phoneNumber});
}

class AppSettingsService {
  AppSettingsService._internal();
  static final AppSettingsService instance = AppSettingsService._internal();

  static const _kContactName = 'emergency_contact_name';
  static const _kContactPhone = 'emergency_contact_phone';
  static const _kEscalationEnabled = 'escalation_enabled';
  static const _kEscalationIntervalMinutes = 'escalation_interval_minutes';
  static const _kEscalationMaxCount = 'escalation_max_count';

  // ---------- Emergency contact ----------

  Future<EmergencyContact?> getEmergencyContact() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kContactName);
    final phone = prefs.getString(_kContactPhone);
    if (name == null || phone == null || phone.trim().isEmpty) return null;
    return EmergencyContact(name: name, phoneNumber: phone);
  }

  Future<void> setEmergencyContact(EmergencyContact contact) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kContactName, contact.name);
    await prefs.setString(_kContactPhone, contact.phoneNumber);
  }

  Future<void> clearEmergencyContact() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kContactName);
    await prefs.remove(_kContactPhone);
  }

  Future<bool> isEscalationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEscalationEnabled) ?? true;
  }

  Future<void> setEscalationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEscalationEnabled, enabled);
  }

  Future<int> getEscalationIntervalMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kEscalationIntervalMinutes) ?? 5;
  }

  Future<void> setEscalationIntervalMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kEscalationIntervalMinutes, minutes);
  }

  Future<int> getEscalationMaxCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kEscalationMaxCount) ?? 3;
  }

  Future<void> setEscalationMaxCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kEscalationMaxCount, count);
  }
}
