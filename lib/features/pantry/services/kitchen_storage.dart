import 'package:hive_flutter/hive_flutter.dart';

import '../domain/kitchen_item.dart';

class KitchenStorage {
  static const kitchenBoxName = 'kitchen_box';
  static const kitchenItemsKey = 'kitchen_items';

  Future<Box> _openBox() async {
    if (Hive.isBoxOpen(kitchenBoxName)) {
      return Hive.box(kitchenBoxName);
    }
    return Hive.openBox(kitchenBoxName);
  }

  Future<List<KitchenItem>> loadItems() async {
    final box = await _openBox();
    final raw = box.get(kitchenItemsKey, defaultValue: <dynamic>[]);
    final list = (raw as List).cast<Map>();
    return list
        .map((item) => KitchenItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> saveItems(List<KitchenItem> items) async {
    final box = await _openBox();
    final encoded = items.map((item) => item.toJson()).toList();
    await box.put(kitchenItemsKey, encoded);
  }
}
