import 'package:flutter/material.dart';

import '../../../data/default_grocery_catalog.dart';
import '../../../services/category_memory_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_widgets.dart';
import '../data/grocery_repository.dart';
import '../domain/grocery_unit.dart';

class AddGroceryItemScreen extends StatefulWidget {
  const AddGroceryItemScreen({super.key, required this.listId});

  final String listId;

  @override
  State<AddGroceryItemScreen> createState() => _AddGroceryItemScreenState();
}

class _AddGroceryItemScreenState extends State<AddGroceryItemScreen> {
  final GroceryRepository _repository = GroceryRepository();
  final CategoryMemoryService _memory = CategoryMemoryService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '1');

  GroceryUnit _unit = GroceryUnit.item;
  String? _category;
  bool _loadingCategory = false;

  List<String> get _categories => DefaultGroceryCatalog.categories.keys.toList();

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _onNameChanged(String value) async {
    final name = value.trim();
    if (name.isEmpty) return;
    setState(() => _loadingCategory = true);
    final stored = await _memory.getCategoryFor(name);
    if (!mounted) return;
    setState(() {
      _category = stored ?? _category;
      _loadingCategory = false;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final quantity = double.tryParse(_quantityController.text.trim()) ?? 0.0;
    if (name.isEmpty || quantity <= 0) return;

    final category = _category ?? 'Uncategorized';
    await _repository.addItem(
      listId: widget.listId,
      name: name,
      quantity: quantity,
      unit: _unit,
      categoryId: category,
    );

    await _memory.saveCategoryFor(name, category);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Grocery Item')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.space24),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Item name', style: AppTextStyles.bodySmall),
                const SizedBox(height: AppTheme.space8),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(hintText: 'e.g. Basmati Rice'),
                  onChanged: _onNameChanged,
                ),
                if (_loadingCategory) ...[
                  const SizedBox(height: AppTheme.space8),
                  Text('Checking category memory...', style: AppTextStyles.bodySmall),
                ],
                const SizedBox(height: AppTheme.space16),
                Text('Quantity', style: AppTextStyles.bodySmall),
                const SizedBox(height: AppTheme.space8),
                TextField(
                  controller: _quantityController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: 'e.g. 2'),
                ),
                const SizedBox(height: AppTheme.space16),
                Text('Unit', style: AppTextStyles.bodySmall),
                const SizedBox(height: AppTheme.space8),
                DropdownButtonFormField<GroceryUnit>(
                  initialValue: _unit,
                  items: GroceryUnit.values
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
                const SizedBox(height: AppTheme.space16),
                Text('Category', style: AppTextStyles.bodySmall),
                const SizedBox(height: AppTheme.space8),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  hint: const Text('Select category'),
                  items: _categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _category = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space24),
          RoundedButton(
            label: 'Add Item',
            icon: Icons.add,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
