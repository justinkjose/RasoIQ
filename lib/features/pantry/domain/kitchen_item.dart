class KitchenItem {
  const KitchenItem({
    required this.id,
    this.userId = '',
    required this.name,
    required this.category,
    required this.batches,
  });

  final String id;
  final String userId;
  final String name;
  final String category;
  final List<KitchenBatch> batches;

  int get totalQuantity =>
      batches.fold(0, (sum, batch) => sum + batch.quantity);

  bool get isOutOfStock => totalQuantity <= 0;

  KitchenItem copyWith({
    String? id,
    String? userId,
    String? name,
    String? category,
    List<KitchenBatch>? batches,
  }) {
    return KitchenItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      category: category ?? this.category,
      batches: batches ?? this.batches,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'category': category,
      'batches': batches.map((batch) => batch.toJson()).toList(),
    };
  }

  factory KitchenItem.fromJson(Map<String, dynamic> json) {
    return KitchenItem(
      id: json['id'] as String,
      userId: json['userId']?.toString() ?? '',
      name: json['name'] as String,
      category: json['category']?.toString() ?? 'Miscellaneous',
      batches: (json['batches'] as List<dynamic>? ?? [])
          .cast<Map>()
          .map((batch) => KitchenBatch.fromJson(Map<String, dynamic>.from(batch)))
          .toList(),
    );
  }
}

class KitchenBatch {
  const KitchenBatch({
    required this.quantity,
    required this.unit,
    required this.addedDate,
    this.expiryDate,
  });

  final int quantity;
  final String unit;
  final DateTime addedDate;
  final DateTime? expiryDate;

  KitchenBatch copyWith({
    int? quantity,
    String? unit,
    DateTime? addedDate,
    DateTime? expiryDate,
  }) {
    return KitchenBatch(
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      addedDate: addedDate ?? this.addedDate,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quantity': quantity,
      'unit': unit,
      'addedDate': addedDate.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
    };
  }

  factory KitchenBatch.fromJson(Map<String, dynamic> json) {
    final rawUnit = json['unit']?.toString() ?? 'pcs';
    final normalizedUnit = _normalizeUnit(rawUnit);
    return KitchenBatch(
      quantity: _toBaseQuantity(json['quantity'] as num? ?? 0, rawUnit),
      unit: normalizedUnit,
      addedDate: DateTime.tryParse(json['addedDate']?.toString() ?? '') ??
          DateTime.now(),
      expiryDate: json['expiryDate'] == null
          ? null
          : DateTime.tryParse(json['expiryDate']?.toString() ?? ''),
    );
  }
}

String formatQuantity(int qty, String unit) {
  if (unit == 'g' && qty >= 1000) {
    final value = qty / 1000;
    return value % 1 == 0
        ? '${value.toStringAsFixed(0)} kg'
        : '${value.toStringAsFixed(1)} kg';
  }
  if (unit == 'ml' && qty >= 1000) {
    final value = qty / 1000;
    return value % 1 == 0
        ? '${value.toStringAsFixed(0)} litre'
        : '${value.toStringAsFixed(1)} litre';
  }
  return '$qty $unit';
}

String _normalizeUnit(String unit) {
  switch (unit.toLowerCase()) {
    case 'kg':
    case 'g':
      return 'g';
    case 'litre':
    case 'l':
    case 'ml':
      return 'ml';
    case 'pcs':
    case 'piece':
    case 'pieces':
    case 'item':
    case 'items':
      return 'pcs';
    default:
      return 'pcs';
  }
}

int _toBaseQuantity(num quantity, String unit) {
  final raw = unit.toLowerCase();
  if (raw == 'kg') {
    return (quantity * 1000).round();
  }
  if (raw == 'litre' || raw == 'l') {
    return (quantity * 1000).round();
  }
  return quantity.round();
}
