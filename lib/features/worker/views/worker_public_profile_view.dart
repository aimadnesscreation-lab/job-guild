import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/features/worker/models/worker_profile_model.dart';
import 'package:local_services_marketplace/core/services/supabase_repository.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';
import 'package:local_services_marketplace/features/chat/views/chat_detail_view.dart';
import 'package:local_services_marketplace/features/worker/providers/worker_profile_provider.dart';

/// Public (read-only) worker profile as seen by an employer.
/// Shows the worker's info, portfolio, reviews, and action buttons.
class WorkerPublicProfileView extends ConsumerWidget {
  /// Optionally pass a profile directly; otherwise reads from provider
  final WorkerProfile? profile;

  const WorkerPublicProfileView({super.key, this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = profile ?? ref.watch(workerProfileProvider).profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            onPressed: () {
              // TODO: Report user
            },
            tooltip: 'Report',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Profile Header ────────────────────────────────
            _PublicProfileHeader(profile: p),
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
                  title: 'About',
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
                  title: 'Categories',
                  icon: Icons.category_rounded,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: p.categories
                        .map((cat) => Chip(
                              label: Text(cat, style: const TextStyle(fontSize: 12)),
                              backgroundColor: AppTheme.primaryColor
                                  .withValues(alpha: 0.1),
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ))
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
                      title: 'Experience',
                      value: '${p.yearsExperience} years',
                    ),
                  ),
                  if (p.hourlyRatePkr != null)
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.monetization_on_outlined,
                        title: 'Hourly Rate',
                        value: 'Rs. ${p.hourlyRatePkr}/hr',
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
                title: 'Service Radius',
                value: '${p.serviceRadiusKm} km',
              ),
            ),
            const SizedBox(height: 12),

            // ─── Location ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _InfoTile(
                icon: Icons.location_on_outlined,
                title: 'Location',
                value: 'Lahore, Pakistan',
              ),
            ),
            const SizedBox(height: 16),

            // ─── Portfolio ────────────────────────────────────
            if (p.portfolioMediaUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _InfoSection(
                  title: 'Portfolio (${p.portfolioMediaUrls.length})',
                  icon: Icons.photo_library_outlined,
                  child: GridView.builder(
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
                          // TODO: Open full-screen image viewer
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            p.portfolioMediaUrls[index],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppTheme.surfaceColor,
                              child: const Icon(Icons.broken_image_outlined,
                                  color: AppTheme.textDisabled),
                            ),
                          ),
                        ),
                      );
                    },
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
                        ? 'Verified Worker'
                        : 'Not Yet Verified',
                  ),
                  subtitle: Text(
                    p.isVerified
                        ? 'Identity confirmed'
                        : 'This worker has not completed verification',
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
                tooltip: 'Save',
              ),
              const SizedBox(width: 8),
              // Message button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _message(context, ref, p),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('Message'),
                ),
              ),
              const SizedBox(width: 8),
              // Hire button
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _message(context, ref, p),
                  icon: const Icon(Icons.handshake_rounded),
                  label: const Text('Hire'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


  void _toggleFavorite(BuildContext context, WidgetRef ref, String workerId) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    try {
      await ref.read(supabaseRepositoryProvider).toggleFavorite(userId, workerId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Worker saved to favorites')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save favorite')),
        );
      }
    }
  }

  void _message(BuildContext context, WidgetRef ref, WorkerProfile p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatDetailView(
          conversationId: p.userId,
          otherUserName: p.fullName,
          jobTitle: 'Direct message',
        ),
      ),
    );
  }
// ─── Public Profile Sub-widgets ─────────────────────────────────────────

class _PublicProfileHeader extends StatelessWidget {
  final WorkerProfile profile;

  const _PublicProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
                ? const Icon(Icons.person_rounded,
                    size: 48, color: AppTheme.primaryColor)
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
                const Icon(Icons.verified_rounded,
                    color: AppTheme.verifiedBadge, size: 20),
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
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_outlined,
                    size: 16, color: AppTheme.textSecondary),
                SizedBox(width: 4),
                Text(
                  '2.3 km away',
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

class _AvailabilityBadge extends StatelessWidget {
  final AvailabilityStatus status;

  const _AvailabilityBadge({required this.status});

  @override
  Widget build(BuildContext context) {
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
            'Available: ${status.label}',
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
