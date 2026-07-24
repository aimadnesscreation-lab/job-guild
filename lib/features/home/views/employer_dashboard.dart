import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';
import 'package:local_services_marketplace/core/utils/responsive.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/core/services/supabase_repository.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';
import 'package:local_services_marketplace/features/ratings/views/reviews_list_view.dart';
import 'package:local_services_marketplace/features/jobs/models/job_model.dart';
import 'package:local_services_marketplace/features/jobs/providers/job_feed_provider.dart';
import 'package:local_services_marketplace/features/jobs/views/job_detail_view.dart';

/// Employer Dashboard — real active jobs (from the live feed) with applicant
/// counts per job, plus completed-job history.
class EmployerDashboard extends ConsumerWidget {
  const EmployerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final jobsAsync = user != null
        ? ref.watch(employerJobsProvider(user.id))
        : const AsyncValue<List<Job>>.data([]);

    return jobsAsync.when(
      data: (jobs) {
        final active = jobs.where((j) => j.isOpen).toList();
        final completed = jobs
            .where((j) => j.status == JobStatus.completed)
            .toList();
        // Count all jobs the employer has ever posted (not just active+completed).
        final totalPosted = jobs.length;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Stats Row (responsive) ─────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = Breakpoints.statsColumns(constraints.maxWidth);
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatCard(
                        icon: Icons.work_outlined,
                        value: '${active.length}',
                        label: ref.watch(appStringsProvider).activeJobs,
                        color: AppTheme.primaryColor,
                        width: (constraints.maxWidth - (cols - 1) * 8) / cols,
                      ),
                      _StatCard(
                        icon: Icons.people_outlined,
                        value: '$totalPosted',
                        label: ref.watch(appStringsProvider).jobsPosted,
                        color: AppTheme.accentColor,
                        width: (constraints.maxWidth - (cols - 1) * 8) / cols,
                      ),
                      _StatCard(
                        icon: Icons.check_circle_outlined,
                        value: '${completed.length}',
                        label: ref.watch(appStringsProvider).completed,
                        color: AppTheme.verifiedBadge,
                        width: (constraints.maxWidth - (cols - 1) * 8) / cols,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // ─── Quick Actions ────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReviewsListView()),
                  ),
                  icon: const Icon(Icons.star_rounded, size: 16),
                  label: Text(
                    ref.watch(appStringsProvider).myReviews,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ─── Active Jobs ───────────────────────────────────
              Text(
                ref.watch(appStringsProvider).activeJobs,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (active.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      ref.watch(appStringsProvider).noActiveJobs,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                )
              else
                ...active.map((job) => _ActiveJobCard(job: job)),
              const SizedBox(height: 20),

              // ─── Completed Jobs ───────────────────────────────
              Text(
                ref.watch(appStringsProvider).completed,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (completed.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      ref.watch(appStringsProvider).noCompletedJobs,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                )
              else
                ...completed.map(
                  (job) => _ActiveJobCard(
                    job: job,
                    showApplicantCount: false,
                    interactive: false,
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.all(16),
        child: const Column(
          children: [
            Row(
              children: [
                _ShimmerCard(),
                SizedBox(width: 8),
                _ShimmerCard(),
                SizedBox(width: 8),
                _ShimmerCard(),
              ],
            ),
            SizedBox(height: 20),
            _LoadingText(),
          ],
        ),
      ),
      error: (err, _) =>
          Center(child: Text('${ref.watch(appStringsProvider).error}: $err')),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final double? width;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveJobCard extends ConsumerWidget {
  final Job job;
  final bool showApplicantCount;
  final bool interactive;

  const _ActiveJobCard({
    required this.job,
    this.showApplicantCount = true,
    this.interactive = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicantCount = showApplicantCount
        ? ref.watch(_applicantCountProvider(job.id))
        : const AsyncValue.data(0);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.work_outlined,
            color: AppTheme.primaryColor,
            size: 22,
          ),
        ),
        title: Text(
          job.title,
          style: const TextStyle(fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(
              '${applicantCount.value ?? 0} ${ref.watch(appStringsProvider).applicantCount}',
              style: const TextStyle(fontSize: 12, color: AppTheme.accentDark),
            ),
            const SizedBox(width: 8),
            Text(
              job.budgetDisplay,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        trailing: interactive
            ? const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppTheme.textDisabled,
              )
            : null,
        onTap: interactive
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => JobDetailView(job: job)),
                );
              }
            : null,
      ),
    );
  }
}

/// Lightweight applicant-count watcher for a single job.
final _applicantCountProvider = FutureProvider.family<int, String>((
  ref,
  jobId,
) async {
  return ref.watch(supabaseRepositoryProvider).countApplicants(jobId);
});

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _LoadingText extends ConsumerWidget {
  const _LoadingText();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Text(
      ref.watch(appStringsProvider).dashboardLoading,
      style: const TextStyle(color: AppTheme.textSecondary),
    );
  }
}
