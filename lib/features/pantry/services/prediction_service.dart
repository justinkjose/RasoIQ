import 'dart:math';

import '../domain/consumption_event.dart';
import '../domain/predicted_item.dart';
import '../domain/pantry_item.dart';
import 'consumption_service.dart';
import 'pantry_storage.dart';

class PredictionService {
  PredictionService({
    PantryStorage? storage,
    ConsumptionService? consumptionService,
  })  : _storage = storage ?? PantryStorage(),
        _consumptionService = consumptionService ?? ConsumptionService();

  final PantryStorage _storage;
  final ConsumptionService _consumptionService;

  Future<List<PredictedItem>> getPredictions({int limit = 8}) async {
    final items = await _storage.loadItems();
    final events = await _consumptionService.getEvents();
    final memory = await _storage.loadCategoryMemory();

    if (items.isEmpty || events.isEmpty) return [];

    final eventsByItem = <String, List<DateTime>>{};
    for (final ConsumptionEvent event in events) {
      eventsByItem.putIfAbsent(event.itemName, () => []).add(event.timestamp);
    }

    final scored = <PredictedItem>[];
    for (final item in items) {
      final history = eventsByItem[item.normalizedName];
      if (history == null || history.length < 2) continue;

      history.sort();
      final avgInterval = _averageIntervalDays(history);
      if (avgInterval <= 0) continue;

      final daysSinceLastUse =
          DateTime.now().difference(history.last).inDays.toDouble();
      final score = daysSinceLastUse / avgInterval;
      if (score <= 1) continue;

      final category = _resolveCategory(item, memory);

      scored.add(
        PredictedItem(
          name: item.name,
          confidenceScore: score.clamp(0.0, 3.0).toDouble(),
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
    return total / max(1, events.length - 1);
  }

  String _resolveCategory(PantryItem item, Map<String, String> memory) {
    final category = memory[item.normalizedName] ?? '';
    if (category.isEmpty) return 'Uncategorized';
    return category[0].toUpperCase() + category.substring(1);
  }
}
