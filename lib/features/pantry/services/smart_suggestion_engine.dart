import '../domain/pantry_item.dart';
import '../domain/smart_suggestion.dart';
import 'pantry_storage.dart';
import 'prediction_service.dart';

class SmartSuggestionEngine {
  SmartSuggestionEngine({
    PantryStorage? storage,
    PredictionService? predictionService,
  })  : _storage = storage ?? PantryStorage(),
        _predictionService = predictionService ?? PredictionService();

  final PantryStorage _storage;
  final PredictionService _predictionService;

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

  Future<List<SmartSuggestion>> getSuggestions({int limit = 12}) async {
    final items = await _storage.loadItems();
    final memory = await _storage.loadCategoryMemory();
    final predicted = await _predictionService.getPredictions();

    final suggestions = <SmartSuggestion>[];

    for (final item in items.where(_isLowStock)) {
      suggestions.add(
        SmartSuggestion(
          name: item.name,
          reason: 'Low stock',
          category: _resolveCategory(item, memory),
        ),
      );
    }

    for (final item in items.where(_isExpiringSoon)) {
      suggestions.add(
        SmartSuggestion(
          name: item.name,
          reason: 'Expiring soon',
          category: _resolveCategory(item, memory),
        ),
      );
    }

    final missing = _missingStaples(items);
    for (final staple in missing) {
      suggestions.add(
        SmartSuggestion(
          name: _titleCase(staple),
          reason: 'Missing staple',
          category: _resolveCategoryName(staple, memory),
        ),
      );
    }

    for (final item in predicted) {
      suggestions.add(
        SmartSuggestion(
          name: item.name,
          reason: 'Predicted',
          category: item.category,
        ),
      );
    }

    final map = <String, SmartSuggestion>{};
    for (final suggestion in suggestions) {
      map.putIfAbsent(suggestion.name.toLowerCase(), () => suggestion);
    }

    return map.values.take(limit).toList();
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

  bool _isExpiringSoon(PantryItem item) {
    final expiry = item.expiryDate;
    if (expiry == null) return false;
    return expiry.isBefore(DateTime.now().add(const Duration(days: 2)));
  }

  String _resolveCategory(PantryItem item, Map<String, String> memory) {
    return _resolveCategoryName(item.normalizedName, memory);
  }

  String _resolveCategoryName(String normalizedName, Map<String, String> memory) {
    final category = memory[normalizedName] ?? '';
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
}
