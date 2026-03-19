import 'package:hive_flutter/hive_flutter.dart';

import '../domain/user_item.dart';

class UserItemStorage {
  static const userItemsBoxName = 'user_items_box';
  static const userItemsKey = 'user_items';

  Future<Box> _openBox() async {
    if (Hive.isBoxOpen(userItemsBoxName)) {
      return Hive.box(userItemsBoxName);
    }
    return Hive.openBox(userItemsBoxName);
  }

  Future<List<UserItem>> loadUserItems() async {
    final box = await _openBox();
    final raw = box.get(userItemsKey, defaultValue: <dynamic>[]);
    final list = (raw as List).cast<Map>();
    return list
        .map((item) => UserItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> saveUserItems(List<UserItem> items) async {
    final box = await _openBox();
    final encoded = items.map((item) => item.toJson()).toList();
    await box.put(userItemsKey, encoded);
  }
}
