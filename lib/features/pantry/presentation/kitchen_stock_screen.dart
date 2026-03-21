
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../data/default_grocery_catalog.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_widgets.dart';
import '../../grocery/data/user_item_storage.dart';
import '../../grocery/domain/user_item.dart';
import '../widgets/kitchen_add_item_sheet.dart';
import '../domain/kitchen_item.dart';
import '../providers/kitchen_stock_provider.dart';
import 'pantry_expiry_calendar_page.dart';
import 'receipt_scanner_screen.dart';

class KitchenStockScreen extends StatefulWidget {
  const KitchenStockScreen({super.key});

  @override
  State<KitchenStockScreen> createState() => _KitchenStockScreenState();
}

class _KitchenStockScreenState extends State<KitchenStockScreen> {
  final SpeechToText _speech = SpeechToText();
  final UserItemStorage _userItemStorage = UserItemStorage();
  bool _isListening = false;
  String _lastWords = '';

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kitchen Stock', style: AppTextStyles.headingMedium),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PantryExpiryCalendarPage(),
                ),
              );
            },
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Expiry Calendar',
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 24, bottom: 24),
        child: FloatingActionButton(
          onPressed: () => _openAddMenu(context),
          backgroundColor: AppTheme.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Consumer<KitchenStockProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final insights = _buildInsights(provider.items);
          final expiringItems = _expiringSoonItems(provider.items);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space24,
              AppTheme.space24,
              AppTheme.space24,
              90,
            ),
            children: [
              const SectionHeader(title: 'Smart Kitchen Insights'),
              const SizedBox(height: AppTheme.space16),
              _InsightsRow(insights: insights),
              const SizedBox(height: AppTheme.space16),
              _PantryHealthScoreCard(score: insights.healthScore),
              if (_isListening) ...[
                const SizedBox(height: AppTheme.space16),
                _ListeningPill(
                  text: _lastWords.isEmpty ? 'Listening...' : _lastWords,
                ),
              ],
              const SizedBox(height: AppTheme.space24),
              if (expiringItems.isNotEmpty) ...[
                const SectionHeader(title: 'Expiring Soon'),
                const SizedBox(height: AppTheme.space12),
                ...expiringItems.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.space12),
                    child: _ExpiringItemCard(item: entry.item, batch: entry.batch),
                  ),
                ),
                const SizedBox(height: AppTheme.space12),
              ],
              const SectionHeader(title: 'Kitchen Items'),
              const SizedBox(height: AppTheme.space16),
              if (provider.items.isEmpty)
                const _EmptyState(message: 'No kitchen items yet'),
              if (provider.items.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: provider.items.length,
                  itemBuilder: (context, index) {
                    final item = provider.items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.space12),
                      child: _KitchenItemCard(
                        item: item,
                        onQuickAdd: () => _quickAdjust(context, item, 1),
                        onQuickRemove: () => _quickAdjust(context, item, -1),
                        onUseQuantity: () =>
                            _openUseQuantitySheet(context, item),
                        onSetExpiry: () => _setExpiryForItem(context, item),
                        onDelete: () => _deleteItem(context, item),
                      ),
                    );
                  },
                ),
              const SizedBox(height: AppTheme.space32),
            ],
          );
        },
      ),
    );
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

    if (!available) {
      if (!context.mounted) return;
      _showMicPermissionDialog(context);
      return;
    }

    if (!mounted) return;
    setState(() {
      _isListening = true;
      _lastWords = '';
    });

    await _speech.listen(
      localeId: 'en_IN',
      listenFor: const Duration(seconds: 5),
      onResult: (result) {
        if (!mounted) return;
        setState(() => _lastWords = result.recognizedWords);
      },
    );
  }

  void _handleVoiceResult(BuildContext context, String words) {
    final parsed = _parseVoice(words);
    if (parsed == null) return;
    _openManualAddSheet(
      context,
      name: parsed.name,
      quantity: parsed.quantity.toDouble(),
      unit: parsed.unit,
      category: parsed.category,
    );
  }

  _VoiceParseResult? _parseVoice(String words) {
    final cleaned = words.toLowerCase().replaceFirst('add ', '').trim();
    if (cleaned.isEmpty) return null;

    final regex =
        RegExp(r'(\\d+(?:\\.\\d+)?)\\s*(kg|g|litre|ml|pcs)\\s*(.*)');
    final match = regex.firstMatch(cleaned);
    if (match != null) {
      final qty = double.tryParse(match.group(1) ?? '1') ?? 1;
      final unit = match.group(2) ?? 'pcs';
      final baseUnit = _baseUnitFromUnit(unit);
      final baseQty = _toBaseQuantity(qty, unit);
      final name = (match.group(3) ?? '').trim();
      final category = _detectCategory(name.isEmpty ? cleaned : name);
      return _VoiceParseResult(
        name: name.isEmpty ? cleaned : name,
        quantity: baseQty,
        unit: baseUnit,
        category: category,
      );
    }

    final category = _detectCategory(cleaned);
    return _VoiceParseResult(
      name: cleaned,
      quantity: 1,
      unit: 'pcs',
      category: category,
    );
  }

  Future<void> _openAddMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Scan Item'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ReceiptScannerScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.mic_none_outlined),
                title: const Text('Voice Add'),
                onTap: () {
                  Navigator.of(context).pop();
                  _toggleListening(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Manual Add'),
                onTap: () {
                  Navigator.of(context).pop();
                  _openManualAddSheet(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  void _openManualAddSheet(
    BuildContext context, {
    String? name,
    double? quantity,
    String? unit,
    String? category,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => KitchenAddItemSheet(
        initialName: name,
        initialQuantity: quantity,
        initialUnit: unit,
        initialCategory: category,
        onSubmit: (payload) async {
          final baseUnit = _baseUnitFromUnit(payload.unit);
          final baseQuantity = _toBaseQuantity(
            payload.totalQuantity,
            payload.unit,
          );
          final provider = context.read<KitchenStockProvider>();
          KitchenItem? existing;
          for (final item in provider.items) {
            if (item.name.toLowerCase() == payload.name.toLowerCase()) {
              existing = item;
              break;
            }
          }

          final batch = KitchenBatch(
            quantity: baseQuantity,
            unit: baseUnit,
            addedDate: DateTime.now(),
            expiryDate: payload.expiryDate,
          );

          if (existing != null) {
            await provider.addBatch(existing, batch);
          } else {
            await provider.addItem(
              KitchenItem(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                name: payload.name,
                category: payload.category,
                batches: [batch],
              ),
            );
          }

          await _learnUserItemIfNeeded(payload.name, payload.category);
        },
      ),
    );
  }

  Future<void> _quickAdjust(
    BuildContext context,
    KitchenItem item,
    int direction,
  ) async {
    final step = _defaultStepForItem(item);
    final provider = context.read<KitchenStockProvider>();
    if (direction < 0) {
      await provider.useQuantity(item, step);
      return;
    }

    final batches = [...item.batches];
    if (batches.isEmpty) {
      batches.add(
        KitchenBatch(
          quantity: step,
          unit: _baseUnitForItem(item),
          addedDate: DateTime.now(),
        ),
      );
    } else {
      final lastIndex = batches.length - 1;
      final batch = batches[lastIndex];
      batches[lastIndex] = batch.copyWith(quantity: batch.quantity + step);
    }
    await provider.updateItem(item.copyWith(batches: batches));
  }

  Future<void> _setExpiryForItem(BuildContext context, KitchenItem item) async {
    if (item.batches.isEmpty) return;
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 3)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!context.mounted) return;
    final batches = [...item.batches];
    var targetIndex = batches.indexWhere((batch) => batch.expiryDate == null);
    if (targetIndex == -1) {
      targetIndex = 0;
    }
    final target = batches[targetIndex];
    batches[targetIndex] = target.copyWith(expiryDate: date);
    final provider = context.read<KitchenStockProvider>();
    await provider.updateItem(item.copyWith(batches: batches));
  }

  void _openUseQuantitySheet(BuildContext context, KitchenItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _UseQuantitySheet(item: item),
    );
  }

  Future<void> _deleteItem(BuildContext context, KitchenItem item) async {
    final provider = context.read<KitchenStockProvider>();
    await provider.deleteItem(item);
  }

  _InsightData _buildInsights(List<KitchenItem> items) {
    final now = DateTime.now();
    final expiringSoon = items.where((item) {
      return item.batches.any((batch) {
        if (batch.expiryDate == null) return false;
        final diff = batch.expiryDate!.difference(now).inDays;
        return diff <= 3;
      });
    }).toList();

    final outOfStock = items.where((item) => item.isOutOfStock).toList();

    final unused = items.where((item) {
      if (item.totalQuantity <= 0) return false;
      final lastAdded = item.batches
          .map((batch) => batch.addedDate)
          .fold<DateTime>(DateTime(1970), (prev, date) {
        return date.isAfter(prev) ? date : prev;
      });
      return now.difference(lastAdded).inDays >= 30;
    }).toList();

    final categoryTotals = <String, int>{};
    for (final item in items) {
      categoryTotals[item.category] =
          (categoryTotals[item.category] ?? 0) + item.totalQuantity;
    }

    String mostStockedCategory = '—';
    int highest = 0;
    categoryTotals.forEach((key, value) {
      if (value > highest) {
        highest = value;
        mostStockedCategory = _categoryLabel(key);
      }
    });

    KitchenItem? mostUsed;
    KitchenItem? leastUsed;
    final available = items.where((item) => item.totalQuantity > 0).toList();
    available.sort((a, b) => a.totalQuantity.compareTo(b.totalQuantity));
    if (available.isNotEmpty) {
      mostUsed = available.first;
      leastUsed = available.last;
    }

    var score = 100;
    if (expiringSoon.length > 3) score -= 10;
    if (outOfStock.length > 3) score -= 10;
    if (unused.length > 5) score -= 10;
    score = score.clamp(0, 100);

    return _InsightData(
      expiringSoon: expiringSoon.length,
      outOfStock: outOfStock.length,
      mostStockedCategory: mostStockedCategory,
      mostUsed: mostUsed?.name ?? '—',
      leastUsed: leastUsed?.name ?? '—',
      healthScore: score,
    );
  }

  List<_ExpiringItemEntry> _expiringSoonItems(List<KitchenItem> items) {
    final now = DateTime.now();
    final entries = <_ExpiringItemEntry>[];
    for (final item in items) {
      for (final batch in item.batches) {
        final expiry = batch.expiryDate;
        if (expiry == null) continue;
        final diff = expiry.difference(now).inDays;
        if (diff >= 0 && diff <= 3) {
          entries.add(_ExpiringItemEntry(item: item, batch: batch));
        }
      }
    }
    entries.sort((a, b) {
      final aDate = a.batch.expiryDate ?? DateTime(9999);
      final bDate = b.batch.expiryDate ?? DateTime(9999);
      return aDate.compareTo(bDate);
    });
    return entries;
  }

  String _categoryLabel(String key) {
    if (key.isEmpty) return 'Miscellaneous';
    final cleaned = key.replaceAll('_', ' ');
    return cleaned
        .split(' ')
        .map((word) => word.isEmpty
            ? ''
            : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
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

  Future<void> _learnUserItemIfNeeded(String name, String category) async {
    if (_isInDefaultCatalog(name)) return;
    final items = await _userItemStorage.loadUserItems();
    final normalized = _normalizeName(name);
    final exists = items.any(
      (item) => _normalizeName(item.name) == normalized,
    );
    if (exists) return;
    items.add(
      UserItem(
        id: _normalizeName(name),
        name: name,
        category: category,
        unit: 'pcs',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        pendingSync: true,
      ),
    );
    await _userItemStorage.saveUserItems(items);
  }

  bool _isInDefaultCatalog(String name) {
    final normalized = _normalizeName(name);
    for (final entry in DefaultGroceryCatalog.categories.entries) {
      for (final item in entry.value) {
        if (_normalizeName(item) == normalized) return true;
      }
    }
    return false;
  }

  String _normalizeName(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\\s]'), ' ')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
  }

  String _baseUnitForItem(KitchenItem item) {
    if (item.batches.isNotEmpty) return item.batches.first.unit;
    return 'pcs';
  }

  int _defaultStepForItem(KitchenItem item) {
    final unit = _baseUnitForItem(item);
    if (unit == 'g' || unit == 'ml') return 50;
    return 1;
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

  void _showMicPermissionDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Microphone access needed'),
        content: const Text('Enable microphone permission to use voice add.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _InsightData {
  const _InsightData({
    required this.expiringSoon,
    required this.outOfStock,
    required this.mostStockedCategory,
    required this.mostUsed,
    required this.leastUsed,
    required this.healthScore,
  });

  final int expiringSoon;
  final int outOfStock;
  final String mostStockedCategory;
  final String mostUsed;
  final String leastUsed;
  final int healthScore;
}

class _InsightsRow extends StatelessWidget {
  const _InsightsRow({required this.insights});

  final _InsightData insights;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _InsightCard(
        title: 'Items Expiring Soon',
        value: '${insights.expiringSoon}',
        icon: Icons.timer_outlined,
      ),
      _InsightCard(
        title: 'Most Stocked Category',
        value: insights.mostStockedCategory,
        icon: Icons.inventory_2_outlined,
      ),
      _InsightCard(
        title: 'Most Used Ingredients',
        value: insights.mostUsed,
        icon: Icons.local_fire_department_outlined,
      ),
      _InsightCard(
        title: 'Least Used Ingredients',
        value: insights.leastUsed,
        icon: Icons.spa_outlined,
      ),
      _InsightCard(
        title: 'Out of Stock',
        value: '${insights.outOfStock}',
        icon: Icons.warning_amber_outlined,
      ),
    ];
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: cards,
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        color: scheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: scheme.primary),
          const SizedBox(height: AppTheme.space8),
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppTheme.space8),
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _PantryHealthScoreCard extends StatelessWidget {
  const _PantryHealthScoreCard({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    Color color;
    if (score > 80) {
      color = Colors.green;
    } else if (score >= 60) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.space20),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
            ),
            alignment: Alignment.center,
            child: Text(
              '$score',
              style: AppTextStyles.titleMedium.copyWith(color: color),
            ),
          ),
          const SizedBox(width: AppTheme.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pantry Health Score', style: AppTextStyles.bodyLarge),
                const SizedBox(height: AppTheme.space8),
                Text('Track expiry, stock and usage trends.',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KitchenItemCard extends StatelessWidget {
  const _KitchenItemCard({
    required this.item,
    required this.onQuickAdd,
    required this.onQuickRemove,
    required this.onUseQuantity,
    required this.onSetExpiry,
    required this.onDelete,
  });

  final KitchenItem item;
  final VoidCallback onQuickAdd;
  final VoidCallback onQuickRemove;
  final VoidCallback onUseQuantity;
  final VoidCallback onSetExpiry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final unit = item.batches.isNotEmpty ? item.batches.first.unit : 'pcs';
    final remainingLabel = formatQuantity(item.totalQuantity, unit);
    final expiryDate = _nextExpiry(item);
    final expiryLabel = expiryDate == null
        ? 'Expiry: Not set'
        : 'Expiry: ${expiryDate.day}/${expiryDate.month}/${expiryDate.year}';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: AppTextStyles.titleMedium),
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      '${item.batches.length} batch${item.batches.length == 1 ? '' : 'es'} • $remainingLabel',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Text(expiryLabel, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              if (item.isOutOfStock) const _StockBadge(),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          Row(
            children: [
              OutlinedButton(
                onPressed: onQuickAdd,
                child: const Text('+1'),
              ),
              const SizedBox(width: AppTheme.space8),
              OutlinedButton(
                onPressed: onQuickRemove,
                child: const Text('-1'),
              ),
              const SizedBox(width: AppTheme.space8),
              Expanded(
                child: FilledButton(
                  onPressed: onUseQuantity,
                  child: const Text('Use Qty'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onSetExpiry,
              child: const Text('Set Expiry'),
            ),
          ),
          if (item.batches.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space8),
            Text(
              'Batches (${item.batches.length})',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppTheme.space8),
            ...item.batches.asMap().entries.map((entry) {
              final index = entry.key;
              final batch = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.space4),
                child: Text(
                  'Batch ${index + 1}: ${formatQuantity(batch.quantity, batch.unit)} • ${_expiryLabel(batch)}',
                  style: AppTextStyles.bodySmall,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  DateTime? _nextExpiry(KitchenItem item) {
    final dates = item.batches
        .map((batch) => batch.expiryDate)
        .whereType<DateTime>()
        .toList()
      ..sort();
    if (dates.isEmpty) return null;
    return dates.first;
  }

  String _expiryLabel(KitchenBatch batch) {
    final expiryDate = batch.expiryDate;
    if (expiryDate == null) return 'No expiry';
    final today = DateTime.now();
    final days = expiryDate.difference(today).inDays;
    if (days < 0) return 'Expired';
    if (days == 0) return 'Expires today';
    return 'Expiry in $days days';
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space12,
        vertical: AppTheme.space4,
      ),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Text(
        'Out of Stock',
        style: AppTextStyles.bodySmall.copyWith(
          color: Colors.red,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ExpiringItemEntry {
  const _ExpiringItemEntry({required this.item, required this.batch});

  final KitchenItem item;
  final KitchenBatch batch;
}

class _ExpiringItemCard extends StatelessWidget {
  const _ExpiringItemCard({required this.item, required this.batch});

  final KitchenItem item;
  final KitchenBatch batch;

  @override
  Widget build(BuildContext context) {
    final expiry = batch.expiryDate;
    final dateLabel = expiry == null
        ? 'Expiry: Not set'
        : 'Expiry: ${expiry.day}/${expiry.month}/${expiry.year}';
    return AppCard(
      padding: const EdgeInsets.all(AppTheme.space16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: AppTextStyles.bodyLarge),
                const SizedBox(height: AppTheme.space8),
                Text(dateLabel, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space12,
              vertical: AppTheme.space4,
            ),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: Text(
              'Expiring Soon',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListeningPill extends StatelessWidget {
  const _ListeningPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mic, size: 18),
          const SizedBox(width: AppTheme.space8),
          Flexible(
            child: Text(text, style: AppTextStyles.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Center(child: Text(message, style: AppTextStyles.bodySmall)),
    );
  }
}

class _AddBatchSheet extends StatefulWidget {
  const _AddBatchSheet({required this.item});

  final KitchenItem item;

  @override
  State<_AddBatchSheet> createState() => _AddBatchSheetState();
}

class _AddBatchSheetState extends State<_AddBatchSheet> {
  final TextEditingController _quantityController = TextEditingController();
  DateTime? _expiryDate;
  late String _unit;

  @override
  void initState() {
    super.initState();
    _unit = widget.item.batches.isNotEmpty
        ? widget.item.batches.first.unit
        : 'pcs';
  }

  @override
  void dispose() {
    _quantityController.dispose();
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
          Text('Add Batch', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppTheme.space12),
          TextField(
            controller: _quantityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Quantity'),
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
                  child: const Text('Add Batch'),
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
    final baseQuantity = _toBaseQuantity(quantity, _unit);
    final baseUnit = _baseUnitFromUnit(_unit);

    final provider = context.read<KitchenStockProvider>();
    await provider.addBatch(
      widget.item,
      KitchenBatch(
        quantity: baseQuantity,
        unit: baseUnit,
        addedDate: DateTime.now(),
        expiryDate: _expiryDate,
      ),
    );

    if (!context.mounted) return;
    Navigator.of(context).pop();
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

class _UseQuantitySheet extends StatefulWidget {
  const _UseQuantitySheet({required this.item});

  final KitchenItem item;

  @override
  State<_UseQuantitySheet> createState() => _UseQuantitySheetState();
}

class _UseQuantitySheetState extends State<_UseQuantitySheet> {
  late final String _unit;
  late int _selectedStep;
  late int _currentQty;

  @override
  void initState() {
    super.initState();
    _unit = widget.item.batches.isNotEmpty
        ? widget.item.batches.first.unit
        : 'pcs';
    if (_unit == 'g' || _unit == 'ml') {
      _selectedStep = 50;
      _currentQty = widget.item.totalQuantity < 50
          ? widget.item.totalQuantity
          : 50;
    } else {
      _selectedStep = 1;
      _currentQty = widget.item.totalQuantity < 1
          ? 0
          : 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSolid = _unit == 'g';
    final isLiquid = _unit == 'ml';
    final isPiece = _unit == 'pcs';
    final remaining = formatQuantity(widget.item.totalQuantity, _unit);

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
          Text('Use Quantity', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppTheme.space12),
          Text('Remaining: $remaining', style: AppTextStyles.bodySmall),
          const SizedBox(height: AppTheme.space12),
          if (!isPiece) ...[
            Wrap(
              spacing: AppTheme.space8,
              children: [
                ChoiceChip(
                  label: Text(isSolid ? '50 g' : '50 ml'),
                  selected: _selectedStep == 50,
                  onSelected: (_) {
                    setState(() {
                      _selectedStep = 50;
                      _currentQty = _selectedStep > widget.item.totalQuantity
                          ? widget.item.totalQuantity
                          : _selectedStep;
                    });
                  },
                ),
                ChoiceChip(
                  label: Text(isSolid ? '100 g' : '100 ml'),
                  selected: _selectedStep == 100,
                  onSelected: (_) {
                    setState(() {
                      _selectedStep = 100;
                      _currentQty = _selectedStep > widget.item.totalQuantity
                          ? widget.item.totalQuantity
                          : _selectedStep;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  final next = _currentQty - _selectedStep;
                  if (next >= _selectedStep) {
                    setState(() => _currentQty = next);
                  }
                },
                icon: const Icon(Icons.remove_circle_outline),
              ),
              const SizedBox(width: AppTheme.space8),
              Text(
                '$_currentQty ${isSolid ? 'g' : isLiquid ? 'ml' : 'pcs'}',
                style: AppTextStyles.bodyLarge,
              ),
              const SizedBox(width: AppTheme.space8),
              IconButton(
                onPressed: () {
                  final maxAllowed = widget.item.totalQuantity;
                  final next = _currentQty + _selectedStep;
                  if (next <= maxAllowed) {
                    setState(() => _currentQty = next);
                  }
                },
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
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
                  child: const Text('Use'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final quantity = _currentQty;
    if (quantity <= 0) return;
    final provider = context.read<KitchenStockProvider>();
    await provider.useQuantity(widget.item, quantity);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }
}


class _VoiceParseResult {
  const _VoiceParseResult({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
  });

  final String name;
  final int quantity;
  final String unit;
  final String category;
}
