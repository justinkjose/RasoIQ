import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

import '../domain/grocery_item.dart';
import '../domain/shopping_list.dart';
import 'local_grocery_repository.dart';
import 'remote_grocery_repository.dart';

class GrocerySyncService {
  GrocerySyncService({
    LocalGroceryRepository? localRepository,
    RemoteGroceryRepository? remoteRepository,
  })  : _local = localRepository ?? LocalGroceryRepository(),
        _remote = remoteRepository ?? RemoteGroceryRepository();

  final LocalGroceryRepository _local;
  final RemoteGroceryRepository _remote;

  DateTime? _lastRemoteSync;
  bool _syncInFlight = false;
  Timer? _syncDebounce;
  static const Duration _syncThrottle = Duration(seconds: 30);
  static const String _metaBox = 'grocery_meta_box';
  static const String _listSyncKey = 'last_list_sync';
  static const String _itemSyncKey = 'last_item_sync';

  Future<void> syncFromRemote() async {
    if (_syncInFlight) return;
    final now = DateTime.now();
    if (_lastRemoteSync != null &&
        now.difference(_lastRemoteSync!) < _syncThrottle) {
      return;
    }
    _syncInFlight = true;
    try {
      final lastListSync = await _loadLastSync(_listSyncKey);
      if (lastListSync == null) {
        await _saveLastSync(_listSyncKey, now);
        await _saveLastSync(_itemSyncKey, now);
        return;
      }
      final remoteLists = await _remote.fetchListsUpdatedSince(lastListSync);
      if (remoteLists.isEmpty) {
        await _saveLastSync(_listSyncKey, now);
      }

      final localLists = await _local.loadLists();
      final listMap = <String, ShoppingList>{};
      for (final list in localLists) {
        listMap[list.id] = list;
      }
      for (final remote in remoteLists) {
        final existing = listMap[remote.id];
        if (existing == null ||
            remote.updatedAt.isAfter(existing.updatedAt)) {
          listMap[remote.id] = remote;
        }
      }
      final mergedLists = listMap.values.toList();
      await _local.saveLists(mergedLists);
      await _saveLastSync(_listSyncKey, now);

      final localItems = await _local.loadItems();
      final itemMap = <String, GroceryItem>{};
      for (final item in localItems) {
        itemMap[item.id] = item;
      }
      final lastItemSync = await _loadLastSync(_itemSyncKey) ?? lastListSync;
      final listsToCheck = mergedLists.isNotEmpty ? mergedLists : localLists;
      for (final list in listsToCheck) {
        final remoteItems =
            await _remote.fetchItemsUpdatedSince(list.id, lastItemSync);
        for (final remote in remoteItems) {
          final existing = itemMap[remote.id];
          if (existing == null ||
              remote.updatedAt.isAfter(existing.updatedAt)) {
            itemMap[remote.id] = remote;
          }
        }
      }
      await _local.saveItems(itemMap.values.toList());
      await _saveLastSync(_itemSyncKey, now);
      _lastRemoteSync = DateTime.now();
    } catch (_) {
      return;
    } finally {
      _syncInFlight = false;
    }
  }

  Future<void> scheduleSync(Future<void> Function() onMerged) async {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(seconds: 2), () async {
      await syncFromRemote();
      await onMerged();
    });
  }

  Future<void> stop() async {
    _syncDebounce?.cancel();
    _syncDebounce = null;
  }

  Future<DateTime?> _loadLastSync(String key) async {
    final box = await Hive.openBox(_metaBox);
    final raw = box.get(key);
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  Future<void> _saveLastSync(String key, DateTime value) async {
    final box = await Hive.openBox(_metaBox);
    await box.put(key, value.toIso8601String());
  }
}
