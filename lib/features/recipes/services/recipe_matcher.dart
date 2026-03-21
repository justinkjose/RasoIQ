import '../domain/recipe_meta.dart';

class RecipeMatcher {
  const RecipeMatcher();

  List<RecipeMatch> matchRecipes({
    required List<RecipeMeta> recipes,
    required Set<String> available,
    int minMatches = 1,
  }) {
    final results = <RecipeMatch>[];
    for (final recipe in recipes) {
      final ingredients = recipe.ingredients;
      if (ingredients.isEmpty) continue;
      final total = ingredients.length;
      var matched = 0;
      for (final ingredient in ingredients) {
        if (available.contains(_normalize(ingredient))) {
          matched += 1;
        }
      }
      if (matched < minMatches) continue;
      results.add(
        RecipeMatch(
          recipe: recipe,
          matched: matched,
          total: total,
        ),
      );
    }
    results.sort((a, b) => b.matchPercent.compareTo(a.matchPercent));
    return results;
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\\s]'), ' ')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
  }
}

class RecipeMatch {
  const RecipeMatch({
    required this.recipe,
    required this.matched,
    required this.total,
  });

  final RecipeMeta recipe;
  final int matched;
  final int total;

  double get matchPercent => total == 0 ? 0 : matched / total;
}
