import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/grocery_repository.dart';
import '../../../theme/app_theme.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GroceryRepository _repository = GroceryRepository();
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR')),
      body: MobileScanner(
        onDetect: (capture) async {
          if (_handled) return;
          final barcodes = capture.barcodes;
          if (barcodes.isEmpty) return;
          final raw = barcodes.first.rawValue;
          if (raw == null || raw.isEmpty) return;
          final navigator = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);
          setState(() => _handled = true);
          try {
            final payload = _repository.decodeQrPayload(raw);
            if (!mounted) return;
            final shouldImport = await _showImportSheet(context, payload);
            if (shouldImport != true) {
              if (!mounted) return;
              setState(() => _handled = false);
              return;
            }
            await _repository.importListPayload(payload);
            if (!mounted) return;
            navigator.pop(true);
          } catch (_) {
            if (!mounted) return;
            setState(() => _handled = false);
            messenger.showSnackBar(
              const SnackBar(content: Text('Invalid QR code.')),
            );
          }
        },
      ),
    );
  }

  Future<bool?> _showImportSheet(
    BuildContext context,
    QrListPayload payload,
  ) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(AppTheme.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Import Grocery List', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppTheme.space8),
              Text(payload.name, style: AppTextStyles.bodyLarge),
              const SizedBox(height: AppTheme.space12),
              SizedBox(
                height: 220,
                child: ListView.builder(
                  itemCount: payload.items.length,
                  itemBuilder: (context, index) {
                    final item = payload.items[index];
                    return ListTile(
                      dense: true,
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1)} ${item.unit}',
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppTheme.space12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Import'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
