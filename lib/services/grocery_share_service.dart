import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

import '../features/grocery/domain/grocery_item.dart';
import '../features/grocery/domain/shopping_list.dart';
import '../features/grocery/data/remote_grocery_repository.dart';
import 'analytics_service.dart';

class GroceryShareService {
  GroceryShareService({RemoteGroceryRepository? remoteRepository})
      : _remoteRepository = remoteRepository ?? RemoteGroceryRepository(),
        _firestore = FirebaseFirestore.instance;

  final RemoteGroceryRepository _remoteRepository;
  final FirebaseFirestore _firestore;

  static const String _deepLinkBase = 'https://rasoiq.app/list';

  Future<Uri> createShareLink({
    required ShoppingList list,
    required List<GroceryItem> items,
  }) async {
    await _remoteRepository.upsertList(list);
    for (final item in items) {
      await _remoteRepository.upsertItem(item);
    }

    await _firestore.collection('shared_lists').doc(list.id).set({
      'list': list.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));

    return Uri.parse('$_deepLinkBase?listId=${list.id}');
  }

  Future<void> shareToWhatsApp({
    required ShoppingList list,
    required List<GroceryItem> items,
  }) async {
    final link = await createShareLink(list: list, items: items);
    final message =
        "Hey! Here's my grocery list:\n\n${list.name}\n\nOpen here: $link";
    await Share.share(message);
    await AnalyticsService.instance.logListShared(list.id);
  }
}
