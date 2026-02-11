import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bolo_debate/core/theme/app_theme.dart';
import 'package:bolo_debate/shared/widgets/page_header.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      body: ListView(
        children: [
          // Header banner (replaces AppBar)
          PageHeaders.settings(
            onBack: () => Navigator.of(context).pop(),
          ),

          _SectionHeader(title: 'Appearance'),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Theme'),
            subtitle: Text(_getThemeLabel(themeMode)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showThemePicker(context, ref, themeMode),
          ),

          _SectionHeader(title: 'Notifications'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text('Push Notifications'),
            subtitle: const Text('Get notified when rooms go live'),
            value: true,
            onChanged: (value) {
              // TODO: Handle notification toggle
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.mail),
            title: const Text('Friend Requests'),
            subtitle: const Text('Notify me of new friend requests'),
            value: true,
            onChanged: (value) {
              // TODO: Handle friend request notifications
            },
          ),

          _SectionHeader(title: 'Privacy'),
          ListTile(
            leading: const Icon(Icons.visibility),
            title: const Text('Profile Visibility'),
            subtitle: const Text('Who can see your profile'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Profile visibility settings
            },
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Blocked Users'),
            subtitle: const Text('Manage blocked users'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Blocked users
            },
          ),

          _SectionHeader(title: 'Data'),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export Data'),
            subtitle: const Text('Download your data'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Export data
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.error),
            title: const Text('Delete Account', style: TextStyle(color: AppColors.error)),
            subtitle: const Text('Permanently delete your account'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showDeleteAccountDialog(context),
          ),

          _SectionHeader(title: 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () {
              // TODO: Open terms
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () {
              // TODO: Open privacy policy
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System default';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  void _showThemePicker(BuildContext context, WidgetRef ref, ThemeMode current) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.settings_suggest),
                title: const Text('System default'),
                trailing: current == ThemeMode.system ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  ref.read(themeModeProvider.notifier).setTheme(ThemeMode.system);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.light_mode),
                title: const Text('Light'),
                trailing: current == ThemeMode.light ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  ref.read(themeModeProvider.notifier).setTheme(ThemeMode.light);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: const Text('Dark'),
                trailing: current == ThemeMode.dark ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  ref.read(themeModeProvider.notifier).setTheme(ThemeMode.dark);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This action cannot be undone. All your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              // TODO: Delete account
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
