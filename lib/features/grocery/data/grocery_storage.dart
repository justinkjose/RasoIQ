import 'package:hive_flutter/hive_flutter.dart';

import '../domain/grocery_item.dart';
import '../domain/shopping_list.dart';

class GroceryStorage {
  static const legacyBoxName = 'grocery_box';
  static const shoppingListsKey = 'shopping_lists';
  static const groceryItemsKey = 'grocery_items';
  static const recentItemsKey = 'grocery_recent_items';

  static const listsBoxName = 'grocery_lists_box';
  static const itemsBoxName = 'grocery_items_box';
  static const recentBoxName = 'grocery_recent_box';
  static const metaBoxName = 'grocery_meta_box';
  static const _migratedKey = 'migrated_v2';

  Future<void> _ensureMigrated() async {
    final meta = await Hive.openBox(metaBoxName);
    final migrated = meta.get(_migratedKey, defaultValue: false) as bool;
    if (migrated) return;

    if (!await Hive.boxExists(legacyBoxName)) {
      await meta.put(_migratedKey, true);
      return;
    }

    final legacy = await Hive.openBox(legacyBoxName);
    final rawLists = legacy.get(shoppingListsKey, defaultValue: <dynamic>[]);
    final rawItems = legacy.get(groceryItemsKey, defaultValue: <dynamic>[]);
    final rawRecent = legacy.get(recentItemsKey, defaultValue: <dynamic>[]);

    if (rawLists is List && rawLists.isNotEmpty) {
      final lists = rawLists
          .cast<Map>()
          .map((item) => ShoppingList.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      final listBox = await _openListsBox();
      for (final list in lists) {
        await listBox.put(list.id, list);
      }
    }

    if (rawItems is List && rawItems.isNotEmpty) {
      final items = rawItems
          .cast<Map>()
          .map((item) => GroceryItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      final itemBox = await _openItemsBox();
      for (final item in items) {
        await itemBox.put(item.id, item);
      }
    }

    if (rawRecent is List && rawRecent.isNotEmpty) {
      final recentBox = await _openRecentBox();
      await recentBox.put(recentItemsKey, rawRecent);
    }

    await meta.put(_migratedKey, true);
  }

  Future<Box<ShoppingList>> _openListsBox() async {
    if (Hive.isBoxOpen(listsBoxName)) {
      return Hive.box<ShoppingList>(listsBoxName);
    }
    return Hive.openBox<ShoppingList>(listsBoxName);
  }

  Future<Box<GroceryItem>> _openItemsBox() async {
    if (Hive.isBoxOpen(itemsBoxName)) {
      return Hive.box<GroceryItem>(itemsBoxName);
    }
    return Hive.openBox<GroceryItem>(itemsBoxName);
  }

  Future<Box<dynamic>> _openRecentBox() async {
    if (Hive.isBoxOpen(recentBoxName)) {
      return Hive.box(recentBoxName);
    }
    return Hive.openBox(recentBoxName);
  }

  Future<List<ShoppingList>> loadShoppingLists() async {
    await _ensureMigrated();
    final box = await _openListsBox();
    return box.values.toList();
  }

  Future<void> saveShoppingLists(List<ShoppingList> lists) async {
    await _ensureMigrated();
    final box = await _openListsBox();
    await box.clear();
    for (final list in lists) {
      await box.put(list.id, list);
    }
  }

  Future<List<GroceryItem>> loadGroceryItems() async {
    await _ensureMigrated();
    final box = await _openItemsBox();
    return box.values.toList();
  }

  Future<void> saveGroceryItems(List<GroceryItem> items) async {
    await _ensureMigrated();
    final box = await _openItemsBox();
    await box.clear();
    for (final item in items) {
      await box.put(item.id, item);
    }
  }

  Future<List<String>> loadRecentItems() async {
    await _ensureMigrated();
    final box = await _openRecentBox();
    final raw = box.get(recentItemsKey, defaultValue: <dynamic>[]);
    return (raw as List).map((item) => item.toString()).toList();
  }

  Future<void> saveRecentItems(List<String> items) async {
    await _ensureMigrated();
    final box = await _openRecentBox();
    await box.put(recentItemsKey, items);
  }
}
