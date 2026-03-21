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
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR')),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) async {
              if (_handled) return;
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              final raw = barcodes.first.rawValue;
              if (raw == null || raw.isEmpty) return;
              setState(() {
                _handled = true;
                _loading = true;
              });
              await _handleScan(raw);
            },
          ),
          if (_loading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Future<void> _handleScan(String raw) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      if (raw.startsWith('RASOIQ_INVITE:')) {
        final code = raw.replaceFirst('RASOIQ_INVITE:', '').trim();
        if (code.isEmpty) {
          _showError(messenger, 'Invalid QR code.');
          return;
        }
        final shouldJoin = await _confirmJoin(code);
        if (shouldJoin != true) {
          _resetScan();
          return;
        }
        final listId = await _repository.joinListByCode(code);
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Joined shared list')),
        );
        navigator.pop('RASOIQ_INVITE:${listId ?? code}');
        return;
      }

      if (raw.startsWith('RASOIQ_EXPORT:')) {
        final payloadRaw = raw.replaceFirst('RASOIQ_EXPORT:', '').trim();
        if (payloadRaw.isEmpty) {
          _showError(messenger, 'Invalid QR code.');
          return;
        }
        final payload = _repository.decodeQrPayload(payloadRaw);
        if (!mounted) return;
        final shouldImport = await _showImportSheet(context, payload);
        if (shouldImport != true) {
          _resetScan();
          return;
        }
        final listId = await _repository.importListPayload(payload);
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('List imported')),
        );
        navigator.pop('RASOIQ_EXPORT:$listId');
        return;
      }

      _showError(messenger, 'Invalid QR code.');
    } catch (_) {
      _showError(messenger, 'Invalid QR code.');
    }
  }

  Future<bool?> _confirmJoin(String code) {
    return showModalBottomSheet<bool>(
      context: context,
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
              Text('Join shared list?', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppTheme.space8),
              Text('List code: $code', style: AppTextStyles.bodySmall),
              const SizedBox(height: AppTheme.space16),
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
                      child: const Text('Join'),
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

  void _resetScan() {
    if (!mounted) return;
    setState(() {
      _handled = false;
      _loading = false;
    });
  }

  void _showError(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
    _resetScan();
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
