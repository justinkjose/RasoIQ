class ShoppingList {
  final String id;
  final String userId;
  final List<String> members;
  final String name;
  final String icon;
  final DateTime createdDate;
  final DateTime updatedAt;
  final bool isArchived;

  const ShoppingList({
    required this.id,
    this.userId = '',
    this.members = const [],
    required this.name,
    required this.icon,
    required this.createdDate,
    required this.updatedAt,
    required this.isArchived,
  });

  ShoppingList copyWith({
    String? id,
    String? userId,
    List<String>? members,
    String? name,
    String? icon,
    DateTime? createdDate,
    DateTime? updatedAt,
    bool? isArchived,
  }) {
    return ShoppingList(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      members: members ?? this.members,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      createdDate: createdDate ?? this.createdDate,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'members': members,
      'name': name,
      'icon': icon,
      'createdDate': createdDate.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isArchived': isArchived,
    };
  }

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    final created = DateTime.parse(json['createdDate'] as String);
    final userId = json['userId']?.toString() ?? '';
    final members = (json['members'] as List<dynamic>? ?? [])
        .map((item) => item.toString())
        .toList();
    return ShoppingList(
      id: json['id'] as String,
      userId: userId,
      members: members.isEmpty && userId.isNotEmpty ? [userId] : members,
      name: json['name'] as String,
      icon: json['icon'] as String,
      createdDate: created,
      updatedAt: json['updatedAt'] == null
          ? created
          : DateTime.parse(json['updatedAt'] as String),
      isArchived: json['isArchived'] as bool,
    );
  }
}
