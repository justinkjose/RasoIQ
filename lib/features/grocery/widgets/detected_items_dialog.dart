import 'package:flutter/material.dart';

import '../domain/grocery_unit.dart';
import '../services/grocery_item_parser.dart';

class DetectedItemsDialog extends StatefulWidget {
  const DetectedItemsDialog({
    super.key,
    required this.items,
  });

  final List<ParsedGroceryItem> items;

  @override
  State<DetectedItemsDialog> createState() => _DetectedItemsDialogState();
}

class _DetectedItemsDialogState extends State<DetectedItemsDialog> {
  late final List<_EditableDetectedItem> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.items
        .map((item) => _EditableDetectedItem.from(item))
        .toList();
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.nameController.dispose();
      item.qtyController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Detected Items'),
      content: SizedBox(
        width: 360,
        child: _items.isEmpty
            ? const Text('No items detected.')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Checkbox(
                          value: item.selected,
                          onChanged: (value) {
                            setState(() => item.selected = value ?? true);
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: item.nameController,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'Item',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 72,
                          child: TextField(
                            controller: item.qtyController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'Qty',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_unitLabel(item.unit)),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop<List<ParsedGroceryItem>>(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _items.isEmpty ? null : _confirm,
          child: const Text('Add Items'),
        ),
      ],
    );
  }

  void _confirm() {
    final selected = <ParsedGroceryItem>[];
    for (final item in _items) {
      if (!item.selected) continue;
      final name = item.nameController.text.trim();
      if (name.isEmpty) continue;
      final qty = double.tryParse(item.qtyController.text.trim()) ?? item.quantity;
      selected.add(
        ParsedGroceryItem(
          name: name,
          quantity: qty <= 0 ? item.quantity : qty,
          unit: item.unit,
        ),
      );
    }
    Navigator.of(context).pop<List<ParsedGroceryItem>>(selected);
  }

  String _unitLabel(GroceryUnit unit) {
    switch (unit) {
      case GroceryUnit.kg:
        return 'kg';
      case GroceryUnit.g:
        return 'g';
      case GroceryUnit.litre:
        return 'l';
      case GroceryUnit.ml:
        return 'ml';
      case GroceryUnit.pcs:
        return 'pcs';
      case GroceryUnit.packet:
        return 'pkt';
      case GroceryUnit.item:
        return 'item';
    }
  }
}

class _EditableDetectedItem {
  _EditableDetectedItem({
    required this.nameController,
    required this.qtyController,
    required this.unit,
    required this.quantity,
  }) : selected = true;

  factory _EditableDetectedItem.from(ParsedGroceryItem item) {
    return _EditableDetectedItem(
      nameController: TextEditingController(text: item.name),
      qtyController: TextEditingController(text: item.quantity.toString()),
      unit: item.unit,
      quantity: item.quantity,
    );
  }

  final TextEditingController nameController;
  final TextEditingController qtyController;
  final GroceryUnit unit;
  final double quantity;
  bool selected;
}
