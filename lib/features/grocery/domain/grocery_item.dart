import 'grocery_unit.dart';

class GroceryItem {
  final String id;
  final String listId;
  final String userId;
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
  final DateTime updatedAt;

  const GroceryItem({
    required this.id,
    required this.listId,
    this.userId = '',
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
    required this.updatedAt,
  });

  bool get completed => isDone;

  GroceryItem copyWith({
    String? id,
    String? listId,
    String? userId,
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
    DateTime? updatedAt,
  }) {
    return GroceryItem(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      userId: userId ?? this.userId,
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
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listId': listId,
      'userId': userId,
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
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'] == null
        ? DateTime.now()
        : DateTime.parse(json['createdAt'] as String);
    return GroceryItem(
      id: json['id'] as String,
      listId: json['listId'] as String,
      userId: json['userId']?.toString() ?? '',
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
      createdAt: created,
      updatedAt: json['updatedAt'] == null
          ? created
          : DateTime.parse(json['updatedAt'] as String),
    );
  }
}
