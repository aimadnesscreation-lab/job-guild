// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/core/services/supabase_repository.dart';
import 'package:local_services_marketplace/features/chat/views/chat_detail_view.dart';
import 'package:local_services_marketplace/features/jobs/models/job_model.dart';
import 'package:local_services_marketplace/features/jobs/views/post_job_view.dart';
import 'package:local_services_marketplace/features/jobs/providers/job_provider.dart';

/// Employer's view of a job — shows interested workers with match scores,
/// "Hire" and "Mark Complete" actions (all persisted to Supabase).
class JobDetailView extends ConsumerStatefulWidget {
  final Job job;

  const JobDetailView({super.key, required this.job});

  @override
  ConsumerState<JobDetailView> createState() => _JobDetailViewState();
}

class _JobDetailViewState extends ConsumerState<JobDetailView> {
  List<Map<String, dynamic>> _applicants = const [];
  String? _hiredWorkerId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadApplicants();
  }

  Future<void> _loadApplicants() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(supabaseRepositoryProvider);
      final list = await repo.getApplicants(widget.job.id);
      if (!context.mounted) return;
      setState(() {
        _applicants = list;
        // Pre-select a hired worker if any application is already hired.
        _hiredWorkerId = list
            .where((a) => a['status'] == 'hired')
            .map((a) => a['worker_id'] as String?)
            .firstWhere((id) => id != null, orElse: () => null);
        _loading = false;
      });
    } catch (e) {
      if (!context.mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${ref.read(appStringsProvider).error}: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _hire(String workerId) async {
    try {
      final repo = ref.read(supabaseRepositoryProvider);
      final success = await repo.hireWorker(widget.job.id, workerId);
      if (!context.mounted) return;
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${ref.read(appStringsProvider).error}: Hire failed — the job state may have changed. Please refresh.',
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        _loadApplicants();
        return;
      }
      setState(() => _hiredWorkerId = workerId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(appStringsProvider).workerHired),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${ref.read(appStringsProvider).error}: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      _loadApplicants();
    }
  }

  Future<void> _markComplete() async {
    try {
      final repo = ref.read(supabaseRepositoryProvider);
      await repo.updateJobStatus(widget.job.id, JobStatus.completed);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(appStringsProvider).jobMarkedComplete),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${ref.read(appStringsProvider).error}: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  String _workerName(Map<String, dynamic> a) {
    final wp = a['worker_profiles'] as Map<String, dynamic>?;
    final user = wp?['users'] as Map<String, dynamic>?;
    return user?['full_name'] as String? ??
        ref.watch(appStringsProvider).workerName;
  }

  double _workerRating(Map<String, dynamic> a) {
    final wp = a['worker_profiles'] as Map<String, dynamic>?;
    return (wp?['average_rating'] as num?)?.toDouble() ?? 0;
  }

  bool _isVerified(Map<String, dynamic> a) {
    final wp = a['worker_profiles'] as Map<String, dynamic>?;
    final user = wp?['users'] as Map<String, dynamic>?;
    return user?['is_verified'] as bool? ?? false;
  }

  /// Match score that considers rating, verification, experience, and category.
  /// Mirrors the weighting logic in the backend match_workers_for_job function.
  int _matchScore(Map<String, dynamic> a) {
    final rating = _workerRating(a);
    final verified = _isVerified(a);
    final wp = a['worker_profiles'] as Map<String, dynamic>?;
    final completedJobs = (wp?['total_jobs_completed'] as num?)?.toInt() ?? 0;
    // Rating: up to 70 points (scaled from 5-star rating)
    final ratingScore = (rating / 5 * 70).round();
    // Verification: 15 points
    final verifiedScore = verified ? 15 : 0;
    // Experience: up to 10 points (1 pt per 10 completed jobs, max 10)
    final experienceScore = (completedJobs / 10).round().clamp(0, 10);
    // Base: 5 points
    return (ratingScore + verifiedScore + experienceScore + 5).clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.watch(appStringsProvider).viewDetails),
        actions: [
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              color: job.isOpen ? AppTheme.primaryColor : AppTheme.textDisabled,
            ),
            onPressed: job.isOpen
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProviderScope(
                          overrides: [
                            postJobProvider.overrideWith(
                              () => PostJobNotifier(),
                            ),
                          ],
                          child: PostJobView(job: widget.job),
                        ),
                      ),
                    );
                  }
                : null,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
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
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  ref.watch(appStringsProvider).urgentBadge,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (job.isInstant) const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.1,
                                ),
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
                            const Icon(
                              Icons.monetization_on_outlined,
                              size: 16,
                              color: AppTheme.accentDark,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              job.budgetDisplay,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accentDark,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              job.locationText ?? 'Lahore',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        if (job.aiExtractedMetadata != null) ...[
                          const SizedBox(height: 12),
                          const Divider(),
                          Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: AppTheme.accentColor,
                              ),
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
                  ref.watch(appStringsProvider).interestedWorkers,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (_applicants.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        ref.watch(appStringsProvider).noApplicants,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  )
                else
                  ..._applicants.map((a) {
                    final workerId = a['worker_id'] as String? ?? '';
                    final isHired = workerId == _hiredWorkerId;
                    return _WorkerCard(
                      name: _workerName(a),
                      rating: _workerRating(a),
                      isVerified: _isVerified(a),
                      matchScore: _matchScore(a),
                      isHired: isHired,
                      onHire: () => _hire(workerId),
                      onMessage: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatDetailView(
                              conversationId: widget.job.id,
                              otherUserName: _workerName(a),
                              jobTitle: widget.job.title,
                            ),
                          ),
                        );
                      },
                    );
                  }),
                const SizedBox(height: 24),

                // ─── Actions ─────────────────────────────────────
                if (_hiredWorkerId != null && job.status == JobStatus.hired)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _markComplete,
                      icon: const Icon(Icons.check_circle_rounded),
                      label: Text(ref.watch(appStringsProvider).markComplete),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryDark,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ─── Supporting widgets ──────────────────────────────────────────

class _WorkerCard extends ConsumerWidget {
  final String name;
  final double rating;
  final bool isVerified;
  final int matchScore;
  final bool isHired;
  final VoidCallback onHire;
  final VoidCallback onMessage;

  const _WorkerCard({
    required this.name,
    required this.rating,
    required this.isVerified,
    required this.matchScore,
    required this.isHired,
    required this.onHire,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    name.isNotEmpty ? name[0] : '?',
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
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: AppTheme.verifiedBadge,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 13,
                            color: AppTheme.accentColor,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: matchScore >= 90
                        ? AppTheme.primaryColor.withValues(alpha: 0.1)
                        : matchScore >= 75
                        ? AppTheme.accentColor.withValues(alpha: 0.1)
                        : AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$matchScore%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: matchScore >= 90
                              ? AppTheme.primaryColor
                              : matchScore >= 75
                              ? AppTheme.accentDark
                              : AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        ref.watch(appStringsProvider).matchLabel,
                        style: const TextStyle(
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
                if (isHired)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          ref.watch(appStringsProvider).hired,
                          style: const TextStyle(
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
                      child: Text(
                        ref.watch(appStringsProvider).message,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: onHire,
                      child: Text(
                        ref.watch(appStringsProvider).hire,
                        style: const TextStyle(fontSize: 12),
                      ),
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
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
