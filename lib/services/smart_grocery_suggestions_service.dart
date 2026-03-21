import 'dart:math';

import '../data/models/smart_grocery_suggestion.dart';
import '../features/grocery/data/grocery_repository.dart';
import '../features/grocery/domain/grocery_unit.dart';
import '../features/pantry/domain/pantry_item.dart';
import '../features/pantry/services/consumption_service.dart';
import '../features/pantry/services/pantry_service.dart';
import '../features/pantry/services/pantry_storage.dart';
import '../features/pantry/services/pantry_unit_mapper.dart';

class SmartGrocerySuggestionsService {
  SmartGrocerySuggestionsService({
    PantryService? pantryService,
    ConsumptionService? consumptionService,
    GroceryRepository? groceryRepository,
    PantryUnitMapper? unitMapper,
    PantryStorage? pantryStorage,
  })  : _pantryService = pantryService ?? PantryService(),
        _consumptionService = consumptionService ?? ConsumptionService(),
        _groceryRepository = groceryRepository ?? GroceryRepository(),
        _unitMapper = unitMapper ?? PantryUnitMapper(),
        _pantryStorage = pantryStorage ?? PantryStorage();

  final PantryService _pantryService;
  final ConsumptionService _consumptionService;
  final GroceryRepository _groceryRepository;
  final PantryUnitMapper _unitMapper;
  final PantryStorage _pantryStorage;

  Future<List<SmartGrocerySuggestion>> getSuggestions({int limit = 10}) async {
    final suggestions = <String, SmartGrocerySuggestion>{};
    final categoryMemory = await _pantryStorage.loadCategoryMemory();

    final items = await _pantryService.getItems();
    for (final item in items.where(_isLowStock)) {
      final key = _normalize(item.name);
      suggestions[key] = SmartGrocerySuggestion(
        name: item.name,
        reason: 'Low stock',
        category: _categoryFor(item, categoryMemory),
      );
    }

    final expiring = await _pantryService.expiringSoon(days: 3);
    for (final item in expiring) {
      final key = _normalize(item.name);
      suggestions[key] = SmartGrocerySuggestion(
        name: item.name,
        reason: 'Expiring soon',
        category: _categoryFor(item, categoryMemory),
      );
    }

    final frequent = await _frequentUsage(limit: 5);
    for (final item in frequent) {
      final key = _normalize(item.name);
      suggestions.putIfAbsent(
        key,
        () => SmartGrocerySuggestion(
          name: item.name,
          reason: 'Frequently used',
          category: _categoryFor(item, categoryMemory),
        ),
      );
    }

    return suggestions.values.take(limit).toList();
  }

  Future<void> addSuggestionsToList(
    String listId,
    List<SmartGrocerySuggestion> suggestions,
  ) async {
    for (final suggestion in suggestions) {
      final unitLabel = _unitMapper.unitForName(suggestion.name);
      await _groceryRepository.addItem(
        listId: listId,
        name: suggestion.name,
        quantity: 1,
        unit: _unitFromLabel(unitLabel),
        categoryId: suggestion.category,
      );
    }
  }

  Future<List<PantryItem>> _frequentUsage({int limit = 5}) async {
    final events = await _consumptionService.getEvents();
    if (events.isEmpty) return [];
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final recent = events.where((event) => event.timestamp.isAfter(cutoff));
    final counts = <String, int>{};
    for (final event in recent) {
      final key = _normalize(event.itemName);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    if (counts.isEmpty) return [];

    final items = await _pantryService.getItems();
    final map = <String, PantryItem>{
      for (final item in items) _normalize(item.name): item,
    };

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(min(limit, sorted.length));
    return top
        .map((entry) => map[entry.key])
        .whereType<PantryItem>()
        .toList();
  }

  bool _isLowStock(PantryItem item) {
    final unit = item.unit.toLowerCase();
    if (unit == 'g' || unit == 'ml') {
      return item.quantity <= 500;
    }
    if (unit == 'kg' || unit == 'litre' || unit == 'l') {
      return item.quantity <= 1;
    }
    return item.quantity <= 1;
  }

  String _categoryFor(
    PantryItem item,
    Map<String, String> memory,
  ) {
    final key = _normalize(item.name);
    return memory[key] ?? '';
  }

  GroceryUnit _unitFromLabel(String label) {
    switch (label.toLowerCase()) {
      case 'g':
        return GroceryUnit.g;
      case 'kg':
        return GroceryUnit.kg;
      case 'ml':
        return GroceryUnit.ml;
      case 'litre':
      case 'l':
        return GroceryUnit.litre;
      case 'pcs':
      case 'piece':
      case 'pieces':
        return GroceryUnit.pcs;
      default:
        return GroceryUnit.item;
    }
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
