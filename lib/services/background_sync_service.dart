import 'dart:async';
import '../data/local/sync_queue_storage.dart';
import '../data/models/sync_queue_item.dart';
import '../data/remote/firestore_service.dart';
import '../features/grocery/domain/grocery_item.dart';
import '../features/grocery/domain/shopping_list.dart';
import '../features/grocery/data/user_item_storage.dart';
import '../features/grocery/domain/user_item.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class BackgroundSyncService {
  BackgroundSyncService({
    SyncQueueStorage? queueStorage,
    FirestoreService? firestoreService,
    UserItemStorage? userItemStorage,
  })  : _queueStorage = queueStorage ?? SyncQueueStorage(),
        _firestoreService = firestoreService ?? FirestoreService(),
        _userItemStorage = userItemStorage ?? UserItemStorage();

  final SyncQueueStorage _queueStorage;
  final FirestoreService _firestoreService;
  final UserItemStorage _userItemStorage;

  Timer? _timer;
  bool _running = false;

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 10), (_) {
      _processQueue();
    });
    _processQueue();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _processQueue() async {
    if (_running) return;
    _running = true;
    try {
      final online = await _isOnline();
      if (!online) return;
      final items = await _queueStorage.loadQueue();
      if (items.isEmpty) return;

      final remaining = <SyncQueueItem>[];
      for (final item in items) {
        final success = await _handle(item);
        if (!success) {
          remaining.add(item.copyWith(retryCount: item.retryCount + 1));
        }
      }
      await _queueStorage.saveQueueItems(remaining);
    } finally {
      _running = false;
    }
  }

  Future<bool> _handle(SyncQueueItem item) async {
    try {
      switch (item.type) {
        case 'create_list':
        case 'update_list':
          await _firestoreService.upsertGroceryList(
            ShoppingList.fromJson(item.payload),
          );
          return true;
        case 'update_item':
          await _firestoreService.upsertItem(
            GroceryItem.fromJson(item.payload),
          );
          return true;
        case 'delete_item':
          final listId = item.payload['listId']?.toString();
          final itemId = item.payload['id']?.toString();
          if (listId == null || itemId == null) return true;
          await _firestoreService.deleteItem(listId, itemId);
          return true;
        case 'user_item_upsert':
          await _firestoreService.upsertUserItem(item.payload);
          await _markUserItemSynced(item.payload);
          return true;
        default:
          return true;
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> _markUserItemSynced(Map<String, dynamic> payload) async {
    final name = payload['name']?.toString() ?? '';
    if (name.trim().isEmpty) return;
    final items = await _userItemStorage.loadUserItems();
    final normalized = name.toLowerCase().trim();
    final index = items.indexWhere(
      (item) => item.name.toLowerCase().trim() == normalized,
    );
    if (index == -1) return;
    final existing = items[index];
    items[index] = UserItem(
      id: existing.id,
      name: existing.name,
      category: existing.category,
      unit: existing.unit,
      createdAt: existing.createdAt,
      updatedAt: existing.updatedAt,
      pendingSync: false,
    );
    await _userItemStorage.saveUserItems(items);
  }

  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    if (results.isEmpty) return false;
    if (results.contains(ConnectivityResult.none)) return false;
    return true;
  }
}
