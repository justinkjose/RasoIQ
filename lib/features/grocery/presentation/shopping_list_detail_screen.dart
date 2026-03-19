import 'package:flutter/material.dart';

import '../data/grocery_repository.dart';
import '../domain/grocery_item.dart';
import '../domain/grocery_unit.dart';
import '../domain/shopping_list.dart';
import '../widgets/grocery_item_card.dart';
import 'add_grocery_item_screen.dart';
import 'qr_export_screen.dart';
import 'qr_scanner_screen.dart';

class ShoppingListDetailScreen extends StatefulWidget {
  const ShoppingListDetailScreen({super.key, required this.list});

  final ShoppingList list;

  @override
  State<ShoppingListDetailScreen> createState() => _ShoppingListDetailScreenState();
}

class _ShoppingListDetailScreenState extends State<ShoppingListDetailScreen> {
  final GroceryRepository _repository = GroceryRepository();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quickAddController = TextEditingController();
  List<GroceryItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quickAddController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final items = await _repository.getItemsForList(widget.list.id);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  void _applyFilter() {
    setState(() {});
  }

  Future<void> _toggleDone(GroceryItem item) async {
    await _repository.toggleDone(item.id);
    await _loadItems();
  }

  Future<void> _toggleImportant(GroceryItem item) async {
    await _repository.toggleImportant(item.id);
    await _loadItems();
  }

  Future<void> _quickAdd() async {
    final name = _quickAddController.text.trim();
    if (name.isEmpty) return;
    await _repository.addItem(
      listId: widget.list.id,
      name: name,
      quantity: 1,
      unit: GroceryUnit.item,
      categoryId: '',
    );
    _quickAddController.clear();
    await _loadItems();
  }

  Future<void> _openAddDialog() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddGroceryItemScreen(listId: widget.list.id),
      ),
    );
    if (created == true) {
      await _loadItems();
    }
  }

  Future<void> _openExport() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QRExportScreen(
          listId: widget.list.id,
          listName: widget.list.name,
        ),
      ),
    );
  }

  Future<void> _openScanner() async {
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );
    if (imported == true) {
      await _loadItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final visibleItems = query.isEmpty
        ? _items
        : _items.where((item) => item.name.toLowerCase().contains(query)).toList();
    final grouped = _groupByCategory(visibleItems);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.list.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: _openExport,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _openScanner,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openAddDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search items',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _quickAddController,
                          decoration: const InputDecoration(
                            hintText: 'Quick add item',
                          ),
                          onSubmitted: (_) => _quickAdd(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _quickAdd,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: grouped.entries.map((entry) {
                      final title = entry.key == 'uncategorized'
                          ? 'Uncategorized'
                          : entry.key;
                      final items = entry.value;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          ...items.map(
                            (item) => GroceryItemCard(
                              item: item,
                              onToggleDone: () => _toggleDone(item),
                              onToggleImportant: () => _toggleImportant(item),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  Map<String, List<GroceryItem>> _groupByCategory(List<GroceryItem> items) {
    final map = <String, List<GroceryItem>>{};
    for (final item in items) {
      final key = item.categoryId.isEmpty ? 'uncategorized' : item.categoryId;
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }
}
