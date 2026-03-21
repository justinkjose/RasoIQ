import 'package:flutter/material.dart';

import '../../../data/default_grocery_catalog.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_widgets.dart';
import '../domain/grocery_unit.dart';
import '../services/grocery_search_service.dart';
import '../services/unit_config.dart';

class GroceryAddItemPayload {
  const GroceryAddItemPayload({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.categoryId,
    required this.isImportant,
    required this.packCount,
    required this.packSize,
  });

  final String name;
  final double quantity;
  final GroceryUnit unit;
  final String categoryId;
  final bool isImportant;
  final int packCount;
  final double packSize;
}

class GroceryAddItemSheet extends StatefulWidget {
  const GroceryAddItemSheet({
    super.key,
    required this.initialName,
    required this.onSubmit,
    this.closeOnSubmit = true,
    this.initialQuantity,
    this.initialUnit,
    this.initialCategory,
  });

  final String initialName;
  final double? initialQuantity;
  final GroceryUnit? initialUnit;
  final String? initialCategory;
  final bool closeOnSubmit;
  final Future<void> Function(GroceryAddItemPayload payload) onSubmit;

  @override
  State<GroceryAddItemSheet> createState() => _GroceryAddItemSheetState();
}

class _GroceryAddItemSheetState extends State<GroceryAddItemSheet> {
  late TextEditingController _nameController;
  late TextEditingController _packSizeController;
  int _packCount = 1;
  GroceryUnit _unit = GroceryUnit.pcs;
  String _category = 'Miscellaneous';
  bool _important = false;
  bool _submitting = false;
  final GrocerySearchService _searchService = GrocerySearchService();
  final Map<String, GrocerySearchItem> _localIndex = {};
  List<GrocerySearchItem> _localItems = const [];
  List<GrocerySearchItem> _suggestions = const [];
  List<_QuickQuantity> _quickQuantities = const [];
  bool _loadingLocal = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _packSizeController = TextEditingController(text: '');
    _category = widget.initialCategory ?? _categoryForItem(widget.initialName);
    final initialConfig =
        UnitConfigResolver.resolve(widget.initialName, _category);
    _unit = widget.initialUnit ??
        UnitConfigResolver.defaultUnit(widget.initialName, _category);
    _quickQuantities = _quickQuantitiesFor(initialConfig, _unit);
    _loadLocal();
    _nameController.addListener(_handleNameChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _packSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final config =
        UnitConfigResolver.resolve(_nameController.text.trim(), _category);
    final unitOptions = config.units.toSet().toList();
    if (unitOptions.isEmpty) {
      unitOptions.add(GroceryUnit.pcs);
    }
    if (!unitOptions.contains(_unit)) {
      _unit = unitOptions.first;
      _quickQuantities = _quickQuantitiesFor(config, _unit);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.space24,
        AppTheme.space24,
        AppTheme.space24,
        viewInsets + AppTheme.space24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Item', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppTheme.space16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Item name'),
          ),
          if (_loadingLocal) ...[
            const SizedBox(height: AppTheme.space8),
            Text('Loading local suggestions...', style: AppTextStyles.bodySmall),
          ],
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space8),
            Text('Suggestions', style: AppTextStyles.bodySmall),
            const SizedBox(height: AppTheme.space8),
            ..._suggestions.map(_buildSuggestionTile),
          ],
          const SizedBox(height: AppTheme.space12),
          if (_quickQuantities.isNotEmpty) ...[
            Wrap(
              spacing: AppTheme.space8,
              runSpacing: AppTheme.space8,
              children: _quickQuantities.map(_buildQuantityChip).toList(),
            ),
            const SizedBox(height: AppTheme.space12),
          ],
          Row(
            children: [
              const Text('Quantity'),
              const SizedBox(width: AppTheme.space12),
              IconButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() {
                          _packCount = (_packCount - 1).clamp(1, 9999);
                        }),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_packCount'),
              IconButton(
                onPressed:
                    _submitting ? null : () => setState(() => _packCount += 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
              const SizedBox(width: AppTheme.space12),
              DropdownButton<GroceryUnit>(
                value: _unit,
                items: unitOptions
                    .map(
                      (unit) => DropdownMenuItem(
                        value: unit,
                        child: Text(unit.label),
                      ),
                    )
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _unit = value;
                          final config = UnitConfigResolver.resolve(
                            _nameController.text.trim(),
                            _category,
                          );
                          _quickQuantities = _quickQuantitiesFor(config, _unit);
                        });
                      },
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          TextField(
            controller: _packSizeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Pack size (optional)',
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          SwitchListTile(
            value: _important,
            onChanged: _submitting
                ? null
                : (value) => setState(() => _important = value),
            contentPadding: EdgeInsets.zero,
            title: const Text('Mark item important'),
          ),
          const SizedBox(height: AppTheme.space16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: const Text('Add'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _submitting = true);
    final packSize = double.tryParse(_packSizeController.text.trim()) ?? 0;
    final totalQty =
        packSize > 0 ? packSize * _packCount : _packCount.toDouble();
    final category =
        _category.trim().isEmpty ? _categoryForItem(name) : _category;
    await widget.onSubmit(
      GroceryAddItemPayload(
        name: name,
        quantity: totalQty,
        unit: _unit,
        categoryId: category,
        isImportant: _important,
        packCount: _packCount,
        packSize: packSize,
      ),
    );
    if (!mounted) return;
    if (widget.closeOnSubmit) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _submitting = false;
      _nameController.clear();
      _packSizeController.clear();
      _packCount = 1;
      _important = false;
      _category = 'Miscellaneous';
      final config = UnitConfigResolver.resolve('', _category);
      _unit = UnitConfigResolver.defaultUnit('', _category);
      _quickQuantities = _quickQuantitiesFor(config, _unit);
    });
  }

  Future<void> _loadLocal() async {
    final data = await _searchService.loadLocal();
    _localItems = data.items;
    for (final item in data.items) {
      final key = _normalize(item.name);
      if (key.isEmpty) continue;
      _localIndex[key] = item;
    }
    if (!mounted) return;
    setState(() => _loadingLocal = false);
  }

  void _handleNameChanged() {
    final name = _nameController.text.trim();
    final normalized = _normalize(name);
    if (normalized.isEmpty) {
      setState(() {
        _suggestions = const [];
        _category = _categoryForItem('');
        _unit = _defaultUnitFor('', _category);
        _quickQuantities =
            _quickQuantitiesFor(UnitConfigResolver.general, _unit);
      });
      return;
    }
    final match = _localIndex[normalized];
    final detected = match == null ? _categoryForItem(name) : match.category;
    final config = UnitConfigResolver.resolve(name, detected);
    final defaultUnit = UnitConfigResolver.defaultUnit(name, detected);
    final suggestions = _localItems
        .where(
          (item) => _normalize(item.name).contains(normalized),
        )
        .take(6)
        .toList();
    setState(() {
      _category = detected;
      _unit = defaultUnit;
      _suggestions = suggestions;
      _quickQuantities = _quickQuantitiesFor(config, _unit);
    });
  }

  String _categoryForItem(String name) {
    if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      final normalizedName = _normalize(name);
      final normalizedInitial = _normalize(widget.initialName);
      if (normalizedName.isEmpty || normalizedName == normalizedInitial) {
        return widget.initialCategory!;
      }
    }
    for (final entry in DefaultGroceryCatalog.categories.entries) {
      for (final item in entry.value) {
        if (item.toLowerCase() == name.toLowerCase()) {
          return entry.key;
        }
      }
    }
    return 'Miscellaneous';
  }

  GroceryUnit _defaultUnitFor(String name, String categoryKey) {
    return UnitConfigResolver.defaultUnit(name, categoryKey);
  }

  List<_QuickQuantity> _quickQuantitiesFor(
    UnitConfig config,
    GroceryUnit unit,
  ) {
    final values = config.suggestionsFor(unit);
    return values
        .map((value) => _QuickQuantity(value: value, unit: unit))
        .toList();
  }

  Widget _buildQuantityChip(_QuickQuantity chip) {
    final valueText = chip.value % 1 == 0
        ? chip.value.toStringAsFixed(0)
        : chip.value.toString();
    final label = '$valueText ${chip.unit.label}';
    final selected = chip.unit == _unit &&
        ((chip.unit == GroceryUnit.pcs || chip.unit == GroceryUnit.packet)
            ? _packCount == chip.value.toInt()
            : _packSizeController.text == valueText);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _unit = chip.unit;
          if (chip.unit == GroceryUnit.pcs || chip.unit == GroceryUnit.packet) {
            _packCount = chip.value.toInt();
            _packSizeController.clear();
          } else {
            _packCount = 1;
            _packSizeController.text = valueText;
          }
        });
      },
    );
  }

  Widget _buildSuggestionTile(GrocerySearchItem item) {
    return AppCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        onTap: () => _applySuggestion(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space12,
            vertical: AppTheme.space12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: AppTextStyles.bodyLarge),
                    const SizedBox(height: 4),
                    Text(
                      item.category.replaceAll('_', ' '),
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.add_circle_outline),
            ],
          ),
        ),
      ),
    );
  }

  void _applySuggestion(GrocerySearchItem item) {
    _nameController.text = item.name;
    _nameController.selection = TextSelection.fromPosition(
      TextPosition(offset: item.name.length),
    );
    final config = UnitConfigResolver.resolve(item.name, item.category);
    setState(() {
      _category = item.category;
      _unit = UnitConfigResolver.defaultUnit(item.name, item.category);
      _suggestions = const [];
      _packCount = 1;
      _packSizeController.clear();
      _quickQuantities = _quickQuantitiesFor(config, _unit);
    });
  }

  String _normalize(String input) => input.toLowerCase().trim();
}

class _QuickQuantity {
  const _QuickQuantity({
    required this.value,
    required this.unit,
  });

  final double value;
  final GroceryUnit unit;
}
