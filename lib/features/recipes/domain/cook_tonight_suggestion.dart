class CookTonightSuggestion {
  final String recipeName;
  final double matchPercent;
  final List<String> missingIngredients;

  CookTonightSuggestion({
    required this.recipeName,
    required this.matchPercent,
    required this.missingIngredients,
  });
}
