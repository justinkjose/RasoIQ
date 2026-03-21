import 'package:flutter/material.dart';

import '../../../data/default_grocery_catalog.dart';
import '../../../theme/app_theme.dart';

class KitchenAddItemPayload {
  const KitchenAddItemPayload({
    required this.name,
    required this.packCount,
    required this.packSize,
    required this.unit,
    required this.category,
    required this.expiryDate,
  });

  final String name;
  final int packCount;
  final double packSize;
  final String unit;
  final String category;
  final DateTime? expiryDate;

  double get totalQuantity =>
      packSize > 0 ? packSize * packCount : packCount.toDouble();
}

class KitchenAddItemSheet extends StatefulWidget {
  const KitchenAddItemSheet({
    super.key,
    required this.onSubmit,
    this.initialName,
    this.initialQuantity,
    this.initialUnit,
    this.initialCategory,
    this.title = 'Add to Kitchen',
    this.submitLabel = 'Add',
  });

  final Future<void> Function(KitchenAddItemPayload payload) onSubmit;
  final String? initialName;
  final double? initialQuantity;
  final String? initialUnit;
  final String? initialCategory;
  final String title;
  final String submitLabel;

  @override
  State<KitchenAddItemSheet> createState() => _KitchenAddItemSheetState();
}

class _KitchenAddItemSheetState extends State<KitchenAddItemSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _packSizeController;
  int _packCount = 1;
  late String _unit;
  late String _category;
  DateTime? _expiryDate;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _packSizeController = TextEditingController(
      text: widget.initialQuantity == null
          ? ''
          : widget.initialQuantity!.toString(),
    );
    _category = widget.initialCategory ??
        _detectCategory(widget.initialName ?? '');
    _unit = widget.initialUnit ?? _unitsForCategory(_category).first;
    _nameController.addListener(() {
      final detected = _detectCategory(_nameController.text.trim());
      if (detected != _category) {
        setState(() {
          _category = detected;
          final updatedUnits = _unitsForCategory(_category);
          if (updatedUnits.isNotEmpty) {
            _unit = updatedUnits.first;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _packSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unitOptions = _unitsForCategory(_category);
    if (!unitOptions.contains(_unit)) {
      _unit = unitOptions.first;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.space24,
        right: AppTheme.space24,
        top: AppTheme.space16,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.space24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: AppTextStyles.titleMedium),
          const SizedBox(height: AppTheme.space16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Item name'),
          ),
          const SizedBox(height: AppTheme.space12),
          TextField(
            controller: _packSizeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Pack size (optional)'),
          ),
          const SizedBox(height: AppTheme.space12),
          Row(
            children: [
              Expanded(
                child: _Stepper(
                  label: 'Quantity',
                  value: _packCount,
                  onChanged: (value) => setState(() => _packCount = value),
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _unit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: unitOptions
                      .map(
                        (unit) => DropdownMenuItem(
                          value: unit,
                          child: Text(unit),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _unit = value ?? _unit),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          OutlinedButton.icon(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 3)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() => _expiryDate = date);
              }
            },
            icon: const Icon(Icons.event_outlined),
            label: Text(
              _expiryDate == null
                  ? 'Set Expiry Date'
                  : 'Expiry: ${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}',
            ),
          ),
          const SizedBox(height: AppTheme.space16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(widget.submitLabel),
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
    final category = _detectCategory(name);
    await widget.onSubmit(
      KitchenAddItemPayload(
        name: name,
        packCount: _packCount,
        packSize: packSize,
        unit: _unit,
        category: category,
        expiryDate: _expiryDate,
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  List<String> _unitsForCategory(String categoryKey) {
    final normalized = categoryKey.toLowerCase();
    final units = <String>[];
    if (normalized.contains('dairy') || normalized.contains('oil')) {
      units.addAll(['ml', 'litre']);
    } else if (normalized.contains('snack') ||
        normalized.contains('toiletr') ||
        normalized.contains('clean') ||
        normalized.contains('baby') ||
        normalized.contains('kitchen') ||
        normalized.contains('misc')) {
      units.addAll(['pcs']);
    } else {
      units.addAll(['kg', 'g']);
    }
    return units.toSet().toList();
  }

  String _detectCategory(String name) {
    for (final entry in DefaultGroceryCatalog.categories.entries) {
      for (final item in entry.value) {
        if (item.toLowerCase() == name.toLowerCase()) {
          return entry.key;
        }
      }
    }
    return widget.initialCategory?.isNotEmpty == true
        ? widget.initialCategory!
        : 'Miscellaneous';
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodySmall),
        const SizedBox(height: AppTheme.space8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: value > 1 ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Center(
                  child: Text('$value', style: AppTextStyles.bodyLarge),
                ),
              ),
              IconButton(
                onPressed: () => onChanged(value + 1),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
