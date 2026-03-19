import '../domain/consumption_event.dart';
import 'pantry_storage.dart';

class ConsumptionService {
  ConsumptionService({PantryStorage? storage})
      : _storage = storage ?? PantryStorage();

  final PantryStorage _storage;

  Future<List<ConsumptionEvent>> getEvents() async {
    return _storage.loadConsumptionEvents();
  }

  Future<void> recordConsumption({
    required String itemName,
    required double quantity,
    DateTime? timestamp,
  }) async {
    final events = await _storage.loadConsumptionEvents();
    events.add(
      ConsumptionEvent(
        itemName: itemName,
        quantityConsumed: quantity,
        timestamp: timestamp ?? DateTime.now(),
      ),
    );
    await _storage.saveConsumptionEvents(events);
  }
}
