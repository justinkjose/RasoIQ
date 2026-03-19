import 'dart:math';

import '../domain/consumption_event.dart';
import '../domain/predicted_item.dart';
import '../domain/pantry_item.dart';
import 'pantry_storage.dart';

class SnapUpPredictionService {
  SnapUpPredictionService({PantryStorage? storage})
      : _storage = storage ?? PantryStorage();

  final PantryStorage _storage;

  Future<List<PredictedItem>> getPredictions({int limit = 6}) async {
    final items = await _storage.loadItems();
    final events = await _storage.loadConsumptionEvents();
    final categoryMemory = await _storage.loadCategoryMemory();

    if (items.isEmpty || events.isEmpty) return [];

    final eventsByItem = <String, List<DateTime>>{};
    for (final ConsumptionEvent event in events) {
      final key = event.itemName;
      eventsByItem.putIfAbsent(key, () => []).add(event.timestamp);
    }

    final scored = <PredictedItem>[];
    final maxFrequency = eventsByItem.values
        .map((list) => list.length)
        .fold<int>(0, max);

    for (final item in items) {
      final history = eventsByItem[item.normalizedName];
      if (history == null || history.length < 2) continue;

      history.sort();
      final avgInterval = _averageIntervalDays(history);
      if (avgInterval <= 0) continue;

      final daysSinceLastUse =
          DateTime.now().difference(history.last).inDays.toDouble();
      final baseScore = daysSinceLastUse / avgInterval;

      final frequencyWeight = maxFrequency == 0
          ? 0
          : log(1 + history.length) / log(1 + maxFrequency);
      final recencyWeight = 1 / (1 + daysSinceLastUse);
      final intervalWeight = 1 / (1 + avgInterval);
      final bayesWeight = (frequencyWeight + recencyWeight + intervalWeight) / 3;

      final confidence = (baseScore * bayesWeight).clamp(0.0, 1.5).toDouble();
      if (confidence <= 0.05) continue;

      final category = _resolveCategory(item, categoryMemory);

      scored.add(
        PredictedItem(
          name: item.name,
          confidenceScore: confidence,
          category: category,
        ),
      );
    }

    scored.sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));
    return scored.take(limit).toList();
  }

  double _averageIntervalDays(List<DateTime> events) {
    if (events.length < 2) return 0;
    double total = 0;
    for (var i = 1; i < events.length; i++) {
      final diff = events[i].difference(events[i - 1]).inHours / 24;
      total += diff <= 0 ? 0.1 : diff;
    }
    return total / (events.length - 1);
  }

  String _resolveCategory(PantryItem item, Map<String, String> memory) {
    final category = memory[item.normalizedName] ?? '';
    if (category.isEmpty) return 'Uncategorized';
    return category[0].toUpperCase() + category.substring(1);
  }
}
