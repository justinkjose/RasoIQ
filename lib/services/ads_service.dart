import 'dart:async';

import '../data/models/ad_item.dart';
import '../data/repository/ads_repository.dart';

class AdsService {
  AdsService({AdsRepository? repository})
      : _repository = repository ?? AdsRepository();

  final AdsRepository _repository;

  Future<List<AdItem>> getAdsForScreen(
    String targetScreen, {
    String? type,
  }) async {
    final ads = await _repository.getAdsForScreen(targetScreen, type: type);
    unawaited(_repository.syncFromRemote());
    return ads;
  }

  Future<void> refreshAds() async {
    await _repository.syncFromRemote();
  }
}
