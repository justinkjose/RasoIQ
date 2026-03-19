import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'app/grocery_app.dart';
import 'features/grocery/providers/grocery_provider.dart';
import 'features/pantry/providers/kitchen_stock_provider.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final provider = ThemeProvider();
            provider.load();
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = GroceryProvider();
            provider.load();
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = KitchenStockProvider();
            provider.load();
            return provider;
          },
        ),
      ],
      child: const GroceryApp(),
    ),
  );
}
