class UserItem {
  const UserItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.createdAt,
    required this.updatedAt,
    required this.pendingSync,
  });

  final String id;
  final String name;
  final String category;
  final String unit;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool pendingSync;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'unit': unit,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'pendingSync': pendingSync,
    };
  }

  factory UserItem.fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now();
    return UserItem(
      id: json['id']?.toString() ??
          (json['name']?.toString().toLowerCase().trim() ?? ''),
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Miscellaneous',
      unit: json['unit']?.toString() ?? 'pcs',
      createdAt: created,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? created,
      pendingSync: json['pendingSync'] as bool? ?? false,
    );
  }
}
