import 'package:hive_flutter/hive_flutter.dart';

import '../models/sync_queue_item.dart';

class SyncQueueStorage {
  static const _boxName = 'sync_queue_box';
  static const _queueKey = 'queue_items';

  Future<Box> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box(_boxName);
    }
    return Hive.openBox(_boxName);
  }

  Future<List<SyncQueueItem>> loadQueue() async {
    final box = await _openBox();
    final raw = box.get(_queueKey, defaultValue: <dynamic>[]);
    final list = (raw as List).cast<Map>();
    return list
        .map((item) => SyncQueueItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> saveQueue(List<SyncQueueItem> items) async {
    final box = await _openBox();
    final encoded = items.map((e) => e.toJson()).toList();
    await box.put(_queueKey, encoded);
  }

  Future<void> enqueue(SyncQueueItem item) async {
    final items = await loadQueue();
    items.add(item);
    await saveQueue(items);
  }

  Future<void> saveQueueItems(List<SyncQueueItem> items) async {
    await saveQueue(items);
  }

  Future<void> removeByIds(Set<String> ids) async {
    if (ids.isEmpty) return;
    final items = await loadQueue();
    items.removeWhere((item) => ids.contains(item.id));
    await saveQueue(items);
  }
}
