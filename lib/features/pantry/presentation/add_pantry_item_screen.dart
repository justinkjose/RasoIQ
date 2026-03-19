import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_widgets.dart';
import '../../expenses/domain/expense_entry.dart';
import '../../expenses/services/expense_service.dart';
import '../services/pantry_service.dart';

class AddPantryItemScreen extends StatefulWidget {
  const AddPantryItemScreen({super.key});

  @override
  State<AddPantryItemScreen> createState() => _AddPantryItemScreenState();
}

class _AddPantryItemScreenState extends State<AddPantryItemScreen> {
  final PantryService _pantryService = PantryService();
  final ExpenseService _expenseService = ExpenseService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  String _unit = 'item';
  DateTime? _expiryDate;

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
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() => _expiryDate = picked);
  }

  Future<void> _saveItem() async {
    final name = _nameController.text.trim();
    final quantity = double.tryParse(_quantityController.text.trim()) ?? 0;
    final priceText = _priceController.text.trim();
    final price = priceText.isEmpty ? null : double.tryParse(priceText);
    if (name.isEmpty || quantity <= 0) return;

    await _pantryService.addItem(
      name: name,
      quantity: quantity,
      unit: _unit,
      expiryDate: _expiryDate,
    );
    if (price != null && price > 0) {
      await _expenseService.addEntry(
        ExpenseEntry(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          itemName: name,
          category: 'Pantry',
          quantity: quantity,
          unit: _unit,
          price: price,
          date: DateTime.now(),
          source: 'manual_add',
        ),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Pantry Item')),
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
                  decoration: const InputDecoration(
                    hintText: 'e.g. Basmati Rice',
                  ),
                ),
                const SizedBox(height: AppTheme.space16),
                Text('Quantity', style: AppTextStyles.bodySmall),
                const SizedBox(height: AppTheme.space8),
                TextField(
                  controller: _quantityController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'e.g. 2',
                  ),
                ),
                const SizedBox(height: AppTheme.space16),
                Text('Unit', style: AppTextStyles.bodySmall),
                const SizedBox(height: AppTheme.space8),
                DropdownButtonFormField<String>(
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
                  },
                  decoration: const InputDecoration(),
                ),
                const SizedBox(height: AppTheme.space16),
                Text('Price (optional)', style: AppTextStyles.bodySmall),
                const SizedBox(height: AppTheme.space8),
                TextField(
                  controller: _priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'e.g. 120',
                  ),
                ),
                const SizedBox(height: AppTheme.space16),
                Text('Expiry date', style: AppTextStyles.bodySmall),
                const SizedBox(height: AppTheme.space8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _expiryDate == null
                            ? 'No date selected'
                            : '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}',
                        style: AppTextStyles.bodyLarge,
                      ),
                    ),
                    RoundedButton(
                      label: 'Pick',
                      onPressed: _pickExpiryDate,
                      fullWidth: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space24),
          RoundedButton(
            label: 'Add Item',
            icon: Icons.add,
            onPressed: _saveItem,
          ),
        ],
      ),
    );
  }
}
