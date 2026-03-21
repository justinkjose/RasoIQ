import 'package:flutter/material.dart';

import '../../grocery/data/grocery_repository.dart';
import '../../pantry/services/pantry_service.dart';
import '../data/recipes_repository.dart';
import '../domain/recipe_meta.dart';
import '../services/recipe_matcher.dart';
import '../../../theme/app_theme.dart';

class CookWithWhatYouHaveScreen extends StatefulWidget {
  const CookWithWhatYouHaveScreen({super.key});

  @override
  State<CookWithWhatYouHaveScreen> createState() =>
      _CookWithWhatYouHaveScreenState();
}

class _CookWithWhatYouHaveScreenState
    extends State<CookWithWhatYouHaveScreen> {
  final RecipesRepository _recipesRepository = RecipesRepository();
  final PantryService _pantryService = PantryService();
  final GroceryRepository _groceryRepository = GroceryRepository();
  final RecipeMatcher _matcher = const RecipeMatcher();
  final TextEditingController _inputController = TextEditingController();

  bool _loading = true;
  List<RecipeMeta> _recipes = [];
  List<_ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final recipes = await _recipesRepository.loadRecipeMeta();
    if (!mounted) return;
    setState(() {
      _recipes = recipes;
      _loading = false;
    });
  }

  Future<void> _generateSuggestions(String input) async {
    setState(() {
      _messages = [
        ..._messages,
        _ChatMessage(role: _ChatRole.user, text: input),
      ];
    });

    final pantry = await _pantryService.getItems();
    final groceries = await _groceryRepository.getAllItems();
    final available = <String>{
      ...pantry.map((item) => item.normalizedName),
      ...groceries
          .where((item) => item.isDone && !item.isUnavailable)
          .map((item) => item.normalizedName),
      ..._parseInput(input),
    };
    final matches = _matcher.matchRecipes(
      recipes: _recipes,
      available: available,
      minMatches: 1,
    );
    final top = matches.take(8).toList();

    final response = top.isEmpty
        ? 'I could not find a good match yet. Try adding more pantry items.'
        : top
            .map(
              (match) =>
                  '${match.recipe.name} • ${(match.matchPercent * 100).round()}% match',
            )
            .join('\n');

    setState(() {
      _messages = [
        ..._messages,
        _ChatMessage(role: _ChatRole.assistant, text: response),
      ];
    });
  }

  Set<String> _parseInput(String input) {
    return input
        .split(',')
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .map((item) => item
            .replaceAll(RegExp(r'[^a-z0-9\\s]'), ' ')
            .replaceAll(RegExp(r'\\s+'), ' ')
            .trim())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cook With What You Have'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(AppTheme.space16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message.role == _ChatRole.user;
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppTheme.space12),
                    padding: const EdgeInsets.all(AppTheme.space12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    child: Text(
                      message.text,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: isUser
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.space16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: const InputDecoration(
                      hintText: 'I have eggs, rice, onion...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                FilledButton(
                  onPressed: () {
                    final text = _inputController.text.trim();
                    if (text.isEmpty) return;
                    _inputController.clear();
                    _generateSuggestions(text);
                  },
                  child: const Text('Ask'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _ChatRole { user, assistant }

class _ChatMessage {
  const _ChatMessage({required this.role, required this.text});

  final _ChatRole role;
  final String text;
}
