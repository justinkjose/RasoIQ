import '../../../data/default_grocery_catalog.dart';

class CategoryMatcher {
  const CategoryMatcher();

  String matchCategory(String name) {
    final normalized = _normalize(name);
    if (normalized.isEmpty) return 'other';

    final inputTokens = _tokens(normalized);
    double bestScore = 0;
    String bestCategory = 'other';

    for (final entry in DefaultGroceryCatalog.categories.entries) {
      for (final item in entry.value) {
        final itemNormalized = _normalize(item);
        final itemTokens = _tokens(itemNormalized);
        final score = _scoreMatch(
          input: normalized,
          inputTokens: inputTokens,
          item: itemNormalized,
          itemTokens: itemTokens,
        );
        if (score > bestScore) {
          bestScore = score;
          bestCategory = entry.key.toLowerCase();
        }
      }
    }

    final minScore = inputTokens.length <= 1 ? 0.45 : 0.36;
    if (bestScore >= minScore) {
      return bestCategory;
    }

    if (normalized.contains('milk')) return 'dairy';
    if (normalized.contains('rice') || normalized.contains('poha')) {
      return 'grains';
    }
    if (normalized.contains('sugar')) return 'staples';
    if (normalized.contains('mint') || normalized.contains('onion')) {
      return 'vegetables';
    }
    return 'other';
  }

  double _scoreMatch({
    required String input,
    required List<String> inputTokens,
    required String item,
    required List<String> itemTokens,
  }) {
    if (input == item) return 1.0;
    if (input.contains(item) || item.contains(input)) return 0.9;

    final overlap = _tokenOverlap(inputTokens, itemTokens);
    final prefixBonus = _prefixBonus(inputTokens, itemTokens);
    final partialScore = _partialTokenScore(inputTokens, itemTokens);
    final lengthPenalty = _lengthPenalty(input, item);

    return (overlap * 0.55) +
        (prefixBonus * 0.25) +
        (partialScore * 0.2) +
        _containsTokenBoost(inputTokens, itemTokens) -
        lengthPenalty;
  }

  double _tokenOverlap(List<String> inputTokens, List<String> itemTokens) {
    if (inputTokens.isEmpty || itemTokens.isEmpty) return 0;
    final inputSet = inputTokens.toSet();
    final matches = itemTokens.where(inputSet.contains).length;
    return matches / itemTokens.length;
  }

  double _prefixBonus(List<String> inputTokens, List<String> itemTokens) {
    for (final input in inputTokens) {
      for (final item in itemTokens) {
        if (input.startsWith(item) || item.startsWith(input)) {
          return 0.6;
        }
      }
    }
    return 0;
  }

  double _containsTokenBoost(List<String> inputTokens, List<String> itemTokens) {
    for (final input in inputTokens) {
      for (final item in itemTokens) {
        if (input.contains(item) || item.contains(input)) {
          return 0.2;
        }
      }
    }
    return 0;
  }

  double _partialTokenScore(List<String> inputTokens, List<String> itemTokens) {
    double best = 0;
    for (final input in inputTokens) {
      for (final item in itemTokens) {
        final score = _partialOverlap(input, item);
        if (score > best) best = score;
      }
    }
    return best;
  }

  double _partialOverlap(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final shorter = a.length <= b.length ? a : b;
    final longer = a.length > b.length ? a : b;
    if (longer.contains(shorter)) {
      return (shorter.length / longer.length).clamp(0.2, 0.6);
    }
    return 0;
  }

  double _lengthPenalty(String input, String item) {
    final diff = (input.length - item.length).abs();
    if (diff <= 2) return 0;
    return (diff / 24).clamp(0, 0.22);
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\\s]'), ' ')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
  }

  List<String> _tokens(String value) {
    if (value.isEmpty) return const [];
    return value.split(' ');
  }
}
