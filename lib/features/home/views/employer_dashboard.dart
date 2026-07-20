import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/core/services/supabase_repository.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';
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
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Stats Row ─────────────────────────────────────
              Row(
                children: [
                  _StatCard(
                    icon: Icons.work_outlined,
                    value: '${active.length}',
                    label: 'Active Jobs',
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  _StatCard(
                    icon: Icons.people_outlined,
                    value: '${_totalApplicants(ref, jobs)}',
                    label: 'Applicants',
                    color: AppTheme.accentColor,
                  ),
                  const SizedBox(width: 8),
                  _StatCard(
                    icon: Icons.check_circle_outlined,
                    value: '${completed.length}',
                    label: 'Completed',
                    color: AppTheme.verifiedBadge,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ─── Active Jobs ───────────────────────────────────
              Text(
                'Active Jobs',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (active.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No active jobs. Post a job to get started.',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                )
              else
                ...active.map((job) => _ActiveJobCard(job: job)),
              const SizedBox(height: 20),

              // ─── Completed Jobs ───────────────────────────────
              Text(
                'Completed Jobs',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (completed.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text('No completed jobs yet.',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                )
              else
                ...completed.map((job) => _ActiveJobCard(job: job)),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }
}

int _totalApplicants(WidgetRef ref, List<Job> jobs) {
  return jobs.fold<int>(
      0, (sum, j) => sum + (ref.read(_applicantCountProvider(j.id)).value ?? 0));
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
    return Expanded(
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
                fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveJobCard extends ConsumerWidget {
  final Job job;

  const _ActiveJobCard({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicantCount = ref.watch(_applicantCountProvider(job.id));
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.work_outlined,
              color: AppTheme.primaryColor, size: 22),
        ),
        title: Text(job.title,
            style: const TextStyle(fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            Text('${applicantCount.value ?? 0} applicants',
                style: const TextStyle(fontSize: 12, color: AppTheme.accentDark)),
            const SizedBox(width: 8),
            Text(job.budgetDisplay,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded,
            size: 18, color: AppTheme.textDisabled),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => JobDetailView(job: job),
            ),
          );
        },
      ),
    );
  }
}

/// Lightweight applicant-count watcher for a single job.
final _applicantCountProvider =
    FutureProvider.family<int, String>((ref, jobId) async {
  return ref.watch(supabaseRepositoryProvider).countApplicants(jobId);
});
