import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ad_item.dart';

class AdsFirestoreService {
  AdsFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const int _limit = 200;

  Future<List<AdItem>> fetchAds() async {
    final snapshot = await _firestore.collection('ads').limit(_limit).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      final map = <String, dynamic>{
        ...data,
        'id': doc.id,
      };
      return AdItem.fromJson(map);
    }).toList();
  }
}
