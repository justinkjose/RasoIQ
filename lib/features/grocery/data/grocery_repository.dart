import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:archive/archive.dart';

import '../domain/grocery_item.dart';
import '../domain/grocery_unit.dart';
import '../domain/shopping_list.dart';
import 'grocery_storage.dart';
import 'local_grocery_repository.dart';
import 'remote_grocery_repository.dart';
import 'grocery_sync_service.dart';
import 'user_item_storage.dart';
import '../../../services/category_memory_service.dart';
import '../../../data/default_grocery_catalog.dart';
import '../domain/user_item.dart';
import '../../../data/local/sync_queue_storage.dart';
import '../../../data/models/sync_queue_item.dart';
import '../../../services/auth_service.dart';
import '../../../services/analytics_service.dart';
import '../../../services/notification_service.dart';
import '../services/unit_normalizer.dart';

class GroceryRepository {
  GroceryRepository({
    GroceryStorage? storage,
    LocalGroceryRepository? localRepository,
    RemoteGroceryRepository? remoteRepository,
    GrocerySyncService? syncService,
    CategoryMemoryService? categoryMemory,
    UserItemStorage? userItemStorage,
    SyncQueueStorage? syncQueueStorage,
    AuthService? authService,
  })  : _localRepository =
            localRepository ?? LocalGroceryRepository(storage: storage),
        _remoteRepository = remoteRepository ?? RemoteGroceryRepository(),
        _syncService = syncService ??
            GrocerySyncService(
              localRepository:
                  localRepository ?? LocalGroceryRepository(storage: storage),
              remoteRepository: remoteRepository ?? RemoteGroceryRepository(),
            ),
        _categoryMemory = categoryMemory ?? CategoryMemoryService(),
        _userItemStorage = userItemStorage ?? UserItemStorage(),
        _syncQueueStorage = syncQueueStorage ?? SyncQueueStorage(),
        _authService = authService ?? AuthService.instance;

  final LocalGroceryRepository _localRepository;
  final RemoteGroceryRepository _remoteRepository;
  final GrocerySyncService _syncService;
  final CategoryMemoryService _categoryMemory;
  final UserItemStorage _userItemStorage;
  final SyncQueueStorage _syncQueueStorage;
  final AuthService _authService;
  StreamSubscription<List<ShoppingList>>? _listSubscription;
  final Map<String, StreamSubscription<List<GroceryItem>>> _itemSubscriptions =
      {};

  Future<List<ShoppingList>> getLists() async {
    final lists = await _localRepository.loadLists();
    final userId = _authService.userId;
    final filtered = userId.isEmpty
        ? lists
        : lists.where((list) {
            if (list.members.isEmpty) {
              return list.userId == userId;
            }
            return list.members.contains(userId);
          }).toList();
    filtered.sort((a, b) => b.createdDate.compareTo(a.createdDate));
    return filtered;
  }

  Future<ShoppingList> createList({
    required String name,
    required String icon,
  }) async {
    final userId = await _authService.ensureUserId();
    final lists = await _localRepository.loadLists();
    final now = DateTime.now();
    final list = ShoppingList(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      members: [userId],
      name: name.trim(),
      icon: icon,
      createdDate: now,
      updatedAt: now,
      isArchived: false,
    );
    lists.add(list);
    await _localRepository.saveLists(lists);
    await _syncQueueStorage.enqueue(
      SyncQueueItem.operation(
        type: 'create_list',
        collection: 'grocery_lists',
        entityId: list.id,
        payload: list.toJson(),
      ),
    );
    await AnalyticsService.instance.logListCreated(list.id);
    return list;
  }

  Future<void> updateListName(String listId, String name) async {
    final userId = await _authService.ensureUserId();
    final lists = await _localRepository.loadLists();
    final index = lists.indexWhere((list) => list.id == listId);
    if (index == -1) return;
    final existing = lists[index];
    final updated = existing.copyWith(
      name: name.trim(),
      updatedAt: DateTime.now(),
      userId: existing.userId.isEmpty ? userId : existing.userId,
      members: existing.members.isEmpty && userId.isNotEmpty
          ? [userId]
          : existing.members,
    );
    lists[index] = updated;
    await _localRepository.saveLists(lists);
    await _syncQueueStorage.enqueue(
      SyncQueueItem.operation(
        type: 'update_list',
        collection: 'grocery_lists',
        entityId: updated.id,
        payload: updated.toJson(),
      ),
    );
  }

  Future<void> deleteList(String listId) async {
    final lists = await _localRepository.loadLists();
    lists.removeWhere((list) => list.id == listId);
    await _localRepository.saveLists(lists);
    final items = await _localRepository.loadItems();
    items.removeWhere((item) => item.listId == listId);
    await _localRepository.saveItems(items);
  }

  Future<String> getShareCode(String listId) async {
    final lists = await _localRepository.loadLists();
    final list = lists.firstWhere(
      (entry) => entry.id == listId,
      orElse: () => ShoppingList(
        id: listId,
        name: 'Grocery List',
        icon: 'CART',
        createdDate: DateTime.now(),
        updatedAt: DateTime.now(),
        isArchived: false,
      ),
    );
    unawaited(NotificationService.instance.notifyListShared(list.name));
    return listId;
  }

  Future<String?> joinListByCode(String code) async {
    final userId = await _authService.ensureUserId();
    final list = await _remoteRepository.fetchListById(code);
    if (list != null) {
      if (!list.members.contains(userId)) {
        await _remoteRepository.addMemberToList(code, userId);
      }
      await syncFromRemote();
      return list.id;
    }

    final importedId = await importSharedList(code);
    if (importedId == null) {
      throw StateError('List not found');
    }
    return importedId;
  }

  Future<List<GroceryItem>> getItemsForList(String listId) async {
    if (listId.trim().isEmpty) {
      return [];
    }
    final items = await _localRepository.loadItems();
    return items.where((item) => item.listId == listId).toList();
  }

  Future<List<GroceryItem>> getAllItems() async {
    return _localRepository.loadItems();
  }

  Future<void> addItem({
    required String listId,
    required String name,
    required double quantity,
    required GroceryUnit unit,
    required String categoryId,
    bool isImportant = false,
    int packCount = 1,
    double packSize = 0,
  }) async {
    final items = await _localRepository.loadItems();
    final normalized = normalizeName(name);
    final learnedCategory =
        categoryId.isEmpty ? await _categoryMemory.getCategoryFor(name) : categoryId;
    final resolvedCategory =
        (learnedCategory == null || learnedCategory.trim().isEmpty)
            ? 'uncategorized'
            : learnedCategory.trim();
    final existingIndex = items.indexWhere(
      (item) => item.listId == listId && item.normalizedName == normalized,
    );

    final incoming = UnitNormalizer.normalize(quantity, unit);

    late final GroceryItem createdItem;
    final now = DateTime.now();
    final userId = await _authService.ensureUserId();
    if (existingIndex != -1) {
      final existing = items[existingIndex];
      final merged = UnitNormalizer.add(
        existing.quantity,
        existing.unit,
        incoming.quantity,
        incoming.unit,
      );
      final updated = existing.copyWith(
        quantity: max(0.1, merged.quantity),
        unit: merged.unit,
        isImportant: existing.isImportant || isImportant,
        packCount: existing.packCount + packCount,
        packSize: packSize > 0 ? packSize : existing.packSize,
        isDone: false,
        updatedAt: now,
        userId: existing.userId.isEmpty ? userId : existing.userId,
      );
      items[existingIndex] = updated;
      createdItem = updated;
    } else {
      createdItem = GroceryItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        listId: listId,
        userId: userId,
        name: name.trim(),
        normalizedName: normalized,
        quantity: max(0.1, incoming.quantity),
        packCount: packCount,
        packSize: packSize,
        unit: incoming.unit,
        categoryId: resolvedCategory,
        isDone: false,
        isImportant: isImportant,
        isUnavailable: false,
        expiryDate: null,
        createdAt: now,
        updatedAt: now,
      );
      items.add(createdItem);
    }

    await _localRepository.saveItems(items);
    await _syncQueueStorage.enqueue(
      SyncQueueItem.operation(
        type: 'update_item',
        collection: 'grocery_items',
        entityId: createdItem.id,
        payload: createdItem.toJson(),
      ),
    );
    unawaited(NotificationService.instance.notifyItemAdded(createdItem.name));
    await AnalyticsService.instance.logItemAdded(listId, createdItem.id);
    await _addRecentItem(name.trim());
    if (resolvedCategory != 'uncategorized') {
      await _categoryMemory.saveCategoryFor(name.trim(), resolvedCategory);
    }
    await _maybeLearnUserItem(name.trim(), resolvedCategory);
  }

  Future<void> toggleDone(String itemId) async {
    final items = await _localRepository.loadItems();
    final index = items.indexWhere((item) => item.id == itemId);
    if (index == -1) return;
    final item = items[index];
    final userId = await _authService.ensureUserId();
    final updated = item.copyWith(
      isDone: !item.isDone,
      updatedAt: DateTime.now(),
      userId: item.userId.isEmpty ? userId : item.userId,
    );
    items[index] = updated;
    await _localRepository.saveItems(items);
    await _syncQueueStorage.enqueue(
      SyncQueueItem.operation(
        type: 'update_item',
        collection: 'grocery_items',
        entityId: updated.id,
        payload: updated.toJson(),
      ),
    );
    unawaited(NotificationService.instance.notifyItemCompleted(updated.name));
  }

  Future<void> toggleImportant(String itemId) async {
    final items = await _localRepository.loadItems();
    final index = items.indexWhere((item) => item.id == itemId);
    if (index == -1) return;
    final item = items[index];
    final userId = await _authService.ensureUserId();
    final updated = item.copyWith(
      isImportant: !item.isImportant,
      updatedAt: DateTime.now(),
      userId: item.userId.isEmpty ? userId : item.userId,
    );
    items[index] = updated;
    await _localRepository.saveItems(items);
    await _syncQueueStorage.enqueue(
      SyncQueueItem.operation(
        type: 'update_item',
        collection: 'grocery_items',
        entityId: updated.id,
        payload: updated.toJson(),
      ),
    );
  }

  Future<void> toggleUnavailable(String itemId) async {
    final items = await _localRepository.loadItems();
    final index = items.indexWhere((item) => item.id == itemId);
    if (index == -1) return;
    final item = items[index];
    final userId = await _authService.ensureUserId();
    final updated = item.copyWith(
      isUnavailable: !item.isUnavailable,
      updatedAt: DateTime.now(),
      userId: item.userId.isEmpty ? userId : item.userId,
    );
    items[index] = updated;
    await _localRepository.saveItems(items);
    await _syncQueueStorage.enqueue(
      SyncQueueItem.operation(
        type: 'update_item',
        collection: 'grocery_items',
        entityId: updated.id,
        payload: updated.toJson(),
      ),
    );
  }

  Future<void> updateItem(
    String itemId, {
    String? name,
    double? quantity,
    GroceryUnit? unit,
    String? categoryId,
    bool? isDone,
    bool? isImportant,
    bool? isUnavailable,
    int? packCount,
    double? packSize,
  }) async {
    final items = await _localRepository.loadItems();
    final index = items.indexWhere((item) => item.id == itemId);
    if (index == -1) return;
    final item = items[index];
    final userId = await _authService.ensureUserId();
    final resolvedName = name?.trim();
    final normalizedName = resolvedName == null || resolvedName.isEmpty
        ? item.normalizedName
        : normalizeName(resolvedName);
    final resolvedQuantity = quantity ?? item.quantity;
    final resolvedUnit = unit ?? item.unit;
    final normalized = UnitNormalizer.normalize(resolvedQuantity, resolvedUnit);
    final updated = item.copyWith(
      name: resolvedName == null || resolvedName.isEmpty ? item.name : resolvedName,
      normalizedName: normalizedName,
      quantity: normalized.quantity,
      unit: normalized.unit,
      categoryId: categoryId ?? item.categoryId,
      isDone: isDone ?? item.isDone,
      isImportant: isImportant ?? item.isImportant,
      isUnavailable: isUnavailable ?? item.isUnavailable,
      packCount: packCount ?? item.packCount,
      packSize: packSize ?? item.packSize,
      updatedAt: DateTime.now(),
      userId: item.userId.isEmpty ? userId : item.userId,
    );
    items[index] = updated;
    await _localRepository.saveItems(items);
    await _syncQueueStorage.enqueue(
      SyncQueueItem.operation(
        type: 'update_item',
        collection: 'grocery_items',
        entityId: updated.id,
        payload: updated.toJson(),
      ),
    );
  }

  Future<void> removeItem(String itemId) async {
    final items = await _localRepository.loadItems();
    GroceryItem? removed;
    items.removeWhere((item) {
      if (item.id == itemId) {
        removed = item;
        return true;
      }
      return false;
    });
    await _localRepository.saveItems(items);
    if (removed != null) {
      await _syncQueueStorage.enqueue(
        SyncQueueItem.operation(
          type: 'delete_item',
          collection: 'grocery_items',
          entityId: removed!.id,
          payload: {
            'id': removed!.id,
            'listId': removed!.listId,
          },
        ),
      );
    }
  }

  Future<void> addCustomUserItem({
    required String name,
    required String category,
    required GroceryUnit unit,
  }) async {
    final normalized = normalizeName(name);
    if (normalized.isEmpty) return;
    final now = DateTime.now();
    final items = await _userItemStorage.loadUserItems();
    final index = items.indexWhere(
      (item) => normalizeName(item.name) == normalized,
    );
    final resolvedCategory =
        category.trim().isEmpty ? 'Miscellaneous' : category.trim();
    final unitLabel = unit.label;

    UserItem updated;
    if (index == -1) {
      updated = UserItem(
        id: normalized,
        name: name.trim(),
        category: resolvedCategory,
        unit: unitLabel,
        createdAt: now,
        updatedAt: now,
        pendingSync: true,
      );
      items.add(updated);
    } else {
      final existing = items[index];
      updated = UserItem(
        id: existing.id.isEmpty ? normalized : existing.id,
        name: name.trim(),
        category: resolvedCategory,
        unit: unitLabel,
        createdAt: existing.createdAt,
        updatedAt: now,
        pendingSync: true,
      );
      items[index] = updated;
    }

    await _userItemStorage.saveUserItems(items);
    await _syncQueueStorage.enqueue(
      SyncQueueItem.operation(
        type: 'user_item_upsert',
        collection: 'user_items',
        entityId: updated.id,
        payload: updated.toJson(),
      ),
    );
  }

  Future<String> exportListToQr(String listId) async {
    final lists = await _localRepository.loadLists();
    final list = lists.firstWhere((item) => item.id == listId);
    final items = await getItemsForList(listId);
    return encodeListForShare(list, items);
  }

  Future<String> importListFromQr(String payload) async {
    final parsed = decodeQrPayload(payload);
    return importListPayload(parsed);
  }

  Future<void> syncFromRemote() async {
    await _syncService.syncFromRemote();
  }

  Future<Map<String, dynamic>> buildSharePayload(String listId) async {
    final lists = await _localRepository.loadLists();
    ShoppingList? list;
    for (final entry in lists) {
      if (entry.id == listId) {
        list = entry;
        break;
      }
    }
    final items = await getItemsForList(listId);
    return {
      'name': list?.name ?? 'Grocery List',
      'items': items
          .map(
            (item) => {
              'name': item.name,
              'qty': item.quantity,
              'unit': item.unit.label,
              'category': item.categoryId,
              'completed': item.isDone,
            },
          )
          .toList(),
    };
  }

  QrListPayload decodeQrPayload(String payload) {
    final decoded = _decodeCompressedPayload(payload);
    final listRaw = decoded['list'] as Map<String, dynamic>? ?? {};
    final name = listRaw['name']?.toString() ?? 'Imported List';
    final icon = listRaw['icon']?.toString() ?? 'CART';

    final detailed = (decoded['itemsDetailed'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    final items = detailed.isNotEmpty
        ? detailed
            .map(
              (item) => QrItemPayload(
                name: item['name']?.toString() ?? 'Item',
                quantity: (item['quantity'] as num?)?.toDouble() ?? 1,
                unit: item['unit']?.toString() ?? 'item',
                categoryId: item['categoryId']?.toString() ?? 'uncategorized',
              ),
            )
            .toList()
        : (decoded['items'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>()
            .map(
              (item) {
                if (item.containsKey('n')) {
                  return QrItemPayload(
                    name: item['n']?.toString() ?? 'Item',
                    quantity: (item['q'] as num?)?.toDouble() ?? 1,
                    unit: item['u']?.toString() ?? 'item',
                    categoryId: item['c']?.toString() ?? 'uncategorized',
                  );
                }
                final parsed = _parseQtyString(item['qty']?.toString() ?? '1');
                return QrItemPayload(
                  name: item['name']?.toString() ?? 'Item',
                  quantity: parsed.quantity,
                  unit: parsed.unit,
                  categoryId: 'uncategorized',
                );
              },
            )
            .toList();

    return QrListPayload(name: name, icon: icon, items: items);
  }

  Future<String> importListPayload(QrListPayload payload) async {
    final list = await createList(name: payload.name, icon: payload.icon);
    for (final item in payload.items) {
      await addItem(
        listId: list.id,
        name: item.name,
        quantity: item.quantity,
        unit: _unitFromLabel(item.unit),
        categoryId: item.categoryId,
      );
    }
    return list.id;
  }

  Future<String?> importSharedList(String shareId) async {
    final payload = await _remoteRepository.fetchSharedList(shareId);
    if (payload == null) return null;
    final listRaw = payload['list'] as Map<String, dynamic>? ?? {};
    final itemsRaw = (payload['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    final name = listRaw['name']?.toString() ?? 'Shared List';
    final icon = listRaw['icon']?.toString() ?? 'CART';
    final list = await createList(name: name, icon: icon);

    for (final raw in itemsRaw) {
      final itemName = raw['name']?.toString() ?? 'Item';
      final qty = (raw['quantity'] as num?)?.toDouble() ?? 1;
      final unitLabel = raw['unit']?.toString() ?? 'item';
      final category = raw['categoryId']?.toString() ?? 'uncategorized';
      await addItem(
        listId: list.id,
        name: itemName,
        quantity: qty,
        unit: _unitFromLabel(unitLabel),
        categoryId: category,
      );
    }
    return list.id;
  }

  String encodeListForShare(ShoppingList list, List<GroceryItem> items) {
    final jsonStr = jsonEncode({
      'version': 2,
      'list': {
        'name': list.name,
        'icon': list.icon,
      },
      'items': items
          .map(
            (item) => {
              'n': item.name,
              'q': item.quantity,
              'u': item.unit.label,
              'c': item.categoryId,
              'd': item.isDone,
            },
          )
          .toList(),
    });
    final bytes = utf8.encode(jsonStr);
    final compressed = GZipEncoder().encode(bytes);
    if (compressed == null) return jsonStr;
    return base64Encode(compressed);
  }

  String encodeExportQr(ShoppingList list, List<GroceryItem> items) {
    final payload = encodeListForShare(list, items);
    return 'RASOIQ_EXPORT:$payload';
  }

  Map<String, dynamic> _decodeCompressedPayload(String payload) {
    try {
      final bytes = base64Decode(payload);
      final decompressed = GZipDecoder().decodeBytes(bytes);
      return jsonDecode(utf8.decode(decompressed)) as Map<String, dynamic>;
    } catch (_) {
      return jsonDecode(payload) as Map<String, dynamic>;
    }
  }

  GroceryUnit _unitFromLabel(String label) {
    switch (label.toLowerCase()) {
      case 'pcs':
        return GroceryUnit.pcs;
      case 'packet':
        return GroceryUnit.packet;
      case 'kg':
        return GroceryUnit.kg;
      case 'g':
        return GroceryUnit.g;
      case 'litre':
      case 'l':
        return GroceryUnit.litre;
      case 'ml':
        return GroceryUnit.ml;
      case 'item':
      default:
        return GroceryUnit.item;
    }
  }

  _ParsedQty _parseQtyString(String input) {
    final match = RegExp(r'(\\d+(?:\\.\\d+)?)\\s*([a-zA-Z]+)?')
        .firstMatch(input.trim());
    if (match == null) {
      return const _ParsedQty(quantity: 1, unit: 'item');
    }
    final quantity = double.tryParse(match.group(1) ?? '') ?? 1;
    final unit = (match.group(2) ?? 'item').toLowerCase();
    return _ParsedQty(quantity: quantity, unit: unit);
  }

  Future<List<String>> getRecentItems() async {
    return _localRepository.loadRecentItems();
  }

  Future<List<UserItem>> getUserItems() async {
    return _userItemStorage.loadUserItems();
  }

  Future<void> _addRecentItem(String name) async {
    final items = await _localRepository.loadRecentItems();
    final normalized = normalizeName(name);
    items.removeWhere((item) => normalizeName(item) == normalized);
    items.insert(0, name);
    if (items.length > 20) {
      items.removeRange(20, items.length);
    }
    await _localRepository.saveRecentItems(items);
  }

  Future<void> _maybeLearnUserItem(String name, String categoryId) async {
    if (_isInDefaultCatalog(name)) return;
    final items = await _userItemStorage.loadUserItems();
    final normalized = normalizeName(name);
    final exists = items.any((item) => normalizeName(item.name) == normalized);
    if (exists) return;
    final now = DateTime.now();
    final created = UserItem(
      id: normalized,
      name: name,
      category:
          (categoryId.isEmpty || categoryId == 'uncategorized')
              ? 'Miscellaneous'
              : categoryId,
      unit: GroceryUnit.item.label,
      createdAt: now,
      updatedAt: now,
      pendingSync: true,
    );
    items.add(created);
    await _userItemStorage.saveUserItems(items);
    await _syncQueueStorage.enqueue(
      SyncQueueItem.operation(
        type: 'user_item_upsert',
        collection: 'user_items',
        entityId: created.id,
        payload: created.toJson(),
      ),
    );
  }

  bool _isInDefaultCatalog(String name) {
    final normalized = normalizeName(name);
    for (final entry in DefaultGroceryCatalog.categories.entries) {
      for (final item in entry.value) {
        if (normalizeName(item) == normalized) return true;
      }
    }
    return false;
  }

  String normalizeName(String input) {
    final stripped = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\\s]'), ' ')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
    return stripped;
  }

  Future<void> startRealtimeSync({
    required Future<void> Function() onMerged,
  }) async {
    await _stopRealtimeSync();
    _listSubscription =
        _remoteRepository.streamLists().listen((lists) async {
      await _syncService.scheduleSync(onMerged);
      await _updateItemSubscriptions(lists, onMerged);
    }, onError: (_) {});
  }

  Future<void> _updateItemSubscriptions(
    List<ShoppingList> lists,
    Future<void> Function() onMerged,
  ) async {
    final activeIds = lists.map((list) => list.id).toSet();
    final existingIds = _itemSubscriptions.keys.toSet();
    for (final id in existingIds.difference(activeIds)) {
      await _itemSubscriptions[id]?.cancel();
      _itemSubscriptions.remove(id);
    }
    for (final id in activeIds.difference(existingIds)) {
      _itemSubscriptions[id] =
          _remoteRepository.streamItems(id).listen((_) async {
        await _syncService.scheduleSync(onMerged);
      }, onError: (_) {});
    }
  }

  Future<void> _stopRealtimeSync() async {
    await _listSubscription?.cancel();
    _listSubscription = null;
    for (final entry in _itemSubscriptions.values) {
      await entry.cancel();
    }
    _itemSubscriptions.clear();
    await _syncService.stop();
  }
}

class QrListPayload {
  const QrListPayload({
    required this.name,
    required this.icon,
    required this.items,
  });

  final String name;
  final String icon;
  final List<QrItemPayload> items;
}

class QrItemPayload {
  const QrItemPayload({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.categoryId,
  });

  final String name;
  final double quantity;
  final String unit;
  final String categoryId;
}

class _ParsedQty {
  const _ParsedQty({required this.quantity, required this.unit});

  final double quantity;
  final String unit;
}
