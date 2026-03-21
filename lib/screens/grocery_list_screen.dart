import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/grocery/data/grocery_repository.dart';
import '../features/grocery/domain/shopping_list.dart';
import '../features/grocery/presentation/shopping_list_detail_screen.dart';
import '../providers/connectivity_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/offline_banner.dart';

class GroceryListScreen extends StatefulWidget {
  const GroceryListScreen({super.key});

  @override
  State<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  final GroceryRepository _repository = GroceryRepository();
  List<ShoppingList> _lists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    setState(() => _loading = true);
    final lists = await _repository.getLists();
    if (!mounted) return;
    setState(() {
      _lists = lists;
      _loading = false;
    });
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Grocery List'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter list name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final navigator = Navigator.of(dialogContext);
              await _repository.createList(name: name, icon: 'CART');
              if (!mounted) return;
              navigator.pop();
              await _loadLists();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _openList(ShoppingList list) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShoppingListDetailScreen(listId: list.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grocery Lists'),
        actions: [
          IconButton(
            onPressed: _loadLists,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
      body: Builder(
        builder: (context) {
          final isOffline = context.watch<ConnectivityProvider>().isOffline;
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_lists.isEmpty) {
            return Column(
              children: [
                if (isOffline) const OfflineBanner(),
                const Expanded(child: _EmptyState()),
              ],
            );
          }
          return Column(
            children: [
              if (isOffline) const OfflineBanner(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppTheme.space24),
                  itemCount: _lists.length,
                  itemBuilder: (context, index) {
                    final list = _lists[index];
                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppTheme.space12),
                      child: Card(
                        child: ListTile(
                          title: Text(list.name),
                          onTap: () => _openList(list),
                          subtitle: FutureBuilder<int>(
                            future: _repository.getItemsForList(list.id).then(
                                  (items) => items.length,
                                ),
                            builder: (context, snapshot) {
                              final count = snapshot.data ?? 0;
                              return Text('$count items');
                            },
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No lists yet. Tap + to create one.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
