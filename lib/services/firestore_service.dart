import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addGroceryItem(String name, String category, String unit) {
    return _db.collection('grocery_items').add({
      'name': name,
      'category': category,
      'unit': unit,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getGroceryItems() {
    return _db
        .collection('grocery_items')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> deleteItem(String id) {
    return _db.collection('grocery_items').doc(id).delete();
  }

  Future<void> updateItem(String id, Map<String, dynamic> data) {
    return _db.collection('grocery_items').doc(id).update(data);
  }
}
