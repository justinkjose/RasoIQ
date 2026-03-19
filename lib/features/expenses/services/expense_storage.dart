import 'package:hive_flutter/hive_flutter.dart';

import '../domain/expense_entry.dart';

class ExpenseStorage {
  static const expenseBoxName = 'expense_box';
  static const expenseEntriesKey = 'expense_entries';

  Future<Box> _openBox() async {
    if (Hive.isBoxOpen(expenseBoxName)) {
      return Hive.box(expenseBoxName);
    }
    return Hive.openBox(expenseBoxName);
  }

  Future<List<ExpenseEntry>> loadEntries() async {
    final box = await _openBox();
    final raw = box.get(expenseEntriesKey, defaultValue: <dynamic>[]);
    final list = (raw as List).cast<Map>();
    return list
        .map((entry) => ExpenseEntry.fromJson(Map<String, dynamic>.from(entry)))
        .toList();
  }

  Future<void> saveEntries(List<ExpenseEntry> entries) async {
    final box = await _openBox();
    final encoded = entries.map((entry) => entry.toJson()).toList();
    await box.put(expenseEntriesKey, encoded);
  }
}
