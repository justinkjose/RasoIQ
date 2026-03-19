import 'package:flutter/material.dart';

import '../domain/pantry_item.dart';

class PantryItemCard extends StatelessWidget {
  const PantryItemCard({super.key, required this.item, this.onConsume});

  final PantryItem item;
  final VoidCallback? onConsume;

  @override
  Widget build(BuildContext context) {
    final expiry = item.expiryDate;
    return Card(
      child: ListTile(
        title: Text(item.name),
        subtitle: Text('${item.quantity.toStringAsFixed(1)} ${item.unit}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (expiry != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, size: 18),
                    Text(
                      '${expiry.month}/${expiry.day}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            if (onConsume != null)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: 'Consume stock',
                onPressed: onConsume,
              ),
          ],
        ),
      ),
    );
  }
}
