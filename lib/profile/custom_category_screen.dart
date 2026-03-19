import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class CustomCategoryScreen extends StatefulWidget {
  const CustomCategoryScreen({super.key});

  @override
  State<CustomCategoryScreen> createState() => _CustomCategoryScreenState();
}

class _CustomCategoryScreenState extends State<CustomCategoryScreen> {
  static const _boxName = 'category_box';

  final TextEditingController _controller = TextEditingController();
  bool _loading = true;
  List<MapEntry<String, String>> _categories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final box = await Hive.openBox<String>(_boxName);
    final entries = box.toMap().entries.map((entry) {
      return MapEntry(entry.key.toString(), entry.value.toString());
    }).toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    if (!mounted) return;
    setState(() {
      _categories = entries;
      _loading = false;
    });
  }

  Future<void> _addCategory() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final box = await Hive.openBox<String>(_boxName);
    await box.put(id, name);
    _controller.clear();
    await _load();
  }

  Future<void> _removeCategory(String id) async {
    final box = await Hive.openBox<String>(_boxName);
    await box.delete(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custom Categories')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppTheme.space24),
              children: [
                AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            labelText: 'New category',
                          ),
                          onSubmitted: (_) => _addCategory(),
                        ),
                      ),
                      const SizedBox(width: AppTheme.space12),
                      RoundedButton(
                        label: 'Add',
                        onPressed: _addCategory,
                        fullWidth: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space16),
                if (_categories.isEmpty)
                  const AppCard(
                    child: Text('No custom categories yet.'),
                  ),
                if (_categories.isNotEmpty)
                  ..._categories.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.space12),
                      child: AppCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(entry.value, style: AppTextStyles.bodyLarge),
                            ),
                            IconButton(
                              onPressed: () => _removeCategory(entry.key),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
