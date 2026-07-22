import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';
import 'package:local_services_marketplace/core/localization/strings.dart';
import 'package:local_services_marketplace/core/services/supabase_repository.dart';

import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/features/chat/providers/chat_provider.dart';
import 'package:local_services_marketplace/features/jobs/models/job_model.dart';
import 'package:local_services_marketplace/features/jobs/providers/job_feed_provider.dart';
import 'package:local_services_marketplace/features/jobs/views/job_detail_worker_view.dart';
import 'package:local_services_marketplace/features/worker/models/worker_profile_model.dart';
import 'package:local_services_marketplace/features/worker/providers/worker_provider.dart';
import 'package:local_services_marketplace/features/worker/views/edit_worker_profile_view.dart';

/// Worker Dashboard — live stats from Supabase: nearby jobs count, applications,
/// messages, ratings, recent applications, and completed-jobs earnings log.
class WorkerDashboard extends ConsumerWidget {
  const WorkerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myWorkerProfileProvider);
    final jobsAsync = ref.watch(openJobsProvider);
    final applicationsAsync = ref.watch(workerApplicationsProvider);
    final completedJobsAsync = ref.watch(workerCompletedJobsProvider);
    final chatState = ref.watch(chatProvider);
    final s = ref.watch(appStringsProvider);
    final profile = profileAsync.asData?.value;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Stats Grid ────────────────────────────────────
          jobsAsync.when(
            data: (openJobs) => applicationsAsync.when(
              data: (applications) => completedJobsAsync.when(
                data: (completed) {
                  final rating = profileAsync.asData?.value?.averageRating ?? 0;
                  final items = [
                    _StatData(
                      icon: Icons.work_rounded,
                      value: '${openJobs.length}',
                      label: s.nearbyJobsCount,
                      color: AppTheme.primaryColor,
                    ),
                    _StatData(
                      icon: Icons.thumb_up_alt_rounded,
                      value: '${applications.length}',
                      label: s.applied,
                      color: AppTheme.accentColor,
                    ),
                    _StatData(
                      icon: Icons.chat_rounded,
                      value: '${chatState.conversations.length}',
                      label: s.messages,
                      color: AppTheme.verifiedBadge,
                    ),
                    _StatData(
                      icon: Icons.star_rounded,
                      value: rating > 0 ? rating.toStringAsFixed(1) : '—',
                      label: s.rating,
                      color: AppTheme.accentDark,
                    ),
                  ];
                  return Row(
                    children: items
                        .map(
                          (d) => Expanded(
                            child: _StatCard(
                              icon: d.icon,
                              value: d.value,
                              label: d.label,
                              color: d.color,
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
                loading: () => const _StatsShimmer(),
                error: (e, s) => const _StatsShimmer(),
              ),
              loading: () => const _StatsShimmer(),
              error: (e, s) => const _StatsShimmer(),
            ),
            loading: () => const _StatsShimmer(),
            error: (e, s) => const _StatsShimmer(),
          ),
          const SizedBox(height: 20),

          // ─── Quick Actions ─────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditWorkerProfileView(),
                      ),
                    );
                    // Refresh profile data when returning from edit screen.
                    ref.invalidate(myWorkerProfileProvider);
                  },
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: Text(
                    s.editProfile,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAvailabilitySheet(
                    context,
                    ref,
                    profileAsync.asData?.value,
                    s,
                  ),
                  icon: const Icon(Icons.toggle_on_outlined, size: 16),
                  label: Text(
                    s.availability,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ─── Offline Warning Banner ────────────────────────
          if (profile != null &&
              profile.availabilityStatus == AvailabilityStatus.offline)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Card(
                margin: EdgeInsets.zero,
                color: AppTheme.errorColor.withValues(alpha: 0.05),
                child: ListTile(
                  leading: const Icon(
                    Icons.visibility_off,
                    color: AppTheme.errorColor,
                  ),
                  title: const Text(
                    'You are currently invisible to employers',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Toggle availability to start receiving job matches.',
                  ),
                  trailing: TextButton(
                    onPressed: () => _showAvailabilitySheet(
                      context,
                      ref,
                      profile,
                      s,
                    ),
                    child: const Text('Update'),
                  ),
                ),
              ),
            ),

          // ─── Recent Applications ───────────────────────────
          Text(
            s.recentApplications,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          applicationsAsync.when(
            data: (applications) {
              if (applications.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      s.noData,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                );
              }
              return Column(
                children: applications.take(5).map((app) {
                  final jobData = app['jobs'] as Map<String, dynamic>? ?? {};
                  final status = app['status'] as String? ?? 'pending';
                  final title = jobData['title'] as String? ?? '';
                  final budget = jobData['budget_amount'] as int?;
                  final budgetStr = budget != null ? 'PKR $budget' : '';
                  final (statusLabel, statusColor) = _statusDisplay(status, s);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _ApplicationCard(
                      jobTitle: title,
                      status: statusLabel,
                      statusColor: statusColor,
                      budget: budgetStr,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JobDetailWorkerView(
                              job: _jobFromApplication(app),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const _ApplicationShimmer(),
            error: (err, st) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  '${s.error}: $err',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ─── Earnings Log ──────────────────────────────────
          Text(
            s.earningsLog,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          completedJobsAsync.when(
            data: (completed) {
              if (completed.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      s.noCompletedJobs,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                );
              }                  final now = DateTime.now();
                  final sevenDaysAgo = now.subtract(const Duration(days: 7));

                  // Compute the full earnings total over the last 7 days
                  // first, then only display the 10 most recent entries.
                  final recentEntries = completed.where((entry) {
                    final jobData =
                        entry['jobs'] as Map<String, dynamic>? ?? {};
                    final updatedAt = jobData['updated_at'] as String?;
                    final createdAt = jobData['created_at'] as String?;
                    final date = DateTime.tryParse(updatedAt ?? '') ??
                        DateTime.tryParse(createdAt ?? '');
                    return date != null &&
                        date.isAfter(sevenDaysAgo) &&
                        date.isBefore(now.add(const Duration(days: 1)));
                  }).toList();

                  final totalEarnings = recentEntries.fold<int>(
                    0,
                    (sum, entry) {
                      final jobData =
                          entry['jobs'] as Map<String, dynamic>? ?? {};
                      final amount = jobData['budget_amount'] as num? ?? 0;
                      return sum + amount.toInt();
                    },
                  );

                  final displayEntries = recentEntries.take(10);

                  return Column(
                    children: [
                      ...displayEntries.map((entry) {
                        final jobData =
                            entry['jobs'] as Map<String, dynamic>? ?? {};
                        final title = jobData['title'] as String? ?? '';
                        final amount = jobData['budget_amount'] as num? ?? 0;
                        final updatedAt = jobData['updated_at'] as String?;
                        final createdAt = jobData['created_at'] as String?;
                        final dateStr = _formatDate(
                          DateTime.tryParse(updatedAt ?? '') ??
                              DateTime.tryParse(createdAt ?? ''),
                          s,
                        );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _EarningEntry(
                        jobTitle: title,
                        amount: 'PKR ${amount.toInt()}',
                        date: dateStr,
                      ),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              s.totalThisWeek,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'PKR $totalEarnings',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const _EarningsShimmer(),
            error: (e, st) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  '${s.error}: $e',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show a bottom sheet to quickly toggle the worker's availability status
  /// and immediately persist the change to Supabase.
  void _showAvailabilitySheet(
    BuildContext context,
    WidgetRef ref,
    WorkerProfile? profile,
    AppStrings s,
  ) {
    final currentStatus =
        profile?.availabilityStatus ?? AvailabilityStatus.offline;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _AvailabilitySheet(
          currentStatus: currentStatus,
          onSelect: (status) async {
            Navigator.pop(sheetContext);
            if (status == currentStatus) return;

            final userId = profile?.userId;
            // Guard against placeholder user IDs (e.g. 'user-placeholder'
            // set when the profile hasn't loaded yet).
            if (userId == null ||
                userId.isEmpty ||
                userId == 'user-placeholder') {
              return;
            }

            try {
              await ref
                  .read(supabaseRepositoryProvider)
                  .updateAvailabilityStatus(userId, status);
              ref.invalidate(myWorkerProfileProvider);

              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text('${s.availability}: ${status.label} ✓'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text('${s.error}: $e'),
                    backgroundColor: AppTheme.errorColor,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
            }
          },
        );
      },
    );
  }

  /// Map application status to a localized label + color for display.
  (String label, Color color) _statusDisplay(String status, AppStrings s) {
    switch (status) {
      case 'hired':
        return (s.hired, AppTheme.primaryDark);
      case 'shortlisted':
        return (s.shortlisted, AppTheme.accentColor);
      case 'completed':
        return (s.completed, AppTheme.verifiedBadge);
      case 'pending':
      case 'applied':
      default:
        return (s.interested, AppTheme.primaryColor);
    }
  }

  /// Build a minimal Job from an application record for navigation.
  static Job _jobFromApplication(Map<String, dynamic> app) {
    final jobData = app['jobs'] as Map<String, dynamic>? ?? {};
    final budgetAmount = jobData['budget_amount'];
    return Job(
      id: app['job_id'] as String? ?? '',
      employerId: jobData['employer_id'] as String? ?? '',
      title: jobData['title'] as String? ?? '',
      description: jobData['description'] as String? ?? '',
      categoryId: jobData['category_id'] as int? ?? 1,
      budgetAmount: budgetAmount is int ? budgetAmount : (budgetAmount as num?)?.toInt(),
      budgetType: Job.parseBudgetType(jobData['budget_type'] as String?),
      locationText: jobData['location_text'] as String?,
      status: Job.parseJobStatus(jobData['status'] as String?),
      urgency: Job.parseUrgency(jobData['urgency'] as String?),
    );
  }

  static String _formatDate(DateTime? dt, AppStrings s) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return s.now;
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}';
  }
}

// ─── Availability Bottom Sheet ────────────────────────────────────────

/// Bottom sheet that lets the worker quickly pick an availability status
/// without navigating to the full profile editor.
class _AvailabilitySheet extends StatelessWidget {
  final AvailabilityStatus currentStatus;
  final ValueChanged<AvailabilityStatus> onSelect;

  const _AvailabilitySheet({
    required this.currentStatus,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Set Availability',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Let nearby employers know when you can work',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AvailabilityStatus.values.map((status) {
              final isSelected = status == currentStatus;
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      status.icon,
                      size: 16,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      status.label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                selected: isSelected,
                selectedColor: AppTheme.primaryColor,
                backgroundColor: AppTheme.surfaceColor,
                side: BorderSide(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.borderColor,
                ),
                onSelected: (_) => onSelect(status),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shimmer placeholders ────────────────────────────────────────────

class _StatsShimmer extends StatelessWidget {
  const _StatsShimmer();

  @override
  Widget build(BuildContext context) {
    // Match the actual stats layout: 4 cards in a single row.
    return Row(
      children: List.generate(4, (_) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 4, right: 4),
            child: const _ShimmerStatCard(),
          ),
        );
      }),
    );
  }
}

class _ShimmerStatCard extends StatelessWidget {
  const _ShimmerStatCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _ApplicationShimmer extends StatelessWidget {
  const _ApplicationShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

class _EarningsShimmer extends StatelessWidget {
  const _EarningsShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────

/// Lightweight data holder for responsive stats layout.
class _StatData {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatData({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final String jobTitle;
  final String status;
  final Color statusColor;
  final String budget;
  final VoidCallback? onTap;

  const _ApplicationCard({
    required this.jobTitle,
    required this.status,
    required this.statusColor,
    required this.budget,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.work_outline, color: statusColor, size: 20),
        ),
        title: Text(
          jobTitle,
          style: const TextStyle(fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              budget,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.accentDark,
              ),
            ),
          ],
        ),
        trailing: onTap != null
            ? const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppTheme.textDisabled,
              )
            : null,
      ),
    );
  }
}

class _EarningEntry extends StatelessWidget {
  final String jobTitle;
  final String amount;
  final String date;

  const _EarningEntry({
    required this.jobTitle,
    required this.amount,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(jobTitle, style: const TextStyle(fontSize: 13)),
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              amount,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
