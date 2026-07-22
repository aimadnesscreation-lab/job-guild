import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/core/services/supabase_repository.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';
import 'package:local_services_marketplace/features/settings/providers/settings_provider.dart';
import 'package:local_services_marketplace/features/settings/views/reports_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:local_services_marketplace/features/worker/providers/worker_provider.dart';
import 'package:local_services_marketplace/features/worker/views/id_verification_view.dart';

/// Settings screen — language, notification preferences, service radius,
/// account, verification, logout, report/block management, delete account.
/// All settings are persisted to the `users` table in Supabase.
class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final settings = state.settings;
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(ref.watch(appStringsProvider).settings)),
      body: ListView(
        children: [
          // ─── Account ──────────────────────────────────
          _SectionHeader(title: ref.watch(appStringsProvider).account),
          _AccountHeader(),
          const Divider(height: 1),

          // ─── Verification ─────────────────────────────
          _SectionHeader(title: ref.watch(appStringsProvider).verification),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.verifiedBadge.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: AppTheme.verifiedBadge,
              ),
            ),
            title: Text(s.verification),
            subtitle: Text(s.verifyIdentityBadge),
            trailing: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const IdVerificationView(),
                ),
              ),
              child: Text(s.verifyNow),
            ),
          ),
          const Divider(height: 1),

          // ─── Language ─────────────────────────────────
          _SectionHeader(title: ref.watch(appStringsProvider).appLanguage),
          ListTile(
            leading: const Icon(
              Icons.language_rounded,
              color: AppTheme.textSecondary,
            ),
            title: Text(s.appLanguage),
            trailing: DropdownButton<String>(
              value: settings.preferredLanguage == 'ur' ? 'Urdu' : 'English',
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(value: 'English', child: Text(s.englishLabel)),
                DropdownMenuItem(value: 'Urdu', child: Text(s.urduLabel)),
              ],
              onChanged: (val) {
                if (val != null) {
                  ref
                      .read(settingsProvider.notifier)
                      .updateLanguage(val == 'Urdu' ? 'ur' : 'en');
                }
              },
            ),
          ),
          const Divider(height: 1),

          // ─── Notifications ────────────────────────────
          _SectionHeader(
            title: ref.watch(appStringsProvider).pushNotifications,
          ),
          SwitchListTile(
            secondary: const Icon(
              Icons.notifications_rounded,
              color: AppTheme.textSecondary,
            ),
            title: Text(s.pushNotifications),
            subtitle: Text(s.receiveAlerts),
            value: settings.notificationsEnabled,
            onChanged: (val) => ref
                .read(settingsProvider.notifier)
                .updateNotificationsEnabled(val),
          ),
          SwitchListTile(
            secondary: const Icon(
              Icons.work_outline,
              color: AppTheme.textSecondary,
            ),
            title: Text(s.jobAlerts),
            subtitle: Text(s.newJobMatches),
            value: settings.jobAlertsEnabled,
            onChanged: (val) =>
                ref.read(settingsProvider.notifier).updateJobAlertsEnabled(val),
          ),
          SwitchListTile(
            secondary: const Icon(
              Icons.chat_outlined,
              color: AppTheme.textSecondary,
            ),
            title: Text(s.messageAlerts),
            subtitle: Text(s.newMessagesFrom),
            value: settings.messageAlertsEnabled,
            onChanged: (val) => ref
                .read(settingsProvider.notifier)
                .updateMessageAlertsEnabled(val),
          ),
          const Divider(height: 1),

          // ─── Service Radius ───────────────────────────
          _SectionHeader(title: s.serviceArea),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.near_me_rounded,
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${s.serviceRadiusKm} ${settings.serviceRadiusKm} km',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Slider(
                  value: settings.serviceRadiusKm.toDouble(),
                  min: 1,
                  max: 50,
                  divisions: 49,
                  label: '${settings.serviceRadiusKm} km',
                  onChanged: (val) => ref
                      .read(settingsProvider.notifier)
                      .updateServiceRadius(val.round()),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ─── Support ──────────────────────────────────
          _SectionHeader(title: ref.watch(appStringsProvider).support),
          ListTile(
            leading: const Icon(
              Icons.help_outline,
              color: AppTheme.textSecondary,
            ),
            title: Text(s.helpCenter),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final uri = Uri.parse(
                'https://localservices.app/help',
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Could not open help center. Please visit '
                        'localservices.app/help in your browser.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.flag_outlined,
              color: AppTheme.textSecondary,
            ),
            title: Text(s.reportProblem),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReportsView(),
                ),
              );
            },
          ),
          const Divider(height: 1),

          // ─── Account Actions ──────────────────────────
          _SectionHeader(title: ref.watch(appStringsProvider).account),
          ListTile(
            leading: const Icon(
              Icons.logout_rounded,
              color: AppTheme.errorColor,
            ),
            title: Text(s.logOut, style: TextStyle(color: AppTheme.errorColor)),
            onTap: () => _showConfirmDialog(
              context,
              ref,
              s.logOut,
              s.logOutConfirm,
              () async {
                await ref.read(authProvider.notifier).signOut();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.delete_forever_rounded,
              color: AppTheme.errorColor,
            ),
            title: Text(
              s.deleteAccount,
              style: TextStyle(color: AppTheme.errorColor),
            ),
            subtitle: const Text('This action cannot be undone'),
            onTap: () => _showConfirmDialog(
              context,
              ref,
              s.deleteAccount,
              s.deleteConfirm,
              () async {
                try {
                  final repo = ref.read(supabaseRepositoryProvider);
                  final userId = ref.read(currentUserProvider)?.id;
                  if (userId == null) return;

                  // Delete user data from application tables
                  await repo.deleteUserData(userId);

                  // Sign out — this effectively deletes the local state.
                  // Server-side auth account deletion requires the Supabase
                  // Admin API (RPC) which is a Phase 2 concern.
                  await ref.read(authProvider.notifier).signOut();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Account data cleared'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete account: $e'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                }
              },
              isDestructive: true,
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              '${s.versionLabel} 1.0.0',
              style: TextStyle(color: AppTheme.textDisabled, fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showConfirmDialog(
    BuildContext context,
    WidgetRef ref,
    String title,
    String message,
    VoidCallback onConfirm, {
    bool isDestructive = false,
  }) {
    final s = ref.read(appStringsProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: isDestructive
                ? FilledButton.styleFrom(backgroundColor: AppTheme.errorColor)
                : null,
            child: Text(title),
          ),
        ],
      ),
    );
  }
}

class _AccountHeader extends ConsumerWidget {
  const _AccountHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final workerAsync = ref.watch(myWorkerProfileProvider);

    final name = workerAsync.when(
      data: (p) => p?.fullName ?? '',
      loading: () => '',
      error: (_, _) => '',
    );
    final phone = user?.phone ?? ref.watch(appStringsProvider).notSignedIn;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
        child: const Icon(Icons.person_rounded, color: AppTheme.primaryColor),
      ),
      title: Text(
        name.isEmpty ? ref.watch(appStringsProvider).yourAccount : name,
      ),
      subtitle: Text(phone),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {},
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
        title,
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
