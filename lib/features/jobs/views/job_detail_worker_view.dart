import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/core/services/supabase_repository.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';
import 'package:local_services_marketplace/features/jobs/models/job_model.dart';

/// Worker's view of a job — shows job info, employer rating, distance,
/// and an "I'm Interested" button (persisted via applyForJob).
class JobDetailWorkerView extends ConsumerStatefulWidget {
  final Job job;

  const JobDetailWorkerView({super.key, required this.job});

  @override
  ConsumerState<JobDetailWorkerView> createState() =>
      _JobDetailWorkerViewState();
}

class _JobDetailWorkerViewState extends ConsumerState<JobDetailWorkerView> {
  bool _isInterested = false;

  @override
  Widget build(BuildContext context) {
    final job = widget.job;

    return Scaffold(
      appBar: AppBar(title: const Text('Job Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // — Job Header Card —
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (job.isInstant)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('⚡ URGENT',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        if (job.isInstant) const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            job.urgency.name.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          job.budgetDisplay,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      job.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      job.description,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          job.locationText ?? 'Lahore, Pakistan',
                          style: const TextStyle(
                              color: AppTheme.textSecondary),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.calendar_today_rounded,
                            size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          job.isInstant
                              ? 'ASAP'
                              : job.scheduledFor != null
                                  ? _formatDate(job.scheduledFor!)
                                  : 'Today',
                          style: const TextStyle(
                              color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (job.aiExtractedMetadata != null)
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome,
                              size: 14, color: AppTheme.accentColor),
                          const SizedBox(width: 4),
                          Text(
                            'Estimated: ~${job.aiExtractedMetadata!.estimatedDurationHours} hours • ${job.aiExtractedMetadata!.category}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // — Employer Info —
            Text(
              'Posted by',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      AppTheme.verifiedBadge.withValues(alpha: 0.1),
                  child: const Icon(Icons.person_rounded,
                      color: AppTheme.verifiedBadge),
                ),
                title: const Text('Employer Name'),
                subtitle: Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 14, color: AppTheme.accentColor),
                    const SizedBox(width: 2),
                    const Text(
                      '4.5',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '32 jobs posted',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const Spacer(),
                    Icon(Icons.location_on_outlined,
                        size: 13, color: AppTheme.textSecondary),
                    const SizedBox(width: 2),
                    Text(
                      '${(2.3 + (job.id.hashCode % 10)).toStringAsFixed(1)} km',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // — Required Skills —
            if (job.aiExtractedMetadata?.requiredSkills != null &&
                job.aiExtractedMetadata!.requiredSkills.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Skills Needed',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: job.aiExtractedMetadata!.requiredSkills
                        .map((s) => Chip(
                              label: Text(s),
                              backgroundColor: AppTheme.primaryColor
                                  .withValues(alpha: 0.1),
                              side: BorderSide.none,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                ],
              ),

            // — Similar Jobs —
            Text(
              'Similar Jobs Nearby',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            _SimilarJobCard(
              title: 'Bathroom renovation needed',
              budget: 'PKR 8,000 - 12,000',
              distance: '1.5 km',
            ),
            const SizedBox(height: 6),
            _SimilarJobCard(
              title: 'Water tank installation',
              budget: 'PKR 3,000',
              distance: '2.1 km',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      // — Bottom Action —
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          12 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _isInterested
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryColor),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: AppTheme.primaryColor, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Interested ✓',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: _isInterested ? null : () async {
                        final userId = ref.read(currentUserProvider)?.id;
                        if (userId == null) return;
                        setState(() => _isInterested = true);
                        final repo = ref.read(supabaseRepositoryProvider);
                        await repo.applyForJob(job.id, userId);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Employer will be notified of your interest'),
                              backgroundColor: AppTheme.primaryColor,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.thumb_up_alt_outlined),
                      label: const Text("I'm Interested"),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }
}

class _SimilarJobCard extends StatelessWidget {
  final String title;
  final String budget;
  final String distance;

  const _SimilarJobCard({
    required this.title,
    required this.budget,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.work_outline,
              color: AppTheme.primaryColor, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontSize: 14)),
        subtitle: Row(
          children: [
            Text(budget,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text(distance,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          // TODO: Navigate to that job
        },
      ),
    );
  }
}
