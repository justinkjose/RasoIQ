import '../domain/grocery_unit.dart';

class ParsedGroceryItem {
  const ParsedGroceryItem({
    required this.name,
    this.quantity = 1,
    this.unit = GroceryUnit.item,
  });

  final String name;
  final double quantity;
  final GroceryUnit unit;
}

class GroceryItemParser {
  const GroceryItemParser();

  List<ParsedGroceryItem> parse(String input) {
    final cleaned = input
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('•', '\n')
        .replaceAll('• ', '\n')
        .replaceAll('–', '-')
        .replaceAll('\t', ' ');
    final parts = cleaned.split(RegExp(r'[,\n;]+'));
    final items = <ParsedGroceryItem>[];

    for (final raw in parts) {
      var token = raw.trim();
      if (token.isEmpty) continue;
      token = token.replaceAll(RegExp(r'^[\-\*]+\s*'), '');
      token = token.replaceAll(RegExp(r'^\d+[\)\.\-]\s*'), '');
      token = token.trim();
      if (token.isEmpty) continue;

      final parsed = _parseQuantityAndUnit(token);
      if (parsed.name.trim().isEmpty) continue;
      items.add(parsed);
    }

    return _dedupe(items);
  }

  ParsedGroceryItem _parseQuantityAndUnit(String token) {
    final pattern = RegExp(
      r'^(\d+(?:\.\d+)?)\s*(kg|g|l|litre|liter|ml|pcs|pc|piece|pieces|packet|packets|item|items)\s+(.*)$',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(token);
    if (match == null) {
      return ParsedGroceryItem(name: token.trim());
    }

    final qty = double.tryParse(match.group(1) ?? '') ?? 1;
    final unitLabel = (match.group(2) ?? '').toLowerCase();
    final name = (match.group(3) ?? '').trim();

    return ParsedGroceryItem(
      name: name.isEmpty ? token.trim() : name,
      quantity: qty,
      unit: _unitFromLabel(unitLabel),
    );
  }

  GroceryUnit _unitFromLabel(String label) {
    switch (label) {
      case 'kg':
        return GroceryUnit.kg;
      case 'g':
        return GroceryUnit.g;
      case 'l':
      case 'litre':
      case 'liter':
        return GroceryUnit.litre;
      case 'ml':
        return GroceryUnit.ml;
      case 'pcs':
      case 'pc':
      case 'piece':
      case 'pieces':
        return GroceryUnit.pcs;
      case 'packet':
      case 'packets':
        return GroceryUnit.packet;
      case 'item':
      case 'items':
      default:
        return GroceryUnit.item;
    }
  }

  List<ParsedGroceryItem> _dedupe(List<ParsedGroceryItem> items) {
    final seen = <String, ParsedGroceryItem>{};
    for (final item in items) {
      final key = item.name.trim().toLowerCase();
      if (key.isEmpty) continue;
      if (!seen.containsKey(key)) {
        seen[key] = item;
      }
    }
    return seen.values.toList();
  }
}
