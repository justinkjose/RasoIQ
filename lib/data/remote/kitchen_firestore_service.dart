import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/pantry/domain/kitchen_item.dart';
import '../../services/auth_service.dart';

class KitchenFirestoreService {
  KitchenFirestoreService({FirebaseFirestore? firestore, AuthService? authService})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _authService = authService ?? AuthService.instance;

  final FirebaseFirestore _firestore;
  final AuthService _authService;
  static const int _limit = 300;

  Future<List<KitchenItem>> fetchKitchenItems() async {
    final userId = _authService.userId;
    final query = userId.isEmpty
        ? _firestore.collection('kitchen_items')
        : _firestore
            .collection('kitchen_items')
            .where('userId', isEqualTo: userId);
    final snapshot = await query.limit(_limit).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return KitchenItem(
        id: doc.id,
        userId: data['userId']?.toString() ?? userId,
        name: data['name']?.toString() ?? 'Item',
        category: data['category']?.toString() ?? 'Miscellaneous',
        batches: (data['batches'] as List<dynamic>? ?? [])
            .cast<Map>()
            .map((batch) => KitchenBatch.fromJson(Map<String, dynamic>.from(batch)))
            .toList(),
      );
    }).toList();
  }

  Stream<List<KitchenItem>> streamKitchenItems() {
    final userId = _authService.userId;
    final query = userId.isEmpty
        ? _firestore.collection('kitchen_items')
        : _firestore
            .collection('kitchen_items')
            .where('userId', isEqualTo: userId);
    return query.limit(_limit).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return KitchenItem(
          id: doc.id,
          userId: data['userId']?.toString() ?? userId,
          name: data['name']?.toString() ?? 'Item',
          category: data['category']?.toString() ?? 'Miscellaneous',
          batches: (data['batches'] as List<dynamic>? ?? [])
              .cast<Map>()
              .map(
                (batch) => KitchenBatch.fromJson(Map<String, dynamic>.from(batch)),
              )
              .toList(),
        );
      }).toList();
    });
  }

  Future<void> upsertKitchenItem(KitchenItem item) async {
    await _firestore.collection('kitchen_items').doc(item.id).set({
      'userId': item.userId,
      'name': item.name,
      'category': item.category,
      'batches': item.batches.map((batch) => batch.toJson()).toList(),
    }, SetOptions(merge: true));
  }
}
