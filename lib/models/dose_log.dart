enum DoseStatus { taken, missed, snoozed }

class DoseLog {
  final String id;
  final String medicineId;
  final String medicineName;
  final String reminderId;
  final DateTime scheduledTime;
  final DateTime actualTime;
  final DoseStatus status;

  DoseLog({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    required this.reminderId,
    required this.scheduledTime,
    required this.actualTime,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicineId': medicineId,
      'medicineName': medicineName,
      'reminderId': reminderId,
      'scheduledTime': scheduledTime.toIso8601String(),
      'actualTime': actualTime.toIso8601String(),
      'status': status.name,
    };
  }

  factory DoseLog.fromMap(Map<String, dynamic> map) {
    return DoseLog(
      id: map['id'] as String,
      medicineId: map['medicineId'] as String,
      medicineName: map['medicineName'] as String,
      reminderId: map['reminderId'] as String? ?? '',
      scheduledTime: DateTime.parse(map['scheduledTime'] as String),
      actualTime: DateTime.parse(map['actualTime'] as String),
      status: DoseStatus.values.firstWhere((e) => e.name == map['status']),
    );
  }
}
