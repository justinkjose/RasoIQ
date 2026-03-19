import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_widgets.dart';
import '../domain/pantry_item.dart';

class PantryCategoryPage extends StatelessWidget {
  const PantryCategoryPage({super.key, required this.title, required this.items});

  final String title;
  final List<PantryItem> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.space24),
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.space12),
                child: PantryItemTile(
                  title: item.name,
                  quantityLabel:
                      '${item.quantity.toStringAsFixed(1)} ${item.unit}',
                  expiryLabel: _expiryLabel(item.expiryDate),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  String? _expiryLabel(DateTime? date) {
    if (date == null) return null;
    final daysLeft = date.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return 'Expired';
    if (daysLeft == 0) return 'Expires today';
    return 'Exp in ${daysLeft}d';
  }
}
