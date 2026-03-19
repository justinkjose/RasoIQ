import 'dart:convert';
import 'dart:math';

import '../domain/grocery_item.dart';
import '../domain/grocery_unit.dart';
import '../domain/shopping_list.dart';
import 'grocery_storage.dart';
import 'user_item_storage.dart';
import '../../../services/category_memory_service.dart';
import '../../../data/default_grocery_catalog.dart';
import '../domain/user_item.dart';

class GroceryRepository {
  GroceryRepository({
    GroceryStorage? storage,
    CategoryMemoryService? categoryMemory,
    UserItemStorage? userItemStorage,
  })  : _storage = storage ?? GroceryStorage(),
        _categoryMemory = categoryMemory ?? CategoryMemoryService(),
        _userItemStorage = userItemStorage ?? UserItemStorage();

  final GroceryStorage _storage;
  final CategoryMemoryService _categoryMemory;
  final UserItemStorage _userItemStorage;

  Future<List<ShoppingList>> getLists() async {
    final lists = await _storage.loadShoppingLists();
    lists.sort((a, b) => b.createdDate.compareTo(a.createdDate));
    return lists;
  }

  Future<ShoppingList> createList({required String name, required String icon}) async {
    final lists = await _storage.loadShoppingLists();
    final list = ShoppingList(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      icon: icon,
      createdDate: DateTime.now(),
      isArchived: false,
    );
    lists.add(list);
    await _storage.saveShoppingLists(lists);
    return list;
  }

  Future<List<GroceryItem>> getItemsForList(String listId) async {
    final items = await _storage.loadGroceryItems();
    return items.where((item) => item.listId == listId).toList();
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
    final items = await _storage.loadGroceryItems();
    final normalized = normalizeName(name);
    final learnedCategory = categoryId.isEmpty
        ? await _categoryMemory.getCategoryFor(name)
        : categoryId;
    final resolvedCategory =
        (learnedCategory == null || learnedCategory.trim().isEmpty)
            ? 'uncategorized'
            : learnedCategory.trim();
    final existingIndex = items.indexWhere(
      (item) => item.listId == listId && item.normalizedName == normalized,
    );

    if (existingIndex != -1) {
      final existing = items[existingIndex];
      items[existingIndex] = existing.copyWith(
        quantity: existing.quantity + max(0.1, quantity),
        isImportant: existing.isImportant || isImportant,
        packCount: existing.packCount + packCount,
        packSize: packSize > 0 ? packSize : existing.packSize,
        isDone: false,
      );
    } else {
      items.add(
        GroceryItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          listId: listId,
          name: name.trim(),
          normalizedName: normalized,
          quantity: max(0.1, quantity),
          packCount: packCount,
          packSize: packSize,
          unit: unit,
          categoryId: resolvedCategory,
          isDone: false,
          isImportant: isImportant,
          isUnavailable: false,
          expiryDate: null,
          createdAt: DateTime.now(),
        ),
      );
    }

    await _storage.saveGroceryItems(items);
    await _addRecentItem(name.trim());
    if (resolvedCategory != 'uncategorized') {
      await _categoryMemory.saveCategoryFor(name.trim(), resolvedCategory);
    }
    await _maybeLearnUserItem(name.trim(), resolvedCategory);
  }

  Future<void> toggleDone(String itemId) async {
    final items = await _storage.loadGroceryItems();
    final index = items.indexWhere((item) => item.id == itemId);
    if (index == -1) return;
    final item = items[index];
    items[index] = item.copyWith(isDone: !item.isDone);
    await _storage.saveGroceryItems(items);
  }

  Future<void> toggleImportant(String itemId) async {
    final items = await _storage.loadGroceryItems();
    final index = items.indexWhere((item) => item.id == itemId);
    if (index == -1) return;
    final item = items[index];
    items[index] = item.copyWith(isImportant: !item.isImportant);
    await _storage.saveGroceryItems(items);
  }

  Future<void> toggleUnavailable(String itemId) async {
    final items = await _storage.loadGroceryItems();
    final index = items.indexWhere((item) => item.id == itemId);
    if (index == -1) return;
    final item = items[index];
    items[index] = item.copyWith(isUnavailable: !item.isUnavailable);
    await _storage.saveGroceryItems(items);
  }

  Future<void> updateItem(
    String itemId, {
    double? quantity,
    GroceryUnit? unit,
    String? categoryId,
    bool? isDone,
    bool? isImportant,
    bool? isUnavailable,
    int? packCount,
    double? packSize,
  }) async {
    final items = await _storage.loadGroceryItems();
    final index = items.indexWhere((item) => item.id == itemId);
    if (index == -1) return;
    final item = items[index];
    items[index] = item.copyWith(
      quantity: quantity ?? item.quantity,
      unit: unit ?? item.unit,
      categoryId: categoryId ?? item.categoryId,
      isDone: isDone ?? item.isDone,
      isImportant: isImportant ?? item.isImportant,
      isUnavailable: isUnavailable ?? item.isUnavailable,
      packCount: packCount ?? item.packCount,
      packSize: packSize ?? item.packSize,
    );
    await _storage.saveGroceryItems(items);
  }

  Future<void> removeItem(String itemId) async {
    final items = await _storage.loadGroceryItems();
    items.removeWhere((item) => item.id == itemId);
    await _storage.saveGroceryItems(items);
  }

  Future<String> exportListToQr(String listId) async {
    final lists = await _storage.loadShoppingLists();
    final list = lists.firstWhere((item) => item.id == listId);
    final items = await getItemsForList(listId);

    final payload = {
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'list': {
        'name': list.name,
        'icon': list.icon,
      },
      'items': items
          .map(
            (item) => {
              'name': item.name,
              'qty': _formatQty(item),
            },
          )
          .toList(),
      'itemsDetailed': items
          .map(
            (item) => {
              'name': item.name,
              'quantity': item.quantity,
              'unit': item.unit.label,
              'categoryId': item.categoryId,
            },
          )
          .toList(),
    };

    return jsonEncode(payload);
  }

  Future<String> importListFromQr(String payload) async {
    final parsed = decodeQrPayload(payload);
    return importListPayload(parsed);
  }

  QrListPayload decodeQrPayload(String payload) {
    final decoded = jsonDecode(payload) as Map<String, dynamic>;
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

  String _formatQty(GroceryItem item) {
    final quantity = item.quantity % 1 == 0
        ? item.quantity.toStringAsFixed(0)
        : item.quantity.toStringAsFixed(1);
    return '$quantity${item.unit.label}';
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
    return _storage.loadRecentItems();
  }

  Future<List<UserItem>> getUserItems() async {
    return _userItemStorage.loadUserItems();
  }

  Future<void> _addRecentItem(String name) async {
    final items = await _storage.loadRecentItems();
    final normalized = normalizeName(name);
    items.removeWhere((item) => normalizeName(item) == normalized);
    items.insert(0, name);
    if (items.length > 20) {
      items.removeRange(20, items.length);
    }
    await _storage.saveRecentItems(items);
  }

  Future<void> _maybeLearnUserItem(String name, String categoryId) async {
    if (_isInDefaultCatalog(name)) return;
    final items = await _userItemStorage.loadUserItems();
    final normalized = normalizeName(name);
    final exists = items.any((item) => normalizeName(item.name) == normalized);
    if (exists) return;
    items.add(
      UserItem(
        name: name,
        category:
            (categoryId.isEmpty || categoryId == 'uncategorized')
                ? 'Miscellaneous'
                : categoryId,
        createdAt: DateTime.now(),
      ),
    );
    await _userItemStorage.saveUserItems(items);
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
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return stripped;
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



