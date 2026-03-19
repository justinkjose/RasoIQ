import '../../pantry/services/pantry_service.dart';
import '../data/recipes_repository.dart';
import '../domain/recipe_detail.dart';

class RecipeService {
  RecipeService({
    RecipesRepository? repository,
    PantryService? pantryService,
  })  : _repository = repository ?? RecipesRepository(),
        _pantryService = pantryService ?? PantryService();

  final RecipesRepository _repository;
  final PantryService _pantryService;

  Future<List<RecipeDetail>> getMatchedRecipes({int limit = 6}) async {
    final recipes = await _repository.loadRecipes();
    final pantry = await _pantryService.getItems();
    if (recipes.isEmpty || pantry.isEmpty) return [];

    final pantryNormalized =
        pantry.map((item) => _normalize(item.name)).toSet();

    final matches = recipes
        .map((recipe) {
          final total = recipe.ingredients.length;
          final available = recipe.ingredients
              .where(
                (ingredient) =>
                    pantryNormalized.contains(_normalize(ingredient.name)),
              )
              .length;
          final percent = total == 0 ? 0.0 : available / total;
          return _RecipeMatch(recipe: recipe, matchPercent: percent);
        })
        .where((match) => match.matchPercent >= 0.6)
        .toList()
      ..sort((a, b) => b.matchPercent.compareTo(a.matchPercent));

    return matches.take(limit).map((match) => match.recipe).toList();
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _RecipeMatch {
  const _RecipeMatch({
    required this.recipe,
    required this.matchPercent,
  });

  final RecipeDetail recipe;
  final double matchPercent;
}
