class PantryInsights {
  PantryInsights({
    required this.expiringSoonCount,
    required this.lowStockCount,
    required this.missingStaplesCount,
    required this.mostStockedCategory,
    required this.mostUsedItem,
    required this.wasteCount,
    required this.healthScore,
  });

  final int expiringSoonCount;
  final int lowStockCount;
  final int missingStaplesCount;
  final String mostStockedCategory;
  final String mostUsedItem;
  final int wasteCount;
  final int healthScore;
}
