import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../screens/main_navigation_screen.dart';
import '../theme/app_theme.dart';
import '../features/grocery/data/grocery_repository.dart';
import '../features/grocery/presentation/shopping_list_detail_screen.dart';
import '../features/recipes/data/recipes_repository.dart';
import '../features/recipes/presentation/recipe_detail_screen.dart';
import '../features/pantry/services/pantry_service.dart';
import '../services/deep_link_service.dart';

class GroceryApp extends StatefulWidget {
  const GroceryApp({super.key});

  @override
  State<GroceryApp> createState() => _GroceryAppState();
}

class _GroceryAppState extends State<GroceryApp> {
  final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final GroceryRepository _repository = GroceryRepository();
  final RecipesRepository _recipesRepository = RecipesRepository();
  final PantryService _pantryService = PantryService();
  late final DeepLinkService _deepLinkService;

  @override
  void initState() {
    super.initState();
    _deepLinkService = DeepLinkService(onLink: _handleLink);
    unawaited(_deepLinkService.start());
  }

  Future<void> _handleLink(Uri link) async {
    if (link.scheme != 'https' || link.host != 'rasoiq.app') {
      return;
    }
    if (link.path.startsWith('/recipe')) {
      final recipeId = link.queryParameters['recipeId'];
      if (recipeId == null || recipeId.trim().isEmpty) {
        _messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Invalid recipe link.')),
        );
        return;
      }
      final detail = await _recipesRepository.loadRecipeDetail(recipeId);
      if (detail == null) {
        _messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Recipe not found.')),
        );
        return;
      }
      final available = await _loadAvailableIngredients();
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => RecipeDetailScreen(
            recipe: detail,
            availableIngredients: available,
            onAddMissing: () {},
          ),
        ),
      );
      return;
    }

    if (link.path.startsWith('/list')) {
      final listId = link.queryParameters['listId'];
      if (listId == null || listId.trim().isEmpty) {
        _messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Invalid grocery list link.')),
        );
        return;
      }
      try {
        final resolvedId = await _repository.joinListByCode(listId);
        if (resolvedId == null || resolvedId.isEmpty) {
          throw StateError('Missing list');
        }
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ShoppingListDetailScreen(listId: resolvedId),
          ),
        );
        return;
      } catch (_) {
        _messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Unable to open shared list.')),
        );
        return;
      }
    }
  }

  Future<Set<String>> _loadAvailableIngredients() async {
    final pantry = await _pantryService.getItems();
    final groceries = await _repository.getAllItems();
    final pantryNormalized =
        pantry.map((item) => item.normalizedName).toSet();
    final groceryAvailable = groceries
        .where((item) => item.isDone && !item.isUnavailable)
        .map((item) => item.normalizedName);
    return {...pantryNormalized, ...groceryAvailable};
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'RasoIQ',
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.mode,
      home: const MainNavigationScreen(),
    );
  }

  @override
  void dispose() {
    unawaited(_deepLinkService.dispose());
    super.dispose();
  }
}
