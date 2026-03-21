import 'package:hive_flutter/hive_flutter.dart';

import '../../../data/default_grocery_catalog.dart';
import '../../pantry/data/kitchen_repository.dart';
import '../../pantry/domain/kitchen_item.dart';
import '../../pantry/services/kitchen_storage.dart';
import '../data/grocery_repository.dart';
import '../domain/grocery_item.dart';
import '../domain/user_item.dart';

class GrocerySearchItem {
  const GrocerySearchItem({
    required this.name,
    required this.category,
  });

  final String name;
  final String category;
}

class GrocerySearchData {
  const GrocerySearchData({
    required this.categories,
    required this.items,
  });

  final List<String> categories;
  final List<GrocerySearchItem> items;
}

class GrocerySearchService {
  static const String _customCategoryBox = 'category_box';
  static const Duration _syncCooldown = Duration(minutes: 10);
  static DateTime? _lastSyncAt;

  GrocerySearchService({
    GroceryRepository? groceryRepository,
    KitchenStorage? kitchenStorage,
    KitchenRepository? kitchenRepository,
  })  : _groceryRepository = groceryRepository ?? GroceryRepository(),
        _kitchenStorage = kitchenStorage ?? KitchenStorage(),
        _kitchenRepository = kitchenRepository ?? KitchenRepository();

  final GroceryRepository _groceryRepository;
  final KitchenStorage _kitchenStorage;
  final KitchenRepository _kitchenRepository;

  Future<GrocerySearchData> loadLocal() async {
    final groceryItems = await _groceryRepository.getAllItems();
    final pantryItems = await _kitchenStorage.loadItems();
    final userItems = await _groceryRepository.getUserItems();
    final customCategories = await _loadCustomCategories();

    final categories = <String>{};
    categories.addAll(DefaultGroceryCatalog.categories.keys);
    categories.addAll(_categoriesFromGrocery(groceryItems));
    categories.addAll(_categoriesFromUser(userItems));
    categories.addAll(_categoriesFromPantry(pantryItems));
    categories.addAll(customCategories);

    final items = _buildItems(
      groceryItems: groceryItems,
      pantryItems: pantryItems,
      userItems: userItems,
    );

    return GrocerySearchData(
      categories: categories.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
      items: items,
    );
  }

  Future<GrocerySearchData> syncRemoteAndLoad() async {
    if (_lastSyncAt != null &&
        DateTime.now().difference(_lastSyncAt!) < _syncCooldown) {
      return loadLocal();
    }
    await _groceryRepository.syncFromRemote();
    await _kitchenRepository.getItems();
    _lastSyncAt = DateTime.now();
    return loadLocal();
  }

  List<GrocerySearchItem> _buildItems({
    required List<GroceryItem> groceryItems,
    required List<UserItem> userItems,
    required List<KitchenItem> pantryItems,
  }) {
    final items = <GrocerySearchItem>[];
    final added = <String>{};

    for (final entry in DefaultGroceryCatalog.categories.entries) {
      for (final item in entry.value) {
        final key = _normalize(item);
        if (added.add(key)) {
          items.add(GrocerySearchItem(name: item, category: entry.key));
        }
      }
    }

    for (final item in groceryItems) {
      final key = _normalize(item.name);
      if (key.isEmpty || !added.add(key)) continue;
      items.add(
        GrocerySearchItem(
          name: item.name,
          category: item.categoryId.isEmpty ? 'Miscellaneous' : item.categoryId,
        ),
      );
    }

    for (final item in pantryItems) {
      final name = item.name;
      final key = _normalize(name);
      if (key.isEmpty || !added.add(key)) continue;
      items.add(
        GrocerySearchItem(
          name: name,
          category: item.category,
        ),
      );
    }

    for (final item in userItems) {
      final name = item.name;
      final key = _normalize(name);
      if (key.isEmpty || !added.add(key)) continue;
      items.add(
        GrocerySearchItem(
          name: name,
          category: item.category,
        ),
      );
    }

    return items;
  }

  Iterable<String> _categoriesFromGrocery(List<GroceryItem> items) {
    return items
        .map((item) => item.categoryId.isEmpty ? 'Miscellaneous' : item.categoryId)
        .where((category) => category.trim().isNotEmpty);
  }

  Iterable<String> _categoriesFromUser(List<UserItem> items) {
    return items.map((item) => item.category).where((category) => category.trim().isNotEmpty);
  }

  Iterable<String> _categoriesFromPantry(List<KitchenItem> items) {
    return items
        .map((item) => item.category)
        .where((category) => category.trim().isNotEmpty);
  }

  String _normalize(String input) => input.toLowerCase().trim();

  Future<List<String>> _loadCustomCategories() async {
    if (Hive.isBoxOpen(_customCategoryBox)) {
      return Hive.box<String>(_customCategoryBox)
          .values
          .map((value) => value.toString())
          .where((value) => value.trim().isNotEmpty)
          .toList();
    }
    final box = await Hive.openBox<String>(_customCategoryBox);
    return box.values
        .map((value) => value.toString())
        .where((value) => value.trim().isNotEmpty)
        .toList();
  }
}
