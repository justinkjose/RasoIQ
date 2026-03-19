import 'grocery_unit.dart';

class GroceryItem {
  final String id;
  final String listId;
  final String name;
  final String normalizedName;
  final double quantity;
  final int packCount;
  final double packSize;
  final GroceryUnit unit;
  final String categoryId;
  final bool isDone;
  final bool isImportant;
  final bool isUnavailable;
  final DateTime? expiryDate;
  final DateTime createdAt;

  const GroceryItem({
    required this.id,
    required this.listId,
    required this.name,
    required this.normalizedName,
    required this.quantity,
    required this.packCount,
    required this.packSize,
    required this.unit,
    required this.categoryId,
    required this.isDone,
    required this.isImportant,
    required this.isUnavailable,
    required this.expiryDate,
    required this.createdAt,
  });

  bool get completed => isDone;

  GroceryItem copyWith({
    String? id,
    String? listId,
    String? name,
    String? normalizedName,
    double? quantity,
    int? packCount,
    double? packSize,
    GroceryUnit? unit,
    String? categoryId,
    bool? isDone,
    bool? isImportant,
    bool? isUnavailable,
    DateTime? expiryDate,
    DateTime? createdAt,
  }) {
    return GroceryItem(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      quantity: quantity ?? this.quantity,
      packCount: packCount ?? this.packCount,
      packSize: packSize ?? this.packSize,
      unit: unit ?? this.unit,
      categoryId: categoryId ?? this.categoryId,
      isDone: isDone ?? this.isDone,
      isImportant: isImportant ?? this.isImportant,
      isUnavailable: isUnavailable ?? this.isUnavailable,
      expiryDate: expiryDate ?? this.expiryDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listId': listId,
      'name': name,
      'normalizedName': normalizedName,
      'quantity': quantity,
      'packCount': packCount,
      'packSize': packSize,
      'unit': unit.name,
      'categoryId': categoryId,
      'isDone': isDone,
      'completed': isDone,
      'isImportant': isImportant,
      'isUnavailable': isUnavailable,
      'expiryDate': expiryDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    return GroceryItem(
      id: json['id'] as String,
      listId: json['listId'] as String,
      name: json['name'] as String,
      normalizedName: json['normalizedName'] as String,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      packCount: (json['packCount'] as num?)?.toInt() ?? 1,
      packSize: (json['packSize'] as num?)?.toDouble() ?? 0.0,
      unit: GroceryUnit.values.firstWhere(
        (unit) => unit.name == json['unit'],
        orElse: () => GroceryUnit.item,
      ),
      categoryId: json['categoryId']?.toString() ?? 'uncategorized',
      isDone: json['isDone'] as bool? ?? json['completed'] as bool? ?? false,
      isImportant: json['isImportant'] as bool? ?? false,
      isUnavailable: json['isUnavailable'] as bool? ?? false,
      expiryDate: json['expiryDate'] == null
          ? null
          : DateTime.parse(json['expiryDate'] as String),
      createdAt: json['createdAt'] == null
          ? DateTime.now()
          : DateTime.parse(json['createdAt'] as String),
    );
  }
}
