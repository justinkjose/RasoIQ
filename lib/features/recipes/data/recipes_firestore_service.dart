import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/recipe_detail.dart';
import '../domain/recipe_meta.dart';

class RecipesFirestoreService {
  RecipesFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const int _limit = 300;

  Future<List<RecipeMeta>> fetchRecipeMeta() async {
    final snapshot =
        await _firestore.collection('recipes_meta').limit(_limit).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      final map = <String, dynamic>{
        ...data,
        'id': data['id']?.toString() ?? doc.id,
      };
      return RecipeMeta.fromJson(map);
    }).toList();
  }

  Future<RecipeDetail?> fetchRecipeDetail(String id) async {
    final doc = await _firestore.collection('recipes_details').doc(id).get();
    final data = doc.data();
    if (data == null) return null;
    return RecipeDetail.fromJson({
      ...data,
      'id': data['id']?.toString() ?? doc.id,
    });
  }

  Future<void> bumpTrendingScore(String recipeId, double delta) async {
    await _firestore.collection('recipes_meta').doc(recipeId).set({
      'trendingScore': FieldValue.increment(delta),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
