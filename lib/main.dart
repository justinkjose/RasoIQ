import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'app/grocery_app.dart';
import 'features/grocery/data/hive/grocery_hive_adapters.dart';
import 'features/grocery/providers/grocery_provider.dart';
import 'features/pantry/providers/kitchen_stock_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/theme_provider.dart';
import 'services/analytics_service.dart';
import 'services/background_sync_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

final BackgroundSyncService _backgroundSyncService = BackgroundSyncService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };

  developer.log('Init: Firebase', name: 'startup');
  await Firebase.initializeApp();
  developer.log('Init: Hive', name: 'startup');
  await Hive.initFlutter();
  Hive.registerAdapter(ShoppingListAdapter());
  Hive.registerAdapter(GroceryItemAdapter());

  developer.log('Init: runApp', name: 'startup');
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
            final provider = ConnectivityProvider();
            provider.start();
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<ConnectivityProvider, GroceryProvider>(
          create: (_) => GroceryProvider(),
          update: (_, connectivity, grocery) {
            grocery ??= GroceryProvider();
            grocery.bindConnectivity(connectivity);
            grocery.ensureInitialized();
            return grocery;
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

  unawaited(_bootstrapAsync());
}

Future<void> _bootstrapAsync() async {
  try {
    developer.log('Init: Auth', name: 'startup');
    await AuthService.instance.init();
    await AnalyticsService.instance.logAppOpen();
    developer.log('Init: Notifications', name: 'startup');
    await NotificationService.instance.init(
      topic: AuthService.instance.userId,
    );
    developer.log('Init: Background sync', name: 'startup');
    _backgroundSyncService.start();
  } catch (e) {
    developer.log('Init: background bootstrap failed: $e', name: 'startup');
  }
}
