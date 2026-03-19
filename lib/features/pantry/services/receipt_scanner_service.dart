import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/pantry_scan_item.dart';

class ReceiptScannerService {
  ReceiptScannerService({TextRecognizer? recognizer})
      : _recognizer = recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  Future<List<PantryScanItem>> scanReceipt(File image) async {
    final input = InputImage.fromFile(image);
    final result = await _recognizer.processImage(input);
    final lines = result.blocks.expand((block) => block.lines).map((line) => line.text).toList();
    return _parseLines(lines);
  }

  Future<void> dispose() async {
    await _recognizer.close();
  }

  List<PantryScanItem> _parseLines(List<String> lines) {
    final items = <PantryScanItem>[];
    for (final raw in lines) {
      final line = _cleanOcrLine(raw);
      if (line.isEmpty) continue;
      if (_isIgnored(line)) continue;
      if (_hasLongNumber(line)) continue;

      final parsed = _parseLine(line);
      if (parsed == null) continue;
      items.add(parsed);
    }

    return _mergeDuplicates(items);
  }

  bool _isIgnored(String line) {
    final upper = line.toUpperCase();
    const ignore = [
      'TOTAL',
      'GST',
      'PHONE',
      'DATE',
      'BILL',
      'CASH',
      'UPI',
      'CARD',
      'SUBTOTAL',
      'PAYMENT',
    ];
    return ignore.any(upper.contains);
  }

  PantryScanItem? _parseLine(String line) {
    final patterns = <RegExp>[
      RegExp(r'^([A-Z\s]+)\s+(\d+\.\d+|\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)'),
      RegExp(r'^([A-Z\s]+)\s+(\d+\.\d+)\s+(\d+\.\d+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(line);
      if (match == null) continue;

      final rawName = match.group(1)?.trim() ?? '';
      if (rawName.isEmpty) return null;

      final quantityValue = double.tryParse(match.group(2) ?? '') ?? 0;
      if (quantityValue <= 0 || quantityValue > 20) return null;

      final priceValue = double.tryParse(match.group(3) ?? '') ?? 0;
      if (priceValue <= 0 || priceValue > 10000) return null;

      final normalizedName = _normalizeItemName(rawName);
      if (normalizedName.isEmpty) return null;

      return PantryScanItem(
        name: normalizedName,
        quantity: quantityValue,
        unit: _detectUnit(normalizedName),
        price: priceValue,
      );
    }

    return null;
  }

  List<PantryScanItem> _mergeDuplicates(List<PantryScanItem> items) {
    final map = <String, PantryScanItem>{};
    for (final item in items) {
      final key = item.name.toLowerCase();
      if (!map.containsKey(key)) {
        map[key] = PantryScanItem(
          name: item.name,
          quantity: item.quantity,
          unit: item.unit,
          price: item.price,
        );
      } else {
        final existing = map[key]!;
        if (existing.unit == item.unit) {
          existing.quantity += item.quantity;
          if (item.price != null) {
            existing.price = (existing.price ?? 0) + item.price!;
          }
        }
      }
    }
    return map.values.toList();
  }

  String _cleanOcrLine(String raw) {
    var line = raw.trim().toUpperCase();
    if (line.isEmpty) return '';

    line = line.replaceAll(RegExp(r'[^A-Z0-9\.\s]'), ' ');
    line = line.replaceAll(RegExp(r'\s+'), ' ').trim();

    final parts = line.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.length > 1 && RegExp(r'^[A-Z]{1,3}$').hasMatch(parts.last)) {
      parts.removeLast();
      line = parts.join(' ');
    }

    return line;
  }

  bool _hasLongNumber(String line) {
    final matches = RegExp(r'\d{6,}').allMatches(line);
    return matches.isNotEmpty;
  }

  String _normalizeItemName(String rawName) {
    final tokens = rawName
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList();

    const trailing = {'PKT', 'SFL', 'PACK', 'PCS'};
    while (tokens.isNotEmpty && trailing.contains(tokens.last)) {
      tokens.removeLast();
    }

    return tokens.join(' ').toLowerCase();
  }

  String _detectUnit(String name) {
    final lower = name.toLowerCase();
    if (_isProduce(lower)) return 'kg';
    if (lower.contains('milk')) return 'litre';
    return 'item';
  }

  bool _isProduce(String name) {
    const produce = [
      'apple',
      'banana',
      'onion',
      'potato',
      'tomato',
      'orange',
      'mango',
      'grapes',
      'carrot',
      'cabbage',
      'spinach',
      'cucumber',
      'lemon',
      'lime',
      'capsicum',
      'chilli',
      'garlic',
      'ginger',
      'beans',
      'peas',
    ];
    return produce.any((item) => name.contains(item));
  }
}
