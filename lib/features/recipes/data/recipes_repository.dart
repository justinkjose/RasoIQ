import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/recipe_detail.dart';
import '../domain/recipe_list_item.dart';

class RecipesRepository {
  Future<List<RecipeDetail>> loadRecipes() async {
    final raw = await rootBundle.loadString('assets/recipes.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = decoded['recipes'] as List<dynamic>;
    return list
        .map((item) => RecipeDetail.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  List<RecipeListItem> toListItems(List<RecipeDetail> recipes) {
    return recipes
        .map(
          (recipe) => RecipeListItem(
            id: recipe.id,
            name: recipe.name,
            image: recipe.image,
            description: recipe.description,
            cookTimeMinutes: recipe.cookTimeMinutes,
          ),
        )
        .toList();
  }
}
