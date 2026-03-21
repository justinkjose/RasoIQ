import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../widgets/offline_banner.dart';
import '../../../services/grocery_share_service.dart';
import '../data/grocery_repository.dart';
import '../domain/grocery_unit.dart';
import '../domain/shopping_list.dart';
import '../services/unit_normalizer.dart';
import 'qr_scanner_screen.dart';
import 'shopping_list_detail_screen.dart';

class GroceryListsScreen extends StatefulWidget {
  const GroceryListsScreen({super.key});

  @override
  State<GroceryListsScreen> createState() => _GroceryListsScreenState();
}

class _GroceryListsScreenState extends State<GroceryListsScreen> {
  final GroceryRepository _repository = GroceryRepository();
  final GroceryShareService _shareService = GroceryShareService();
  List<ShoppingList> _lists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    setState(() => _loading = true);
    final lists = await _repository.getLists();
    if (!mounted) return;
    setState(() {
      _lists = lists;
      _loading = false;
    });
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Grocery List'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter list name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final navigator = Navigator.of(dialogContext);
              await _repository.createList(name: name, icon: 'CART');
              if (!mounted) return;
              navigator.pop();
              await _loadLists();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grocery Lists'),
        actions: [
          IconButton(
            onPressed: () => _showJoinDialog(context),
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'Join list',
          ),
          IconButton(
            onPressed: () => _showImportOptions(context),
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Import',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
      body: Builder(
        builder: (context) {
          final isOffline = context.watch<ConnectivityProvider>().isOffline;
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_lists.isEmpty) {
            return Column(
              children: [
                if (isOffline) const OfflineBanner(),
                const Expanded(child: _EmptyState()),
              ],
            );
          }
          return Column(
            children: [
              if (isOffline) const OfflineBanner(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppTheme.space24),
                  itemCount: _lists.length,
                  itemBuilder: (context, index) {
                    final list = _lists[index];
                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppTheme.space12),
                      child: Card(
                        child: ListTile(
                          title: Text(list.name),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ShoppingListDetailScreen(listId: list.id),
                              ),
                            );
                          },
                          subtitle: FutureBuilder<int>(
                            future: _repository.getItemsForList(list.id).then(
                                  (items) => items.length,
                                ),
                            builder: (context, snapshot) {
                              final count = snapshot.data ?? 0;
                              return Text('$count items');
                            },
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editList(context, list);
                              }
                              if (value == 'delete') {
                                _confirmDelete(context, list);
                              }
                              if (value == 'share') {
                                _showShareRoot(context, list);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                              PopupMenuItem(
                                value: 'share',
                                child: Text('Share'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showShareRoot(
    BuildContext context,
    ShoppingList list,
  ) async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.link_outlined),
                title: const Text('Invite to List (Real-time)'),
                subtitle: const Text('Live sync with members'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showInviteOptions(context, list);
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('Export List'),
                subtitle: const Text('Offline copy'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showShareOptions(context, list);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showInviteOptions(
    BuildContext context,
    ShoppingList list,
  ) async {
    final code = await _repository.getShareCode(list.id);
    if (!context.mounted) return;
    final inviteCode = 'RASOIQ_INVITE:$code';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.text_snippet_outlined),
                title: const Text('Share invite text'),
                onTap: () {
                  Navigator.of(context).pop();
                  Share.share('Join my RasoiQ list: $inviteCode');
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code),
                title: const Text('Show invite QR'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showInviteQr(context, inviteCode);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showInviteQr(BuildContext context, String code) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Invite to List'),
        content: SizedBox(
          width: 240,
          height: 240,
          child: QrImageView(
            data: code,
            version: QrVersions.auto,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _editList(BuildContext context, ShoppingList list) async {
    final controller = TextEditingController(text: list.name);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit List'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final navigator = Navigator.of(dialogContext);
              await _repository.updateListName(list.id, name);
              if (!mounted) return;
              navigator.pop();
              await _loadLists();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ShoppingList list) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete List'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              await _repository.deleteList(list.id);
              if (!mounted) return;
              navigator.pop();
              await _loadLists();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _showShareOptions(
    BuildContext context,
    ShoppingList list,
  ) async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.chat_outlined),
                title: const Text('Share via WhatsApp'),
                onTap: () {
                  Navigator.of(context).pop();
                  _shareToWhatsApp(list);
                },
              ),
              ListTile(
                leading: const Icon(Icons.text_snippet_outlined),
                title: const Text('Share as Text'),
                onTap: () {
                  Navigator.of(context).pop();
                  _shareAsText(list);
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: const Text('Share as JSON File'),
                onTap: () {
                  Navigator.of(context).pop();
                  _shareAsFile(list);
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code),
                title: const Text('Share as QR Code'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showQrDialog(context, list);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareAsText(ShoppingList list) async {
    final items = await _repository.getItemsForList(list.id);
    final lines = items
        .map(
          (item) =>
              '${item.name} - ${UnitNormalizer.format(item.quantity, item.unit)}',
        )
        .join('\n');
    final body = lines.isEmpty ? 'No items yet.' : lines;
    Share.share('Grocery List: ${list.name}\n\n$body');
  }

  Future<void> _shareToWhatsApp(ShoppingList list) async {
    final items = await _repository.getItemsForList(list.id);
    await _shareService.shareToWhatsApp(list: list, items: items);
  }

  Future<void> _shareAsFile(ShoppingList list) async {
    final payload = await _repository.buildSharePayload(list.id);
    final encoded = jsonEncode(payload);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${list.name}.json');
    await file.writeAsString(encoded);
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> _showQrDialog(BuildContext context, ShoppingList list) async {
    final items = await _repository.getItemsForList(list.id);
    final encoded = _repository.encodeExportQr(list, items);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Share ${list.name}'),
        content: SizedBox(
          width: 240,
          height: 240,
          child: QrImageView(
            data: encoded,
            version: QrVersions.auto,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showImportOptions(BuildContext context) async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.text_snippet_outlined),
                title: const Text('Import from Text'),
                onTap: () {
                  Navigator.of(context).pop();
                  _importFromText(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: const Text('Import from JSON File'),
                onTap: () {
                  Navigator.of(context).pop();
                  _importFromFile(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: const Text('Scan QR Code'),
                onTap: () {
                  Navigator.of(context).pop();
                  _scanQrCode(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Import QR from Image'),
                onTap: () {
                  Navigator.of(context).pop();
                  _importQrFromImage(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showJoinDialog(BuildContext context) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Join List'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter list code',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
      final code = controller.text.trim();
      if (code.isEmpty) return;
      try {
        final listId = await _repository.joinListByCode(code);
        if (!context.mounted) return;
        await _loadLists();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined shared list')),
        );
        if (listId != null && listId.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ShoppingListDetailScreen(listId: listId),
            ),
          );
        }
      } catch (_) {
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Invalid or unavailable list code.')),
      );
    }
  }

  Future<void> _importFromText(BuildContext context) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import Grocery List'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Paste shared list JSON here',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final raw = controller.text.trim();
    if (raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      await _importPayload(data);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid list data.')),
      );
    }
  }

  Future<void> _importFromFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'txt'],
    );
    if (result == null) return;
    final path = result.files.single.path;
    if (path == null) return;
    final contents = await File(path).readAsString();
    try {
      final data = jsonDecode(contents) as Map<String, dynamic>;
      await _importPayload(data);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid list data.')),
      );
    }
  }

  Future<void> _scanQrCode(BuildContext context) async {
    final imported = await Navigator.of(context).push<String?>(
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );
    if (imported == null) return;
    if (imported.startsWith('RASOIQ_INVITE:')) {
      final listId = imported.replaceFirst('RASOIQ_INVITE:', '').trim();
      await _loadLists();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joined shared list')),
      );
      if (listId.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ShoppingListDetailScreen(listId: listId),
          ),
        );
      }
      return;
    }
    if (imported.startsWith('RASOIQ_EXPORT:')) {
      await _loadLists();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('List imported')),
      );
      return;
    }
    try {
      final data = jsonDecode(imported) as Map<String, dynamic>;
      await _importPayload(data);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid list data.')),
      );
    }
  }

  Future<void> _importQrFromImage(BuildContext context) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final inputImage = InputImage.fromFilePath(file.path);
    final scanner = BarcodeScanner();
    try {
      final barcodes = await scanner.processImage(inputImage);
      if (barcodes.isEmpty) return;
      final raw = barcodes.first.rawValue;
      if (raw == null || raw.isEmpty) return;
      if (raw.startsWith('RASOIQ_INVITE:')) {
        final code = raw.replaceFirst('RASOIQ_INVITE:', '').trim();
        if (code.isEmpty) return;
        await _repository.joinListByCode(code);
        await _loadLists();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined shared list')),
        );
        return;
      }
      if (raw.startsWith('RASOIQ_EXPORT:')) {
        final payloadRaw = raw.replaceFirst('RASOIQ_EXPORT:', '').trim();
        if (payloadRaw.isEmpty) return;
        final payload = _repository.decodeQrPayload(payloadRaw);
        await _repository.importListPayload(payload);
        await _loadLists();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('List imported')),
        );
        return;
      }
      final data = jsonDecode(raw) as Map<String, dynamic>;
      await _importPayload(data);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid list data.')),
      );
    } finally {
      await scanner.close();
    }
  }

  Future<void> _importPayload(Map<String, dynamic> data) async {
    final name = data['name']?.toString().trim();
    if (name == null || name.isEmpty) {
      throw const FormatException('Missing name');
    }
    final created = await _repository.createList(name: name, icon: 'CART');
    final items = (data['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    for (final item in items) {
      final qty = (item['qty'] as num?)?.toDouble() ?? 1;
      final unitLabel = item['unit']?.toString() ?? 'item';
      await _repository.addItem(
        listId: created.id,
        name: item['name']?.toString() ?? 'Item',
        quantity: qty,
        unit: _unitFromLabel(unitLabel),
        categoryId: item['category']?.toString() ?? 'uncategorized',
      );
    }
    await _loadLists();
  }

  GroceryUnit _unitFromLabel(String label) {
    switch (label.toLowerCase()) {
      case 'pcs':
        return GroceryUnit.pcs;
      case 'packet':
        return GroceryUnit.packet;
      case 'kg':
        return GroceryUnit.kg;
      case 'g':
        return GroceryUnit.g;
      case 'litre':
      case 'l':
        return GroceryUnit.litre;
      case 'ml':
        return GroceryUnit.ml;
      case 'item':
      default:
        return GroceryUnit.item;
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No lists yet. Tap + to create one.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
