enum GroceryUnit {
  item,
  pcs,
  packet,
  kg,
  g,
  litre,
  ml,
}

extension GroceryUnitExtension on GroceryUnit {
  String get label {
    switch (this) {
      case GroceryUnit.item:
        return 'item';
      case GroceryUnit.pcs:
        return 'pcs';
      case GroceryUnit.packet:
        return 'packet';
      case GroceryUnit.kg:
        return 'kg';
      case GroceryUnit.g:
        return 'g';
      case GroceryUnit.litre:
        return 'L';
      case GroceryUnit.ml:
        return 'ml';
    }
  }
}
