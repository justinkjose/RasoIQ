class PantryItem {
  final String id;
  final String name;
  final String normalizedName;
  final double quantity;
  final String unit;
  final DateTime? expiryDate;

  const PantryItem({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.quantity,
    required this.unit,
    required this.expiryDate,
  });

  PantryItem copyWith({
    String? id,
    String? name,
    String? normalizedName,
    double? quantity,
    String? unit,
    DateTime? expiryDate,
  }) {
    return PantryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'normalizedName': normalizedName,
      'quantity': quantity,
      'unit': unit,
      'expiryDate': expiryDate?.toIso8601String(),
    };
  }

  factory PantryItem.fromJson(Map<String, dynamic> json) {
    return PantryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      normalizedName: json['normalizedName'] as String,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String,
      expiryDate: json['expiryDate'] == null
          ? null
          : DateTime.parse(json['expiryDate'] as String),
    );
  }
}
