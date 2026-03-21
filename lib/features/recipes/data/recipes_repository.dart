import '../domain/recipe_detail.dart';
import '../domain/recipe_list_item.dart';
import '../domain/recipe_meta.dart';
import 'recipes_firestore_service.dart';
import 'recipes_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../services/analytics_service.dart';

class RecipesRepository {
  RecipesRepository({
    RecipesStorage? storage,
    RecipesFirestoreService? firestoreService,
  })  : _storage = storage ?? RecipesStorage(),
        _firestoreService = firestoreService ?? RecipesFirestoreService();

  final RecipesStorage _storage;
  final RecipesFirestoreService _firestoreService;

  static const Duration _metaCacheTtl = Duration(hours: 12);

  Future<List<RecipeMeta>> loadRecipeMeta({bool forceRefresh = false}) async {
    final local = await _storage.loadMeta();
    if (!forceRefresh && await _shouldUseCache()) {
      return local;
    }
    final online = await _isOnline();
    if (!online) return local;
    try {
      final remote = await _firestoreService.fetchRecipeMeta();
      if (remote.isNotEmpty) {
        await _storage.saveMeta(remote);
        await _storage.saveMetaLastFetch(DateTime.now());
        return remote;
      }
      return local;
    } catch (_) {
      return local;
    }
  }

  Future<RecipeDetail?> loadRecipeDetail(String id) async {
    final cache = await _storage.loadDetails();
    final cached = cache[id];
    if (cached != null) return cached;
    final online = await _isOnline();
    if (!online) return cached;
    try {
      final remote = await _firestoreService.fetchRecipeDetail(id);
      if (remote == null) return cached;
      cache[id] = remote;
      await _storage.saveDetails(cache);
      return remote;
    } catch (_) {
      return cached;
    }
  }

  Future<Set<String>> loadDownloadedIds() async {
    return _storage.loadDownloadedIds();
  }

  Future<void> downloadRecipe(RecipeDetail recipe) async {
    final cache = await _storage.loadDetails();
    cache[recipe.id] = recipe;
    await _storage.saveDetails(cache);
    final downloaded = await _storage.loadDownloadedIds();
    downloaded.add(recipe.id);
    await _storage.saveDownloadedIds(downloaded);
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

  Future<void> recordRecipeOpened(String recipeId) async {
    await AnalyticsService.instance.logRecipeOpened(recipeId);
    await _firestoreService.bumpTrendingScore(recipeId, 1);
  }

  Future<void> recordRecipeShared(String recipeId) async {
    await AnalyticsService.instance.logRecipeShared(recipeId);
    await _firestoreService.bumpTrendingScore(recipeId, 2);
  }

  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    if (results.isEmpty) return false;
    return !results.contains(ConnectivityResult.none);
  }

  Future<bool> _shouldUseCache() async {
    final last = await _storage.loadMetaLastFetch();
    if (last == null) return false;
    return DateTime.now().difference(last) < _metaCacheTtl;
  }
}
