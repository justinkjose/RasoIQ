import 'grocery_storage.dart';
import '../domain/grocery_item.dart';
import '../domain/shopping_list.dart';

class LocalGroceryRepository {
  LocalGroceryRepository({GroceryStorage? storage})
      : _storage = storage ?? GroceryStorage();

  final GroceryStorage _storage;

  Future<List<ShoppingList>> loadLists() => _storage.loadShoppingLists();

  Future<void> saveLists(List<ShoppingList> lists) =>
      _storage.saveShoppingLists(lists);

  Future<List<GroceryItem>> loadItems() => _storage.loadGroceryItems();

  Future<void> saveItems(List<GroceryItem> items) =>
      _storage.saveGroceryItems(items);

  Future<List<String>> loadRecentItems() => _storage.loadRecentItems();

  Future<void> saveRecentItems(List<String> items) =>
      _storage.saveRecentItems(items);
}
