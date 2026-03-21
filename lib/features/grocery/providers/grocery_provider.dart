import 'dart:async';

import 'package:flutter/material.dart';

import '../data/grocery_repository.dart';
import '../domain/grocery_item.dart';
import '../domain/grocery_unit.dart';
import '../domain/shopping_list.dart';
import '../domain/user_item.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../services/sync_service.dart';

class GroceryProvider extends ChangeNotifier {
  GroceryProvider({GroceryRepository? repository})
      : _repository = repository ?? GroceryRepository();

  final GroceryRepository _repository;
  final SyncService _syncService = SyncService();
  ConnectivityProvider? _connectivityProvider;

  bool _loading = true;
  bool _shoppingMode = true;
  bool _offline = false;
  bool _initialized = false;
  ShoppingList? _activeList;
  List<ShoppingList> _lists = [];
  List<GroceryItem> _items = [];
  List<String> _recentItems = [];
  List<UserItem> _userItems = [];

  bool get isLoading => _loading;
  bool get isOffline => _offline;
  bool get shoppingMode => _shoppingMode;
  List<GroceryItem> get items => List.unmodifiable(_items);
  List<String> get recentItems => List.unmodifiable(_recentItems);
  List<UserItem> get userItems => List.unmodifiable(_userItems);
  List<ShoppingList> get lists => List.unmodifiable(_lists);
  String? get activeListId => _activeList?.id;
  String get activeListName => _activeList?.name ?? 'Grocery List';

  void ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    unawaited(load());
  }

  void bindConnectivity(ConnectivityProvider provider) {
    if (_connectivityProvider == provider) return;
    _connectivityProvider?.removeListener(_handleConnectivityChange);
    _connectivityProvider = provider;
    _connectivityProvider?.addListener(_handleConnectivityChange);
    _handleConnectivityChange();
  }

  void _handleConnectivityChange() {
    final offline = _connectivityProvider?.isOffline ?? false;
    if (_offline != offline) {
      _offline = offline;
      notifyListeners();
    }
    if (!offline) {
      unawaited(_syncService.pushLocalToCloud().then((_) async {
        await _syncService.pullCloudToLocal();
        await _refresh();
      }));
    }
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _lists = await _repository.getLists();
    _activeList = _lists.isEmpty
        ? await _repository.createList(name: 'My List', icon: 'CART')
        : _lists.first;
    if (_lists.isEmpty) {
      _lists = [_activeList!];
    }
    await _refresh();
    if (!(_connectivityProvider?.isOffline ?? false)) {
      await _syncService.pushLocalToCloud();
      await _syncService.pullCloudToLocal();
      await _refresh();
    }
    await _repository.startRealtimeSync(onMerged: _refresh);
  }

  Future<void> _refresh() async {
    if (_activeList == null) return;
    _items = await _repository.getItemsForList(_activeList!.id);
    _recentItems = await _repository.getRecentItems();
    _userItems = await _repository.getUserItems();
    _lists = await _repository.getLists();
    _loading = false;
    notifyListeners();
  }

  Future<void> refreshLists() async {
    _lists = await _repository.getLists();
    notifyListeners();
  }

  Future<void> createList(String name) async {
    final created = await _repository.createList(name: name, icon: 'CART');
    _lists = await _repository.getLists();
    _activeList = created;
    await _refresh();
  }

  Future<void> updateList(ShoppingList list) async {
    await _repository.updateListName(list.id, list.name);
    _lists = await _repository.getLists();
    if (_activeList?.id == list.id) {
      _activeList = list;
    }
    notifyListeners();
  }

  Future<void> deleteList(String listId) async {
    await _repository.deleteList(listId);
    _lists = await _repository.getLists();
    if (_activeList?.id == listId) {
      _activeList = _lists.isNotEmpty ? _lists.first : null;
    }
    await _refresh();
  }
  Future<void> setActiveList(ShoppingList list) async {
    _activeList = list;
    await _refresh();
  }

  void setShoppingMode(bool value) {
    if (_shoppingMode == value) return;
    _shoppingMode = value;
    notifyListeners();
  }

  Future<void> addItem({
    required String name,
    required double quantity,
    required GroceryUnit unit,
    required String categoryId,
    bool isImportant = false,
    int packCount = 1,
    double packSize = 0,
  }) async {
    if (_activeList == null) return;
    await _repository.addItem(
      listId: _activeList!.id,
      name: name,
      quantity: quantity,
      unit: unit,
      categoryId: categoryId,
      isImportant: isImportant,
      packCount: packCount,
      packSize: packSize,
    );
    await _refresh();
  }

  Future<void> toggleDone(GroceryItem item) async {
    await _repository.updateItem(
      item.id,
      isDone: !item.isDone,
      isUnavailable: item.isDone ? item.isUnavailable : false,
    );
    await _refresh();
  }

  Future<void> toggleImportant(GroceryItem item) async {
    await _repository.toggleImportant(item.id);
    await _refresh();
  }

  Future<void> toggleUnavailable(GroceryItem item) async {
    await _repository.toggleUnavailable(item.id);
    await _refresh();
  }

  Future<void> deleteItem(GroceryItem item) async {
    await _repository.removeItem(item.id);
    await _refresh();
  }

  Future<void> updateQuantity(GroceryItem item, double quantity) async {
    await _repository.updateItem(item.id, quantity: quantity);
    await _refresh();
  }

  Future<void> updateUnit(GroceryItem item, GroceryUnit unit) async {
    await _repository.updateItem(item.id, unit: unit);
    await _refresh();
  }

  Future<void> updateCategory(GroceryItem item, String categoryId) async {
    await _repository.updateItem(item.id, categoryId: categoryId);
    await _refresh();
  }

  Future<void> updatePackSize(GroceryItem item, double packSize) async {
    await _repository.updateItem(item.id, packSize: packSize);
    await _refresh();
  }
}
