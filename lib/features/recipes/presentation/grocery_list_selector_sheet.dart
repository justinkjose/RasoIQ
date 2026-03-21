import 'package:flutter/material.dart';

import '../../grocery/data/grocery_repository.dart';
import '../../grocery/domain/shopping_list.dart';
import '../../../theme/app_theme.dart';

class GroceryListSelectorSheet extends StatefulWidget {
  const GroceryListSelectorSheet({
    super.key,
    required this.repository,
    required this.onSelected,
  });

  final GroceryRepository repository;
  final ValueChanged<ShoppingList> onSelected;

  @override
  State<GroceryListSelectorSheet> createState() =>
      _GroceryListSelectorSheetState();
}

class _GroceryListSelectorSheetState extends State<GroceryListSelectorSheet> {
  List<ShoppingList> _lists = [];
  bool _loading = true;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadLists() async {
    final lists = await widget.repository.getLists();
    if (!mounted) return;
    setState(() {
      _lists = lists;
      _loading = false;
    });
  }

  Future<void> _createList() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final created =
        await widget.repository.createList(name: name, icon: 'CART');
    if (!mounted) return;
    widget.onSelected(created);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Grocery List', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppTheme.space16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_lists.isEmpty)
              Text(
                'No lists yet. Create one below.',
                style: AppTextStyles.bodySmall,
              )
            else
              SizedBox(
                height: 220,
                child: ListView.builder(
                  itemCount: _lists.length,
                  itemBuilder: (context, index) {
                    final list = _lists[index];
                    return ListTile(
                      title: Text(list.name),
                      leading: const Icon(Icons.list_alt_outlined),
                      onTap: () {
                        widget.onSelected(list);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
            const Divider(height: AppTheme.space32),
            Text('Create new list', style: AppTextStyles.bodyLarge),
            const SizedBox(height: AppTheme.space8),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'New list name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppTheme.space12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _createList,
                child: const Text('Create & Use'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
