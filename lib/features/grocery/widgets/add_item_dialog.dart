import 'package:flutter/material.dart';

import '../domain/grocery_unit.dart';
import 'quantity_chip_selector.dart';
import 'unit_selector_widget.dart';

class AddItemResult {
  AddItemResult({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.categoryId,
    required this.isImportant,
  });

  final String name;
  final double quantity;
  final GroceryUnit unit;
  final String categoryId;
  final bool isImportant;
}

class AddItemDialog extends StatefulWidget {
  const AddItemDialog({super.key});

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  double _quantity = 1;
  GroceryUnit _unit = GroceryUnit.item;
  bool _important = false;

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Item name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 12),
            QuantityChipSelector(
              value: _quantity,
              onChanged: (value) => setState(() => _quantity = value),
            ),
            const SizedBox(height: 12),
            UnitSelectorWidget(
              value: _unit,
              onChanged: (unit) => setState(() => _unit = unit),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mark as important'),
              value: _important,
              onChanged: (value) => setState(() => _important = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(
              AddItemResult(
                name: name,
                quantity: _quantity,
                unit: _unit,
                categoryId: _categoryController.text.trim(),
                isImportant: _important,
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
