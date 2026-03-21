import '../features/grocery/data/local_grocery_repository.dart';
import '../features/grocery/data/remote_grocery_repository.dart';
import '../features/grocery/domain/grocery_item.dart';
import '../features/grocery/domain/shopping_list.dart';

class SyncService {
  SyncService({
    LocalGroceryRepository? localRepository,
    RemoteGroceryRepository? remoteRepository,
  })  : _local = localRepository ?? LocalGroceryRepository(),
        _remote = remoteRepository ?? RemoteGroceryRepository();

  final LocalGroceryRepository _local;
  final RemoteGroceryRepository _remote;

  Future<void> pushLocalToCloud() async {
    final lists = await _local.loadLists();
    for (final list in lists) {
      await _remote.upsertList(list);
    }

    final items = await _local.loadItems();
    for (final item in items) {
      await _remote.upsertItem(item);
    }
  }

  Future<void> pullCloudToLocal() async {
    final remoteLists = await _remote.fetchLists();
    if (remoteLists.isEmpty) return;

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
    await _local.saveLists(listMap.values.toList());

    final localItems = await _local.loadItems();
    final itemMap = <String, GroceryItem>{};
    for (final item in localItems) {
      itemMap[item.id] = item;
    }
    for (final list in remoteLists) {
      final remoteItems = await _remote.fetchItems(list.id);
      for (final remote in remoteItems) {
        final existing = itemMap[remote.id];
        if (existing == null ||
            remote.updatedAt.isAfter(existing.updatedAt)) {
          itemMap[remote.id] = remote;
        }
      }
    }
    await _local.saveItems(itemMap.values.toList());
  }
}
