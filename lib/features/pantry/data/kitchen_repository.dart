import 'dart:async';

import '../../pantry/domain/kitchen_item.dart';
import '../../pantry/services/kitchen_storage.dart';
import '../../../data/remote/kitchen_firestore_service.dart';
import '../../../services/auth_service.dart';

class KitchenRepository {
  KitchenRepository({
    KitchenStorage? storage,
    KitchenFirestoreService? firestoreService,
    AuthService? authService,
  })  : _storage = storage ?? KitchenStorage(),
        _firestoreService = firestoreService ?? KitchenFirestoreService(),
        _authService = authService ?? AuthService.instance;

  final KitchenStorage _storage;
  final KitchenFirestoreService _firestoreService;
  final AuthService _authService;

  StreamSubscription<List<KitchenItem>>? _subscription;
  DateTime? _lastRemoteSync;
  bool _syncInFlight = false;
  Timer? _syncDebounce;
  static const Duration _syncThrottle = Duration(seconds: 30);

  Future<List<KitchenItem>> getItems() async {
    return _storage.loadItems();
  }

  Future<void> syncFromRemote() async {
    if (_syncInFlight) return;
    final now = DateTime.now();
    if (_lastRemoteSync != null &&
        now.difference(_lastRemoteSync!) < _syncThrottle) {
      return;
    }
    _syncInFlight = true;
    try {
      final remote = await _firestoreService.fetchKitchenItems();
      if (remote.isEmpty) return;
      final local = await _storage.loadItems();
      final map = <String, KitchenItem>{
        for (final item in local) item.id: item,
      };
      for (final item in remote) {
        map.putIfAbsent(item.id, () => item);
      }
      await _storage.saveItems(map.values.toList());
      _lastRemoteSync = DateTime.now();
    } catch (_) {
      return;
    } finally {
      _syncInFlight = false;
    }
  }

  Future<void> startRealtimeSync({
    required Future<void> Function() onMerged,
  }) async {
    await _subscription?.cancel();
    _subscription = _firestoreService.streamKitchenItems().listen((_) async {
      _scheduleSync(onMerged);
    }, onError: (_) {});
  }

  void _scheduleSync(Future<void> Function() onMerged) {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(seconds: 2), () async {
      await syncFromRemote();
      await onMerged();
    });
  }

  Future<void> addItem(KitchenItem item) async {
    final userId = await _authService.ensureUserId();
    final normalized = item.userId.isEmpty
        ? item.copyWith(userId: userId)
        : item;
    final items = await _storage.loadItems();
    final existingIndex = items.indexWhere(
      (entry) => entry.name.toLowerCase() == normalized.name.toLowerCase(),
    );
    if (existingIndex != -1) {
      final existing = items[existingIndex];
      items[existingIndex] = existing.copyWith(
        batches: [...existing.batches, ...normalized.batches],
        userId: existing.userId.isEmpty ? userId : existing.userId,
      );
    } else {
      items.add(normalized);
    }
    await _storage.saveItems(items);
    unawaited(_firestoreService.upsertKitchenItem(
      existingIndex != -1 ? items[existingIndex] : normalized,
    ));
  }

  Future<void> addBatch(KitchenItem item, KitchenBatch batch) async {
    final userId = await _authService.ensureUserId();
    final items = await _storage.loadItems();
    final updated = items
        .map(
          (entry) => entry.id == item.id
              ? entry.copyWith(batches: [...entry.batches, batch])
              : entry,
        )
        .toList();
    await _storage.saveItems(updated);
    final refreshed = updated
        .firstWhere((entry) => entry.id == item.id)
        .copyWith(userId: item.userId.isEmpty ? userId : item.userId);
    unawaited(_firestoreService.upsertKitchenItem(refreshed));
  }

  Future<void> useQuantity(KitchenItem item, int quantity) async {
    final userId = await _authService.ensureUserId();
    final updatedBatches = item.batches.toList()
      ..sort((a, b) {
        final aDate = a.expiryDate ?? DateTime(9999);
        final bDate = b.expiryDate ?? DateTime(9999);
        return aDate.compareTo(bDate);
      });

    var remaining = quantity;
    final newBatches = <KitchenBatch>[];
    for (final batch in updatedBatches) {
      if (remaining <= 0) {
        newBatches.add(batch);
        continue;
      }
      final newQty = (batch.quantity - remaining).clamp(0, 999999).toInt();
      remaining = (remaining - batch.quantity).clamp(0, 999999).toInt();
      if (newQty > 0) {
        newBatches.add(batch.copyWith(quantity: newQty));
      }
    }

    final items = await _storage.loadItems();
    final updated = items
        .map(
          (entry) =>
              entry.id == item.id ? entry.copyWith(batches: newBatches) : entry,
        )
        .toList();
    await _storage.saveItems(updated);
    final refreshed = updated
        .firstWhere((entry) => entry.id == item.id)
        .copyWith(userId: item.userId.isEmpty ? userId : item.userId);
    unawaited(_firestoreService.upsertKitchenItem(refreshed));
  }

  Future<void> updateItem(KitchenItem item) async {
    final userId = await _authService.ensureUserId();
    final normalized =
        item.userId.isEmpty ? item.copyWith(userId: userId) : item;
    final items = await _storage.loadItems();
    final updated = items
        .map((entry) => entry.id == item.id ? normalized : entry)
        .toList();
    await _storage.saveItems(updated);
    unawaited(_firestoreService.upsertKitchenItem(normalized));
  }

  Future<void> deleteItem(KitchenItem item) async {
    final items = await _storage.loadItems();
    items.removeWhere((entry) => entry.id == item.id);
    await _storage.saveItems(items);
  }
}
