import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/grocery_repository.dart';

class QRExportScreen extends StatelessWidget {
  const QRExportScreen({super.key, required this.listId, required this.listName});

  final String listId;
  final String listName;

  @override
  Widget build(BuildContext context) {
    final repository = GroceryRepository();
    return Scaffold(
      appBar: AppBar(title: const Text('Export List QR')),
      body: FutureBuilder<String>(
        future: repository.exportListToQr(listId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data ?? '';
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(listName, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Center(
                child: QrImageView(
                  data: data,
                  version: QrVersions.auto,
                  size: 260,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Scan this QR to import the list on another device.'),
              const SizedBox(height: 8),
              FutureBuilder(
                future: repository.getItemsForList(listId),
                builder: (context, itemsSnapshot) {
                  final count = itemsSnapshot.data?.length ?? 0;
                  return Text('$count items included');
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
