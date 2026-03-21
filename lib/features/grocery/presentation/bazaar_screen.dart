
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:io';

import '../../../data/default_grocery_catalog.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_widgets.dart';
import '../../../services/ads_service.dart';
import '../../../data/models/ad_item.dart';
import '../domain/grocery_item.dart';
import '../domain/grocery_unit.dart';
import '../domain/user_item.dart';
import '../providers/grocery_provider.dart';
import '../widgets/grocery_add_item_sheet.dart';
import '../services/whisper_transcription_service.dart';
import '../../pantry/presentation/kitchen_stock_screen.dart';
import '../../pantry/domain/kitchen_item.dart';
import '../../pantry/providers/kitchen_stock_provider.dart';
import 'qr_export_screen.dart';
import 'qr_scanner_screen.dart';
import 'receipt_scanner_screen.dart';

class BazaarScreen extends StatefulWidget {
  const BazaarScreen({super.key});

  @override
  State<BazaarScreen> createState() => _BazaarScreenState();
}

class _BazaarScreenState extends State<BazaarScreen> {
  final _searchController = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  final WhisperTranscriptionService _whisperService =
      WhisperTranscriptionService();
  final AdsService _adsService = AdsService();
  bool _isListening = false;
  String _lastWords = '';
  late final Future<List<AdItem>> _bannerAdsFuture;
  late final Future<List<AdItem>> _productAdsFuture;

  @override
  void initState() {
    super.initState();
    _bannerAdsFuture =
        _adsService.getAdsForScreen('grocery', type: 'banner');
    _productAdsFuture =
        _adsService.getAdsForScreen('grocery', type: 'product');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroceryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(provider.activeListName, style: AppTextStyles.headingMedium),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const KitchenStockScreen(),
                ),
              );
            },
            icon: const Icon(Icons.kitchen_outlined),
            tooltip: 'Kitchen Stock',
          ),
          IconButton(
            onPressed: () => _openShareSheet(context, provider),
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppTheme.space24),
              children: [
                _ShoppingModeToggle(
                  value: provider.shoppingMode,
                  onChanged: provider.setShoppingMode,
                ),
                const SizedBox(height: AppTheme.space12),
                _AdsSection(
                  bannerFuture: _bannerAdsFuture,
                  productFuture: _productAdsFuture,
                ),
                if (!provider.shoppingMode) ...[
                  const SizedBox(height: AppTheme.space16),
                  _SearchBar(
                    controller: _searchController,
                    isListening: _isListening,
                    onTap: () => _openSearchPanel(context, provider.userItems),
                    onVoiceTap: () => _toggleListening(context),
                    onCameraTap: () => _openReceiptScanner(context),
                  ),
                  if (_isListening) ...[
                    const SizedBox(height: AppTheme.space12),
                    _ListeningPill(
                      text: _lastWords.isEmpty ? 'Listening...' : _lastWords,
                    ),
                  ],
                ],
                const SizedBox(height: AppTheme.space16),
                const SectionHeader(title: 'Active Items'),
                const SizedBox(height: AppTheme.space12),
                _GroceryItemList(
                  items: _filterItems(
                    provider.items.where((item) => !item.isDone).toList(),
                  ),
                  emptyMessage: 'No active items yet',
                  onEdit: (item) => _openEditItemDialog(context, item),
                  onComplete: (item) => provider.toggleDone(item),
                  onRemove: (item) => provider.deleteItem(item),
                  onMarkUnavailable: (item) => provider.toggleUnavailable(item),
                  onMoveToKitchen: (item) =>
                      _openMoveToKitchenSheet(context, item),
                ),
                const SizedBox(height: AppTheme.space16),
                const SectionHeader(title: 'Next Grocery Run'),
                const SizedBox(height: AppTheme.space12),
                _GroceryItemList(
                  items: _filterItems(
                    provider.items.where((item) => item.isUnavailable).toList(),
                  ),
                  emptyMessage: 'No unavailable items',
                  onEdit: (item) => _openEditItemDialog(context, item),
                  onComplete: (item) => provider.toggleUnavailable(item),
                  onRemove: (item) => provider.deleteItem(item),
                  onMarkUnavailable: null,
                  onMoveToKitchen: (item) =>
                      _openMoveToKitchenSheet(context, item),
                ),
                const SizedBox(height: AppTheme.space16),
                const SectionHeader(title: 'Completed Items'),
                const SizedBox(height: AppTheme.space12),
                _GroceryItemList(
                  items: _filterItems(
                    provider.items.where((item) => item.isDone).toList(),
                  ),
                  emptyMessage: 'No completed items',
                  onEdit: (item) => _openEditItemDialog(context, item),
                  onComplete: (item) => provider.toggleDone(item),
                  onRemove: (item) => provider.deleteItem(item),
                  onMarkUnavailable: null,
                  completedMode: true,
                  onMoveToKitchen: (item) =>
                      _openMoveToKitchenSheet(context, item),
                ),
                const SizedBox(height: AppTheme.space32),
              ],
            ),
    );
  }

  List<GroceryItem> _filterItems(List<GroceryItem> items) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items
        .where((item) => item.name.toLowerCase().contains(query))
        .toList();
  }

  void _openAddItemSheet(
    BuildContext context, {
    required String name,
    double? quantity,
    GroceryUnit? unit,
    String? category,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => GroceryAddItemSheet(
        initialName: name,
        initialQuantity: quantity,
        initialUnit: unit,
        initialCategory: category,
        onSubmit: (payload) async {
          final provider = context.read<GroceryProvider>();
          await provider.addItem(
            name: payload.name,
            quantity: payload.quantity,
            unit: payload.unit,
            categoryId: payload.categoryId,
            isImportant: payload.isImportant,
            packCount: payload.packCount,
            packSize: payload.packSize,
          );
        },
      ),
    );
  }

  void _openMoveToKitchenSheet(BuildContext context, GroceryItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MoveToKitchenSheet(item: item),
    );
  }
  Future<void> _openEditItemDialog(BuildContext context, GroceryItem item) async {
    final qtyController = TextEditingController(text: item.quantity.toString());
    final packSizeController =
        TextEditingController(text: item.packSize.toString());
    GroceryUnit selectedUnit = item.unit;
    String selectedCategory = item.categoryId;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            const SizedBox(height: AppTheme.space12),
            TextField(
              controller: packSizeController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Pack size'),
            ),
            const SizedBox(height: AppTheme.space12),
            DropdownButtonFormField<GroceryUnit>(
              initialValue: selectedUnit,
              items: const [
                DropdownMenuItem(value: GroceryUnit.ml, child: Text('ml')),
                DropdownMenuItem(value: GroceryUnit.litre, child: Text('litre')),
                DropdownMenuItem(value: GroceryUnit.g, child: Text('g')),
                DropdownMenuItem(value: GroceryUnit.kg, child: Text('kg')),
                DropdownMenuItem(value: GroceryUnit.pcs, child: Text('pcs')),
              ],
              onChanged: (value) => selectedUnit = value ?? selectedUnit,
              decoration: const InputDecoration(labelText: 'Unit'),
            ),
            const SizedBox(height: AppTheme.space12),
            DropdownButtonFormField<String>(
              initialValue: selectedCategory.isEmpty ? null : selectedCategory,
              items: DefaultGroceryCatalog.categories.keys
                  .map(
                    (category) => DropdownMenuItem(
                      value: category.toLowerCase(),
                      child: Text(_categoryLabel(category)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => selectedCategory = value ?? selectedCategory,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;
    if (result != true) return;
    final quantity = double.tryParse(qtyController.text.trim()) ?? item.quantity;
    final packSize =
        double.tryParse(packSizeController.text.trim()) ?? item.packSize;
    final provider = context.read<GroceryProvider>();
    await provider.updateQuantity(item, quantity);
    await provider.updateUnit(item, selectedUnit);
    await provider.updateCategory(item, selectedCategory);
    await provider.updatePackSize(item, packSize);
  }

  Future<void> _toggleListening(BuildContext context) async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
          _handleVoiceResult(context, _lastWords);
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _isListening = false);
        _showMicPermissionDialog(context);
      },
    );

    final hasPermission = await _speech.hasPermission;
    if (!context.mounted) return;
    if (!available || hasPermission == false) {
      _showMicPermissionDialog(context);
      return;
    }

    setState(() {
      _isListening = true;
      _lastWords = '';
    });

    await _speech.listen(
      localeId: 'en_IN',
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 10),
      onResult: (result) {
        if (!mounted) return;
        setState(() => _lastWords = result.recognizedWords);
        if (result.finalResult) {
          _speech.stop();
          setState(() => _isListening = false);
          _handleVoiceResult(context, _lastWords);
        }
      },
    );
  }

  void _handleVoiceResult(BuildContext context, String command) {
    final cleaned = command.trim();
    if (cleaned.isEmpty) return;
    final items = _parseVoiceItems(cleaned);
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not parse voice items.')),
      );
      return;
    }
    final provider = context.read<GroceryProvider>();
    for (final item in items) {
      provider.addItem(
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        categoryId: item.category,
        packCount: item.packCount,
        packSize: item.packSize,
      );
    }
  }

  void _openReceiptScanner(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReceiptScannerScreen()),
    );
  }

  void _openShareSheet(BuildContext context, GroceryProvider provider) {
    final activeItems = provider.items.where((item) => !item.isDone).toList();
    final completedCount = provider.items.where((item) => item.isDone).length;
    final unavailableCount =
        provider.items.where((item) => item.isUnavailable).length;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppTheme.space12),
              Text('Share List', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppTheme.space4),
              Text(
                '${activeItems.length} active • $unavailableCount unavailable • $completedCount completed',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppTheme.space12),
              ListTile(
                leading: const Icon(Icons.text_snippet_outlined),
                title: const Text('Share as Text'),
                onTap: () {
                  Navigator.of(context).pop();
                  final text = _buildShareText(activeItems);
                  Share.share(text);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy Text'),
                onTap: () async {
                  final text = _buildShareText(activeItems);
                  await Clipboard.setData(ClipboardData(text: text));
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('List copied to clipboard')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_2_outlined),
                title: const Text('Share via QR Code'),
                onTap: () {
                  Navigator.of(context).pop();
                  final listId = provider.activeListId;
                  if (listId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No active list to share.')),
                    );
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QRExportScreen(
                        listId: listId,
                        listName: provider.activeListName,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: const Text('Scan QR to Import'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final imported = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const QRScannerScreen()),
                  );
                  if (imported == true) {
                    await provider.load();
                  }
                },
              ),
              const SizedBox(height: AppTheme.space12),
            ],
          ),
        );
      },
    );
  }

  String _buildShareText(List<GroceryItem> items) {
    if (items.isEmpty) return 'Grocery List\\n\\n(No items yet)';
    final map = <String, List<GroceryItem>>{};
    for (final item in items) {
      final key = item.categoryId.isEmpty ? 'Other' : item.categoryId;
      map.putIfAbsent(key, () => []).add(item);
    }
    final sortedEntries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final buffer = StringBuffer('Grocery List\\n');
    for (final entry in sortedEntries) {
      final category = _categoryLabel(entry.key);
      buffer.writeln('\\n$category');
      final sortedItems = [...entry.value]..sort((a, b) => a.name.compareTo(b.name));
      for (final item in sortedItems) {
        buffer.writeln('- ${item.name} ${_formatQty(item)}');
      }
    }
    return buffer.toString();
  }

  String _formatQty(GroceryItem item) {
    final quantity = item.quantity % 1 == 0
        ? item.quantity.toStringAsFixed(0)
        : item.quantity.toStringAsFixed(1);
    final unit = _unitLabel(item.unit);
    return '$quantity $unit';
  }

  String _unitLabel(GroceryUnit unit) {
    switch (unit) {
      case GroceryUnit.ml:
        return 'ml';
      case GroceryUnit.litre:
        return 'L';
      case GroceryUnit.g:
        return 'g';
      case GroceryUnit.kg:
        return 'kg';
      case GroceryUnit.pcs:
        return 'pcs';
      case GroceryUnit.item:
      case GroceryUnit.packet:
        return 'pcs';
    }
  }

  void _openSearchPanel(BuildContext context, List<UserItem> userItems) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SearchPanel(
        userItems: userItems,
        onImportAudio: () => _importAudioTranscript(context),
        onAdd: (name, category) {
          _openAddItemSheet(
            context,
            name: name,
            category: category,
          );
        },
      ),
    );
  }

  Future<void> _importAudioTranscript(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'wav', 'aac', 'ogg'],
    );
    if (result == null) return;
    if (!context.mounted) return;

    final filePath = result.files.single.path;
    if (filePath != null && (Platform.isIOS || Platform.isMacOS)) {
      try {
        final transcript = await _whisperService.transcribeFile(filePath);
        if (!context.mounted) return;
        if (transcript != null && transcript.trim().isNotEmpty) {
          _handleVoiceResult(context, transcript);
          return;
        }
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transcription failed. Paste a transcript instead.'),
          ),
        );
      }
    }

    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import Audio Transcript'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Paste the transcript from your audio',
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
    if (!context.mounted) return;
    final text = controller.text.trim();
    if (text.isEmpty) return;
    _handleVoiceResult(context, text);
  }

  Future<void> _showMicPermissionDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Microphone'),
        content: const Text(
          'RasoIQ needs microphone access for voice input. '
          'Enable the Microphone permission in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(String key) {
    return key.replaceAll('_', ' ');
  }
}

class _ShoppingModeToggle extends StatelessWidget {
  const _ShoppingModeToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Text('Shopping Mode', style: AppTextStyles.bodyLarge),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.isListening,
    required this.onTap,
    required this.onVoiceTap,
    required this.onCameraTap,
  });

  final TextEditingController controller;
  final bool isListening;
  final VoidCallback onTap;
  final VoidCallback onVoiceTap;
  final VoidCallback onCameraTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Add item or search groceries',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onVoiceTap,
                icon: Icon(isListening ? Icons.stop_circle : Icons.mic),
              ),
              IconButton(
                onPressed: onCameraTap,
                icon: const Icon(Icons.camera_alt),
              ),
            ],
          ),
        ),
        style: AppTextStyles.bodyLarge,
      ),
    );
  }
}



class _ListeningPill extends StatelessWidget {
  const _ListeningPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.graphic_eq, color: color, size: 18),
          const SizedBox(width: AppTheme.space8),
          Text(text, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _GroceryItemList extends StatelessWidget {
  const _GroceryItemList({
    required this.items,
    required this.emptyMessage,
    this.onEdit,
    this.onComplete,
    this.onRemove,
    this.onMarkUnavailable,
    this.onMoveToKitchen,
    this.completedMode = false,
  });

  final List<GroceryItem> items;
  final String emptyMessage;
  final ValueChanged<GroceryItem>? onEdit;
  final ValueChanged<GroceryItem>? onComplete;
  final ValueChanged<GroceryItem>? onRemove;
  final ValueChanged<GroceryItem>? onMarkUnavailable;
  final ValueChanged<GroceryItem>? onMoveToKitchen;
  final bool completedMode;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space16),
          child: Text(emptyMessage, style: AppTextStyles.bodySmall),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.space12),
          child: _GroceryItemTile(
            item: item,
            completedMode: completedMode,
            onEdit: onEdit,
            onComplete: onComplete,
            onRemove: onRemove,
            onMarkUnavailable: onMarkUnavailable,
            onMoveToKitchen: onMoveToKitchen,
          ),
        );
      },
    );
  }
}

class _GroceryItemTile extends StatelessWidget {
  const _GroceryItemTile({
    required this.item,
    required this.completedMode,
    this.onEdit,
    this.onComplete,
    this.onRemove,
    this.onMarkUnavailable,
    this.onMoveToKitchen,
  });

  final GroceryItem item;
  final bool completedMode;
  final ValueChanged<GroceryItem>? onEdit;
  final ValueChanged<GroceryItem>? onComplete;
  final ValueChanged<GroceryItem>? onRemove;
  final ValueChanged<GroceryItem>? onMarkUnavailable;
  final ValueChanged<GroceryItem>? onMoveToKitchen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: ListTile(
        leading: Checkbox(
          value: item.isDone,
          onChanged: onComplete == null ? null : (_) => onComplete!(item),
        ),
        title: Text(item.name),
        subtitle: Text(_quantityLine(item)),
        onTap: onEdit == null ? null : () => onEdit!(item),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'edit':
                if (onEdit != null) onEdit!(item);
                break;
              case 'unavailable':
                if (onMarkUnavailable != null) onMarkUnavailable!(item);
                break;
              case 'delete':
                if (onRemove != null) onRemove!(item);
                break;
              case 'undo':
                if (onComplete != null) onComplete!(item);
                break;
              case 'move':
                if (onMoveToKitchen != null) onMoveToKitchen!(item);
                break;
            }
          },
          itemBuilder: (context) {
            final items = <PopupMenuEntry<String>>[];
            if (onEdit != null) {
              items.add(const PopupMenuItem(value: 'edit', child: Text('Edit')));
            }
            if (onMoveToKitchen != null) {
              items.add(
                const PopupMenuItem(
                  value: 'move',
                  child: Text('Move to Kitchen'),
                ),
              );
            }
            if (completedMode) {
              items.add(const PopupMenuItem(
                value: 'undo',
                child: Text('Undo completion'),
              ));
            } else if (onMarkUnavailable != null) {
              items.add(const PopupMenuItem(
                value: 'unavailable',
                child: Text('Mark unavailable'),
              ));
            }
            if (onRemove != null) {
              items.add(const PopupMenuItem(
                value: 'delete',
                child: Text('Delete item'),
              ));
            }
            return items;
          },
        ),
      ),
    );
  }

  String _quantityLine(GroceryItem item) {
    final quantity = item.quantity % 1 == 0
        ? item.quantity.toStringAsFixed(0)
        : item.quantity.toStringAsFixed(1);
    final category = item.categoryId.isEmpty
        ? 'Uncategorized'
        : item.categoryId.replaceAll('_', ' ');
    final packSize = item.packSize > 0
        ? ' • Pack ${item.packSize % 1 == 0 ? item.packSize.toStringAsFixed(0) : item.packSize.toStringAsFixed(1)}'
        : '';
    return '$quantity ${item.unit.label} • $category$packSize';
  }
}




class _MoveToKitchenSheet extends StatefulWidget {
  const _MoveToKitchenSheet({required this.item});

  final GroceryItem item;

  @override
  State<_MoveToKitchenSheet> createState() => _MoveToKitchenSheetState();
}

class _MoveToKitchenSheetState extends State<_MoveToKitchenSheet> {
  late final TextEditingController _quantityController;
  late final TextEditingController _packSizeController;
  DateTime? _expiryDate;
  late String _unit;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.item.quantity % 1 == 0
          ? widget.item.quantity.toStringAsFixed(0)
          : widget.item.quantity.toStringAsFixed(1),
    );
    _packSizeController = TextEditingController(
      text: widget.item.packSize % 1 == 0
          ? widget.item.packSize.toStringAsFixed(0)
          : widget.item.packSize.toStringAsFixed(1),
    );
    _unit = _unitLabel(widget.item.unit);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _packSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          Text('Move to Kitchen', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppTheme.space12),
          TextField(
            controller: _quantityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Quantity'),
          ),
          const SizedBox(height: AppTheme.space12),
          TextField(
            controller: _packSizeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Pack size'),
          ),
          const SizedBox(height: AppTheme.space12),
          DropdownButtonFormField<String>(
            initialValue: _unit,
            decoration: const InputDecoration(labelText: 'Unit'),
            items: const [
              DropdownMenuItem(value: 'kg', child: Text('kg')),
              DropdownMenuItem(value: 'g', child: Text('g')),
              DropdownMenuItem(value: 'litre', child: Text('litre')),
              DropdownMenuItem(value: 'ml', child: Text('ml')),
              DropdownMenuItem(value: 'pcs', child: Text('pcs')),
            ],
            onChanged: (value) => setState(() => _unit = value ?? _unit),
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
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: FilledButton(
                  onPressed: () => _submit(context),
                  child: const Text('Add to Kitchen'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final quantity = double.tryParse(_quantityController.text.trim()) ?? 0;
    if (quantity <= 0) return;
    final packSize =
        double.tryParse(_packSizeController.text.trim()) ?? widget.item.packSize;

    final category = _detectCategory(widget.item.name);
    final baseUnit = _baseUnitFromUnit(_unit);
    final baseQuantity = _toBaseQuantity(quantity, _unit);

    final batch = KitchenBatch(
      quantity: baseQuantity,
      unit: baseUnit,
      addedDate: DateTime.now(),
      expiryDate: _expiryDate,
    );

    final kitchenItem = KitchenItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: widget.item.name,
      category: category,
      batches: [batch],
    );

    final kitchenProvider = context.read<KitchenStockProvider>();
    final groceryProvider = context.read<GroceryProvider>();
    await kitchenProvider.addItem(kitchenItem);
    await groceryProvider.updatePackSize(widget.item, packSize);

    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  String _detectCategory(String name) {
    for (final entry in DefaultGroceryCatalog.categories.entries) {
      for (final item in entry.value) {
        if (item.toLowerCase() == name.toLowerCase()) {
          return entry.key;
        }
      }
    }
    return 'Miscellaneous';
  }

  String _unitLabel(GroceryUnit unit) {
    switch (unit) {
      case GroceryUnit.kg:
        return 'kg';
      case GroceryUnit.g:
        return 'g';
      case GroceryUnit.litre:
        return 'litre';
      case GroceryUnit.ml:
        return 'ml';
      case GroceryUnit.pcs:
      case GroceryUnit.item:
      case GroceryUnit.packet:
        return 'pcs';
    }
  }

  String _baseUnitFromUnit(String unit) {
    switch (unit) {
      case 'kg':
      case 'g':
        return 'g';
      case 'litre':
      case 'ml':
        return 'ml';
      default:
        return 'pcs';
    }
  }

  int _toBaseQuantity(double quantity, String unit) {
    if (unit == 'kg' || unit == 'litre') {
      return (quantity * 1000).round();
    }
    return quantity.round();
  }
}
class _SearchPanel extends StatefulWidget {
  const _SearchPanel({
    required this.onAdd,
    required this.userItems,
    required this.onImportAudio,
  });

  final void Function(String name, String categoryKey) onAdd;
  final List<UserItem> userItems;
  final VoidCallback onImportAudio;

  @override
  State<_SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<_SearchPanel> {
  final TextEditingController _controller = TextEditingController();
  static const String _allCategories = 'All Categories';
  final List<String> _categories = [
    _allCategories,
    ...DefaultGroceryCatalog.categories.keys,
  ];
  String _selectedCategory = _allCategories;
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(AppTheme.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Smart Search', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppTheme.space16),
              TextField(
                controller: _controller,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: 'Search items',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
              const SizedBox(height: AppTheme.space12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                items: _categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category.replaceAll('_', ' ')),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _selectedCategory = value ?? _allCategories;
                }),
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: AppTheme.space8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: widget.onImportAudio,
                  icon: const Icon(Icons.audio_file_outlined),
                  label: const Text('Import Audio'),
                ),
              ),
              const SizedBox(height: AppTheme.space8),
              Text('${items.length} items', style: AppTextStyles.bodySmall),
              const SizedBox(height: AppTheme.space16),
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppTheme.space12,
                    crossAxisSpacing: AppTheme.space12,
                    childAspectRatio: 1,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              item.name.isNotEmpty
                                  ? item.name[0].toUpperCase()
                                  : '?',
                              style: AppTextStyles.bodyLarge,
                            ),
                          ),
                          const SizedBox(height: AppTheme.space12),
                          Expanded(
                            child: Text(
                              item.name,
                              style: AppTextStyles.bodyLarge,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () {
                                final category =
                                    _selectedCategory == _allCategories
                                        ? item.categoryKey
                                        : _selectedCategory;
                                widget.onAdd(item.name, category);
                              },
                              child: const Text('+ Add'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _query = value.trim().toLowerCase());
    });
  }

  List<_SearchItem> _filteredItems() {
    final items = _selectedCategory == _allCategories
        ? _allItems()
        : _itemsForCategory(_selectedCategory);
    if (_query.isEmpty) return items;
    return items
        .where((item) => item.name.toLowerCase().contains(_query))
        .toList();
  }

  List<_SearchItem> _allItems() {
    final items = <_SearchItem>[];
    final added = <String>{};
    for (final entry in DefaultGroceryCatalog.categories.entries) {
      for (final item in entry.value) {
        final key = item.toLowerCase();
        if (added.add(key)) {
          items.add(_SearchItem(name: item, categoryKey: entry.key));
        }
      }
    }
    for (final item in widget.userItems) {
      final key = item.name.toLowerCase();
      if (added.add(key)) {
        items.add(_SearchItem(name: item.name, categoryKey: item.category));
      }
    }
    return items;
  }

  List<_SearchItem> _itemsForCategory(String category) {
    final items = <_SearchItem>[];
    final added = <String>{};
    for (final item in DefaultGroceryCatalog.categories[category] ?? []) {
      final key = item.toLowerCase();
      if (added.add(key)) {
        items.add(_SearchItem(name: item, categoryKey: category));
      }
    }
    for (final item in widget.userItems) {
      if (item.category.toLowerCase() != category.toLowerCase()) continue;
      final key = item.name.toLowerCase();
      if (added.add(key)) {
        items.add(_SearchItem(name: item.name, categoryKey: item.category));
      }
    }
    return items;
  }
}

class _SearchItem {
  const _SearchItem({required this.name, required this.categoryKey});

  final String name;
  final String categoryKey;
}

class _AdsSection extends StatelessWidget {
  const _AdsSection({
    required this.bannerFuture,
    required this.productFuture,
  });

  final Future<List<AdItem>> bannerFuture;
  final Future<List<AdItem>> productFuture;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FutureBuilder<List<AdItem>>(
          future: bannerFuture,
          builder: (context, snapshot) {
            final ads = snapshot.data ?? const <AdItem>[];
            if (ads.isEmpty) return const SizedBox.shrink();
            return _AdCard(ad: ads.first, variant: _AdVariant.banner);
          },
        ),
        FutureBuilder<List<AdItem>>(
          future: productFuture,
          builder: (context, snapshot) {
            final ads = snapshot.data ?? const <AdItem>[];
            if (ads.isEmpty) return const SizedBox.shrink();
            return _AdCard(ad: ads.first, variant: _AdVariant.product);
          },
        ),
      ],
    );
  }
}

enum _AdVariant { banner, product }

class _AdCard extends StatelessWidget {
  const _AdCard({required this.ad, required this.variant});

  final AdItem ad;
  final _AdVariant variant;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    final titleStyle = Theme.of(context).textTheme.titleSmall;
    final bodyStyle = Theme.of(context).textTheme.bodySmall;
    final image = ad.imageUrl.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: Image.network(
              ad.imageUrl,
              height: variant == _AdVariant.banner ? 120 : 72,
              width: variant == _AdVariant.banner ? double.infinity : 72,
              fit: BoxFit.cover,
            ),
          )
        : Container(
            height: variant == _AdVariant.banner ? 120 : 72,
            width: variant == _AdVariant.banner ? double.infinity : 72,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.local_offer_outlined),
          );

    final content = variant == _AdVariant.banner
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              image,
              const SizedBox(height: AppTheme.space8),
              Text(ad.title, style: titleStyle),
              if (ad.clickUrl.isNotEmpty) ...[
                const SizedBox(height: AppTheme.space4),
                Text('Sponsored', style: bodyStyle),
              ],
            ],
          )
        : Row(
            children: [
              image,
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ad.title, style: titleStyle),
                    if (ad.clickUrl.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.space4),
                      Text('Sponsored', style: bodyStyle),
                    ],
                  ],
                ),
              ),
            ],
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space12),
      child: AppCard(child: content),
    );
  }
}

List<_ParsedVoiceItem> _parseVoiceItems(String input) {
  final lower = input.toLowerCase().replaceFirst(RegExp(r'^add\s+'), '');
  final normalized = lower.replaceAll(' and ', ',');
  final chunks = normalized
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  final items = <_ParsedVoiceItem>[];
  for (final chunk in chunks) {
    final parsed = _parseVoiceItem(chunk);
    if (parsed != null) {
      items.add(parsed);
    }
  }
  return items;
}

_ParsedVoiceItem? _parseVoiceItem(String input) {
  final packCountMatch =
      RegExp(r'(\\d+)\\s*(packets|packet|packs|pack|pcs|pieces)\\b')
          .firstMatch(input);
  var packCount = 1;
  var working = input;
  if (packCountMatch != null) {
    packCount = int.tryParse(packCountMatch.group(1) ?? '1') ?? 1;
    working = working.replaceRange(
      packCountMatch.start,
      packCountMatch.end,
      ' ',
    );
  }

  final qtyMatch =
      RegExp(r'(\\d+(?:\\.\\d+)?)\\s*(kg|g|litre|l|ml)\\b')
          .firstMatch(working);
  double packSize = 0;
  GroceryUnit unit = GroceryUnit.pcs;
  if (qtyMatch != null) {
    packSize = double.tryParse(qtyMatch.group(1) ?? '0') ?? 0;
    unit = _unitFromString(qtyMatch.group(2));
    working = working.replaceRange(qtyMatch.start, qtyMatch.end, ' ');
  } else {
    final countMatch = RegExp(r'\\b(\\d+)\\b').firstMatch(working);
    if (countMatch != null) {
      packCount = int.tryParse(countMatch.group(1) ?? '1') ?? packCount;
      working = working.replaceRange(countMatch.start, countMatch.end, ' ');
    }
  }

  final name = working.replaceAll(RegExp(r'\\s+'), ' ').trim();
  if (name.isEmpty) return null;
  final totalQuantity = packSize > 0 ? packSize * packCount : packCount.toDouble();
  final titled = _titleCase(name);
  return _ParsedVoiceItem(
    name: titled,
    quantity: totalQuantity,
    unit: unit,
    packCount: packCount,
    packSize: packSize,
    category: _catalogCategoryForItem(titled),
  );
}

String _titleCase(String value) {
  return value
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
      .join(' ');
}

GroceryUnit _unitFromString(String? value) {
  switch (value) {
    case 'kg':
      return GroceryUnit.kg;
    case 'g':
      return GroceryUnit.g;
    case 'ml':
      return GroceryUnit.ml;
    case 'litre':
    case 'l':
      return GroceryUnit.litre;
    case 'pcs':
      return GroceryUnit.pcs;
    default:
      return GroceryUnit.pcs;
  }
}

class _ParsedVoiceItem {
  const _ParsedVoiceItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.packCount,
    required this.packSize,
    required this.category,
  });

  final String name;
  final double quantity;
  final GroceryUnit unit;
  final int packCount;
  final double packSize;
  final String category;
}

String _catalogCategoryForItem(String name) {
  for (final entry in DefaultGroceryCatalog.categories.entries) {
    for (final item in entry.value) {
      if (item.toLowerCase() == name.toLowerCase()) {
        return entry.key;
      }
    }
  }
  return 'Miscellaneous';
}




