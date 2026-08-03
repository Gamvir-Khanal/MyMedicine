enum ReminderFrequency { daily, specificDays, once }

enum ReminderType { dose, refill, expiry }

class Reminder {
  final String id;
  final String medicineId;
  final String medicineName;
  final ReminderType type;
  final ReminderFrequency frequency;
  final int hour;
  final int minute;
  final List<int> daysOfWeek; // 1 = Monday ... 7 = Sunday, used if specificDays
  final DateTime? specificDate; // used if frequency == once
  final bool isActive;
  final String note;
  final int notificationId;
  final String? customSoundPath;

  Reminder({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    this.type = ReminderType.dose,
    this.frequency = ReminderFrequency.daily,
    required this.hour,
    required this.minute,
    this.daysOfWeek = const [],
    this.specificDate,
    this.isActive = true,
    this.note = '',
    required this.notificationId,
    this.customSoundPath,
  });

  Reminder copyWith({
    ReminderType? type,
    ReminderFrequency? frequency,
    int? hour,
    int? minute,
    List<int>? daysOfWeek,
    DateTime? specificDate,
    bool? isActive,
    String? note,
    String? customSoundPath,
    bool resetToDefaultSound = false,
  }) {
    return Reminder(
      id: id,
      medicineId: medicineId,
      medicineName: medicineName,
      type: type ?? this.type,
      frequency: frequency ?? this.frequency,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      specificDate: specificDate ?? this.specificDate,
      isActive: isActive ?? this.isActive,
      note: note ?? this.note,
      notificationId: notificationId,
      customSoundPath: resetToDefaultSound
          ? null
          : (customSoundPath ?? this.customSoundPath),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicineId': medicineId,
      'medicineName': medicineName,
      'type': type.name,
      'frequency': frequency.name,
      'hour': hour,
      'minute': minute,
      'daysOfWeek': daysOfWeek.join(','),
      'specificDate': specificDate?.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'note': note,
      'notificationId': notificationId,
      'customSoundPath': customSoundPath,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] as String,
      medicineId: map['medicineId'] as String,
      medicineName: map['medicineName'] as String,
      type: ReminderType.values.firstWhere((e) => e.name == map['type']),
      frequency: ReminderFrequency.values
          .firstWhere((e) => e.name == map['frequency']),
      hour: map['hour'] as int,
      minute: map['minute'] as int,
      daysOfWeek: (map['daysOfWeek'] as String).isEmpty
          ? []
          : (map['daysOfWeek'] as String)
              .split(',')
              .map((e) => int.parse(e))
              .toList(),
      specificDate: map['specificDate'] == null
          ? null
          : DateTime.parse(map['specificDate'] as String),
      isActive: (map['isActive'] as int) == 1,
      note: map['note'] as String? ?? '',
      notificationId: map['notificationId'] as int? ??
          ((map['id'] as String).hashCode & 0x7fffffff),
      customSoundPath: map['customSoundPath'] as String?,
    );
  }
}
