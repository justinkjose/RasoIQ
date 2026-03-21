import 'dart:async';

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_widgets.dart';
import '../data/grocery_repository.dart';
import '../services/grocery_search_service.dart';
import '../widgets/grocery_add_item_sheet.dart';
import '../domain/grocery_unit.dart';

class GrocerySearchModal extends StatefulWidget {
  const GrocerySearchModal({
    super.key,
    required this.listId,
    required this.isOffline,
    required this.onItemsAdded,
  });

  final String listId;
  final bool isOffline;
  final VoidCallback onItemsAdded;

  @override
  State<GrocerySearchModal> createState() => _GrocerySearchModalState();
}

class _GrocerySearchModalState extends State<GrocerySearchModal> {
  static const String _allCategories = 'All Categories';

  final GrocerySearchService _searchService = GrocerySearchService();
  final GroceryRepository _repository = GroceryRepository();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<GrocerySearchItem> _items = [];
  List<String> _categories = [];
  String _selectedCategory = _allCategories;
  String _query = '';
  bool _loading = true;
  bool _syncing = false;
  bool _remoteSyncStarted = false;

  @override
  void initState() {
    super.initState();
    _loadLocal();
    _maybeSyncRemote();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocal() async {
    setState(() => _loading = true);
    final data = await _searchService.loadLocal();
    if (!mounted) return;
    setState(() {
      _items = data.items;
      _categories = [_allCategories, ...data.categories];
      _selectedCategory = _categories.contains(_selectedCategory)
          ? _selectedCategory
          : _allCategories;
      _loading = false;
    });
  }

  Future<void> _maybeSyncRemote() async {
    if (_remoteSyncStarted || widget.isOffline) return;
    _remoteSyncStarted = true;
    setState(() => _syncing = true);
    final data = await _searchService.syncRemoteAndLoad();
    if (!mounted) return;
    setState(() {
      _items = data.items;
      _categories = [_allCategories, ...data.categories];
      _selectedCategory = _categories.contains(_selectedCategory)
          ? _selectedCategory
          : _allCategories;
      _syncing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems();
    final query = _searchController.text.trim();
    final normalizedQuery = _normalize(query);
    final hasExactMatch = normalizedQuery.isNotEmpty &&
        _items.any((item) => _normalize(item.name) == normalizedQuery);
    return Scaffold(
      appBar: AppBar(
        title: Text('Smart Search', style: AppTextStyles.headingMedium),
        actions: [
          if (_syncing)
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.space16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppTheme.space24),
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onQueryChanged,
                  decoration: InputDecoration(
                    hintText: 'Search items',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: AppTheme.space12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  items: _categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category.replaceAll('_', ' ')),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _selectedCategory = value ?? _allCategories;
                  }),
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: AppTheme.space8),
                Text(
                  '${filteredItems.length} items',
                  style: AppTextStyles.bodySmall,
                ),
                if (normalizedQuery.isNotEmpty && !hasExactMatch) ...[
                  const SizedBox(height: AppTheme.space12),
                  AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Add new item',
                            style: AppTextStyles.bodyLarge,
                          ),
                        ),
                        FilledButton(
                          onPressed: () => _openCustomItemSheet(query),
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.space16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppTheme.space12,
                    crossAxisSpacing: AppTheme.space12,
                    childAspectRatio: 1,
                  ),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      onTap: () => _openAddItemSheet(item),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusMedium),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                item.name.isNotEmpty
                                    ? item.name[0].toUpperCase()
                                    : '?',
                                style: AppTextStyles.bodyLarge,
                              ),
                            ),
                            const SizedBox(height: AppTheme.space12),
                            Expanded(
                              child: Text(
                                item.name,
                                style: AppTextStyles.bodyLarge,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              item.category.replaceAll('_', ' '),
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _query = _normalize(value));
    });
  }

  List<GrocerySearchItem> _filteredItems() {
    final items = _selectedCategory == _allCategories
        ? _items
        : _items
            .where((item) => _normalize(item.category) == _normalize(_selectedCategory))
            .toList();
    if (_query.isEmpty) return items;
    return items
        .where((item) => _normalize(item.name).contains(_query))
        .toList();
  }

  Future<void> _openAddItemSheet(GrocerySearchItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => GroceryAddItemSheet(
        initialName: item.name,
        initialCategory: item.category,
        onSubmit: (payload) async {
          await _repository.addItem(
            listId: widget.listId,
            name: payload.name,
            quantity: payload.quantity,
            unit: payload.unit,
            categoryId: payload.categoryId,
            isImportant: payload.isImportant,
            packCount: payload.packCount,
            packSize: payload.packSize,
          );
          widget.onItemsAdded();
          await _loadLocal();
        },
      ),
    );
  }

  String _normalize(String value) => value.toLowerCase().trim();

  Future<void> _openCustomItemSheet(String initialName) async {
    final categories =
        _categories.where((category) => category != _allCategories).toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CustomItemSheet(
        initialName: initialName,
        categories: categories,
        onSave: (name, unit, category) async {
          await _repository.addCustomUserItem(
            name: name,
            unit: unit,
            category: category,
          );
          await _loadLocal();
        },
      ),
    );
  }
}

class _CustomItemSheet extends StatefulWidget {
  const _CustomItemSheet({
    required this.initialName,
    required this.categories,
    required this.onSave,
  });

  final String initialName;
  final List<String> categories;
  final Future<void> Function(
    String name,
    GroceryUnit unit,
    String category,
  ) onSave;

  @override
  State<_CustomItemSheet> createState() => _CustomItemSheetState();
}

class _CustomItemSheetState extends State<_CustomItemSheet> {
  late final TextEditingController _nameController;
  GroceryUnit _unit = GroceryUnit.pcs;
  String? _category;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _category = widget.categories.isNotEmpty ? widget.categories.first : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.space24,
        right: AppTheme.space24,
        top: AppTheme.space16,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.space24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add New Item', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppTheme.space16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: AppTheme.space12),
          DropdownButtonFormField<GroceryUnit>(
            initialValue: _unit,
            decoration: const InputDecoration(labelText: 'Default unit'),
            items: GroceryUnit.values
                .toSet()
                .map(
                  (unit) => DropdownMenuItem(
                    value: unit,
                    child: Text(unit.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _unit = value);
            },
          ),
          const SizedBox(height: AppTheme.space12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: widget.categories
                .map(
                  (category) => DropdownMenuItem(
                    value: category,
                    child: Text(category.replaceAll('_', ' ')),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: AppTheme.space16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _category == null || _category!.isEmpty) return;
    setState(() => _saving = true);
    await widget.onSave(name, _unit, _category!);
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}
