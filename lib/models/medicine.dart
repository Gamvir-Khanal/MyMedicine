class Medicine {
  final String id;
  final String name;
  final String dosage;
  final String form;
  final int quantity;
  final int lowStockThreshold;
  final DateTime expiryDate;
  final String instructions;
  final DateTime createdAt;

  Medicine({
    required this.id,
    required this.name,
    required this.dosage,
    required this.form,
    required this.quantity,
    this.lowStockThreshold = 5,
    required this.expiryDate,
    this.instructions = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isExpired => expiryDate.isBefore(DateTime.now());

  bool get isExpiringSoon =>
      !isExpired && expiryDate.difference(DateTime.now()).inDays <= 30;

  bool get isLowStock => quantity <= lowStockThreshold;

  Medicine copyWith({
    String? name,
    String? dosage,
    String? form,
    int? quantity,
    int? lowStockThreshold,
    DateTime? expiryDate,
    String? instructions,
  }) {
    return Medicine(
      id: id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      form: form ?? this.form,
      quantity: quantity ?? this.quantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      expiryDate: expiryDate ?? this.expiryDate,
      instructions: instructions ?? this.instructions,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'form': form,
      'quantity': quantity,
      'lowStockThreshold': lowStockThreshold,
      'expiryDate': expiryDate.toIso8601String(),
      'instructions': instructions,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'] as String,
      name: map['name'] as String,
      dosage: map['dosage'] as String,
      form: map['form'] as String,
      quantity: map['quantity'] as int,
      lowStockThreshold: map['lowStockThreshold'] as int? ?? 5,
      expiryDate: DateTime.parse(map['expiryDate'] as String),
      instructions: map['instructions'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
