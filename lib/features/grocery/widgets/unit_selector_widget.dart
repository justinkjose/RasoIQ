import 'package:flutter/material.dart';

import '../domain/grocery_unit.dart';

class UnitSelectorWidget extends StatelessWidget {
  const UnitSelectorWidget({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final GroceryUnit value;
  final ValueChanged<GroceryUnit> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<GroceryUnit>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Unit'),
      items: GroceryUnit.values
          .map(
            (unit) => DropdownMenuItem(
              value: unit,
              child: Text(unit.label),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}
