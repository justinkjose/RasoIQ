class PantryUnitMapper {
  static const Map<String, String> categoryUnits = {
    'grains': 'kg',
    'flours': 'kg',
    'spices': 'g',
    'dairy': 'litre',
    'oils': 'litre',
    'vegetables': 'kg',
    'fruits': 'kg',
    'beverages': 'litre',
  };

  static const Map<String, String> keywordUnits = {
    'milk': 'litre',
    'oil': 'litre',
    'powder': 'g',
    'rice': 'kg',
    'onion': 'kg',
    'tomato': 'kg',
  };

  String unitForCategory(String category) {
    return categoryUnits[category.toLowerCase()] ?? 'kg';
  }

  String unitForName(String name) {
    final normalized = name.toLowerCase();
    for (final entry in keywordUnits.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }
    return 'kg';
  }
}
