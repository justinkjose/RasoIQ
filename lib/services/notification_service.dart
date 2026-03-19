import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

import '../features/pantry/services/pantry_service.dart';
import '../features/recipes/services/cook_tonight_service.dart';
import 'settings_service.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'rasoiq_reminders';
  static const _channelName = 'RasoIQ Reminders';
  static const _channelDescription = 'Reminders and pantry alerts';

  static const _dailyReminderId = 1001;
  static const _cookTonightId = 1002;
  static const _expiryAlertLogKey = 'pantry_expiry_alerts_log';

  final SettingsService _settingsService = SettingsService();
  final PantryService _pantryService = PantryService();
  final CookTonightService _cookTonightService = CookTonightService();

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(settings: settings);
    tz.initializeTimeZones();
  }

  Future<void> initInstance() async {
    await NotificationService.init();
  }

  static Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'rasoiq_channel',
      'RasoIQ Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      id: 0,
      title: 'RasoIQ Test Notification',
      body: 'Notifications are working correctly',
      notificationDetails: details,
    );
  }

  Future<void> syncSchedules() async {
    final reminderEnabled = await _settingsService.getDailyGroceryReminderEnabled();
    if (reminderEnabled) {
      await _scheduleDailyReminder();
    } else {
      await _notifications.cancel(id: _dailyReminderId);
    }

    await _scheduleCookTonight();
  }

  Future<void> _scheduleDailyReminder() async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 19);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _scheduleSafely(
      id: _dailyReminderId,
      title: 'Grocery check-in',
      body: 'Review your lists and pantry before shopping.',
      scheduled: scheduled,
      importance: Importance.high,
      priority: Priority.high,
    );
  }

  Future<void> _scheduleCookTonight() async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 18);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _scheduleSafely(
      id: _cookTonightId,
      title: 'Cook Tonight',
      body: await _cookTonightBody(),
      scheduled: scheduled,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
  }

  Future<String> _cookTonightBody() async {
    final suggestion = await _cookTonightService.getTopSuggestion();
    if (suggestion == null) {
      return 'Check your pantry for a recipe to cook tonight.';
    }
    return 'Cook ${suggestion.recipeName} tonight - ${(suggestion.matchPercent * 100).toStringAsFixed(0)}% ingredients available.';
  }

  Future<void> checkPantryExpiryAlerts() async {
    final enabled = await _settingsService.getPantryExpiryAlertsEnabled();
    if (!enabled) return;

    final items = await _pantryService.getItems();
    final now = DateTime.now();
    final threshold = now.add(const Duration(days: 2));
    final prefs = await SharedPreferences.getInstance();
    final log = prefs.getString(_expiryAlertLogKey) ?? '{}';
    final Map<String, dynamic> decoded = log == '{}' ? {} : _decodeMap(log);
    final todayKey = _dateKey(now);

    for (final item in items) {
      final expiryDate = item.expiryDate;
      final expiring = expiryDate != null && !expiryDate.isAfter(threshold);
      if (!expiring) continue;

      final lastAlert = decoded[item.id]?.toString();
      if (lastAlert == todayKey) continue;

      await _notifications.show(
        id: item.id.hashCode,
        title: 'Expiry alert',
        body: '${item.name} is expiring soon.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
      decoded[item.id] = todayKey;
    }

    await prefs.setString(_expiryAlertLogKey, _encodeMap(decoded));
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _decodeMap(String raw) {
    return raw.isEmpty ? {} : Map<String, dynamic>.from(_jsonDecode(raw));
  }

  String _encodeMap(Map<String, dynamic> value) {
    return _jsonEncode(value);
  }

  dynamic _jsonDecode(String raw) {
    return raw.isEmpty ? {} : jsonDecode(raw);
  }

  String _jsonEncode(Object value) => jsonEncode(value);

  Future<void> _scheduleSafely({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduled,
    required Importance importance,
    required Priority priority,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: importance,
        priority: priority,
      ),
    );

    try {
      await _notifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } on PlatformException catch (error) {
      if (error.code != 'exact_alarms_not_permitted') rethrow;
      await _notifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }
}

