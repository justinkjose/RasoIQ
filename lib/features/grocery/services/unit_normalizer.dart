import '../domain/grocery_unit.dart';

class NormalizedQuantity {
  const NormalizedQuantity(this.quantity, this.unit);

  final double quantity;
  final GroceryUnit unit;
}

class UnitNormalizer {
  static NormalizedQuantity normalize(double quantity, GroceryUnit unit) {
    if (unit == GroceryUnit.g && quantity >= 1000) {
      return NormalizedQuantity(quantity / 1000, GroceryUnit.kg);
    }
    if (unit == GroceryUnit.ml && quantity >= 1000) {
      return NormalizedQuantity(quantity / 1000, GroceryUnit.litre);
    }
    return NormalizedQuantity(quantity, unit);
  }

  static NormalizedQuantity toBase(double quantity, GroceryUnit unit) {
    switch (unit) {
      case GroceryUnit.kg:
        return NormalizedQuantity(quantity * 1000, GroceryUnit.g);
      case GroceryUnit.litre:
        return NormalizedQuantity(quantity * 1000, GroceryUnit.ml);
      case GroceryUnit.g:
      case GroceryUnit.ml:
        return NormalizedQuantity(quantity, unit);
      case GroceryUnit.item:
      case GroceryUnit.packet:
      case GroceryUnit.pcs:
        return NormalizedQuantity(quantity, GroceryUnit.pcs);
    }
  }

  static bool sameFamily(GroceryUnit a, GroceryUnit b) {
    if (_isWeight(a) && _isWeight(b)) return true;
    if (_isVolume(a) && _isVolume(b)) return true;
    if (_isCount(a) && _isCount(b)) return true;
    return false;
  }

  static NormalizedQuantity add(
    double qtyA,
    GroceryUnit unitA,
    double qtyB,
    GroceryUnit unitB,
  ) {
    if (!sameFamily(unitA, unitB)) {
      return normalize(qtyA + qtyB, unitA);
    }
    final baseA = toBase(qtyA, unitA);
    final baseB = toBase(qtyB, unitB);
    final summed = baseA.quantity + baseB.quantity;
    return normalize(summed, baseA.unit);
  }

  static String format(double quantity, GroceryUnit unit) {
    final normalized = normalize(quantity, unit);
    final value = normalized.quantity % 1 == 0
        ? normalized.quantity.toStringAsFixed(0)
        : normalized.quantity.toStringAsFixed(1);
    return '$value ${normalized.unit.label}';
  }

  static bool _isWeight(GroceryUnit unit) {
    return unit == GroceryUnit.g || unit == GroceryUnit.kg;
  }

  static bool _isVolume(GroceryUnit unit) {
    return unit == GroceryUnit.ml || unit == GroceryUnit.litre;
  }

  static bool _isCount(GroceryUnit unit) {
    return unit == GroceryUnit.pcs ||
        unit == GroceryUnit.item ||
        unit == GroceryUnit.packet;
  }
}
