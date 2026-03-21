import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  Future<void> logAppOpen() => _analytics.logAppOpen();

  Future<void> logListCreated(String listId) => _analytics.logEvent(
        name: 'list_created',
        parameters: {'listId': listId},
      );

  Future<void> logItemAdded(String listId, String itemId) => _analytics.logEvent(
        name: 'item_added',
        parameters: {'listId': listId, 'itemId': itemId},
      );

  Future<void> logListShared(String listId) => _analytics.logEvent(
        name: 'list_shared',
        parameters: {'listId': listId},
      );

  Future<void> logRecipeOpened(String recipeId) => _analytics.logEvent(
        name: 'recipe_opened',
        parameters: {'recipeId': recipeId},
      );

  Future<void> logRecipeShared(String recipeId) => _analytics.logEvent(
        name: 'recipe_shared',
        parameters: {'recipeId': recipeId},
      );
}
