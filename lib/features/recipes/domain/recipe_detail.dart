import 'recipe_ingredient.dart';
import 'recipe_nutrition.dart';

class RecipeDetail {
  final String id;
  final String name;
  final String image;
  final String description;
  final int cookTimeMinutes;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final RecipeNutrition nutrition;

  const RecipeDetail({
    required this.id,
    required this.name,
    required this.image,
    required this.description,
    required this.cookTimeMinutes,
    required this.ingredients,
    required this.steps,
    required this.nutrition,
  });

  factory RecipeDetail.fromJson(Map<String, dynamic> json) {
    return RecipeDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      image: json['image'] as String,
      description: json['description'] as String,
      cookTimeMinutes: (json['cookTimeMinutes'] as num?)?.toInt() ?? 0,
      ingredients: (json['ingredients'] as List<dynamic>)
          .map((item) => RecipeIngredient.fromJson(item as Map<String, dynamic>))
          .toList(),
      steps: (json['steps'] as List<dynamic>).map((step) => step.toString()).toList(),
      nutrition: RecipeNutrition.fromJson(json['nutrition'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image': image,
      'description': description,
      'cookTimeMinutes': cookTimeMinutes,
      'ingredients': ingredients.map((item) => item.toJson()).toList(),
      'steps': steps,
      'nutrition': nutrition.toJson(),
    };
  }
}
