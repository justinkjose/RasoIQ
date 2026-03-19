import '../domain/pantry_item.dart';
import '../domain/predicted_item.dart';

class InsightService {
  List<String> buildInsights({
    required List<PantryItem> items,
    required List<PredictedItem> predictions,
    required List<PantryItem> expiring,
  }) {
    final insights = <String>[];

    if (expiring.isNotEmpty) {
      final soonest = expiring.first;
      insights.add('${soonest.name} is expiring soon. Plan a meal today.');
    }

    if (predictions.isNotEmpty) {
      final top = predictions.first;
      insights.add('You may need ${top.name.toLowerCase()} soon.');
    }

    if (items.isNotEmpty) {
      final sorted = [...items]..sort((a, b) => b.quantity.compareTo(a.quantity));
      final mostStocked = sorted.first;
      insights.add('Your pantry is stocked on ${mostStocked.name.toLowerCase()}.');
    }

    if (insights.length < 3) {
      insights.add('Keep your staples topped up to maintain a high pantry score.');
    }

    return insights.take(3).toList();
  }
}
