import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_widgets.dart';
import '../domain/recipe_detail.dart';

class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    required this.onAddMissing,
  });

  final RecipeDetail recipe;
  final VoidCallback onAddMissing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 260,
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroImage(image: recipe.image),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.space24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.translate(
                    offset: const Offset(0, -24),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(recipe.name, style: AppTextStyles.headingLarge),
                          const SizedBox(height: AppTheme.space12),
                          Text(recipe.description, style: AppTextStyles.bodyLarge),
                          const SizedBox(height: AppTheme.space12),
                          Row(
                            children: [
                              const Icon(Icons.schedule, size: 18),
                              const SizedBox(width: AppTheme.space8),
                              Text(
                                '${recipe.cookTimeMinutes} min',
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space8),
                  const SizedBox(height: AppTheme.space24),
                  const SectionHeader(title: 'Ingredients'),
                  const SizedBox(height: AppTheme.space12),
                  AppCard(
                    child: Column(
                      children: recipe.ingredients.map((ingredient) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.space8,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusSmall),
                                ),
                                child: Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: AppTheme.space12),
                              Expanded(
                                child: Text(
                                  ingredient.name,
                                  style: AppTextStyles.bodyLarge,
                                ),
                              ),
                              Text(
                                '${ingredient.quantity} ${ingredient.unit}',
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space24),
                  const SectionHeader(title: 'Steps'),
                  const SizedBox(height: AppTheme.space12),
                  ...recipe.steps.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: AppTheme.space12),
                          child: AppCard(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondary
                                        .withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSmall,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${entry.key + 1}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Theme.of(context).colorScheme.secondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppTheme.space12),
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: AppTextStyles.bodyLarge,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  const SizedBox(height: AppTheme.space24),
                  const SectionHeader(title: 'Nutrition'),
                  const SizedBox(height: AppTheme.space12),
                  Wrap(
                    spacing: AppTheme.space12,
                    runSpacing: AppTheme.space12,
                    children: [
                      _NutritionChip(
                        label: 'Calories',
                        value: '${recipe.nutrition.calories} kcal',
                      ),
                      _NutritionChip(
                        label: 'Protein',
                        value: '${recipe.nutrition.protein} g',
                      ),
                      _NutritionChip(
                        label: 'Carbs',
                        value: '${recipe.nutrition.carbs} g',
                      ),
                      _NutritionChip(
                        label: 'Fat',
                        value: '${recipe.nutrition.fat} g',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space32),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onAddMissing,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Add Missing Ingredients'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.image});

  final String image;

  @override
  Widget build(BuildContext context) {
    if (image.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: const Center(
          child: Icon(Icons.restaurant_menu, size: 64),
        ),
      );
    }

    final Widget content = image.startsWith('http')
        ? Image.network(image, fit: BoxFit.cover)
        : Image.asset(image, fit: BoxFit.cover);

    return SizedBox(height: 260, child: content);
  }
}

class _NutritionChip extends StatelessWidget {
  const _NutritionChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.bodySmall),
          const SizedBox(height: AppTheme.space4),
          Text(value, style: AppTextStyles.bodyLarge),
        ],
      ),
    );
  }
}
