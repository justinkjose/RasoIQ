import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../grocery/data/grocery_repository.dart';
import '../../grocery/domain/grocery_item.dart';
import '../../grocery/domain/shopping_list.dart';
import '../../grocery/domain/grocery_unit.dart';
import '../../pantry/domain/pantry_item.dart';
import '../../pantry/services/pantry_service.dart';
import '../../pantry/services/pantry_unit_mapper.dart';
import '../../../services/ads_service.dart';
import '../../../data/models/ad_item.dart';
import '../data/recipes_repository.dart';
import '../domain/recipe_detail.dart';
import '../domain/recipe_meta.dart';
import 'recipe_detail_screen.dart';
import 'grocery_list_selector_sheet.dart';
import 'cook_with_what_you_have_screen.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final RecipesRepository _repository = RecipesRepository();
  final PantryService _pantryService = PantryService();
  final GroceryRepository _groceryRepository = GroceryRepository();
  final PantryUnitMapper _unitMapper = PantryUnitMapper();
  final AdsService _adsService = AdsService();

  bool _loading = true;
  List<RecipeMeta> _recipes = [];
  List<PantryItem> _pantryItems = [];
  List<GroceryItem> _groceryItems = [];
  Set<String> _downloadedIds = {};
  String _query = '';
  late final Future<List<AdItem>> _bannerAdsFuture;
  late final Future<List<AdItem>> _productAdsFuture;

  @override
  void initState() {
    super.initState();
    _bannerAdsFuture = _adsService.getAdsForScreen('recipes', type: 'banner');
    _productAdsFuture = _adsService.getAdsForScreen('recipes', type: 'product');
    _load();
  }

  Future<void> _load() async {
    final recipes = await _repository.loadRecipeMeta();
    final pantry = await _pantryService.getItems();
    final groceries = await _groceryRepository.getAllItems();
    final downloaded = await _repository.loadDownloadedIds();
    if (!mounted) return;
    setState(() {
      _recipes = recipes;
      _pantryItems = pantry;
      _groceryItems = groceries;
      _downloadedIds = downloaded;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final matches = _matchedRecipes();
    final trending = _trendingRecipes();

    return Scaffold(
      appBar: AppBar(
        title: Text('Recipes', style: AppTextStyles.headingMedium),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CookWithWhatYouHaveScreen(),
                ),
              );
            },
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Cook with what you have'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.space24),
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search recipes',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() => _query = value.trim());
            },
          ),
          const SizedBox(height: AppTheme.space16),
          _AdsSection(
            bannerFuture: _bannerAdsFuture,
            productFuture: _productAdsFuture,
          ),
          if (trending.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space16),
            Text('Trending Recipes', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppTheme.space12),
            _RecipeList(
              recipes: trending,
              onTap: _openRecipe,
              onDownload: _downloadRecipe,
              downloadedIds: _downloadedIds,
            ),
          ],
          const SizedBox(height: AppTheme.space16),
          Text('All Recipes', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppTheme.space12),
          _RecipeList(
            recipes: _filteredRecipes(),
            onTap: _openRecipe,
            onDownload: _downloadRecipe,
            downloadedIds: _downloadedIds,
          ),
          const SizedBox(height: AppTheme.space24),
          Text('Cook With What You Have', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppTheme.space12),
          _MatchedRecipeList(
            recipes: matches,
            onTap: _openRecipe,
            onDownload: _downloadRecipe,
            downloadedIds: _downloadedIds,
          ),
        ],
      ),
    );
  }

  Future<void> _openRecipe(RecipeMeta recipe) async {
    final detail = await _repository.loadRecipeDetail(recipe.id);
    if (detail == null || !mounted) return;
    await _repository.recordRecipeOpened(recipe.id);
    if (!mounted) return;
    final available = _availableIngredients();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(
          recipe: detail,
          availableIngredients: available,
          onAddMissing: () => _addMissingIngredients(detail),
        ),
      ),
    );
  }

  Future<void> _downloadRecipe(RecipeMeta recipe) async {
    final detail = await _repository.loadRecipeDetail(recipe.id);
    if (detail == null) return;
    await _repository.downloadRecipe(detail);
    if (!mounted) return;
    setState(() => _downloadedIds.add(recipe.id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recipe downloaded for offline use.')),
    );
  }

  List<_MatchedRecipe> _matchedRecipes() {
    final available = _availableIngredients();
    return _recipes
        .map((recipe) {
          final total = recipe.ingredients.length;
          final matched = recipe.ingredients
              .where((ingredient) => available.contains(_normalize(ingredient)))
              .length;
          final missingCount = total - matched;
          final percent = total == 0 ? 0.0 : matched / total;
          return _MatchedRecipe(
            recipe: recipe,
            matchPercent: percent,
            missingCount: missingCount,
          );
        })
        .where((item) => item.matchPercent >= 0.4)
        .toList()
      ..sort((a, b) => b.matchPercent.compareTo(a.matchPercent));
  }

  Future<void> _addMissingIngredients(RecipeDetail recipe) async {
    final available = _availableIngredients();
    final missing = recipe.ingredients
        .where(
          (ingredient) => !available.contains(_normalize(ingredient.name)),
        )
        .toList();
    if (missing.isEmpty) return;

    ShoppingList? selected;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => GroceryListSelectorSheet(
        repository: _groceryRepository,
        onSelected: (list) => selected = list,
      ),
    );
    if (selected == null) return;

    for (final ingredient in missing) {
      final unit = _resolveGroceryUnit(ingredient.name, ingredient.unit);
      await _groceryRepository.addItem(
        listId: selected!.id,
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
        .replaceAll(RegExp(r'[^a-z0-9\\s]'), ' ')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
  }

  Set<String> _availableIngredients() {
    final pantryNormalized =
        _pantryItems.map((item) => item.normalizedName).toSet();
    final groceryAvailable = _groceryItems
        .where((item) => item.isDone && !item.isUnavailable)
        .map((item) => item.normalizedName);
    return {...pantryNormalized, ...groceryAvailable};
  }

  List<RecipeMeta> _filteredRecipes() {
    if (_query.isEmpty) return _recipes;
    final needle = _query.toLowerCase();
    return _recipes
        .where((recipe) => recipe.name.toLowerCase().contains(needle))
        .toList();
  }

  List<RecipeMeta> _trendingRecipes() {
    final sorted = [..._recipes]
      ..sort((a, b) => b.trendingScore.compareTo(a.trendingScore));
    return sorted.take(8).toList();
  }
}

class _RecipeList extends StatelessWidget {
  const _RecipeList({
    required this.recipes,
    required this.onTap,
    required this.onDownload,
    required this.downloadedIds,
  });

  final List<RecipeMeta> recipes;
  final ValueChanged<RecipeMeta> onTap;
  final ValueChanged<RecipeMeta> onDownload;
  final Set<String> downloadedIds;

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return const Center(child: Text('No recipes available yet.'));
    }

    return Column(
      children: recipes
          .map(
            (recipe) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space16),
              child: _RecipeListCard(
                recipe: recipe,
                cuisine: _cuisineFor(recipe.name),
                onTap: () => onTap(recipe),
                onDownload: () => onDownload(recipe),
                isDownloaded: downloadedIds.contains(recipe.id),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MatchedRecipeList extends StatelessWidget {
  const _MatchedRecipeList({
    required this.recipes,
    required this.onTap,
    required this.onDownload,
    required this.downloadedIds,
  });

  final List<_MatchedRecipe> recipes;
  final ValueChanged<RecipeMeta> onTap;
  final ValueChanged<RecipeMeta> onDownload;
  final Set<String> downloadedIds;

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return const Center(child: Text('No matching recipes yet.'));
    }

    return Column(
      children: recipes
          .map(
            (match) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space16),
              child: _RecipeListCard(
                recipe: match.recipe,
                cuisine: _cuisineFor(match.recipe.name),
                onTap: () => onTap(match.recipe),
                onDownload: () => onDownload(match.recipe),
                isDownloaded: downloadedIds.contains(match.recipe.id),
              ),
            ),
          )
          .toList(),
    );
  }
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

class _RecipeListCard extends StatelessWidget {
  const _RecipeListCard({
    required this.recipe,
    required this.cuisine,
    required this.onTap,
    required this.onDownload,
    required this.isDownloaded,
  });

  final RecipeMeta recipe;
  final String cuisine;
  final VoidCallback onTap;
  final VoidCallback onDownload;
  final bool isDownloaded;

  @override
  Widget build(BuildContext context) {
    final card = AppCard(
      child: Row(
        children: [
          _RecipeImage(image: recipe.image),
          const SizedBox(width: AppTheme.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipe.name, style: AppTextStyles.bodyLarge),
                const SizedBox(height: AppTheme.space8),
                Text(
                  '$cuisine • ${recipe.cookTimeMinutes} min',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: isDownloaded ? null : onDownload,
            icon: Icon(
              isDownloaded ? Icons.download_done : Icons.download_outlined,
            ),
            tooltip: isDownloaded ? 'Downloaded' : 'Download offline',
          ),
        ],
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      onTap: onTap,
      child: card,
    );
  }
}

class _RecipeImage extends StatelessWidget {
  const _RecipeImage({required this.image});

  final String image;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: const Icon(Icons.restaurant_menu),
    );

    if (image.isEmpty) return placeholder;

    final Widget content = image.startsWith('http')
        ? Image.network(image, fit: BoxFit.cover)
        : Image.asset(image, fit: BoxFit.cover);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: SizedBox(width: 72, height: 72, child: content),
    );
  }
}

String _cuisineFor(String name) {
  final normalized = name.toLowerCase();
  if (normalized.contains('rajma') || normalized.contains('chawal')) {
    return 'North Indian';
  }
  if (normalized.contains('pasta')) {
    return 'Italian';
  }
  if (normalized.contains('biryani')) {
    return 'Hyderabadi';
  }
  if (normalized.contains('tacos')) {
    return 'Mexican';
  }
  return 'Indian';
}

class _MatchedRecipe {
  const _MatchedRecipe({
    required this.recipe,
    required this.matchPercent,
    required this.missingCount,
  });

  final RecipeMeta recipe;
  final double matchPercent;
  final int missingCount;
}
