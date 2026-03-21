import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_widgets.dart';
import '../../grocery/data/grocery_repository.dart';
import '../../grocery/domain/grocery_unit.dart';
import '../../pantry/domain/pantry_item.dart';
import '../../pantry/domain/predicted_item.dart';
import '../../pantry/services/insight_service.dart';
import '../../pantry/services/pantry_insights.dart';
import '../../pantry/services/pantry_service.dart';
import '../../pantry/services/pantry_unit_mapper.dart';
import '../../pantry/services/prediction_service.dart';
import '../../recipes/domain/recipe_detail.dart';
import '../../recipes/presentation/recipe_detail_screen.dart';
import '../../recipes/services/recipe_service.dart';
import 'add_pantry_item_screen.dart';
import 'pantry_category_page.dart';
import 'pantry_expiry_calendar_page.dart';
import 'receipt_scanner_screen.dart';
import 'voice_add_screen.dart';

class PantryPage extends StatefulWidget {
  const PantryPage({super.key});

  @override
  State<PantryPage> createState() => _PantryPageState();
}

class _PantryPageState extends State<PantryPage> {
  final PantryService _service = PantryService();
  final PredictionService _predictionService = PredictionService();
  final InsightService _insightService = InsightService();
  final RecipeService _recipeService = RecipeService();
  final GroceryRepository _groceryRepository = GroceryRepository();
  final PantryUnitMapper _unitMapper = PantryUnitMapper();

  late Future<_DashboardData> _dashboardFuture;

  static const _categoryData = <_CategoryInfo>[
    _CategoryInfo('Vegetables', Icons.eco_outlined),
    _CategoryInfo('Grains', Icons.grass_outlined),
    _CategoryInfo('Dairy', Icons.icecream_outlined),
    _CategoryInfo('Snacks', Icons.cookie_outlined),
    _CategoryInfo('Fruits', Icons.apple_outlined),
    _CategoryInfo('Spices', Icons.auto_awesome_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
  }

  Future<_DashboardData> _loadDashboard() async {
    final items = await _service.getItems();
    final expiring = await _service.expiringSoon(days: 7);
    final lowStock = await _service.lowStockItems();
    final categories = await _service.groupByCategory();
    final insights = await _service.getInsights();
    final predictions = await _predictionService.getPredictions(limit: 6);
    final aiInsights = _insightService.buildInsights(
      items: items,
      predictions: predictions,
      expiring: expiring,
    );
    final recipes = await _recipeService.getMatchedRecipes(limit: 6);

    return _DashboardData(
      items: items,
      expiring: expiring,
      lowStock: lowStock,
      categories: categories,
      insights: insights,
      predictions: predictions,
      aiInsights: aiInsights,
      recipes: recipes,
    );
  }

  Future<void> _openConsumeDialog(PantryItem item) async {
    final controller = TextEditingController();
    final quantity = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Consume ${item.name}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Quantity (${item.unit})',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final raw = controller.text.trim();
              final value = double.tryParse(raw) ?? 0;
              if (value <= 0) return;
              Navigator.of(context).pop(value);
            },
            child: const Text('Consume'),
          ),
        ],
      ),
    );
    if (quantity == null) return;
    await _service.consumeStock(itemId: item.id, quantity: quantity);
    setState(() => _dashboardFuture = _loadDashboard());
  }

  Future<void> _openAddItem() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddPantryItemScreen()),
    );
    if (created == true) {
      setState(() => _dashboardFuture = _loadDashboard());
    }
  }

  Future<void> _openReceiptScan() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ReceiptScannerScreen()),
    );
    if (updated == true) {
      setState(() => _dashboardFuture = _loadDashboard());
    }
  }

  Future<void> _openVoiceAdd() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const VoiceAddScreen()),
    );
    if (updated == true) {
      setState(() => _dashboardFuture = _loadDashboard());
    }
  }

  Future<void> _addToGrocery(PantryItem item) async {
    final lists = await _groceryRepository.getLists();
    final list = lists.isEmpty
        ? await _groceryRepository.createList(name: 'Quick List', icon: 'CART')
        : lists.first;

    await _groceryRepository.addItem(
      listId: list.id,
      name: item.name,
      quantity: 1,
      unit: GroceryUnit.item,
      categoryId: '',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.name} added to ${list.name}.')),
    );
  }

  Future<void> _addPredictionToGrocery(PredictedItem item) async {
    final lists = await _groceryRepository.getLists();
    final list = lists.isEmpty
        ? await _groceryRepository.createList(name: 'Quick List', icon: 'CART')
        : lists.first;

    await _groceryRepository.addItem(
      listId: list.id,
      name: item.name,
      quantity: 1,
      unit: GroceryUnit.item,
      categoryId: item.category,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.name} added to ${list.name}.')),
    );
  }

  Future<void> _addMissingIngredients(
    RecipeDetail recipe,
    List<PantryItem> pantryItems,
  ) async {
    final pantryNormalized =
        pantryItems.map((item) => _normalize(item.name)).toSet();
    final missing = recipe.ingredients
        .where(
          (ingredient) => !pantryNormalized.contains(_normalize(ingredient.name)),
        )
        .toList();
    if (missing.isEmpty) return;

    final lists = await _groceryRepository.getLists();
    final list = lists.isEmpty
        ? await _groceryRepository.createList(name: 'Quick List', icon: 'CART')
        : lists.first;

    for (final ingredient in missing) {
      final unit = _resolveGroceryUnit(ingredient.name, ingredient.unit);
      await _groceryRepository.addItem(
        listId: list.id,
        name: ingredient.name,
        quantity: ingredient.quantity,
        unit: unit,
        categoryId: 'recipes',
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Missing ingredients added to grocery list.')),
    );
  }

  GroceryUnit _resolveGroceryUnit(String name, String unit) {
    final normalized = unit.toLowerCase();
    if (normalized == 'kg') return GroceryUnit.kg;
    if (normalized == 'g') return GroceryUnit.g;
    if (normalized == 'litre' || normalized == 'l') return GroceryUnit.litre;
    if (normalized == 'ml') return GroceryUnit.ml;
    if (normalized == 'pcs') return GroceryUnit.pcs;
    if (normalized == 'packet') return GroceryUnit.packet;
    if (normalized == 'item') return GroceryUnit.item;

    final mapped = _unitMapper.unitForName(name);
    if (mapped == 'g') return GroceryUnit.g;
    if (mapped == 'litre') return GroceryUnit.litre;
    return GroceryUnit.kg;
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionAddButton(
        label: 'Add Item',
        onPressed: _openAddItem,
      ),
      body: FutureBuilder<_DashboardData>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Unable to load pantry dashboard.'));
          }

          final data = snapshot.data!;
          final insights = data.insights;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _dashboardFuture = _loadDashboard());
              await _dashboardFuture;
            },
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.space24),
              children: [
                const SectionHeader(title: 'Quick Actions'),
                const SizedBox(height: AppTheme.space16),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.mic,
                        label: 'Voice Add',
                        onTap: _openVoiceAdd,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space12),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.camera_alt,
                        label: 'Scan Receipt',
                        onTap: _openReceiptScan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.space24),
                SmartPantryScoreCard(
                  score: insights.healthScore,
                  expiringCount: insights.expiringSoonCount,
                  lowStockCount: insights.lowStockCount,
                ),
                const SizedBox(height: AppTheme.space24),
                AIInsightsCard(insights: data.aiInsights),
                const SizedBox(height: AppTheme.space24),
                const SectionHeader(title: 'AI Predictions'),
                const SizedBox(height: AppTheme.space16),
                _PredictionList(
                  items: data.predictions,
                  onAdd: _addPredictionToGrocery,
                ),
                const SizedBox(height: AppTheme.space24),
                _SectionHeaderRow(
                  title: 'Expiring Soon',
                  actionLabel: 'Calendar',
                  onAction: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PantryExpiryCalendarPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppTheme.space16),
                _ExpiringSoonList(items: data.expiring),
                const SizedBox(height: AppTheme.space24),
                const SectionHeader(title: 'Low Stock'),
                const SizedBox(height: AppTheme.space16),
                _LowStockList(items: data.lowStock, onAdd: _addToGrocery),
                const SizedBox(height: AppTheme.space24),
                  const SectionHeader(title: 'Cook Tonight'),
                  const SizedBox(height: AppTheme.space16),
                  _CookTonightList(
                    recipes: data.recipes,
                    availableIngredients: data.items
                        .map((item) => _normalize(item.name))
                        .toSet(),
                    onAddMissing: (recipe) =>
                        _addMissingIngredients(recipe, data.items),
                  ),
                const SizedBox(height: AppTheme.space24),
                const SectionHeader(title: 'Pantry Categories'),
                const SizedBox(height: AppTheme.space16),
                GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: AppTheme.space12,
                  crossAxisSpacing: AppTheme.space12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: _categoryData.map((category) {
                    return CategoryCard(
                      title: category.title,
                      icon: category.icon,
                      onTap: () {
                        final items = data.categories[category.title] ?? [];
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PantryCategoryPage(
                              title: category.title,
                              items: items,
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppTheme.space24),
                const SectionHeader(title: 'Pantry Items'),
                const SizedBox(height: AppTheme.space16),
                if (data.items.isEmpty)
                  const _EmptyState(message: 'Your pantry is empty'),
                if (data.items.isNotEmpty)
                  ...data.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.space12),
                      child: _SwipeablePantryTile(
                        item: item,
                        onConsume: () => _openConsumeDialog(item),
                      ),
                    ),
                  ),
                const SizedBox(height: AppTheme.space32),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardData {
  const _DashboardData({
    required this.items,
    required this.expiring,
    required this.lowStock,
    required this.categories,
    required this.insights,
    required this.predictions,
    required this.aiInsights,
    required this.recipes,
  });

  final List<PantryItem> items;
  final List<PantryItem> expiring;
  final List<PantryItem> lowStock;
  final Map<String, List<PantryItem>> categories;
  final PantryInsights insights;
  final List<PredictedItem> predictions;
  final List<String> aiInsights;
  final List<RecipeDetail> recipes;
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTheme.shadowOpacity),
            blurRadius: AppTheme.shadowBlur,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return _DashboardCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: Text(label, style: AppTextStyles.bodyLarge),
            ),
          ],
        ),
      ),
    );
  }
}

class SmartPantryScoreCard extends StatelessWidget {
  const SmartPantryScoreCard({
    super.key,
    required this.score,
    required this.expiringCount,
    required this.lowStockCount,
  });

  final int score;
  final int expiringCount;
  final int lowStockCount;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return _DashboardCard(
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(32),
            ),
            alignment: Alignment.center,
            child: Text(
              score.toString(),
              style: AppTextStyles.headingMedium.copyWith(color: color),
            ),
          ),
          const SizedBox(width: AppTheme.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Smart Pantry Score', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppTheme.space8),
                Wrap(
                  spacing: AppTheme.space8,
                  runSpacing: AppTheme.space8,
                  children: [
                    QuantityChip(label: '$expiringCount expiring'),
                    QuantityChip(label: '$lowStockCount low stock'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AIInsightsCard extends StatelessWidget {
  const AIInsightsCard({super.key, required this.insights});

  final List<String> insights;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI Insights', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppTheme.space12),
          ...insights.map(
            (insight) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome, size: 18),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: Text(insight, style: AppTextStyles.bodyLarge),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeaderRow extends StatelessWidget {
  const _SectionHeaderRow({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.titleMedium),
        TextButton(
          onPressed: onAction,
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _ExpiringSoonList extends StatelessWidget {
  const _ExpiringSoonList({required this.items});

  final List<PantryItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(message: 'No items expiring soon');
    }

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppTheme.space12),
        itemBuilder: (context, index) {
          final item = items[index];
          final daysLeft = item.expiryDate?.difference(DateTime.now()).inDays;
          final label =
              daysLeft == null ? 'No date' : '${daysLeft.clamp(0, 99)} days';
          return SizedBox(
            width: 160,
            child: _DashboardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_outlined),
                  const SizedBox(height: AppTheme.space12),
                  Text(item.name, style: AppTextStyles.bodyLarge),
                  const SizedBox(height: AppTheme.space8),
                  Text(label, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LowStockList extends StatelessWidget {
  const _LowStockList({
    required this.items,
    required this.onAdd,
  });

  final List<PantryItem> items;
  final ValueChanged<PantryItem> onAdd;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(message: 'No low stock items');
    }
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space12),
              child: _DashboardCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(item.name, style: AppTextStyles.bodyLarge),
                    ),
                    RoundedButton(
                      label: 'Add',
                      onPressed: () => onAdd(item),
                      fullWidth: false,
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CookTonightList extends StatelessWidget {
  const _CookTonightList({
    required this.recipes,
    required this.availableIngredients,
    required this.onAddMissing,
  });

  final List<RecipeDetail> recipes;
  final Set<String> availableIngredients;
  final ValueChanged<RecipeDetail> onAddMissing;

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return const _EmptyState(message: 'No recipe matches yet');
    }

    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recipes.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppTheme.space16),
        itemBuilder: (context, index) {
          final recipe = recipes[index];
          return SizedBox(
            width: 180,
            child: RecipeCard(
              title: recipe.name,
              timeLabel: '${recipe.cookTimeMinutes} min',
              image: recipe.image,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecipeDetailScreen(
                        recipe: recipe,
                        availableIngredients: availableIngredients,
                        onAddMissing: () => onAddMissing(recipe),
                      ),
                    ),
                  );
                },
              ),
          );
        },
      ),
    );
  }
}

class _PredictionList extends StatelessWidget {
  const _PredictionList({
    required this.items,
    required this.onAdd,
  });

  final List<PredictedItem> items;
  final ValueChanged<PredictedItem> onAdd;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(message: 'No predictions yet');
    }

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppTheme.space12),
        itemBuilder: (context, index) {
          final item = items[index];
          final percent = (item.confidenceScore * 100).clamp(0, 100).toInt();
          return SizedBox(
            width: 180,
            child: _DashboardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.insights_outlined),
                  const SizedBox(height: AppTheme.space12),
                  Text(item.name, style: AppTextStyles.bodyLarge),
                  const SizedBox(height: AppTheme.space8),
                  Text(item.category, style: AppTextStyles.bodySmall),
                  const SizedBox(height: AppTheme.space8),
                  Row(
                    children: [
                      Expanded(child: QuantityChip(label: '$percent% likely')),
                      const SizedBox(width: AppTheme.space8),
                      RoundedButton(
                        label: 'Add',
                        onPressed: () => onAdd(item),
                        fullWidth: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Text(message, style: AppTextStyles.bodyLarge),
          ),
        ],
      ),
    );
  }
}

class _SwipeablePantryTile extends StatelessWidget {
  const _SwipeablePantryTile({
    required this.item,
    required this.onConsume,
  });

  final PantryItem item;
  final VoidCallback onConsume;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.id),
      confirmDismiss: (_) async => false,
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        icon: Icons.edit_outlined,
        label: 'Edit',
        color: Theme.of(context).colorScheme.primary,
      ),
      secondaryBackground: _SwipeBackground(
        alignment: Alignment.centerRight,
        icon: Icons.remove_circle_outline,
        label: 'Consume',
        color: Theme.of(context).colorScheme.secondary,
      ),
      child: PantryItemTile(
        title: item.name,
        quantityLabel: '${item.quantity.toStringAsFixed(1)} ${item.unit}',
        expiryLabel: _expiryLabel(item.expiryDate),
        onConsume: onConsume,
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

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.icon,
    required this.label,
    required this.color,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppTheme.space8),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryInfo {
  const _CategoryInfo(this.title, this.icon);

  final String title;
  final IconData icon;
}
