import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import 'package:rasoiq/services/notification_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'custom_category_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SettingsService _settingsService = SettingsService();
  bool _dailyReminder = true;
  bool _expiryAlerts = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final daily = await _settingsService.getDailyGroceryReminderEnabled();
    final expiry = await _settingsService.getPantryExpiryAlertsEnabled();
    if (!mounted) return;
    setState(() {
      _dailyReminder = daily;
      _expiryAlerts = expiry;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', style: AppTextStyles.headingMedium),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.space24),
        children: [
          const _UserCard(
            name: 'RasoIQ User',
            subtitle: 'Kitchen Manager',
          ),
          const SizedBox(height: AppTheme.space24),
          const SectionHeader(title: 'Custom Categories'),
          const SizedBox(height: AppTheme.space12),
          _CardListTile(
            title: 'Manage custom categories',
            icon: Icons.category_outlined,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CustomCategoryScreen()),
              );
            },
          ),
          const SizedBox(height: AppTheme.space12),
          _CardListTile(
            title: 'Change category images',
            icon: Icons.image_outlined,
            onTap: () {},
          ),
          const SizedBox(height: AppTheme.space24),
          const SectionHeader(title: 'Notification Settings'),
          const SizedBox(height: AppTheme.space12),
          _SwitchCardTile(
            title: 'Daily Grocery Reminder',
            subtitle: '7:00 PM daily',
            value: _dailyReminder,
            onChanged: (value) async {
              setState(() => _dailyReminder = value);
              await _settingsService.setDailyGroceryReminderEnabled(value);
              await NotificationService.instance.syncSchedules();
            },
          ),
          const SizedBox(height: AppTheme.space12),
          _SwitchCardTile(
            title: 'Expiry Alerts',
            subtitle: 'Alert when items expire within 2 days',
            value: _expiryAlerts,
            onChanged: (value) async {
              setState(() => _expiryAlerts = value);
              await _settingsService.setPantryExpiryAlertsEnabled(value);
              if (value) {
                await NotificationService.instance.checkPantryExpiryAlerts();
              }
            },
          ),
          const SizedBox(height: AppTheme.space24),
          const SectionHeader(title: 'Theme Settings'),
          const SizedBox(height: AppTheme.space12),
          AppCard(
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ],
              selected: {themeProvider.mode},
              onSelectionChanged: (value) {
                if (value.isEmpty) return;
                themeProvider.setThemeMode(value.first);
              },
              style: ButtonStyle(
                textStyle: WidgetStatePropertyAll(AppTextStyles.bodySmall),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space24),
          const SectionHeader(title: 'Testing'),
          const SizedBox(height: AppTheme.space12),
          AppCard(
            child: Row(
              children: [
                Icon(
                  Icons.notifications_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: Text(
                    'Send test notification',
                    style: AppTextStyles.bodyLarge,
                  ),
                ),
                RoundedButton(
                  label: 'Send',
                  onPressed: () {
                    NotificationService.showTestNotification();
                  },
                  fullWidth: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space32),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.name, required this.subtitle});

  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            child: Icon(
              Icons.person_outline,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: AppTheme.space16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppTextStyles.headingMedium),
              const SizedBox(height: AppTheme.space4),
              Text(subtitle, style: AppTextStyles.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardListTile extends StatelessWidget {
  const _CardListTile({
    required this.title,
    required this.icon,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = AppCard(
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Text(title, style: AppTextStyles.bodyLarge),
          ),
          Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: card,
    );
  }
}

class _SwitchCardTile extends StatelessWidget {
  const _SwitchCardTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyLarge),
                const SizedBox(height: AppTheme.space4),
                Text(subtitle, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
