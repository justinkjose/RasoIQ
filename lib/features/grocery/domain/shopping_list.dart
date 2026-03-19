class ShoppingList {
  final String id;
  final String name;
  final String icon;
  final DateTime createdDate;
  final bool isArchived;

  const ShoppingList({
    required this.id,
    required this.name,
    required this.icon,
    required this.createdDate,
    required this.isArchived,
  });

  ShoppingList copyWith({
    String? id,
    String? name,
    String? icon,
    DateTime? createdDate,
    bool? isArchived,
  }) {
    return ShoppingList(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      createdDate: createdDate ?? this.createdDate,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'createdDate': createdDate.toIso8601String(),
      'isArchived': isArchived,
    };
  }

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    return ShoppingList(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      createdDate: DateTime.parse(json['createdDate'] as String),
      isArchived: json['isArchived'] as bool,
    );
  }
}
