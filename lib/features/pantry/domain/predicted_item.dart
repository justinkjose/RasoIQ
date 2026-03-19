class PredictedItem {
  const PredictedItem({
    required this.name,
    required this.confidenceScore,
    required this.category,
  });

  final String name;
  final double confidenceScore;
  final String category;
}
