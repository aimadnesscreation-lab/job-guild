import 'package:flutter/material.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/features/jobs/models/job_model.dart';

/// Employer's view of a job — shows interested workers with match scores,
/// "Hire" and "Mark Complete" actions.
class JobDetailView extends StatefulWidget {
  final Job job;

  const JobDetailView({super.key, required this.job});

  @override
  State<JobDetailView> createState() => _JobDetailViewState();
}

class _JobDetailViewState extends State<JobDetailView> {
  String? _hiredWorkerId;

  @override
  Widget build(BuildContext context) {
    final job = widget.job;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              color: job.isOpen ? AppTheme.primaryColor : AppTheme.textDisabled,
            ),
            onPressed: job.isOpen
                ? () {
                    // TODO: Edit job
                  }
                : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Job Header ──────────────────────────────────
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
                            job.status.name.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        _StatusBadge(status: job.status),
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
                    Row(
                      children: [
                        const Icon(Icons.monetization_on_outlined,
                            size: 16, color: AppTheme.accentDark),
                        const SizedBox(width: 4),
                        Text(
                          job.budgetDisplay,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentDark,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.location_on_outlined,
                            size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          job.locationText ?? 'Lahore',
                          style: const TextStyle(
                              color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    if (job.aiExtractedMetadata != null) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome,
                              size: 14, color: AppTheme.accentColor),
                          const SizedBox(width: 4),
                          Text(
                            'AI: ${job.aiExtractedMetadata!.category} • ~${job.aiExtractedMetadata!.estimatedDurationHours}h',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ─── Interested Workers ──────────────────────────
            Text(
              'Interested Workers',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            ..._interestedWorkers.map((worker) => _WorkerCard(
                  worker: worker,
                  isHired: worker.id == _hiredWorkerId,
                  onHire: () {
                    setState(() => _hiredWorkerId = worker.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Hired ${worker.name} for this job!'),
                        backgroundColor: AppTheme.primaryColor,
                      ),
                    );
                  },
                  onMessage: () {
                    // TODO: Navigate to chat
                  },
                )),
            const SizedBox(height: 24),

            // ─── Actions ─────────────────────────────────────
            if (_hiredWorkerId != null && job.isOpen)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    // TODO: Mark as complete
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Job marked as complete!'),
                        backgroundColor: AppTheme.primaryColor,
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Mark Complete'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryDark,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static final _interestedWorkers = [
    _Worker(
      id: 'w1',
      name: 'Ahmed Khan',
      rating: 4.8,
      totalJobs: 127,
      distance: '1.2 km',
      responseTime: '5 min',
      matchScore: 95,
      isVerified: true,
    ),
    _Worker(
      id: 'w2',
      name: 'Imran Ali',
      rating: 4.5,
      totalJobs: 83,
      distance: '2.5 km',
      responseTime: '12 min',
      matchScore: 82,
      isVerified: true,
    ),
    _Worker(
      id: 'w3',
      name: 'Sajid Mehmood',
      rating: 4.2,
      totalJobs: 45,
      distance: '3.8 km',
      responseTime: '30 min',
      matchScore: 68,
      isVerified: false,
    ),
  ];
}

// ─── Supporting types & widgets ──────────────────────────────────────────

class _Worker {
  final String id;
  final String name;
  final double rating;
  final int totalJobs;
  final String distance;
  final String responseTime;
  final int matchScore;
  final bool isVerified;

  const _Worker({
    required this.id,
    required this.name,
    required this.rating,
    required this.totalJobs,
    required this.distance,
    required this.responseTime,
    required this.matchScore,
    required this.isVerified,
  });
}

class _WorkerCard extends StatelessWidget {
  final _Worker worker;
  final bool isHired;
  final VoidCallback onHire;
  final VoidCallback onMessage;

  const _WorkerCard({
    required this.worker,
    required this.isHired,
    required this.onHire,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    worker.name[0],
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            worker.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (worker.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded,
                                size: 16, color: AppTheme.verifiedBadge),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 13, color: AppTheme.accentColor),
                          const SizedBox(width: 2),
                          Text(
                            '${worker.rating}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${worker.totalJobs} jobs',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            worker.distance,
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
                // Match score badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: worker.matchScore >= 90
                        ? AppTheme.primaryColor.withValues(alpha: 0.1)
                        : worker.matchScore >= 75
                            ? AppTheme.accentColor.withValues(alpha: 0.1)
                            : AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${worker.matchScore}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: worker.matchScore >= 90
                              ? AppTheme.primaryColor
                              : worker.matchScore >= 75
                                  ? AppTheme.accentDark
                                  : AppTheme.textSecondary,
                        ),
                      ),
                      const Text(
                        'Match',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.textDisabled,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _MiniStat(
                    icon: Icons.timer_outlined,
                    text: worker.responseTime),
                const SizedBox(width: 12),
                const Spacer(),
                if (isHired)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 14, color: AppTheme.primaryColor),
                        SizedBox(width: 4),
                        Text(
                          'Hired',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onMessage,
                      child: const Text('Message', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: onHire,
                      child: const Text('Hire', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniStat({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textSecondary),
        const SizedBox(width: 2),
        Text(text,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final JobStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case JobStatus.open:
        color = AppTheme.primaryColor;
      case JobStatus.hired:
        color = AppTheme.accentColor;
      case JobStatus.completed:
        color = AppTheme.verifiedBadge;
      case JobStatus.cancelled:
        color = AppTheme.errorColor;
      case JobStatus.expired:
        color = AppTheme.textDisabled;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
