import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_widgets.dart';
import '../domain/grocery_unit.dart';
import '../providers/grocery_provider.dart';
import '../services/category_matcher.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  bool _captured = false;
  bool _processed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Receipt Scanner', style: AppTextStyles.headingMedium),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.space24),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Open camera', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppTheme.space8),
                Text('Capture receipt to begin OCR.', style: AppTextStyles.bodySmall),
                const SizedBox(height: AppTheme.space16),
                FilledButton(
                  onPressed: () => setState(() => _captured = true),
                  child: const Text('Capture Receipt'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Run OCR', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppTheme.space8),
                Text('Extract grocery items from receipt.', style: AppTextStyles.bodySmall),
                const SizedBox(height: AppTheme.space16),
                FilledButton(
                  onPressed: _captured ? () => setState(() => _processed = true) : null,
                  child: const Text('Run OCR'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Confirm items', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppTheme.space8),
                Text('Review and edit quantities before adding.',
                    style: AppTextStyles.bodySmall),
                const SizedBox(height: AppTheme.space16),
                FilledButton(
                  onPressed: _processed
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ReceiptReviewScreen(),
                            ),
                          );
                        }
                      : null,
                  child: const Text('Review Items'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReceiptReviewScreen extends StatefulWidget {
  const ReceiptReviewScreen({super.key});

  @override
  State<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends State<ReceiptReviewScreen> {
  final List<_ReceiptItem> _items = [
    _ReceiptItem('Milk Toned', 1, GroceryUnit.litre),
    _ReceiptItem('Rice', 2, GroceryUnit.kg),
    _ReceiptItem('Onion', 2, GroceryUnit.kg),
  ];
  final CategoryMatcher _categoryMatcher = const CategoryMatcher();

  @override
  void dispose() {
    for (final item in _items) {
      item.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Confirm Items', style: AppTextStyles.headingMedium),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.space24),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space12),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: AppTextStyles.bodyLarge),
                  const SizedBox(height: AppTheme.space8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: item.controller,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Quantity'),
                        ),
                      ),
                      const SizedBox(width: AppTheme.space12),
                      Expanded(
                        child: DropdownButtonFormField<GroceryUnit>(
                          initialValue: item.unit,
                          items: const [
                            DropdownMenuItem(
                              value: GroceryUnit.ml,
                              child: Text('ml'),
                            ),
                            DropdownMenuItem(
                              value: GroceryUnit.litre,
                              child: Text('litre'),
                            ),
                            DropdownMenuItem(
                              value: GroceryUnit.g,
                              child: Text('g'),
                            ),
                            DropdownMenuItem(
                              value: GroceryUnit.kg,
                              child: Text('kg'),
                            ),
                            DropdownMenuItem(
                              value: GroceryUnit.pcs,
                              child: Text('pcs'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => item.unit = value ?? item.unit);
                          },
                          decoration: const InputDecoration(labelText: 'Unit'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(AppTheme.space16),
        child: FilledButton(
          onPressed: () => _addAll(context),
          child: const Text('Add Items'),
        ),
      ),
    );
  }

  void _addAll(BuildContext context) {
    final provider = context.read<GroceryProvider>();
    for (final item in _items) {
      final quantity = double.tryParse(item.controller.text.trim()) ?? item.quantity;
      provider.addItem(
        name: item.name,
        quantity: quantity,
        unit: item.unit,
        categoryId: _categoryMatcher.matchCategory(item.name),
      );
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

class _ReceiptItem {
  _ReceiptItem(this.name, this.quantity, this.unit)
      : controller = TextEditingController(text: quantity.toString());

  final String name;
  final double quantity;
  GroceryUnit unit;
  final TextEditingController controller;
}
