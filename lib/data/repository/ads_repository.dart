import 'dart:async';

import '../local/ads_storage.dart';
import '../models/ad_item.dart';
import '../remote/ads_firestore_service.dart';

class AdsRepository {
  AdsRepository({
    AdsStorage? storage,
    AdsFirestoreService? firestoreService,
  })  : _storage = storage ?? AdsStorage(),
        _firestoreService = firestoreService ?? AdsFirestoreService();

  final AdsStorage _storage;
  final AdsFirestoreService _firestoreService;

  Future<List<AdItem>> getAds() async {
    return _storage.loadAds();
  }

  Future<void> syncFromRemote() async {
    try {
      final remote = await _firestoreService.fetchAds();
      if (remote.isEmpty) return;
      final local = await _storage.loadAds();
      final map = <String, AdItem>{
        for (final ad in local) ad.id: ad,
      };
      for (final ad in remote) {
        map[ad.id] = ad;
      }
      await _storage.saveAds(map.values.toList());
    } catch (_) {
      return;
    }
  }

  Future<List<AdItem>> getAdsForScreen(
    String targetScreen, {
    String? type,
  }) async {
    final ads = await _storage.loadAds();
    return _filterAds(ads, targetScreen, type);
  }

  Future<List<AdItem>> getAdsForScreenCachedThenSync(
    String targetScreen, {
    String? type,
  }) async {
    final ads = await getAdsForScreen(targetScreen, type: type);
    unawaited(syncFromRemote());
    return ads;
  }

  List<AdItem> _filterAds(
    List<AdItem> ads,
    String targetScreen,
    String? type,
  ) {
    final now = DateTime.now();
    final filtered = ads.where((ad) {
      if (!ad.active) return false;
      if (ad.startAt != null && ad.startAt!.isAfter(now)) return false;
      if (ad.endAt != null && ad.endAt!.isBefore(now)) return false;
      if (type != null && ad.type != type) return false;
      if (ad.targetScreens.isEmpty) return true;
      return ad.targetScreens.any((screen) =>
          screen.toLowerCase() == targetScreen.toLowerCase() ||
          screen.toLowerCase() == 'all');
    }).toList();

    filtered.sort((a, b) => b.priority.compareTo(a.priority));
    return filtered;
  }
}
