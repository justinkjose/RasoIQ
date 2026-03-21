import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/grocery_repository.dart';
import '../domain/grocery_item.dart';
import '../domain/grocery_unit.dart';
import '../domain/shopping_list.dart';
import '../presentation/grocery_search_modal.dart';
import '../services/camera_text_scan_service.dart';
import '../services/grocery_input_handler.dart';
import '../services/grocery_item_parser.dart';
import '../services/voice_input_service.dart';
import '../services/unit_config.dart';
import '../services/unit_normalizer.dart';
import '../widgets/detected_items_dialog.dart';
import 'add_grocery_item_screen.dart';
import 'qr_export_screen.dart';
import 'qr_scanner_screen.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../widgets/offline_banner.dart';
import '../widgets/grocery_add_item_sheet.dart';
import '../../pantry/providers/kitchen_stock_provider.dart';
import '../../pantry/domain/kitchen_item.dart';
import '../../../data/default_grocery_catalog.dart';

class ShoppingListDetailScreen extends StatefulWidget {
  const ShoppingListDetailScreen({super.key, required this.listId});

  final String listId;

  @override
  State<ShoppingListDetailScreen> createState() => _ShoppingListDetailScreenState();
}

class _ShoppingListDetailScreenState extends State<ShoppingListDetailScreen> {
  final GroceryRepository _repository = GroceryRepository();
  late final GroceryInputHandler _inputHandler =
      GroceryInputHandler(repository: _repository);
  final VoiceInputService _voiceInputService = VoiceInputService();
  final CameraTextScanService _cameraScanService = CameraTextScanService();
  List<GroceryItem> _items = [];
  String _listName = 'Grocery List';
  bool _loading = true;
  bool _missingListId = false;
  bool _isScanning = false;
  bool _fabExpanded = false;
  bool _shoppingMode = false;
  List<String> _frequentItems = const [];
  List<String> _recommendedItems = const [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    unawaited(_cameraScanService.dispose());
    super.dispose();
  }

  Future<void> _loadItems() async {
    if (widget.listId.trim().isEmpty) {
      setState(() {
        _missingListId = true;
        _items = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    final lists = await _repository.getLists();
    ShoppingList? list;
    for (final entry in lists) {
      if (entry.id == widget.listId) {
        list = entry;
        break;
      }
    }
    final listName = list?.name ?? _listName;
    final items = await _repository.getItemsForList(widget.listId);
    final recentItems = await _repository.getRecentItems();
    final userItems = await _repository.getUserItems();
    if (!mounted) return;
    setState(() {
      _items = items;
      _listName = listName;
      _missingListId = false;
      _loading = false;
      _frequentItems = recentItems.take(12).toList();
      _recommendedItems =
          userItems.map((item) => item.name).take(12).toList();
    });
  }

  Future<void> _toggleDone(GroceryItem item) async {
    await _repository.toggleDone(item.id);
    await _loadItems();
  }

  Future<void> _toggleUnavailable(GroceryItem item, bool value) async {
    await _repository.updateItem(item.id, isUnavailable: value);
    await _loadItems();
  }

  Future<void> _deleteItem(GroceryItem item) async {
    await _repository.removeItem(item.id);
    await _loadItems();
  }

  Future<void> _openAddDialog() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddGroceryItemScreen(listId: widget.listId),
      ),
    );
    if (created == true) {
      await _loadItems();
    }
  }

  Future<void> _openExport() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QRExportScreen(
          listId: widget.listId,
          listName: _listName,
        ),
      ),
    );
  }

  Future<void> _openScanner() async {
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );
    if (imported == true) {
      await _loadItems();
    }
  }

  void _shareList() {
    final items = [..._items]..sort((a, b) => a.name.compareTo(b.name));
    final buffer = StringBuffer('My Grocery List:\n\n');
    for (final item in items) {
      final qty = UnitNormalizer.format(item.quantity, item.unit);
      buffer.writeln('- ${item.name} $qty');
    }
    Share.share(buffer.toString());
  }

  Future<void> _openSearchModal() async {
    final isOffline = context.read<ConnectivityProvider>().isOffline;
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => GrocerySearchModal(
          listId: widget.listId,
          isOffline: isOffline,
          onItemsAdded: _loadItems,
        ),
      ),
    );
  }

  Future<void> _openAddItemSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => GroceryAddItemSheet(
        initialName: '',
        closeOnSubmit: false,
        onSubmit: (payload) async {
          await _repository.addItem(
            listId: widget.listId,
            name: payload.name,
            quantity: payload.quantity,
            unit: payload.unit,
            categoryId: payload.categoryId,
            isImportant: payload.isImportant,
            packCount: payload.packCount,
            packSize: payload.packSize,
          );
          await _loadItems();
        },
      ),
    );
  }

  Future<void> _openEditItemDialog(GroceryItem item) async {
    final nameController = TextEditingController(text: item.name);
    final qtyController = TextEditingController(
      text: item.quantity % 1 == 0
          ? item.quantity.toStringAsFixed(0)
          : item.quantity.toStringAsFixed(1),
    );
    GroceryUnit selectedUnit = item.unit;
    final config = UnitConfigResolver.resolve(item.name, item.categoryId);
    final unitOptions = {...config.units, item.unit}.toList();
    if (!unitOptions.contains(selectedUnit)) {
      selectedUnit = unitOptions.first;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Item name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<GroceryUnit>(
              initialValue: selectedUnit,
              items: unitOptions
                  .map(
                    (unit) => DropdownMenuItem(
                      value: unit,
                      child: Text(unit.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => selectedUnit = value ?? selectedUnit,
              decoration: const InputDecoration(labelText: 'Unit'),
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

    if (confirmed != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) {
      _showSnackBar('Item name cannot be empty.');
      return;
    }
    final quantity =
        double.tryParse(qtyController.text.trim()) ?? item.quantity;
    final detected = _detectCategory(name);
    final category = detected == 'Miscellaneous' && item.categoryId.isNotEmpty
        ? item.categoryId
        : detected;
    await _repository.updateItem(
      item.id,
      name: name,
      quantity: quantity,
      unit: selectedUnit,
      categoryId: category,
    );
    await _loadItems();
  }

  Future<void> _openMoveToKitchenFlow(GroceryItem item) async {
    final qtyController = TextEditingController(
      text: item.quantity % 1 == 0
          ? item.quantity.toStringAsFixed(0)
          : item.quantity.toStringAsFixed(1),
    );
    GroceryUnit selectedUnit = item.unit;
    final config = UnitConfigResolver.resolve(item.name, item.categoryId);
    final unitOptions = {...config.units, item.unit}.toList();
    if (!unitOptions.contains(selectedUnit)) {
      selectedUnit = unitOptions.first;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Kitchen Stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<GroceryUnit>(
              initialValue: selectedUnit,
              items: unitOptions
                  .map(
                    (unit) => DropdownMenuItem(
                      value: unit,
                      child: Text(unit.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => selectedUnit = value ?? selectedUnit,
              decoration: const InputDecoration(labelText: 'Unit'),
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
            child: const Text('Move'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final quantity =
        double.tryParse(qtyController.text.trim()) ?? item.quantity;
    if (quantity <= 0) {
      _showSnackBar('Enter a valid quantity.');
      return;
    }
    await _moveToKitchen(item, quantity, selectedUnit);
    await _repository.removeItem(item.id);
    await _loadItems();
  }

  Future<void> _moveToKitchen(
    GroceryItem item,
    double quantity,
    GroceryUnit unit,
  ) async {
    final baseUnit = _baseUnitFromGroceryUnit(unit);
    final baseQuantity = _toBaseQuantity(quantity, unit);
    final category = _detectCategory(item.name);
    final batch = KitchenBatch(
      quantity: baseQuantity,
      unit: baseUnit,
      addedDate: DateTime.now(),
    );

    final provider = context.read<KitchenStockProvider>();
    KitchenItem? existing;
    for (final entry in provider.items) {
      if (entry.name.toLowerCase() == item.name.toLowerCase()) {
        existing = entry;
        break;
      }
    }
    if (existing != null) {
      await provider.addBatch(existing, batch);
    } else {
      await provider.addItem(
        KitchenItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: item.name,
          category: category,
          batches: [batch],
        ),
      );
    }
  }

  Future<void> _openCameraInput() async {
    if (_isScanning) return;
    setState(() => _isScanning = true);

    _showLoadingDialog();
    late final CameraTextScanResult result;
    try {
      result = await _cameraScanService.scanFromCamera();
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }

    if (!mounted || result.cancelled) {
      return;
    }

    if (result.error == CameraScanError.permissionDenied) {
      _showSnackBar('Camera permission denied.');
      return;
    }

    if (result.error == CameraScanError.noTextDetected) {
      _showSnackBar('No text detected.');
      return;
    }

    if (result.error != null) {
      _showSnackBar('Unable to scan items right now.');
      return;
    }

    final parsed = _inputHandler.parseInput(result.text ?? '');
    if (parsed.isEmpty) {
      _showSnackBar('No items detected.');
      return;
    }

    final selected = await showDialog<List<ParsedGroceryItem>>(
      context: context,
      builder: (_) => DetectedItemsDialog(items: parsed),
    );

    if (selected == null || selected.isEmpty) {
      return;
    }

    await _inputHandler.addItems(listId: widget.listId, items: selected);
    await _loadItems();
  }

  Future<void> _openVoiceOverlay() async {
    final availability = await _voiceInputService.ensureInitialized();
    if (availability == VoiceInputAvailability.permissionDenied) {
      _showSnackBar('Microphone permission denied.');
      return;
    }
    if (availability == VoiceInputAvailability.unavailable) {
      _showSnackBar('Speech recognition unavailable on this device.');
      return;
    }

    if (!mounted) return;
    final text = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => _VoiceInputOverlay(
        service: _voiceInputService,
      ),
    );

    final spoken = text?.trim() ?? '';
    if (spoken.isEmpty) return;
    final parsed = _parseVoiceInput(spoken);
    if (parsed == null) {
      _showSnackBar('Could not parse voice input.');
      return;
    }

    await _repository.addItem(
      listId: widget.listId,
      name: parsed.name,
      quantity: parsed.quantity,
      unit: parsed.unit,
      categoryId: parsed.category,
      isImportant: false,
      packCount: 1,
      packSize: 0,
    );
    await _loadItems();
  }

  void _showLoadingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  _ParsedVoiceItem? _parseVoiceInput(String input) {
    final cleaned = input.toLowerCase().trim();
    if (cleaned.isEmpty) return null;

    final match = RegExp(
      r'(\\d+(?:\\.\\d+)?)\\s*(kg|g|litre|l|ml|pcs|pc|piece|pieces)\\b',
    ).firstMatch(cleaned);

    double quantity = 1;
    String? unitToken;
    String name = cleaned;

    if (match != null) {
      quantity = double.tryParse(match.group(1) ?? '1') ?? 1;
      unitToken = match.group(2);
      name = cleaned.replaceRange(match.start, match.end, ' ').trim();
    } else {
      final qtyMatch =
          RegExp(r'\\b(\\d+(?:\\.\\d+)?)\\b').firstMatch(cleaned);
      if (qtyMatch != null) {
        quantity = double.tryParse(qtyMatch.group(1) ?? '1') ?? 1;
        name = cleaned.replaceRange(qtyMatch.start, qtyMatch.end, ' ').trim();
      }
    }

    if (name.isEmpty) return null;
    final titled = _titleCase(name);
    final category = _detectCategory(titled);
    final unit = unitToken == null
        ? UnitConfigResolver.defaultUnit(titled, category)
        : _unitFromToken(unitToken);
    final normalized = UnitNormalizer.normalize(quantity, unit);

    return _ParsedVoiceItem(
      name: titled,
      quantity: normalized.quantity,
      unit: normalized.unit,
      category: category,
    );
  }

  GroceryUnit _unitFromToken(String token) {
    switch (token) {
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
      case 'pc':
      case 'piece':
      case 'pieces':
      default:
        return GroceryUnit.pcs;
    }
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

  String _titleCase(String value) {
    return value
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join(' ');
  }

  Future<void> _openAddItemSheetWithName(
    String name,
    String? category,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => GroceryAddItemSheet(
        initialName: name,
        initialCategory: category,
        closeOnSubmit: false,
        onSubmit: (payload) async {
          await _repository.addItem(
            listId: widget.listId,
            name: payload.name,
            quantity: payload.quantity,
            unit: payload.unit,
            categoryId: payload.categoryId,
            isImportant: payload.isImportant,
            packCount: payload.packCount,
            packSize: payload.packSize,
          );
          await _loadItems();
        },
      ),
    );
  }

  List<_SuggestionData> _buildTextSuggestions(
    List<String> items, {
    required String reason,
    required Set<String> existingNames,
  }) {
    final suggestions = <_SuggestionData>[];
    final seen = <String>{};
    for (final name in items) {
      final normalized = name.toLowerCase().trim();
      if (normalized.isEmpty) continue;
      if (existingNames.contains(normalized)) continue;
      if (!seen.add(normalized)) continue;
      suggestions.add(
        _SuggestionData(
          name: name,
          category: _detectCategory(name),
          reason: reason,
        ),
      );
    }
    return suggestions;
  }

  List<_SuggestionData> _buildLowStockSuggestions(
    BuildContext context, {
    required Set<String> existingNames,
  }) {
    final provider = context.watch<KitchenStockProvider>();
    final suggestions = <_SuggestionData>[];
    for (final item in provider.items) {
      if (!_isLowStock(item)) continue;
      final normalized = item.name.toLowerCase().trim();
      if (normalized.isEmpty || existingNames.contains(normalized)) continue;
      suggestions.add(
        _SuggestionData(
          name: item.name,
          category: item.category,
          reason: 'Low stock',
        ),
      );
    }
    return suggestions;
  }

  bool _isLowStock(KitchenItem item) {
    final unit = item.batches.isNotEmpty ? item.batches.first.unit : 'pcs';
    final quantity = item.totalQuantity;
    if (unit == 'g' || unit == 'ml') {
      return quantity <= 500;
    }
    return quantity <= 1;
  }

  List<_ListEntry> _buildListEntries({
    required List<GroceryItem> activeItems,
    required List<GroceryItem> unavailableItems,
    required List<GroceryItem> completedItems,
    required List<_SuggestionData> frequentSuggestions,
    required List<_SuggestionData> recommendedSuggestions,
    required List<_SuggestionData> lowStockSuggestions,
  }) {
    final entries = <_ListEntry>[];
    if (!_shoppingMode) {
      if (frequentSuggestions.isNotEmpty) {
        entries.add(
          _ListEntry.suggestions('Frequently Added Items', frequentSuggestions),
        );
      }
      if (recommendedSuggestions.isNotEmpty) {
        entries.add(
          _ListEntry.suggestions('Recommended Items', recommendedSuggestions),
        );
      }
      if (lowStockSuggestions.isNotEmpty) {
        entries.add(
          _ListEntry.suggestions('Low Stock Items', lowStockSuggestions),
        );
      }
    }

    entries.add(const _ListEntry.header('Active Items'));
    if (activeItems.isEmpty) {
      entries.add(const _ListEntry.empty('No active items'));
    } else {
      for (final item in activeItems) {
        entries.add(_ListEntry.item(item, _ItemSection.active));
      }
    }

    entries.add(const _ListEntry.header('Next Grocery Run'));
    if (unavailableItems.isEmpty) {
      entries.add(const _ListEntry.empty('No unavailable items'));
    } else {
      for (final item in unavailableItems) {
        entries.add(_ListEntry.item(item, _ItemSection.unavailable));
      }
    }

    entries.add(const _ListEntry.header('Completed Items'));
    if (completedItems.isEmpty) {
      entries.add(const _ListEntry.empty('No completed items'));
    } else {
      for (final item in completedItems) {
        entries.add(_ListEntry.item(item, _ItemSection.completed));
      }
    }

    return entries;
  }

  List<_RowAction> _actionsForSection(
    _ItemSection section,
    GroceryItem item,
  ) {
    switch (section) {
      case _ItemSection.active:
        return [
          _RowAction.edit,
          _RowAction.markUnavailable,
          _RowAction.delete,
        ];
      case _ItemSection.unavailable:
        return [
          _RowAction.edit,
          _RowAction.markAvailable,
          _RowAction.delete,
        ];
      case _ItemSection.completed:
        return [
          _RowAction.moveToKitchen,
          _RowAction.markActive,
          _RowAction.delete,
        ];
    }
  }

  Future<void> _handleRowAction(
    _RowAction action,
    GroceryItem item,
  ) async {
    switch (action) {
      case _RowAction.edit:
        await _openEditItemDialog(item);
        return;
      case _RowAction.delete:
        await _deleteItem(item);
        return;
      case _RowAction.markUnavailable:
        await _toggleUnavailable(item, true);
        return;
      case _RowAction.markAvailable:
        await _toggleUnavailable(item, false);
        return;
      case _RowAction.moveToKitchen:
        await _openMoveToKitchenFlow(item);
        return;
      case _RowAction.markActive:
        await _toggleDone(item);
        return;
    }
  }

  String _baseUnitFromGroceryUnit(GroceryUnit unit) {
    switch (unit) {
      case GroceryUnit.kg:
      case GroceryUnit.g:
        return 'g';
      case GroceryUnit.litre:
      case GroceryUnit.ml:
        return 'ml';
      case GroceryUnit.pcs:
      case GroceryUnit.item:
      case GroceryUnit.packet:
        return 'pcs';
    }
  }

  int _toBaseQuantity(double quantity, GroceryUnit unit) {
    if (unit == GroceryUnit.kg || unit == GroceryUnit.litre) {
      return (quantity * 1000).round();
    }
    return quantity.round();
  }

  @override
  Widget build(BuildContext context) {
    if (_missingListId) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Grocery List'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Missing list ID.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                const Text('Please go back and select a list.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to Lists'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final activeItems = _items
        .where((item) => item.isDone == false && item.isUnavailable == false)
        .toList();
    final unavailableItems = _items
        .where((item) => item.isDone == false && item.isUnavailable == true)
        .toList();
    final completedItems = _items.where((item) => item.isDone == true).toList();
    final existingNames =
        _items.map((item) => item.name.toLowerCase()).toSet();
    final frequentSuggestions = _buildTextSuggestions(
      _frequentItems,
      reason: 'Frequently added',
      existingNames: existingNames,
    );
    final recommendedSuggestions = _buildTextSuggestions(
      _recommendedItems,
      reason: 'Recommended',
      existingNames: existingNames,
    );
    final lowStockSuggestions = _buildLowStockSuggestions(
      context,
      existingNames: existingNames,
    );
    final entries = _buildListEntries(
      activeItems: activeItems,
      unavailableItems: unavailableItems,
      completedItems: completedItems,
      frequentSuggestions: frequentSuggestions,
      recommendedSuggestions: recommendedSuggestions,
      lowStockSuggestions: lowStockSuggestions,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
        title: Text(_listName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Text(
                  'Shopping',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Switch(
                  value: _shoppingMode,
                  onChanged: (value) {
                    setState(() => _shoppingMode = value);
                  },
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareList,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Grocery',
            onPressed: _openAddItemSheet,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _openExport();
                  break;
                case 'scan':
                  _openScanner();
                  break;
                case 'add_screen':
                  _openAddDialog();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'export',
                child: Text('Share via QR'),
              ),
              PopupMenuItem(
                value: 'scan',
                child: Text('Scan QR'),
              ),
              PopupMenuItem(
                value: 'add_screen',
                child: Text('Add (Full Screen)'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: _GroceryFab(
        expanded: _fabExpanded,
        onToggle: () => setState(() => _fabExpanded = !_fabExpanded),
        onVoice: () async {
          setState(() => _fabExpanded = false);
          await _openVoiceOverlay();
        },
        onCamera: () async {
          setState(() => _fabExpanded = false);
          await _openCameraInput();
        },
      ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (context.watch<ConnectivityProvider>().isOffline)
                    const OfflineBanner(),
                  if (!_shoppingMode)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              readOnly: true,
                              onTap: _openSearchModal,
                              decoration: InputDecoration(
                                hintText: 'Search items',
                                prefixIcon: IconButton(
                                  icon: const Icon(Icons.search),
                                  onPressed: _openSearchModal,
                                ),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _openAddItemSheet,
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        switch (entry.type) {
                          case _EntryType.header:
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                entry.title ?? '',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            );
                          case _EntryType.empty:
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                entry.title ?? '',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            );
                          case _EntryType.suggestions:
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _SuggestionSection(
                                title: entry.title ?? '',
                                items: entry.suggestions ?? const [],
                                onAdd: (suggestion) => _openAddItemSheetWithName(
                                  suggestion.name,
                                  suggestion.category,
                                ),
                              ),
                            );
                          case _EntryType.item:
                            final item = entry.item!;
                            final section = entry.section!;
                            final actions =
                                _actionsForSection(section, item);
                            return _GroceryItemRow(
                              item: item,
                              showCategory: true,
                              strikeThrough: section == _ItemSection.completed,
                              onToggleDone: () => _toggleDone(item),
                              onAction: (action) =>
                                  _handleRowAction(action, item),
                              actions: actions,
                            );
                        }
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ParsedVoiceItem {
  const _ParsedVoiceItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
  });

  final String name;
  final double quantity;
  final GroceryUnit unit;
  final String category;
}

class _GroceryFab extends StatelessWidget {
  const _GroceryFab({
    required this.expanded,
    required this.onToggle,
    required this.onVoice,
    required this.onCamera,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onVoice;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          opacity: expanded ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: IgnorePointer(
            ignoring: !expanded,
            child: Column(
              children: [
                FloatingActionButton.extended(
                  heroTag: 'voice_fab',
                  onPressed: onVoice,
                  label: const Text('Voice Input'),
                  icon: const Icon(Icons.mic),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'camera_fab',
                  onPressed: onCamera,
                  label: const Text('Camera Input'),
                  icon: const Icon(Icons.camera_alt),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        FloatingActionButton(
          heroTag: 'main_fab',
          onPressed: onToggle,
          child: Icon(expanded ? Icons.close : Icons.add),
        ),
      ],
    );
  }
}

enum _ItemSection { active, unavailable, completed }

enum _RowAction {
  edit,
  delete,
  markUnavailable,
  markAvailable,
  moveToKitchen,
  markActive,
}

enum _EntryType { header, item, empty, suggestions }

class _SuggestionData {
  const _SuggestionData({
    required this.name,
    required this.category,
    required this.reason,
  });

  final String name;
  final String category;
  final String reason;
}

class _ListEntry {
  const _ListEntry.header(this.title)
      : type = _EntryType.header,
        item = null,
        section = null,
        suggestions = null;
  const _ListEntry.item(this.item, this.section)
      : type = _EntryType.item,
        title = null,
        suggestions = null;
  const _ListEntry.empty(this.title)
      : type = _EntryType.empty,
        item = null,
        section = null,
        suggestions = null;
  const _ListEntry.suggestions(this.title, this.suggestions)
      : type = _EntryType.suggestions,
        item = null,
        section = null;

  final _EntryType type;
  final String? title;
  final GroceryItem? item;
  final _ItemSection? section;
  final List<_SuggestionData>? suggestions;
}

class _SuggestionSection extends StatelessWidget {
  const _SuggestionSection({
    required this.title,
    required this.items,
    required this.onAdd,
  });

  final String title;
  final List<_SuggestionData> items;
  final ValueChanged<_SuggestionData> onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return GestureDetector(
                onTap: () => onAdd(item),
                child: Container(
                  width: 180,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.reason,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Icon(
                          Icons.add_circle_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GroceryItemRow extends StatelessWidget {
  const _GroceryItemRow({
    required this.item,
    required this.showCategory,
    required this.strikeThrough,
    required this.onToggleDone,
    required this.onAction,
    required this.actions,
  });

  final GroceryItem item;
  final bool showCategory;
  final bool strikeThrough;
  final VoidCallback onToggleDone;
  final ValueChanged<_RowAction> onAction;
  final List<_RowAction> actions;

  @override
  Widget build(BuildContext context) {
    final categoryText = item.categoryId.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: item.isDone,
            onChanged: (_) => onToggleDone(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration:
                            strikeThrough ? TextDecoration.lineThrough : null,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  UnitNormalizer.format(item.quantity, item.unit),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (showCategory &&
                    categoryText.isNotEmpty &&
                    categoryText.toLowerCase() != 'uncategorized')
                  Text(
                    categoryText.replaceAll('_', ' '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          PopupMenuButton<_RowAction>(
            onSelected: onAction,
            itemBuilder: (context) {
              return actions
                  .map(
                    (action) => PopupMenuItem(
                      value: action,
                      child: Text(_actionLabel(action)),
                    ),
                  )
                  .toList();
            },
          ),
        ],
      ),
    );
  }

  String _actionLabel(_RowAction action) {
    switch (action) {
      case _RowAction.edit:
        return 'Edit';
      case _RowAction.delete:
        return 'Delete';
      case _RowAction.markUnavailable:
        return 'Mark Not Available';
      case _RowAction.markAvailable:
        return 'Mark Available';
      case _RowAction.moveToKitchen:
        return 'Move to Kitchen Stock';
      case _RowAction.markActive:
        return 'Mark Active';
    }
  }
}

class _VoiceInputOverlay extends StatefulWidget {
  const _VoiceInputOverlay({required this.service});

  final VoiceInputService service;

  @override
  State<_VoiceInputOverlay> createState() => _VoiceInputOverlayState();
}

class _VoiceInputOverlayState extends State<_VoiceInputOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;
  String _text = '';
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _startListening();
  }

  @override
  void dispose() {
    _waveController.dispose();
    widget.service.stopListening();
    super.dispose();
  }

  Future<void> _startListening() async {
    await widget.service.startListening(
      onResult: (text) {
        if (!mounted) return;
        setState(() => _text = text);
      },
      onListeningChanged: (listening) {
        if (!mounted) return;
        setState(() => _listening = listening);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF1B5E20),
              Color(0xFF4CAF50),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _listening ? 'Listening...' : 'Paused',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              _Waveform(controller: _waveController),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _text.isEmpty ? 'Say an item and quantity' : _text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1B5E20),
                        ),
                        onPressed: _text.trim().isEmpty
                            ? null
                            : () async {
                                await widget.service.stopListening();
                                if (!context.mounted) return;
                                Navigator.of(context).pop(_text);
                              },
                        child: const Text('Add to List'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final base = controller.value * 2 * pi;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final phase = base + (index * pi / 5);
            final height = 24 + 24 * (0.5 + 0.5 * sin(phase));
            return Container(
              width: 12,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            );
          }),
        );
      },
    );
  }
}
