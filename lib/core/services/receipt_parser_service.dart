import '../../features/pantry/domain/pantry_scan_item.dart';

class ReceiptParserService {
  static const _ignoreTokens = [
    'TOTAL',
    'GST',
    'DATE',
    'PHONE',
    'CASH',
    'CARD',
    'UPI',
  ];

  List<PantryScanItem> parseLines(List<String> lines) {
    final items = <PantryScanItem>[];
    for (final raw in lines) {
      final line = _cleanLine(raw);
      if (line.isEmpty) continue;
      if (_isIgnored(line)) continue;
      if (_hasLongNumber(line)) continue;

      final parsed = _parseLine(line);
      if (parsed == null) continue;
      items.add(parsed);
    }
    return items;
  }

  bool _isIgnored(String line) {
    final upper = line.toUpperCase();
    return _ignoreTokens.any(upper.contains);
  }

  bool _hasLongNumber(String line) {
    return RegExp(r'\d{6,}').hasMatch(line);
  }

  PantryScanItem? _parseLine(String line) {
    final match = RegExp(
      r'^([A-Z\s]+)\s+(\d+\.\d+|\d+)\s+(\d+\.\d+)',
    ).firstMatch(line);
    if (match == null) return null;

    final rawName = match.group(1)?.trim() ?? '';
    if (rawName.isEmpty) return null;

    final quantity = double.tryParse(match.group(2) ?? '') ?? 0.0;
    final price = double.tryParse(match.group(3) ?? '') ?? 0.0;

    if (quantity <= 0 || quantity > 20) return null;
    if (price <= 0 || price > 10000) return null;

    final name = _normalizeName(rawName);
    if (name.isEmpty) return null;

    return PantryScanItem(
      name: name,
      quantity: quantity,
      unit: 'item',
      price: price,
    );
  }

  String _normalizeName(String rawName) {
    final parts = rawName
        .replaceAll(RegExp(r'[^A-Z\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList();

    const trailing = {'PKT', 'SFL', 'PACK', 'PCS'};
    while (parts.isNotEmpty && trailing.contains(parts.last)) {
      parts.removeLast();
    }

    return parts.join(' ').toLowerCase();
  }

  String _cleanLine(String raw) {
    var line = raw.trim().toUpperCase();
    if (line.isEmpty) return '';
    line = line.replaceAll(RegExp(r'[^A-Z0-9\.\s]'), ' ');
    line = line.replaceAll(RegExp(r'\s+'), ' ').trim();
    return line;
  }
}
