import 'package:hive_flutter/hive_flutter.dart';

import '../domain/recipe_detail.dart';
import '../domain/recipe_meta.dart';

class RecipesStorage {
  static const _boxName = 'recipes_box';
  static const _metaKey = 'recipes_meta';
  static const _detailsKey = 'recipes_details';
  static const _downloadedKey = 'downloaded_recipe_ids';
  static const _lastFetchKey = 'recipes_meta_last_fetch';

  Future<Box> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box(_boxName);
    }
    return Hive.openBox(_boxName);
  }

  Future<List<RecipeMeta>> loadMeta() async {
    final box = await _openBox();
    final raw = box.get(_metaKey, defaultValue: <dynamic>[]);
    final list = (raw as List).cast<Map>();
    return list
        .map((item) => RecipeMeta.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> saveMeta(List<RecipeMeta> recipes) async {
    final box = await _openBox();
    final encoded = recipes.map((recipe) => recipe.toJson()).toList();
    await box.put(_metaKey, encoded);
  }

  Future<DateTime?> loadMetaLastFetch() async {
    final box = await _openBox();
    final raw = box.get(_lastFetchKey);
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  Future<void> saveMetaLastFetch(DateTime time) async {
    final box = await _openBox();
    await box.put(_lastFetchKey, time.toIso8601String());
  }

  Future<Map<String, RecipeDetail>> loadDetails() async {
    final box = await _openBox();
    final raw = box.get(_detailsKey, defaultValue: <dynamic>[]);
    final list = (raw as List).cast<Map>();
    final map = <String, RecipeDetail>{};
    for (final item in list) {
      final detail = RecipeDetail.fromJson(
        Map<String, dynamic>.from(item),
      );
      map[detail.id] = detail;
    }
    return map;
  }

  Future<void> saveDetails(Map<String, RecipeDetail> details) async {
    final box = await _openBox();
    final encoded = details.values.map((detail) => detail.toJson()).toList();
    await box.put(_detailsKey, encoded);
  }

  Future<Set<String>> loadDownloadedIds() async {
    final box = await _openBox();
    final raw = box.get(_downloadedKey, defaultValue: <dynamic>[]);
    return (raw as List).map((item) => item.toString()).toSet();
  }

  Future<void> saveDownloadedIds(Set<String> ids) async {
    final box = await _openBox();
    await box.put(_downloadedKey, ids.toList());
  }
}
