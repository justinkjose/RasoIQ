import 'dart:io';

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_widgets.dart';
import '../../expenses/domain/expense_entry.dart';
import '../../expenses/services/expense_service.dart';
import '../domain/pantry_scan_item.dart';
import '../services/pantry_service.dart';

class ReceiptPreviewScreen extends StatefulWidget {
  const ReceiptPreviewScreen({
    super.key,
    required this.image,
    required this.items,
  });

  final File image;
  final List<PantryScanItem> items;

  @override
  State<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends State<ReceiptPreviewScreen> {
  final PantryService _pantryService = PantryService();
  final ExpenseService _expenseService = ExpenseService();

  late List<PantryScanItem> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.items
        .map(
          (item) => PantryScanItem(
            name: item.name,
            quantity: item.quantity,
            unit: item.unit,
            price: item.price,
          ),
        )
        .toList();
  }

  Future<void> _confirm() async {
    if (_items.isEmpty) return;
    final invalid = _items.any(
      (item) =>
          item.quantity <= 0 ||
          item.quantity > 20 ||
          (item.price != null && item.price! > 10000),
    );
    if (invalid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fix invalid quantities or prices first.')),
      );
      return;
    }
    for (final item in _items) {
      await _pantryService.addItem(
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
      );
      final price = item.price;
      if (price != null && price > 0) {
        await _expenseService.addEntry(
          ExpenseEntry(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            itemName: item.name,
            category: 'Pantry',
            quantity: item.quantity,
            unit: item.unit,
            price: price,
            date: DateTime.now(),
            source: 'bill_scan',
          ),
        );
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Items')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.space24),
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: Image.file(widget.image, height: 180, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: AppTheme.space24),
          const SectionHeader(title: 'Detected Items'),
          const SizedBox(height: AppTheme.space12),
          if (_items.isEmpty)
            const Text('No items detected. Try another image.'),
          if (_items.isNotEmpty)
            ..._items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.space12),
                child: _EditableItemCard(
                  item: item,
                  onRemove: () => _removeItem(index),
                  onChanged: (updated) => _items[index] = updated,
                ),
              );
            }),
          const SizedBox(height: AppTheme.space24),
          RoundedButton(
            label: 'Add Items to Pantry',
            icon: Icons.check,
            onPressed: _confirm,
          ),
        ],
      ),
    );
  }
}

class _EditableItemCard extends StatefulWidget {
  const _EditableItemCard({
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  final PantryScanItem item;
  final ValueChanged<PantryScanItem> onChanged;
  final VoidCallback onRemove;

  @override
  State<_EditableItemCard> createState() => _EditableItemCardState();
}

class _EditableItemCardState extends State<_EditableItemCard> {
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late String _unit;
  String? _quantityError;
  String? _priceError;

  static const _units = <String>[
    'item',
    'pcs',
    'kg',
    'g',
    'litre',
    'ml',
    'packet',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _quantityController =
        TextEditingController(text: widget.item.quantity.toString());
    _priceController = TextEditingController(
      text: widget.item.price == null ? '' : widget.item.price!.toString(),
    );
    _unit = widget.item.unit;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _notifyParent() {
    final quantity = double.tryParse(_quantityController.text.trim()) ?? 0;
    String? quantityError;
    if (quantity <= 0) {
      quantityError = 'Enter a valid quantity';
    } else if (quantity > 20) {
      quantityError = 'Quantity must be 20 or less';
    }

    final priceText = _priceController.text.trim();
    final price = priceText.isEmpty ? null : double.tryParse(priceText);
    String? priceError;
    if (price != null && price > 10000) {
      priceError = 'Price must be 10000 or less';
    }

    setState(() {
      _quantityError = quantityError;
      _priceError = priceError;
    });

    if (quantityError != null || priceError != null) return;

    widget.onChanged(
      PantryScanItem(
        name: _nameController.text.trim(),
        quantity: quantity <= 0 ? 1 : quantity,
        unit: _unit,
        price: price != null && price > 0 ? price : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Item name'),
                  onChanged: (_) => _notifyParent(),
                ),
              ),
              IconButton(
                onPressed: widget.onRemove,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    errorText: _quantityError,
                  ),
                  onChanged: (_) => _notifyParent(),
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _unit,
                  items: _units
                      .map(
                        (unit) => DropdownMenuItem(
                          value: unit,
                          child: Text(unit),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _unit = value);
                    _notifyParent();
                  },
                  decoration: const InputDecoration(labelText: 'Unit'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Price',
              errorText: _priceError,
            ),
            onChanged: (_) => _notifyParent(),
          ),
        ],
      ),
    );
  }
}
