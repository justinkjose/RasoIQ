import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../grocery/data/grocery_repository.dart';
import '../../grocery/domain/grocery_unit.dart';
import '../../pantry/domain/pantry_item.dart';
import '../../pantry/services/pantry_service.dart';
import '../../pantry/services/pantry_unit_mapper.dart';
import '../data/recipes_repository.dart';
import '../domain/recipe_detail.dart';
import 'recipe_detail_screen.dart';

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

  bool _loading = true;
  List<RecipeDetail> _recipes = [];
  List<PantryItem> _pantryItems = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final recipes = await _repository.loadRecipes();
    final pantry = await _pantryService.getItems();
    if (!mounted) return;
    setState(() {
      _recipes = recipes;
      _pantryItems = pantry;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final matches = _matchedRecipes();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Recipes', style: AppTextStyles.headingMedium),
          bottom: TabBar(
            labelStyle: AppTextStyles.bodyLarge,
            unselectedLabelStyle: AppTextStyles.bodySmall,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: const [
              Tab(text: 'Recipes'),
              Tab(text: 'Cook With What You Have'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RecipeList(
              recipes: _recipes,
              onTap: _openRecipe,
            ),
            _MatchedRecipeList(
              recipes: matches,
              onTap: _openRecipe,
            ),
          ],
        ),
      ),
    );
  }

  void _openRecipe(RecipeDetail recipe) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(
          recipe: recipe,
          onAddMissing: () => _addMissingIngredients(recipe),
        ),
      ),
    );
  }

  List<_MatchedRecipe> _matchedRecipes() {
    final pantryNormalized =
        _pantryItems.map((item) => _normalize(item.name)).toSet();
    return _recipes
        .map((recipe) {
          final total = recipe.ingredients.length;
          final available = recipe.ingredients
              .where(
                (ingredient) =>
                    pantryNormalized.contains(_normalize(ingredient.name)),
              )
              .length;
          final missingCount = total - available;
          final percent = total == 0 ? 0.0 : available / total;
          return _MatchedRecipe(
            recipe: recipe,
            matchPercent: percent,
            missingCount: missingCount,
          );
        })
        .where((item) => item.matchPercent >= 0.6)
        .toList()
      ..sort((a, b) => b.matchPercent.compareTo(a.matchPercent));
  }

  Future<void> _addMissingIngredients(RecipeDetail recipe) async {
    final pantryNormalized =
        _pantryItems.map((item) => _normalize(item.name)).toSet();
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
}

class _RecipeList extends StatelessWidget {
  const _RecipeList({required this.recipes, required this.onTap});

  final List<RecipeDetail> recipes;
  final ValueChanged<RecipeDetail> onTap;

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return const Center(child: Text('No recipes available yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.space24),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.space16),
          child: _RecipeListCard(
            recipe: recipe,
            cuisine: _cuisineFor(recipe.name),
            onTap: () => onTap(recipe),
          ),
        );
      },
    );
  }
}

class _MatchedRecipeList extends StatelessWidget {
  const _MatchedRecipeList({required this.recipes, required this.onTap});

  final List<_MatchedRecipe> recipes;
  final ValueChanged<RecipeDetail> onTap;

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return const Center(child: Text('No matching recipes yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.space24),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final match = recipes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.space16),
          child: _RecipeListCard(
            recipe: match.recipe,
            cuisine: _cuisineFor(match.recipe.name),
            onTap: () => onTap(match.recipe),
          ),
        );
      },
    );
  }
}

class _RecipeListCard extends StatelessWidget {
  const _RecipeListCard({
    required this.recipe,
    required this.cuisine,
    required this.onTap,
  });

  final RecipeDetail recipe;
  final String cuisine;
  final VoidCallback onTap;

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

  final RecipeDetail recipe;
  final double matchPercent;
  final int missingCount;
}
