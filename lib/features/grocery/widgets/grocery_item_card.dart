import 'package:flutter/material.dart';

import '../domain/grocery_item.dart';
import '../domain/grocery_unit.dart';

class GroceryItemCard extends StatelessWidget {
  const GroceryItemCard({
    super.key,
    required this.item,
    required this.onToggleDone,
    required this.onToggleImportant,
  });

  final GroceryItem item;
  final VoidCallback onToggleDone;
  final VoidCallback onToggleImportant;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Checkbox(
          value: item.isDone,
          onChanged: (_) => onToggleDone(),
        ),
        title: Text(
          item.name,
          style: TextStyle(
            decoration: item.isDone ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text('${item.quantity} ${item.unit.label}'),
        trailing: IconButton(
          icon: Icon(
            item.isImportant ? Icons.star : Icons.star_border,
            color: item.isImportant ? Colors.amber : null,
          ),
          onPressed: onToggleImportant,
        ),
      ),
    );
  }
}
