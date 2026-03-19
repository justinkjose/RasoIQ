import 'dart:math';

import '../domain/pantry_item.dart';
import '../domain/smart_suggestion.dart';
import 'consumption_service.dart';
import 'pantry_insights.dart';
import 'pantry_storage.dart';
import 'pantry_unit_mapper.dart';

class PantryService {
  PantryService({PantryStorage? storage, PantryUnitMapper? unitMapper})
      : _storage = storage ?? PantryStorage(),
        _unitMapper = unitMapper ?? PantryUnitMapper(),
        _consumptionService = ConsumptionService(storage: storage);

  final PantryStorage _storage;
  final PantryUnitMapper _unitMapper;
  final ConsumptionService _consumptionService;

  static const _staples = <String>[
    'milk',
    'rice',
    'flour',
    'atta',
    'oil',
    'salt',
    'sugar',
    'eggs',
    'bread',
    'tea',
  ];

  Future<List<PantryItem>> getItems() async {
    final items = await _storage.loadItems();
    items.sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  Future<void> addItem({
    required String name,
    required double quantity,
    required String unit,
    DateTime? expiryDate,
    String? category,
  }) async {
    final items = await _storage.loadItems();
    final normalized = _normalizeName(name);
    final index = items.indexWhere((item) => item.normalizedName == normalized);
    final categoryMemory = await _storage.loadCategoryMemory();
    final resolvedCategory = category ?? categoryMemory[normalized] ?? _inferCategory(name);

    if (resolvedCategory.isNotEmpty) {
      categoryMemory[normalized] = resolvedCategory;
      await _storage.saveCategoryMemory(categoryMemory);
    }

    final mappedUnit = unit.isEmpty
        ? (resolvedCategory.isNotEmpty
            ? _unitMapper.unitForCategory(resolvedCategory)
            : _unitMapper.unitForName(name))
        : unit;

    if (index == -1) {
      items.add(
        PantryItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: name.trim(),
          normalizedName: normalized,
          quantity: max(0.1, quantity).toDouble(),
          unit: mappedUnit,
          expiryDate: expiryDate,
        ),
      );
    } else {
      final item = items[index];
      final updatedExpiry = _mergeExpiry(item.expiryDate, expiryDate);
      items[index] = item.copyWith(
        quantity: item.quantity + max(0.1, quantity).toDouble(),
        unit: mappedUnit.isEmpty ? item.unit : mappedUnit,
        expiryDate: updatedExpiry,
      );
    }

    await _storage.saveItems(items);
  }

  Future<void> consumeStock({required String itemId, required double quantity}) async {
    if (quantity <= 0) return;
    final items = await _storage.loadItems();
    final index = items.indexWhere((item) => item.id == itemId);
    if (index == -1) return;

    final item = items[index];
    final remaining = max(0, item.quantity - quantity).toDouble();
    if (remaining <= 0) {
      items.removeAt(index);
    } else {
      items[index] = item.copyWith(quantity: remaining);
    }

    await _consumptionService.recordConsumption(
      itemName: _normalizeName(item.name),
      quantity: quantity,
    );
    await _storage.saveItems(items);
  }

  Future<List<PantryItem>> expiringSoon({int days = 7}) async {
    final items = await _storage.loadItems();
    final threshold = DateTime.now().add(Duration(days: days));
    return items
        .where(
          (item) => item.expiryDate != null && item.expiryDate!.isBefore(threshold),
        )
        .toList();
  }

  Future<List<PantryItem>> lowStockItems() async {
    final items = await _storage.loadItems();
    return items.where(_isLowStock).toList();
  }

  Future<List<SmartSuggestion>> getSuggestions({int limit = 8}) async {
    final items = await _storage.loadItems();
    final memory = await _storage.loadCategoryMemory();
    final lowStock = items.where(_isLowStock).toList();
    final missingStaples = _missingStaples(items);

    final suggestions = <SmartSuggestion>[];
    for (final item in lowStock) {
      suggestions.add(
        SmartSuggestion(
          name: item.name,
          reason: 'Low stock',
          category: _resolveCategory(item, memory),
        ),
      );
    }

    for (final staple in missingStaples) {
      suggestions.add(
        SmartSuggestion(
          name: _titleCase(staple),
          reason: 'Missing staple',
          category: _resolveCategoryName(staple, memory),
        ),
      );
    }

    final map = <String, SmartSuggestion>{};
    for (final suggestion in suggestions) {
      map.putIfAbsent(suggestion.name.toLowerCase(), () => suggestion);
    }

    return map.values.take(limit).toList();
  }

  Future<Map<String, List<PantryItem>>> groupByCategory() async {
    final items = await _storage.loadItems();
    final memory = await _storage.loadCategoryMemory();
    final map = <String, List<PantryItem>>{};
    for (final item in items) {
      final category = memory[item.normalizedName] ?? _inferCategory(item.name);
      final key = category.isEmpty ? 'Uncategorized' : _titleCase(category);
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }

  Future<PantryInsights> getInsights() async {
    final items = await _storage.loadItems();
    final categories = await groupByCategory();
    final consumption = await _consumptionService.getEvents();

    final expiringSoonCount = items
        .where(
          (item) => item.expiryDate != null &&
              item.expiryDate!.isBefore(DateTime.now().add(const Duration(days: 2))),
        )
        .length;

    final lowStockCount = items.where(_isLowStock).length;
    final expiredCount = items.where(_isExpired).length;

    final wasteCount = await _recordWasteEvents(items);

    String mostStocked = 'Uncategorized';
    double maxStock = -1;
    for (final entry in categories.entries) {
      final total = entry.value.fold<double>(0, (sum, item) => sum + item.quantity);
      if (total > maxStock) {
        maxStock = total;
        mostStocked = entry.key;
      }
    }

    final usageCount = <String, int>{};
    for (final event in consumption) {
      final key = event.itemName;
      usageCount[key] = (usageCount[key] ?? 0) + 1;
    }
    String mostUsedItem = 'None';
    if (usageCount.isNotEmpty) {
      final top = usageCount.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      final item = items.firstWhere(
        (element) => element.normalizedName == top.key,
        orElse: () => const PantryItem(
          id: '',
          name: 'Unknown',
          normalizedName: '',
          quantity: 0,
          unit: '',
          expiryDate: null,
        ),
      );
      mostUsedItem = item.name.isEmpty ? _titleCase(top.key) : item.name;
    }

    var healthScore = 100;
    if (items.isNotEmpty) {
      healthScore -= expiredCount * 20;
      healthScore -= lowStockCount * 10;
      healthScore -= wasteCount * 15;
    }
    healthScore = healthScore.clamp(0, 100).toInt();

    return PantryInsights(
      expiringSoonCount: expiringSoonCount,
      lowStockCount: lowStockCount,
      missingStaplesCount: _missingStaples(items).length,
      mostStockedCategory: mostStocked,
      mostUsedItem: mostUsedItem,
      wasteCount: wasteCount,
      healthScore: healthScore,
    );
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

  bool _isExpired(PantryItem item) {
    final expiry = item.expiryDate;
    if (expiry == null) return false;
    return expiry.isBefore(DateTime.now());
  }

  Future<int> _recordWasteEvents(List<PantryItem> items) async {
    final events = await _storage.loadWasteEvents();
    final now = DateTime.now();
    final todayKey = _dateKey(now);
    final logged = <String, String>{
      for (final event in events) event['itemId'].toString(): event['date'].toString(),
    };

    for (final item in items.where(_isExpired)) {
      final last = logged[item.id];
      if (last == todayKey) continue;
      events.add({
        'itemId': item.id,
        'date': todayKey,
        'timestamp': now.toIso8601String(),
      });
      logged[item.id] = todayKey;
    }

    await _storage.saveWasteEvents(events);
    return events.length;
  }

  DateTime? _mergeExpiry(DateTime? existing, DateTime? incoming) {
    if (existing == null) return incoming;
    if (incoming == null) return existing;
    return incoming.isBefore(existing) ? incoming : existing;
  }

  String _normalizeName(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _inferCategory(String name) {
    final lowered = name.toLowerCase();
    if (lowered.contains('rice') || lowered.contains('grain')) return 'grains';
    if (lowered.contains('flour') || lowered.contains('atta')) return 'flours';
    if (lowered.contains('spice') || lowered.contains('masala')) return 'spices';
    if (lowered.contains('milk') || lowered.contains('cheese')) return 'dairy';
    if (lowered.contains('oil') || lowered.contains('ghee')) return 'oils';
    if (lowered.contains('onion') || lowered.contains('tomato')) return 'vegetables';
    if (lowered.contains('apple') || lowered.contains('banana')) return 'fruits';
    if (lowered.contains('juice') || lowered.contains('soda')) return 'beverages';
    return '';
  }

  String _resolveCategory(PantryItem item, Map<String, String> memory) {
    return _resolveCategoryName(item.normalizedName, memory);
  }

  String _resolveCategoryName(String normalizedName, Map<String, String> memory) {
    final category = memory[normalizedName] ?? _inferCategory(normalizedName);
    if (category.isEmpty) return 'Uncategorized';
    return _titleCase(category);
  }

  List<String> _missingStaples(List<PantryItem> items) {
    final normalized = items.map((item) => item.normalizedName).toSet();
    return _staples.where((staple) => !normalized.contains(staple)).toList();
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
