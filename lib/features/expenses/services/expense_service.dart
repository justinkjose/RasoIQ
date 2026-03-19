import '../domain/expense_entry.dart';
import 'expense_storage.dart';

class ExpenseService {
  ExpenseService({ExpenseStorage? storage}) : _storage = storage ?? ExpenseStorage();

  final ExpenseStorage _storage;

  Future<void> addEntry(ExpenseEntry entry) async {
    final entries = await _storage.loadEntries();
    entries.add(entry);
    await _storage.saveEntries(entries);
  }
}
