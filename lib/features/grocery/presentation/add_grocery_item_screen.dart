import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../data/grocery_repository.dart';
import '../widgets/grocery_add_item_sheet.dart';

class AddGroceryItemScreen extends StatefulWidget {
  const AddGroceryItemScreen({super.key, required this.listId});

  final String listId;

  @override
  State<AddGroceryItemScreen> createState() => _AddGroceryItemScreenState();
}

class _AddGroceryItemScreenState extends State<AddGroceryItemScreen> {
  final GroceryRepository _repository = GroceryRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Grocery Item')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.space24),
          child: GroceryAddItemSheet(
            initialName: '',
            closeOnSubmit: false,
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
              if (!context.mounted) return;
              Navigator.of(context).pop(true);
            },
          ),
        ),
      ),
    );
  }
}
