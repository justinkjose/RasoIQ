import 'package:hive_flutter/hive_flutter.dart';

import '../domain/grocery_item.dart';
import '../domain/shopping_list.dart';

class GroceryStorage {
  static const groceryBoxName = 'grocery_box';
  static const shoppingListsKey = 'shopping_lists';
  static const groceryItemsKey = 'grocery_items';
  static const recentItemsKey = 'grocery_recent_items';

  Future<Box> _openBox() async {
    if (Hive.isBoxOpen(groceryBoxName)) {
      return Hive.box(groceryBoxName);
    }
    return Hive.openBox(groceryBoxName);
  }

  Future<List<ShoppingList>> loadShoppingLists() async {
    final box = await _openBox();
    final raw = box.get(shoppingListsKey, defaultValue: <dynamic>[]);
    final list = (raw as List).cast<Map>();
    return list
        .map((item) => ShoppingList.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> saveShoppingLists(List<ShoppingList> lists) async {
    final box = await _openBox();
    final encoded = lists.map((e) => e.toJson()).toList();
    await box.put(shoppingListsKey, encoded);
  }

  Future<List<GroceryItem>> loadGroceryItems() async {
    final box = await _openBox();
    final raw = box.get(groceryItemsKey, defaultValue: <dynamic>[]);
    final list = (raw as List).cast<Map>();
    return list
        .map((item) => GroceryItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> saveGroceryItems(List<GroceryItem> items) async {
    final box = await _openBox();
    final encoded = items.map((e) => e.toJson()).toList();
    await box.put(groceryItemsKey, encoded);
  }

  Future<List<String>> loadRecentItems() async {
    final box = await _openBox();
    final raw = box.get(recentItemsKey, defaultValue: <dynamic>[]);
    final list = (raw as List).map((item) => item.toString()).toList();
    return list;
  }

  Future<void> saveRecentItems(List<String> items) async {
    final box = await _openBox();
    await box.put(recentItemsKey, items);
  }
}
