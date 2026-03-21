import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../features/pantry/services/pantry_service.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final PantryService _pantryService = PantryService();
  bool _initialized = false;

  Future<void> init({String? topic}) async {
    if (_initialized) return;
    _initialized = true;

    await _messaging.requestPermission();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(settings: initSettings);

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _showLocal(
        title: notification.title ?? 'RasoiQ',
        body: notification.body ?? '',
      );
    });

    if (topic != null && topic.isNotEmpty) {
      await _messaging.subscribeToTopic(topic);
    }
  }

  Future<void> notifyItemAdded(String name) async {
    await _showLocal(title: 'Item added', body: '$name added to your list');
  }

  Future<void> notifyItemCompleted(String name) async {
    await _showLocal(title: 'Item completed', body: '$name marked as done');
  }

  Future<void> notifyListShared(String listName) async {
    await _showLocal(
      title: 'List shared',
      body: '$listName shared successfully',
    );
  }

  Future<void> syncSchedules() async {
    return;
  }

  Future<void> checkPantryExpiryAlerts() async {
    final items = await _pantryService.expiringSoon(days: 2);
    if (items.isEmpty) return;
    await _showLocal(
      title: 'Expiry alert',
      body: '${items.length} item(s) expiring soon',
    );
  }

  static Future<void> showTestNotification() async {
    await NotificationService.instance._showLocal(
      title: 'Test notification',
      body: 'Notifications are working.',
    );
  }

  Future<void> _showLocal({required String title, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      'rasoiq_general',
      'General',
      channelDescription: 'General notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
