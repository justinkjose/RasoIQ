import 'package:cloud_firestore/cloud_firestore.dart';

class GroceryItem {
  GroceryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String category;
  final String unit;
  final DateTime createdAt;

  factory GroceryItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final Timestamp? timestamp = data['createdAt'] as Timestamp?;
    return GroceryItem(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      unit: (data['unit'] ?? '').toString(),
      createdAt: (timestamp?.toDate()) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'unit': unit,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
