import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/core/services/supabase_repository.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';
import 'package:local_services_marketplace/features/settings/providers/settings_provider.dart';
import 'package:local_services_marketplace/features/settings/views/reports_view.dart';
import 'package:local_services_marketplace/features/home/providers/role_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:local_services_marketplace/features/worker/providers/worker_provider.dart';
import 'package:local_services_marketplace/features/worker/views/id_verification_view.dart';
import 'package:local_services_marketplace/features/worker/views/edit_worker_profile_view.dart';

/// Settings screen — language, notification preferences, service radius,
/// account mode toggle, verification, logout, report management, delete account.
/// All settings are persisted to the `users` table in Supabase.
class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final settings = state.settings;
    final s = ref.watch(appStringsProvider);
    final currentRole = ref.watch(currentRoleProvider);
    final userRoles = ref.watch(userRolesProvider);
    final isWorker = currentRole == AppRole.worker;
    final hasBothRoles = userRoles.asData?.value != null &&
        userRoles.asData!.value.isEmployer &&
        userRoles.asData!.value.isWorker;

    return Scaffold(
      appBar: AppBar(title: Text(ref.watch(appStringsProvider).settings)),
      body: ListView(
        children: [
          // ─── Account ──────────────────────────────────
          _SectionHeader(title: ref.watch(appStringsProvider).account),
          _AccountHeader(),
          const Divider(height: 1),

          // ─── Account Mode ─────────────────────────────
          _SectionHeader(title: s.accountMode),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isWorker
                    ? AppTheme.accentColor.withValues(alpha: 0.1)
                    : AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isWorker ? Icons.engineering_rounded : Icons.business_center_rounded,
                color: isWorker ? AppTheme.accentColor : AppTheme.primaryColor,
              ),
            ),
            title: Text(isWorker ? s.workerMode : s.employerMode),
            subtitle: Text(
              isWorker
                  ? s.browsingJobsSubtitle
                  : s.postingJobsSubtitle,
            ),
            trailing: hasBothRoles
                ? TextButton(
                    onPressed: () {
                      ref.read(currentRoleProvider.notifier).toggle();
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            s.switchedToModeLabel(isWorker ? s.employer : s.worker),
                          ),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Text(isWorker ? s.switchToEmployer : s.switchToWorker),
                  )
                : userRoles.asData?.value != null && !userRoles.asData!.value.isWorker
                    ? TextButton(
                        onPressed: () => _enableWorkerMode(context, ref),
                        child: Text(s.enableWorkerMode),
                      )
                    : userRoles.asData?.value != null && !userRoles.asData!.value.isEmployer
                        ? TextButton(
                            onPressed: () => _enableEmployerMode(context, ref),
                            child: Text(s.enableEmployerMode),
                          )
                        : null,
          ),
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
                      content: Text(s.helpCenterError),
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
            subtitle: Text(s.deleteUndoneWarning),
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
                        content: Text(s.accountDataCleared),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${s.deleteAccountFailed}$e'),
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

  void _enableWorkerMode(BuildContext context, WidgetRef ref) async {
    final s = ref.read(appStringsProvider);
    try {
      final userId = ref.read(currentUserProvider)?.id;
      if (userId == null) return;

      await ref
          .read(supabaseRepositoryProvider)
          .updateUserRole(userId, isWorker: true);

      ref.invalidate(userRolesProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.workerModeEnabled),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${s.failedToEnable}$e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _enableEmployerMode(BuildContext context, WidgetRef ref) async {
    final s = ref.read(appStringsProvider);
    try {
      final userId = ref.read(currentUserProvider)?.id;
      if (userId == null) return;

      await ref
          .read(supabaseRepositoryProvider)
          .updateUserRole(userId, isEmployer: true);

      ref.invalidate(userRolesProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.employerModeEnabled),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${s.failedToEnable}$e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
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
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const EditWorkerProfileView(),
          ),
        );
      },
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
