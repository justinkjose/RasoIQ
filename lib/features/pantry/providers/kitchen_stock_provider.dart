import 'package:flutter/material.dart';

import '../domain/kitchen_item.dart';
import '../data/kitchen_repository.dart';

class KitchenStockProvider extends ChangeNotifier {
  KitchenStockProvider({KitchenRepository? repository})
      : _repository = repository ?? KitchenRepository();

  final KitchenRepository _repository;

  bool _loading = true;
  List<KitchenItem> _items = [];

  bool get isLoading => _loading;
  List<KitchenItem> get items => List.unmodifiable(_items);

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _items = await _repository.getItems();
    if (_items.isEmpty) {
      _items = _seedItems();
      for (final item in _items) {
        await _repository.addItem(item);
      }
    }
    _loading = false;
    notifyListeners();
    await _repository.syncFromRemote();
    _items = await _repository.getItems();
    notifyListeners();
    await _repository.startRealtimeSync(onMerged: _refreshFromLocal);
  }

  Future<void> addItem(KitchenItem item) async {
    await _repository.addItem(item);
    _items = await _repository.getItems();
    notifyListeners();
  }

  Future<void> addBatch(KitchenItem item, KitchenBatch batch) async {
    await _repository.addBatch(item, batch);
    _items = await _repository.getItems();
    notifyListeners();
  }

  Future<void> useQuantity(KitchenItem item, int quantity) async {
    await _repository.useQuantity(item, quantity);
    _items = await _repository.getItems();
    notifyListeners();
  }

  Future<void> updateItem(KitchenItem item) async {
    await _repository.updateItem(item);
    _items = await _repository.getItems();
    notifyListeners();
  }

  Future<void> deleteItem(KitchenItem item) async {
    await _repository.deleteItem(item);
    _items = await _repository.getItems();
    notifyListeners();
  }

  Future<void> _refreshFromLocal() async {
    _items = await _repository.getItems();
    notifyListeners();
  }

  List<KitchenItem> _seedItems() {
    return [
      KitchenItem(
        id: 'k1',
        name: 'Tomato',
        category: 'Vegetables',
        batches: [
          KitchenBatch(
            quantity: 2000,
            unit: 'g',
            addedDate: DateTime(2024, 1, 1),
            expiryDate: DateTime(2024, 1, 3),
          ),
        ],
      ),
      KitchenItem(
        id: 'k2',
        name: 'Milk',
        category: 'Dairy',
        batches: [
          KitchenBatch(
            quantity: 1000,
            unit: 'ml',
            addedDate: DateTime(2024, 1, 1),
            expiryDate: DateTime(2024, 1, 2),
          ),
        ],
      ),
      KitchenItem(
        id: 'k3',
        name: 'Rice',
        category: 'Grains_Flour',
        batches: [
          KitchenBatch(
            quantity: 5000,
            unit: 'g',
            addedDate: DateTime(2024, 1, 1),
          ),
        ],
      ),
    ];
  }
}
