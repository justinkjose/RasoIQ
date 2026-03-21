import '../local/sync_queue_storage.dart';
import '../models/sync_queue_item.dart';

class SyncService<T> {
  SyncService({
    required this.collection,
    required this.loadLocal,
    required this.saveLocal,
    required this.fetchRemote,
    required this.getId,
    required this.getUpdatedAt,
    required this.toPayload,
    SyncQueueStorage? queueStorage,
    this.pushRemote,
    this.isOnline,
  }) : _queueStorage = queueStorage ?? SyncQueueStorage();

  final String collection;
  final Future<List<T>> Function() loadLocal;
  final Future<void> Function(List<T>) saveLocal;
  final Future<List<T>> Function() fetchRemote;
  final String Function(T) getId;
  final DateTime Function(T) getUpdatedAt;
  final Map<String, dynamic> Function(T) toPayload;
  final Future<void> Function(SyncQueueItem item)? pushRemote;
  final Future<bool> Function()? isOnline;
  final SyncQueueStorage _queueStorage;

  Future<List<T>> loadWithSync() async {
    final local = await loadLocal();
    final online = await _isOnline();
    if (!online) return local;
    try {
      final remote = await fetchRemote();
      final merged = _merge(local, remote);
      await saveLocal(merged);
      return merged;
    } catch (_) {
      return local;
    }
  }

  Future<void> enqueueUpsert(T entity) async {
    final item = SyncQueueItem.upsert(
      collection: collection,
      entityId: getId(entity),
      payload: toPayload(entity),
    );
    await _queueStorage.enqueue(item);
    await processQueue();
  }

  Future<void> enqueueDelete(String entityId) async {
    final item = SyncQueueItem.delete(
      collection: collection,
      entityId: entityId,
      payload: {'id': entityId},
    );
    await _queueStorage.enqueue(item);
    await processQueue();
  }

  Future<void> processQueue() async {
    if (pushRemote == null) return;
    final online = await _isOnline();
    if (!online) return;
    final items = await _queueStorage.loadQueue();
    if (items.isEmpty) return;

    final completed = <String>{};
    for (final item in items) {
      try {
        await pushRemote!(item);
        completed.add(item.id);
      } catch (_) {
        break;
      }
    }
    await _queueStorage.removeByIds(completed);
  }

  List<T> _merge(List<T> local, List<T> remote) {
    final map = <String, T>{};
    for (final item in local) {
      map[getId(item)] = item;
    }
    for (final item in remote) {
      final id = getId(item);
      final existing = map[id];
      if (existing == null) {
        map[id] = item;
      } else {
        final updatedAt = getUpdatedAt(item);
        final existingUpdatedAt = getUpdatedAt(existing);
        if (updatedAt.isAfter(existingUpdatedAt)) {
          map[id] = item;
        }
      }
    }
    return map.values.toList();
  }

  Future<bool> _isOnline() async {
    if (isOnline == null) return true;
    try {
      return await isOnline!();
    } catch (_) {
      return false;
    }
  }
}
