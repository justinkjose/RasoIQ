import '../domain/voice_command_result.dart';

class VoiceCommandParser {
  VoiceCommandResult? parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final normalized = trimmed.toLowerCase();
    if (!normalized.startsWith('add ')) return null;

    final payload = normalized.substring(4).trim();
    if (payload.isEmpty) return null;

    final quantityMatch = RegExp(r'(\d+(?:\.\d+)?)\s?(kg|g|l|ml)\b').firstMatch(payload);
    double quantity = 1;
    String unit = 'item';
    String name = payload;

    if (quantityMatch != null) {
      quantity = double.tryParse(quantityMatch.group(1) ?? '') ?? 1;
      unit = (quantityMatch.group(2) ?? 'item').toLowerCase();
      name = payload.replaceRange(quantityMatch.start, quantityMatch.end, ' ');
    }

    name = name
        .replaceAll(RegExp(r'\b\d+(?:\.\d+)?\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (name.isEmpty) return null;

    return VoiceCommandResult(
      name: _titleCase(name),
      quantity: quantity,
      unit: unit,
    );
  }

  String _titleCase(String value) {
    return value
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join(' ');
  }
}
