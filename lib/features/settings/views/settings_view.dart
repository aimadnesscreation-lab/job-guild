import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';

/// Settings screen — language, notification preferences, service radius,
/// account, verification, logout, report/block management, delete account.
class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  bool _notificationsEnabled = true;
  bool _jobAlertsEnabled = true;
  bool _messageAlertsEnabled = true;
  String _selectedLanguage = 'English';
  double _serviceRadius = 15;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ─── Account ──────────────────────────────────
          _SectionHeader(title: 'Account'),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: const Icon(Icons.person_rounded,
                  color: AppTheme.primaryColor),
            ),
            title: const Text('Ahmed Khan'),
            subtitle: const Text('+92 300 1234567'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {},
          ),
          const Divider(height: 1),

          // ─── Verification ─────────────────────────────
          _SectionHeader(title: 'Verification'),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.verifiedBadge.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.verified_rounded,
                  color: AppTheme.verifiedBadge),
            ),
            title: const Text('ID Verification'),
            subtitle: const Text('Verify your identity to earn a trusted badge'),
            trailing: TextButton(
              onPressed: () {},
              child: const Text('Verify Now'),
            ),
          ),
          const Divider(height: 1),

          // ─── Language ─────────────────────────────────
          _SectionHeader(title: 'App Language'),
          ListTile(
            leading: const Icon(Icons.language_rounded,
                color: AppTheme.textSecondary),
            title: const Text('Language'),
            trailing: DropdownButton<String>(
              value: _selectedLanguage,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'English', child: Text('English 🇬🇧')),
                DropdownMenuItem(value: 'Urdu', child: Text('اردو 🇵🇰')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedLanguage = val);
                }
              },
            ),
          ),
          const Divider(height: 1),

          // ─── Notifications ────────────────────────────
          _SectionHeader(title: 'Notifications'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_rounded,
                color: AppTheme.textSecondary),
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive alerts about jobs and messages'),
            value: _notificationsEnabled,
            onChanged: (val) =>
                setState(() => _notificationsEnabled = val),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.work_outline,
                color: AppTheme.textSecondary),
            title: const Text('Job Alerts'),
            subtitle: const Text('New job matches in your area'),
            value: _jobAlertsEnabled,
            onChanged: (val) => setState(() => _jobAlertsEnabled = val),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.chat_outlined,
                color: AppTheme.textSecondary),
            title: const Text('Message Alerts'),
            subtitle: const Text('New messages from employers/workers'),
            value: _messageAlertsEnabled,
            onChanged: (val) =>
                setState(() => _messageAlertsEnabled = val),
          ),
          const Divider(height: 1),

          // ─── Service Radius ───────────────────────────
          _SectionHeader(title: 'Service Area'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.near_me_rounded,
                        size: 18, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Service Radius: ${_serviceRadius.toInt()} km',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Slider(
                  value: _serviceRadius,
                  min: 1,
                  max: 50,
                  divisions: 49,
                  label: '${_serviceRadius.toInt()} km',
                  onChanged: (val) =>
                      setState(() => _serviceRadius = val),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ─── Support ──────────────────────────────────
          _SectionHeader(title: 'Support'),
          ListTile(
            leading: const Icon(Icons.help_outline,
                color: AppTheme.textSecondary),
            title: const Text('Help Center'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined,
                color: AppTheme.textSecondary),
            title: const Text('Report a Problem'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {},
          ),
          const Divider(height: 1),

          // ─── Account Actions ──────────────────────────────────
          _SectionHeader(title: 'Account'),
          ListTile(
            leading: const Icon(Icons.logout_rounded,
                color: AppTheme.errorColor),
            title: const Text('Log Out',
                style: TextStyle(color: AppTheme.errorColor)),
            onTap: () => _showConfirmDialog(
              context,
              'Log Out',
              'Are you sure you want to log out?',
              () async {
                await ref.read(authProvider.notifier).signOut();
                if (mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_rounded,
                color: AppTheme.errorColor),
            title: const Text('Delete Account',
                style: TextStyle(color: AppTheme.errorColor)),
            subtitle: const Text('This action cannot be undone'),
            onTap: () => _showConfirmDialog(
              context,
              'Delete Account',
              'This will permanently delete your account and all data. '
                  'This action cannot be undone. Are you sure?',
              () {
                // TODO: Implement account deletion
              },
              isDestructive: true,
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Version 1.0.0',
              style: TextStyle(
                color: AppTheme.textDisabled,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showConfirmDialog(
    BuildContext context,
    String title,
    String message,
    VoidCallback onConfirm, {
    bool isDestructive = false,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: AppTheme.errorColor)
                : null,
            child: Text(title),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
