import 'package:hive_flutter/hive_flutter.dart';

import '../models/ad_item.dart';

class AdsStorage {
  static const _boxName = 'ads_box';
  static const _adsKey = 'ads_items';

  Future<Box> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box(_boxName);
    }
    return Hive.openBox(_boxName);
  }

  Future<List<AdItem>> loadAds() async {
    final box = await _openBox();
    final raw = box.get(_adsKey, defaultValue: <dynamic>[]);
    final list = (raw as List).cast<Map>();
    return list
        .map((item) => AdItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> saveAds(List<AdItem> ads) async {
    final box = await _openBox();
    final encoded = ads.map((ad) => ad.toJson()).toList();
    await box.put(_adsKey, encoded);
  }
}
