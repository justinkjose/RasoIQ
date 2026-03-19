import 'package:flutter/material.dart';

import '../domain/kitchen_item.dart';
import '../services/kitchen_storage.dart';

class KitchenStockProvider extends ChangeNotifier {
  KitchenStockProvider({KitchenStorage? storage})
      : _storage = storage ?? KitchenStorage();

  final KitchenStorage _storage;

  bool _loading = true;
  List<KitchenItem> _items = [];

  bool get isLoading => _loading;
  List<KitchenItem> get items => List.unmodifiable(_items);

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _items = await _storage.loadItems();
    if (_items.isEmpty) {
      _items = _seedItems();
      await _storage.saveItems(_items);
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> addItem(KitchenItem item) async {
    final existingIndex = _items.indexWhere(
      (entry) => entry.name.toLowerCase() == item.name.toLowerCase(),
    );
    if (existingIndex != -1) {
      final existing = _items[existingIndex];
      _items[existingIndex] = existing.copyWith(
        batches: [...existing.batches, ...item.batches],
      );
    } else {
      _items = [..._items, item];
    }
    await _storage.saveItems(_items);
    notifyListeners();
  }

  Future<void> addBatch(KitchenItem item, KitchenBatch batch) async {
    _items = _items
        .map(
          (entry) => entry.id == item.id
              ? entry.copyWith(batches: [...entry.batches, batch])
              : entry,
        )
        .toList();
    await _storage.saveItems(_items);
    notifyListeners();
  }

  Future<void> useQuantity(KitchenItem item, int quantity) async {
    final updated = item.batches.toList()
      ..sort((a, b) {
        final aDate = a.expiryDate ?? DateTime(9999);
        final bDate = b.expiryDate ?? DateTime(9999);
        return aDate.compareTo(bDate);
      });

    var remaining = quantity;
    final newBatches = <KitchenBatch>[];
    for (final batch in updated) {
      if (remaining <= 0) {
        newBatches.add(batch);
        continue;
      }
      final newQty = (batch.quantity - remaining).clamp(0, 999999).toInt();
      remaining = (remaining - batch.quantity).clamp(0, 999999).toInt();
      if (newQty > 0) {
        newBatches.add(batch.copyWith(quantity: newQty));
      }
    }

    _items = _items
        .map(
          (entry) =>
              entry.id == item.id ? entry.copyWith(batches: newBatches) : entry,
        )
        .toList();
    await _storage.saveItems(_items);
    notifyListeners();
  }

  Future<void> updateItem(KitchenItem item) async {
    _items = _items
        .map((entry) => entry.id == item.id ? item : entry)
        .toList();
    await _storage.saveItems(_items);
    notifyListeners();
  }

  Future<void> deleteItem(KitchenItem item) async {
    _items = _items.where((entry) => entry.id != item.id).toList();
    await _storage.saveItems(_items);
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
