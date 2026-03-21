class RecipeMeta {
  final String id;
  final String name;
  final String image;
  final String description;
  final int cookTimeMinutes;
  final double trendingScore;
  final List<String> ingredients;

  const RecipeMeta({
    required this.id,
    required this.name,
    required this.image,
    required this.description,
    required this.cookTimeMinutes,
    required this.trendingScore,
    required this.ingredients,
  });

  factory RecipeMeta.fromJson(Map<String, dynamic> json) {
    return RecipeMeta(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Recipe',
      image: json['image']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      cookTimeMinutes: (json['cookTimeMinutes'] as num?)?.toInt() ?? 0,
      trendingScore: (json['trendingScore'] as num?)?.toDouble() ?? 0.0,
      ingredients: (json['ingredients'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image': image,
      'description': description,
      'cookTimeMinutes': cookTimeMinutes,
      'trendingScore': trendingScore,
      'ingredients': ingredients,
    };
  }
}
