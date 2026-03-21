import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../../features/grocery/domain/grocery_item.dart';
import '../../features/grocery/domain/grocery_unit.dart';
import '../../features/grocery/domain/shopping_list.dart';
import '../../services/auth_service.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore, AuthService? authService})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _authService = authService ?? AuthService.instance;

  final FirebaseFirestore _firestore;
  final AuthService _authService;
  static const int _listLimit = 200;
  static const int _itemLimit = 500;

  Future<String> _resolveUserId() async {
    final userId = _authService.userId.isNotEmpty
        ? _authService.userId
        : await _authService.ensureUserId();
    return userId;
  }

  CollectionReference<Map<String, dynamic>> _userListsRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('lists');
  }

  CollectionReference<Map<String, dynamic>> _legacyListsRef() {
    return _firestore.collection('grocery_lists');
  }

  CollectionReference<Map<String, dynamic>> _userItemsRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('user_items');
  }

  Future<List<ShoppingList>> fetchGroceryLists() async {
    final userId = await _resolveUserId();
    if (userId.isEmpty) return [];

    final snapshot =
        await _userListsRef(userId).limit(_listLimit).get();
    final lists = snapshot.docs.map((doc) {
      final data = doc.data();
      final created = _parseTimestamp(data['createdDate']);
      final members = (data['members'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList();
      return ShoppingList(
        id: doc.id,
        userId: data['userId']?.toString() ?? userId,
        members: members.isEmpty && userId.isNotEmpty ? [userId] : members,
        name: data['name']?.toString() ?? 'Grocery List',
        icon: data['icon']?.toString() ?? 'CART',
        createdDate: created,
        updatedAt: _parseTimestampNullable(data['updatedAt']) ?? created,
        isArchived: data['isArchived'] as bool? ?? false,
      );
    }).toList();

    if (lists.isNotEmpty) return lists;

    // Legacy fallback: migrate top-level lists into user namespace.
    final legacy = await _legacyListsRef().limit(_listLimit).get();
    if (legacy.docs.isEmpty) return [];

    final migrated = <ShoppingList>[];
    for (final doc in legacy.docs) {
      final data = doc.data();
      final created = _parseTimestamp(data['createdDate']);
      final members = (data['members'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList();
      final list = ShoppingList(
        id: doc.id,
        userId: data['userId']?.toString() ?? userId,
        members: members.isEmpty && userId.isNotEmpty ? [userId] : members,
        name: data['name']?.toString() ?? 'Grocery List',
        icon: data['icon']?.toString() ?? 'CART',
        createdDate: created,
        updatedAt: _parseTimestampNullable(data['updatedAt']) ?? created,
        isArchived: data['isArchived'] as bool? ?? false,
      );
      migrated.add(list);
      await _userListsRef(userId).doc(list.id).set(list.toJson());
    }
    return migrated;
  }

  Future<List<ShoppingList>> fetchGroceryListsUpdatedSince(
    DateTime since,
  ) async {
    final userId = await _resolveUserId();
    if (userId.isEmpty) return [];
    final snapshot = await _userListsRef(userId)
        .where('updatedAt', isGreaterThan: since.toIso8601String())
        .limit(_listLimit)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      final created = _parseTimestamp(data['createdDate']);
      final members = (data['members'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList();
      return ShoppingList(
        id: doc.id,
        userId: data['userId']?.toString() ?? userId,
        members: members.isEmpty && userId.isNotEmpty ? [userId] : members,
        name: data['name']?.toString() ?? 'Grocery List',
        icon: data['icon']?.toString() ?? 'CART',
        createdDate: created,
        updatedAt: _parseTimestampNullable(data['updatedAt']) ?? created,
        isArchived: data['isArchived'] as bool? ?? false,
      );
    }).toList();
  }

  Stream<List<ShoppingList>> streamGroceryLists() {
    final userId = _authService.userId;
    if (userId.isEmpty) {
      return const Stream<List<ShoppingList>>.empty();
    }
    return _userListsRef(userId).limit(_listLimit).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final created = _parseTimestamp(data['createdDate']);
        final members = (data['members'] as List<dynamic>? ?? [])
            .map((item) => item.toString())
            .toList();
        return ShoppingList(
          id: doc.id,
          userId: data['userId']?.toString() ?? userId,
          members: members.isEmpty && userId.isNotEmpty ? [userId] : members,
          name: data['name']?.toString() ?? 'Grocery List',
          icon: data['icon']?.toString() ?? 'CART',
          createdDate: created,
          updatedAt: _parseTimestampNullable(data['updatedAt']) ?? created,
          isArchived: data['isArchived'] as bool? ?? false,
        );
      }).toList();
    });
  }

  Stream<List<GroceryItem>> streamItems(String listId) {
    final userId = _authService.userId;
    if (userId.isEmpty) {
      return const Stream<List<GroceryItem>>.empty();
    }
    Query<Map<String, dynamic>> query =
        _userListsRef(userId).doc(listId).collection('items');
    return query.limit(_itemLimit).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final created = _parseTimestamp(data['createdAt']);
        return GroceryItem(
          id: doc.id,
          listId: listId,
          userId: data['userId']?.toString() ?? userId,
          name: data['name']?.toString() ?? 'Item',
          normalizedName: data['normalizedName']?.toString() ?? '',
          quantity: (data['quantity'] as num?)?.toDouble() ?? 1,
          packCount: (data['packCount'] as num?)?.toInt() ?? 1,
          packSize: (data['packSize'] as num?)?.toDouble() ?? 0,
          unit: _unitFromLabel(data['unit']?.toString()),
          categoryId: data['categoryId']?.toString() ?? 'uncategorized',
          isDone: data['isDone'] as bool? ?? false,
          isImportant: data['isImportant'] as bool? ?? false,
          isUnavailable: data['isUnavailable'] as bool? ?? false,
          expiryDate: _parseTimestampNullable(data['expiryDate']),
          createdAt: created,
          updatedAt: _parseTimestampNullable(data['updatedAt']) ?? created,
        );
      }).toList();
    });
  }

  Future<List<GroceryItem>> fetchItems(String listId) async {
    final userId = await _resolveUserId();
    if (userId.isEmpty) return [];
    Query<Map<String, dynamic>> query =
        _userListsRef(userId).doc(listId).collection('items');
    final snapshot = await query.limit(_itemLimit).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      final created = _parseTimestamp(data['createdAt']);
      return GroceryItem(
        id: doc.id,
        listId: listId,
        userId: data['userId']?.toString() ?? userId,
        name: data['name']?.toString() ?? 'Item',
        normalizedName: data['normalizedName']?.toString() ?? '',
        quantity: (data['quantity'] as num?)?.toDouble() ?? 1,
        packCount: (data['packCount'] as num?)?.toInt() ?? 1,
        packSize: (data['packSize'] as num?)?.toDouble() ?? 0,
        unit: _unitFromLabel(data['unit']?.toString()),
        categoryId: data['categoryId']?.toString() ?? 'uncategorized',
        isDone: data['isDone'] as bool? ?? false,
        isImportant: data['isImportant'] as bool? ?? false,
        isUnavailable: data['isUnavailable'] as bool? ?? false,
        expiryDate: _parseTimestampNullable(data['expiryDate']),
        createdAt: created,
        updatedAt: _parseTimestampNullable(data['updatedAt']) ?? created,
      );
    }).toList();
  }

  Future<List<GroceryItem>> fetchItemsUpdatedSince(
    String listId,
    DateTime since,
  ) async {
    final userId = await _resolveUserId();
    if (userId.isEmpty) return [];
    final snapshot = await _userListsRef(userId)
        .doc(listId)
        .collection('items')
        .where('updatedAt', isGreaterThan: since.toIso8601String())
        .limit(_itemLimit)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      final created = _parseTimestamp(data['createdAt']);
      return GroceryItem(
        id: doc.id,
        listId: listId,
        userId: data['userId']?.toString() ?? userId,
        name: data['name']?.toString() ?? 'Item',
        normalizedName: data['normalizedName']?.toString() ?? '',
        quantity: (data['quantity'] as num?)?.toDouble() ?? 1,
        packCount: (data['packCount'] as num?)?.toInt() ?? 1,
        packSize: (data['packSize'] as num?)?.toDouble() ?? 0,
        unit: _unitFromLabel(data['unit']?.toString()),
        categoryId: data['categoryId']?.toString() ?? 'uncategorized',
        isDone: data['isDone'] as bool? ?? false,
        isImportant: data['isImportant'] as bool? ?? false,
        isUnavailable: data['isUnavailable'] as bool? ?? false,
        expiryDate: _parseTimestampNullable(data['expiryDate']),
        createdAt: created,
        updatedAt: _parseTimestampNullable(data['updatedAt']) ?? created,
      );
    }).toList();
  }

  Future<void> upsertGroceryList(ShoppingList list) async {
    final userId = await _resolveUserId();
    if (userId.isEmpty) return;
    await _userListsRef(userId).doc(list.id).set({
      'userId': list.userId.isEmpty ? userId : list.userId,
      'members': list.members.isEmpty ? [userId] : list.members,
      'name': list.name,
      'icon': list.icon,
      'createdDate': list.createdDate.toIso8601String(),
      'updatedAt': list.updatedAt.toIso8601String(),
      'isArchived': list.isArchived,
    }, SetOptions(merge: true));
  }

  Future<void> upsertItem(GroceryItem item) async {
    final userId = await _resolveUserId();
    if (userId.isEmpty) return;
    await _userListsRef(userId)
        .doc(item.listId)
        .collection('items')
        .doc(item.id)
        .set({
      'name': item.name,
      'normalizedName': item.normalizedName,
      'quantity': item.quantity,
      'packCount': item.packCount,
      'packSize': item.packSize,
      'unit': item.unit.label,
      'userId': item.userId.isEmpty ? userId : item.userId,
      'categoryId': item.categoryId,
      'isDone': item.isDone,
      'isImportant': item.isImportant,
      'isUnavailable': item.isUnavailable,
      'expiryDate': item.expiryDate?.toIso8601String(),
      'createdAt': item.createdAt.toIso8601String(),
      'updatedAt': item.updatedAt.toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteItem(String listId, String itemId) async {
    final userId = await _resolveUserId();
    if (userId.isEmpty) return;
    await _userListsRef(userId)
        .doc(listId)
        .collection('items')
        .doc(itemId)
        .delete();
  }

  Future<void> upsertUserItem(Map<String, dynamic> payload) async {
    final userId = await _resolveUserId();
    if (userId.isEmpty) return;
    final name = payload['name']?.toString() ?? '';
    if (name.trim().isEmpty) return;
    final id = payload['id']?.toString() ?? name.toLowerCase().trim();
    await _userItemsRef(userId).doc(id).set({
      'name': name,
      'category': payload['category']?.toString() ?? 'Miscellaneous',
      'unit': payload['unit']?.toString() ?? 'pcs',
      'createdAt': payload['createdAt']?.toString() ??
          DateTime.now().toIso8601String(),
      'updatedAt': payload['updatedAt']?.toString() ??
          DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> addMemberToList(String listId, String userId) async {
    final ownerId = await _resolveUserId();
    if (ownerId.isEmpty) return;
    await _userListsRef(ownerId).doc(listId).set({
      'members': FieldValue.arrayUnion([userId]),
    }, SetOptions(merge: true));
  }

  Future<ShoppingList?> fetchListById(String listId) async {
    final userId = await _resolveUserId();
    if (userId.isEmpty) return null;
    final doc = await _userListsRef(userId).doc(listId).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    final created = _parseTimestamp(data['createdDate']);
    final members = (data['members'] as List<dynamic>? ?? [])
        .map((item) => item.toString())
        .toList();
    return ShoppingList(
      id: doc.id,
      userId: data['userId']?.toString() ?? '',
      members: members,
      name: data['name']?.toString() ?? 'Grocery List',
      icon: data['icon']?.toString() ?? 'CART',
      createdDate: created,
      updatedAt: _parseTimestampNullable(data['updatedAt']) ?? created,
      isArchived: data['isArchived'] as bool? ?? false,
    );
  }

  Future<Map<String, dynamic>?> fetchSharedList(String shareId) async {
    final doc = await _firestore.collection('shared_lists').doc(shareId).get();
    return doc.data();
  }

  DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  DateTime? _parseTimestampNullable(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  GroceryUnit _unitFromLabel(String? label) {
    switch ((label ?? '').toLowerCase()) {
      case 'pcs':
        return GroceryUnit.pcs;
      case 'packet':
        return GroceryUnit.packet;
      case 'kg':
        return GroceryUnit.kg;
      case 'g':
        return GroceryUnit.g;
      case 'litre':
      case 'l':
        return GroceryUnit.litre;
      case 'ml':
        return GroceryUnit.ml;
      case 'item':
      default:
        return GroceryUnit.item;
    }
  }
}
