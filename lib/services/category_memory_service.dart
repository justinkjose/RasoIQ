import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CategoryMemoryService {
  static const _key = 'category_memory';

  Future<Map<String, String>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key) ?? '{}';
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value.toString()));
  }

  Future<void> _save(Map<String, String> memory) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(memory));
  }

  Future<String?> getCategoryFor(String name) async {
    final key = name.toLowerCase().trim();
    if (key.isEmpty) return null;
    final memory = await _load();
    return memory[key];
  }

  Future<void> saveCategoryFor(String name, String category) async {
    final key = name.toLowerCase().trim();
    if (key.isEmpty || category.trim().isEmpty) return;
    final memory = await _load();
    memory[key] = category.trim();
    await _save(memory);
  }
}
