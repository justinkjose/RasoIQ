import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const dailyGroceryReminderEnabledKey = 'daily_grocery_reminder_enabled';
  static const pantryExpiryAlertsEnabledKey = 'pantry_expiry_alerts_enabled';

  Future<bool> getDailyGroceryReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(dailyGroceryReminderEnabledKey) ?? true;
  }

  Future<bool> getPantryExpiryAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(pantryExpiryAlertsEnabledKey) ?? true;
  }

  Future<void> setDailyGroceryReminderEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(dailyGroceryReminderEnabledKey, value);
  }

  Future<void> setPantryExpiryAlertsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(pantryExpiryAlertsEnabledKey, value);
  }
}
