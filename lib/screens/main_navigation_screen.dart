import 'package:flutter/material.dart';

import '../features/grocery/presentation/grocery_lists_screen.dart';
import '../features/pantry/presentation/kitchen_stock_screen.dart';
import '../features/recipes/presentation/recipes_screen.dart';
import '../profile/profile_screen.dart';
import '../theme/app_theme.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final _navigatorKeys = List.generate(
    4,
    (_) => GlobalKey<NavigatorState>(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PopScope(
        canPop: !(_navigatorKeys[_currentIndex].currentState?.canPop() ?? false),
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          final navigator = _navigatorKeys[_currentIndex].currentState;
          if (navigator != null && navigator.canPop()) {
            navigator.pop();
          }
        },
        child: Stack(
          children: List.generate(4, (index) => _buildOffstageNavigator(index)),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(AppTheme.space16),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color ?? AppTheme.card,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: AppTheme.shadowOpacity),
                blurRadius: AppTheme.shadowBlur,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space8),
          child: NavigationBar(
            height: 64,
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.shopping_basket_outlined),
                selectedIcon: Icon(Icons.shopping_basket),
                label: 'Bazaar',
              ),
              NavigationDestination(
                icon: Icon(Icons.kitchen_outlined),
                selectedIcon: Icon(Icons.kitchen),
                label: 'Kitchen',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: 'Recipes',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOffstageNavigator(int index) {
    return Offstage(
      offstage: _currentIndex != index,
      child: Navigator(
        key: _navigatorKeys[index],
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (_) => _buildRootScreen(index),
          );
        },
      ),
    );
  }

  Widget _buildRootScreen(int index) {
    switch (index) {
      case 0:
        return const GroceryListsScreen();
      case 1:
        return const KitchenStockScreen();
      case 2:
        return const RecipesScreen();
      case 3:
      default:
        return const ProfileScreen();
    }
  }
}

