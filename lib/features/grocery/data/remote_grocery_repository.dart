import '../../../data/remote/firestore_service.dart';
import '../domain/grocery_item.dart';
import '../domain/shopping_list.dart';

class RemoteGroceryRepository {
  RemoteGroceryRepository({FirestoreService? service})
      : _service = service ?? FirestoreService();

  final FirestoreService _service;

  Future<List<ShoppingList>> fetchLists() => _service.fetchGroceryLists();

  Future<List<ShoppingList>> fetchListsUpdatedSince(DateTime since) =>
      _service.fetchGroceryListsUpdatedSince(since);

  Stream<List<ShoppingList>> streamLists() => _service.streamGroceryLists();

  Stream<List<GroceryItem>> streamItems(String listId) =>
      _service.streamItems(listId);

  Future<List<GroceryItem>> fetchItems(String listId) =>
      _service.fetchItems(listId);

  Future<List<GroceryItem>> fetchItemsUpdatedSince(
    String listId,
    DateTime since,
  ) =>
      _service.fetchItemsUpdatedSince(listId, since);

  Future<void> upsertList(ShoppingList list) =>
      _service.upsertGroceryList(list);

  Future<void> upsertItem(GroceryItem item) => _service.upsertItem(item);

  Future<void> deleteItem(String listId, String itemId) =>
      _service.deleteItem(listId, itemId);

  Future<void> addMemberToList(String listId, String userId) =>
      _service.addMemberToList(listId, userId);

  Future<ShoppingList?> fetchListById(String listId) =>
      _service.fetchListById(listId);

  Future<Map<String, dynamic>?> fetchSharedList(String shareId) =>
      _service.fetchSharedList(shareId);
}
