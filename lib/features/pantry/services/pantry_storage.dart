import 'package:hive_flutter/hive_flutter.dart';

import '../domain/consumption_event.dart';
import '../domain/pantry_item.dart';

class PantryStorage {
  static const pantryBoxName = 'pantry_box';
  static const consumptionBoxName = 'consumption_box';
  static const pantryItemsKey = 'pantry_items';
  static const consumptionEventsKey = 'pantry_consumption_events';
  static const categoryMemoryKey = 'category_memory_v1';
  static const wasteEventsKey = 'pantry_waste_events';

  Future<Box> _openBox() async {
    if (Hive.isBoxOpen(pantryBoxName)) {
      return Hive.box(pantryBoxName);
    }
    return Hive.openBox(pantryBoxName);
  }

  Future<Box> _openConsumptionBox() async {
    if (Hive.isBoxOpen(consumptionBoxName)) {
      return Hive.box(consumptionBoxName);
    }
    return Hive.openBox(consumptionBoxName);
  }

  Future<List<PantryItem>> loadItems() async {
    final box = await _openBox();
    final raw = box.get(pantryItemsKey);
    List<Map> list;
    if (raw is List) {
      list = raw.cast<Map>();
    } else {
      list = box.values
          .whereType<Map>()
          .where((entry) => entry.containsKey('name') && entry.containsKey('quantity'))
          .toList();
    }
    return list
        .map((item) => PantryItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> saveItems(List<PantryItem> items) async {
    final box = await _openBox();
    final encoded = items.map((item) => item.toJson()).toList();
    await box.put(pantryItemsKey, encoded);
  }

  Future<List<ConsumptionEvent>> loadConsumptionEvents() async {
    final box = await _openConsumptionBox();
    final raw = box.get(consumptionEventsKey, defaultValue: <dynamic>[]);
    final list = (raw as List).cast<Map>();
    return list
        .map((event) => ConsumptionEvent.fromJson(Map<String, dynamic>.from(event)))
        .toList();
  }

  Future<void> saveConsumptionEvents(List<ConsumptionEvent> events) async {
    final box = await _openConsumptionBox();
    final encoded = events.map((event) => event.toJson()).toList();
    await box.put(consumptionEventsKey, encoded);
  }

  Future<List<Map<String, dynamic>>> loadWasteEvents() async {
    final box = await _openConsumptionBox();
    final raw = box.get(wasteEventsKey, defaultValue: <dynamic>[]);
    final list = (raw as List).cast<Map>();
    return list.map((event) => Map<String, dynamic>.from(event)).toList();
  }

  Future<void> saveWasteEvents(List<Map<String, dynamic>> events) async {
    final box = await _openConsumptionBox();
    await box.put(wasteEventsKey, events);
  }

  Future<Map<String, String>> loadCategoryMemory() async {
    final box = await _openBox();
    final raw = box.get(categoryMemoryKey, defaultValue: <String, dynamic>{});
    final map = Map<String, dynamic>.from(raw as Map);
    return map.map((key, value) => MapEntry(key, value.toString()));
  }

  Future<void> saveCategoryMemory(Map<String, String> memory) async {
    final box = await _openBox();
    await box.put(categoryMemoryKey, memory);
  }
}
