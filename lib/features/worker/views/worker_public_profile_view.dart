import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/utils/responsive.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/features/worker/models/worker_profile_model.dart';
import 'package:local_services_marketplace/core/services/supabase_repository.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';
import 'package:local_services_marketplace/features/worker/providers/worker_profile_provider.dart';

/// Public (read-only) worker profile as seen by an employer.
/// Shows the worker's info, portfolio, reviews, and action buttons.
class WorkerPublicProfileView extends ConsumerWidget {
  /// Optionally pass a profile directly; otherwise reads from provider
  final WorkerProfile? profile;

  /// Optional distance from the viewer to this worker (in kilometres).
  /// When provided, the profile header shows the real distance instead of a
  /// hard-coded placeholder.
  final double? distanceKm;

  const WorkerPublicProfileView({super.key, this.profile, this.distanceKm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = profile ?? ref.watch(workerProfileProvider).profile;

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.watch(appStringsProvider).workerProfile),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            onPressed: () {
              _showReportUserDialog(context, ref, p.userId, p.fullName);
            },
            tooltip: ref.watch(appStringsProvider).reportUser,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Profile Header ────────────────────────────────
            _PublicProfileHeader(profile: p, distanceKm: distanceKm),
            const SizedBox(height: 16),

            // ─── Availability Badge ────────────────────────────
            if (p.availabilityStatus != AvailabilityStatus.offline)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _AvailabilityBadge(status: p.availabilityStatus),
              ),
            const SizedBox(height: 8),

            // ─── Quick Stats ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _StatChip(
                    icon: Icons.star_rounded,
                    value: p.ratingDisplay,
                    color: AppTheme.accentColor,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.work_history_rounded,
                    value: '${p.totalJobsCompleted} jobs',
                    color: AppTheme.verifiedBadge,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.timer_outlined,
                    value: '${p.responseTimeAvgMinutes} min',
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── Bio ──────────────────────────────────────────
            if (p.bio != null && p.bio!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _InfoSection(
                  title: ref.watch(appStringsProvider).about,
                  icon: Icons.description_outlined,
                  child: Text(
                    p.bio!,
                    style: const TextStyle(
                      height: 1.6,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // ─── Categories ───────────────────────────────────
            if (p.categories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _InfoSection(
                  title: ref.watch(appStringsProvider).categories,
                  icon: Icons.category_rounded,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: p.categories
                        .map(
                          (cat) => Chip(
                            label: Text(
                              cat,
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: AppTheme.primaryColor.withValues(
                              alpha: 0.1,
                            ),
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // ─── Experience & Rate ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _InfoTile(
                      icon: Icons.work_outline,
                      title: ref.watch(appStringsProvider).experience,
                      value:
                          '${p.yearsExperience} ${ref.watch(appStringsProvider).years}',
                    ),
                  ),
                  if (p.hourlyRatePkr != null)
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.monetization_on_outlined,
                        title: ref.watch(appStringsProvider).hourlyRate,
                        value: 'PKR ${p.hourlyRatePkr}/hr',
                        valueColor: AppTheme.accentDark,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ─── Service Radius ───────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _InfoTile(
                icon: Icons.near_me_rounded,
                title: ref.watch(appStringsProvider).serviceRadius,
                value: '${p.serviceRadiusKm} km',
              ),
            ),
            const SizedBox(height: 12),

            // ─── Location ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _InfoTile(
                icon: Icons.location_on_outlined,
                title: ref.watch(appStringsProvider).location,
                value: ref.watch(appStringsProvider).lahorePakistan,
              ),
            ),
            const SizedBox(height: 16),

            // ─── Portfolio ────────────────────────────────────
            if (p.portfolioMediaUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _InfoSection(
                  title:
                      '${ref.watch(appStringsProvider).portfolioCount} (${p.portfolioMediaUrls.length})',
                  icon: Icons.photo_library_outlined,
                  child: LayoutBuilder(
                    builder: (context, constraints) => GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: p.portfolioMediaUrls.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            _showFullScreenImage(
                              context,
                              ref,
                              p.portfolioMediaUrls[index],
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              p.portfolioMediaUrls[index],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (_, _, _) => Container(
                                color: AppTheme.surfaceColor,
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  color: AppTheme.textDisabled,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // ─── Verification ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(
                    p.isVerified
                        ? Icons.verified_rounded
                        : Icons.gpp_bad_outlined,
                    color: p.isVerified
                        ? AppTheme.verifiedBadge
                        : AppTheme.textDisabled,
                    size: 28,
                  ),
                  title: Text(
                    p.isVerified
                        ? ref.watch(appStringsProvider).verifiedWorker
                        : ref.watch(appStringsProvider).notYetVerified,
                  ),
                  subtitle: Text(
                    p.isVerified
                        ? ref.watch(appStringsProvider).identityConfirmed
                        : ref
                              .watch(appStringsProvider)
                              .notCompletedVerification,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      // ─── Bottom Action Bar ────────────────────────────────────
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
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              // Save/Favorite button
              IconButton.outlined(
                onPressed: () => _toggleFavorite(context, ref, p.userId),
                icon: const Icon(Icons.bookmark_border_rounded),
                tooltip: ref.watch(appStringsProvider).save,
              ),
              const SizedBox(width: 8),
              // Message button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _message(context, ref, p),
                  icon: const Icon(Icons.chat_outlined),
                  label: Text(ref.watch(appStringsProvider).message),
                ),
              ),
              const SizedBox(width: 8),
              // Hire button
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _message(context, ref, p),
                  icon: const Icon(Icons.handshake_rounded),
                  label: Text(ref.watch(appStringsProvider).hire),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Static helper — toggle favorite/unfavorite a worker profile.
Future<bool> _toggleFavorite(
  BuildContext context,
  WidgetRef ref,
  String workerId,
) async {
  final userId = ref.read(currentUserProvider)?.id;
  if (userId == null) return false;
  try {
    final isNowFavorited = await ref
        .read(supabaseRepositoryProvider)
        .toggleFavorite(userId, workerId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNowFavorited
                ? ref.read(appStringsProvider).workerSavedFavorites
                : ref.read(appStringsProvider).workerRemovedFavorites,
          ),
        ),
      );
    }
    return isNowFavorited;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(appStringsProvider).couldNotSaveFavorite),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
    return false;
  }
}

/// Static helper — message a worker.
void _message(BuildContext context, WidgetRef ref, WorkerProfile p) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(ref.read(appStringsProvider).sendMessageViaJob),
      backgroundColor: AppTheme.primaryColor,
    ),
  );
}

/// Show a report dialog for flagging this worker's profile.
void _showReportUserDialog(
  BuildContext context,
  WidgetRef ref,
  String reportedUserId,
  String reportedUserName,
) {
  final s = ref.read(appStringsProvider);
  final reasons = [
    s.reportReasonFakeProfile,
    s.reportReasonHarassment,
    s.reportReasonSpam,
    s.reportInappropriateContent,
    s.reportReasonScam,
    s.reportReasonOther,
  ];
  String selectedReason = reasons.first;
  final detailsController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.flag_outlined,
              color: AppTheme.errorColor,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.reportTitle(reportedUserName),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.reportWhyReason,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: selectedReason,
                decoration: InputDecoration(labelText: s.reportReasonLabel),
                items: reasons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedReason = val);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsController,
                decoration: InputDecoration(
                  labelText: s.reportDetailsOptionalLabel,
                  hintText: s.reportDetailsHint,
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                maxLength: 500,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.read(appStringsProvider).cancel),
          ),
          FilledButton(
            onPressed: () async {
              final userId = ref.read(currentUserProvider)?.id;
              if (userId == null) return;

              try {
                await ref
                    .read(supabaseRepositoryProvider)
                    .submitReport(
                      reporterId: userId,
                      reportedUserId: reportedUserId,
                      reason: selectedReason,
                      details: detailsController.text.trim(),
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ref.read(appStringsProvider).reportSubmitted),
                    backgroundColor: AppTheme.primaryColor,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${s.reportSubmitFailed}$e'),
                    backgroundColor: AppTheme.errorColor,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(ref.read(appStringsProvider).submit),
          ),
        ],
      ),
    ),
  );
}

/// Show a full-screen image viewer for the given image URL.
void _showFullScreenImage(
  BuildContext context,
  WidgetRef ref,
  String imageUrl,
) {
  final s = ref.read(appStringsProvider);
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(s.portfolioImageDialog),
          actions: [
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        body: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              },
              errorBuilder: (_, _, _) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.broken_image_outlined,
                    size: 64,
                    color: Colors.white38,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.imageLoadFailed,
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// ─── Public Profile Sub-widgets ─────────────────────────────────────────

class _PublicProfileHeader extends ConsumerWidget {
  final WorkerProfile profile;
  final double? distanceKm;

  const _PublicProfileHeader({required this.profile, this.distanceKm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = MediaQuery.of(context).size.width;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Breakpoints.isTablet(w) ? 40 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Photo
          CircleAvatar(
            radius: 48,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
            backgroundImage: profile.profilePhotoUrl != null
                ? NetworkImage(profile.profilePhotoUrl!)
                : null,
            child: profile.profilePhotoUrl == null
                ? const Icon(
                    Icons.person_rounded,
                    size: 48,
                    color: AppTheme.primaryColor,
                  )
                : null,
          ),
          const SizedBox(height: 12),
          // Name with verified badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                profile.fullName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (profile.isVerified) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.verified_rounded,
                  color: AppTheme.verifiedBadge,
                  size: 20,
                ),
              ],
            ],
          ),
          // Headline
          if (profile.headline != null) ...[
            const SizedBox(height: 4),
            Text(
              profile.headline!,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          // Distance badge
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  distanceKm != null
                      ? '${distanceKm!.toStringAsFixed(1)} ${ref.watch(appStringsProvider).kmAway}'
                      : ref.watch(appStringsProvider).nearbyFallback,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityBadge extends ConsumerWidget {
  final AvailabilityStatus status;

  const _AvailabilityBadge({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 6),
          Text(
            '${ref.watch(appStringsProvider).availablePrefix} ${status.label}',
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _InfoSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.primaryColor),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
