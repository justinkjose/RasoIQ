import '../data/grocery_repository.dart';
import '../services/grocery_item_parser.dart';
import '../services/unit_config.dart';
import '../services/unit_normalizer.dart';
import '../../../data/default_grocery_catalog.dart';
import '../domain/grocery_unit.dart';

class GroceryInputHandler {
  GroceryInputHandler({
    GroceryRepository? repository,
    GroceryItemParser? parser,
  })  : _repository = repository ?? GroceryRepository(),
        _parser = parser ?? const GroceryItemParser();

  final GroceryRepository _repository;
  final GroceryItemParser _parser;

  List<ParsedGroceryItem> parseInput(String input) {
    return _parser.parse(input);
  }

  Future<int> addItems({
    required String listId,
    required List<ParsedGroceryItem> items,
  }) async {
    var added = 0;
    for (final item in items) {
      final name = item.name.trim();
      if (name.isEmpty) continue;
      final category = _detectCategory(name);
      final resolvedUnit = item.unit == GroceryUnit.item
          ? UnitConfigResolver.defaultUnit(name, category)
          : item.unit;
      final normalized =
          UnitNormalizer.normalize(item.quantity, resolvedUnit);
      await _repository.addItem(
        listId: listId,
        name: name,
        quantity: normalized.quantity,
        unit: normalized.unit,
        categoryId: category,
      );
      added += 1;
    }
    return added;
  }

  String _detectCategory(String name) {
    for (final entry in DefaultGroceryCatalog.categories.entries) {
      for (final item in entry.value) {
        if (item.toLowerCase() == name.toLowerCase()) {
          return entry.key;
        }
      }
    }
    return 'Miscellaneous';
  }
}
