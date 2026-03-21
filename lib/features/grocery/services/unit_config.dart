import '../domain/grocery_unit.dart';

class UnitConfig {
  const UnitConfig(this.suggestionsByUnit);

  final Map<GroceryUnit, List<double>> suggestionsByUnit;

  List<GroceryUnit> get units => suggestionsByUnit.keys.toList();

  List<double> suggestionsFor(GroceryUnit unit) {
    return suggestionsByUnit[unit] ?? const [];
  }
}

class UnitConfigResolver {
  static const UnitConfig dairy = UnitConfig({
    GroceryUnit.ml: [250, 500, 1000],
    GroceryUnit.litre: [1, 2],
  });
  static const UnitConfig spices = UnitConfig({
    GroceryUnit.g: [50, 100, 250, 500],
  });
  static const UnitConfig grains = UnitConfig({
    GroceryUnit.kg: [1, 2, 5],
  });
  static const UnitConfig vegetables = UnitConfig({
    GroceryUnit.kg: [0.5, 1, 2],
    GroceryUnit.pcs: [1, 2, 3],
  });
  static const UnitConfig general = UnitConfig({
    GroceryUnit.pcs: [1, 2, 3],
    GroceryUnit.packet: [1, 2, 3],
  });

  static UnitConfig resolve(String name, String category) {
    final normalizedName = _normalize(name);
    final normalizedCategory = _normalize(category);

    if (normalizedName.contains('milk') || normalizedCategory.contains('dairy')) {
      return dairy;
    }
    if (normalizedName.contains('ghee') ||
        normalizedName.contains('curry powder') ||
        normalizedCategory.contains('spice') ||
        normalizedCategory.contains('oil')) {
      return spices;
    }
    if (normalizedCategory.contains('grain') ||
        normalizedCategory.contains('flour') ||
        normalizedCategory.contains('rice') ||
        normalizedCategory.contains('dal')) {
      return grains;
    }
    if (normalizedCategory.contains('vegetable')) {
      return vegetables;
    }
    return general;
  }

  static GroceryUnit defaultUnit(String name, String category) {
    final config = resolve(name, category);
    final units = config.units.toSet().toList();
    return units.isEmpty ? GroceryUnit.pcs : units.first;
  }

  static String _normalize(String input) {
    return input.toLowerCase().trim();
  }
}
