import 'package:flutter/material.dart';

class QuantityChipSelector extends StatelessWidget {
  const QuantityChipSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <double>[0.5, 1, 2, 3, 4, 5];
    return Wrap(
      spacing: 8,
      children: options.map((option) {
        return ChoiceChip(
          label: Text(option.toString()),
          selected: value == option,
          onSelected: (_) => onChanged(option),
        );
      }).toList(),
    );
  }
}
