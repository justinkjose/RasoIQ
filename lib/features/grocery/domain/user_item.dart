class UserItem {
  const UserItem({
    required this.name,
    required this.category,
    required this.createdAt,
  });

  final String name;
  final String category;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserItem.fromJson(Map<String, dynamic> json) {
    return UserItem(
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Miscellaneous',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
