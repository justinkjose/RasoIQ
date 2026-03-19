import '../../pantry/services/pantry_service.dart';
import '../../pantry/domain/pantry_item.dart';
import '../data/recipes_repository.dart';
import '../domain/cook_tonight_suggestion.dart';
import '../domain/recipe_detail.dart';

class CookTonightService {
  CookTonightService({
    RecipesRepository? recipesRepository,
    PantryService? pantryService,
  })  : _recipesRepository = recipesRepository ?? RecipesRepository(),
        _pantryService = pantryService ?? PantryService();

  final RecipesRepository _recipesRepository;
  final PantryService _pantryService;

  Future<CookTonightSuggestion?> getTopSuggestion() async {
    final recipes = await _recipesRepository.loadRecipes();
    final pantry = await _pantryService.getItems();
    if (recipes.isEmpty || pantry.isEmpty) return null;

    final pantryNormalized = pantry.map((item) => _normalize(item.name)).toSet();
    final expiring = _expiringSoon(pantry);

    CookTonightSuggestion? best;
    double bestScore = 0;

    for (final recipe in recipes) {
      final total = recipe.ingredients.length;
      if (total == 0) continue;

      final availableIngredients = recipe.ingredients
          .where((ingredient) => pantryNormalized.contains(_normalize(ingredient.name)))
          .toList();
      final available = availableIngredients.length;
      final matchPercent = available / total;
      if (matchPercent < 0.6) continue;

      final missingIngredients = recipe.ingredients
          .where((ingredient) => !pantryNormalized.contains(_normalize(ingredient.name)))
          .map((ingredient) => ingredient.name)
          .toList();

      final expiringIngredient = _firstExpiringIngredient(recipe, expiring);
      var score = matchPercent;
      if (expiringIngredient != null) {
        score += 0.2;
      }

      if (score > bestScore) {
        bestScore = score;
        best = CookTonightSuggestion(
          recipeName: recipe.name,
          matchPercent: matchPercent,
          missingIngredients: missingIngredients,
        );
      }
    }

    return best;
  }

  Map<String, PantryItem> _expiringSoon(List<PantryItem> pantry) {
    final threshold = DateTime.now().add(const Duration(days: 2));
    final map = <String, PantryItem>{};
    for (final item in pantry) {
      final expiry = item.expiryDate;
      if (expiry != null && !expiry.isAfter(threshold)) {
        map[_normalize(item.name)] = item;
      }
    }
    return map;
  }

  String? _firstExpiringIngredient(
    RecipeDetail recipe,
    Map<String, PantryItem> expiring,
  ) {
    for (final ingredient in recipe.ingredients) {
      final key = _normalize(ingredient.name);
      if (expiring.containsKey(key)) {
        return ingredient.name;
      }
    }
    return null;
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
