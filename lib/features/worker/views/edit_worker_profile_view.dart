import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/constants/app_constants.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/features/worker/models/worker_profile_model.dart';
import 'package:local_services_marketplace/features/worker/providers/worker_profile_provider.dart';

/// Editable worker profile screen.
/// Allows the worker to manage their photo, headline, bio (with AI generation),
/// categories, experience, availability, service radius, hourly rate, and portfolio.
class EditWorkerProfileView extends ConsumerStatefulWidget {
  const EditWorkerProfileView({super.key});

  @override
  ConsumerState<EditWorkerProfileView> createState() =>
      _EditWorkerProfileViewState();
}

class _EditWorkerProfileViewState extends ConsumerState<EditWorkerProfileView> {
  final _headlineController = TextEditingController();
  final _bioController = TextEditingController();
  final _aiInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(workerProfileProvider.notifier);
      // Sync controllers with the current state after build
      final state = ref.read(workerProfileProvider);
      _headlineController.text = state.profile.headline ?? '';
      _bioController.text = state.profile.bio ?? '';
    });
  }

  @override
  void dispose() {
    _headlineController.dispose();
    _bioController.dispose();
    _aiInputController.dispose();
    super.dispose();
  }

  // ─── AI Bio Generation Dialog ────────────────────────────────

  void _showAiBioDialog() {
    _aiInputController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _AiBioSheet(
          aiInputController: _aiInputController,
          onGenerate: () {
            final input = _aiInputController.text.trim();
            if (input.isNotEmpty) {
              ref.read(workerProfileProvider.notifier).setTempBioInput(input);
              ref.read(workerProfileProvider.notifier).generateAiBio();
              Navigator.pop(sheetContext);
            }
          },
        );
      },
    );
  }

  void _showAiSuggestionResult() {
    final state = ref.read(workerProfileProvider);
    if (state.aiSuggestionText == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.auto_awesome, color: AppTheme.accentColor),
              const SizedBox(width: 8),
              const Text('AI Generated Profile'),
            ],
          ),
          content: Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(workerProfileProvider);
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Suggested Bio:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        state.aiSuggestionText ?? '',
                        style: const TextStyle(height: 1.5),
                      ),
                    ),
                    if (state.aiSuggestedCategories != null &&
                        state.aiSuggestedCategories!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Suggested Categories:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: state.aiSuggestedCategories!
                            .map((cat) => Chip(
                                  label: Text(cat),
                                  backgroundColor:
                                      AppTheme.primaryColor.withValues(alpha: 0.1),
                                  side: BorderSide.none,
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(workerProfileProvider.notifier).dismissAiSuggestion();
                Navigator.pop(dialogContext);
              },
              child: const Text('Dismiss'),
            ),
            FilledButton(
              onPressed: () {
                ref.read(workerProfileProvider.notifier).applyAiBioSuggestion();
                setState(() {
                  _bioController.text =
                      ref.read(workerProfileProvider).profile.bio ?? '';
                });
                Navigator.pop(dialogContext);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  // ─── Portfolio Image Add Dialog ──────────────────────────────

  void _showAddPortfolioImageDialog() {
    // For now simulate adding a placeholder image URL
    showDialog(
      context: context,
      builder: (dialogContext) {
        final urlController = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Add Portfolio Image'),
          content: TextField(
            controller: urlController,
            decoration: const InputDecoration(
              hintText: 'Paste image URL',
              labelText: 'Image URL',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final url = urlController.text.trim();
                if (url.isNotEmpty) {
                  ref
                      .read(workerProfileProvider.notifier)
                      .addPortfolioImage(url);
                }
                Navigator.pop(dialogContext);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  // ─── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workerProfileProvider);
    final profile = state.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Profile'),
        actions: [
          TextButton(
            onPressed: state.isSaving
                ? null
                : () => ref.read(workerProfileProvider.notifier).saveProfile(),
            child: state.isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Profile Photo ────────────────────────────────
            _ProfilePhotoSection(
              photoUrl: profile.profilePhotoUrl,
              fullName: profile.fullName,
              rating: profile.averageRating,
              totalJobs: profile.totalJobsCompleted,
              isVerified: profile.isVerified,
              onTapPhoto: () {
                // TODO: Implement image picker from camera/gallery
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Image picker coming soon')),
                );
              },
            ),
            const SizedBox(height: 16),

            // ─── Headline ─────────────────────────────────────
            _SectionHeader(title: 'Headline', icon: Icons.short_text_rounded),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _headlineController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Experienced Plumber & Electrician',
                ),
                maxLength: 100,
                onChanged: (val) =>
                    ref.read(workerProfileProvider.notifier).updateHeadline(val),
              ),
            ),
            const SizedBox(height: 16),

            // ─── Bio ──────────────────────────────────────────
            _SectionHeader(
              title: 'Bio',
              icon: Icons.description_outlined,
              trailing: FilledButton.tonalIcon(
                onPressed: () => _showAiBioDialog(),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Let AI write it'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _bioController,
                decoration: const InputDecoration(
                  hintText: 'Describe your experience and skills...',
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                maxLength: 500,
                onChanged: (val) =>
                    ref.read(workerProfileProvider.notifier).updateBio(val),
              ),
            ),

            // AI generation loading indicator
            if (state.isGeneratingBio)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Generating your profile...',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),

            // Show the "View Suggestion" button if AI generated something
            if (state.aiSuggestionText != null && !state.isGeneratingBio)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextButton.icon(
                  onPressed: _showAiSuggestionResult,
                  icon: const Icon(Icons.visibility_rounded, size: 18),
                  label: const Text('View AI Suggestion'),
                ),
              ),

            const SizedBox(height: 16),

            // ─── Categories ───────────────────────────────────
            _SectionHeader(title: 'Categories', icon: Icons.category_rounded),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: allWorkerCategories.map((cat) {
                  final selected = profile.categories.contains(cat);
                  return FilterChip(
                    label: Text(cat),
                    selected: selected,
                    onSelected: (_) =>
                        ref.read(workerProfileProvider.notifier).toggleCategory(cat),
                    selectedColor:
                        AppTheme.primaryColor.withValues(alpha: 0.15),
                    checkmarkColor: AppTheme.primaryColor,
                    side: BorderSide(
                      color: selected ? AppTheme.primaryColor : AppTheme.borderColor,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // ─── Experience & Rate ────────────────────────────
            _SectionHeader(
              title: 'Experience & Rate',
              icon: Icons.work_outline,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: profile.yearsExperience,
                      decoration: const InputDecoration(
                        labelText: 'Years Experience',
                      ),
                      items: List.generate(31, (i) => i)
                          .map((y) => DropdownMenuItem(
                                value: y,
                                child: Text(y == 0 ? 'Less than 1' : '$y years'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref
                              .read(workerProfileProvider.notifier)
                              .updateYearsExperience(val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Rate (PKR/hr)',
                        prefixText: 'Rs. ',
                      ),
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(
                        text: profile.hourlyRatePkr?.toString() ?? '',
                      ),
                      onChanged: (val) {
                        final rate = int.tryParse(val);
                        ref
                            .read(workerProfileProvider.notifier)
                            .updateHourlyRate(rate);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── Service Radius ───────────────────────────────
            _SectionHeader(
              title: 'Service Radius',
              icon: Icons.near_me_rounded,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${profile.serviceRadiusKm} km',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        'Max: ${AppConstants.maxServiceRadiusKm} km',
                        style: const TextStyle(
                          color: AppTheme.textDisabled,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: profile.serviceRadiusKm.toDouble(),
                    min: 1,
                    max: AppConstants.maxServiceRadiusKm.toDouble(),
                    divisions: AppConstants.maxServiceRadiusKm - 1,
                    label: '${profile.serviceRadiusKm} km',
                    onChanged: (val) =>
                        ref.read(workerProfileProvider.notifier).updateServiceRadius(val.round()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ─── Availability ─────────────────────────────────
            _SectionHeader(
              title: 'Availability',
              icon: Icons.schedule_rounded,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _AvailabilitySelector(
                currentStatus: profile.availabilityStatus,
                onChanged: (status) =>
                    ref.read(workerProfileProvider.notifier).updateAvailability(status),
              ),
            ),
            const SizedBox(height: 16),

            // ─── Portfolio ────────────────────────────────────
            _SectionHeader(
              title: 'Portfolio',
              icon: Icons.photo_library_outlined,
              trailing: TextButton.icon(
                onPressed: profile.portfolioMediaUrls.length >=
                        AppConstants.maxPortfolioImages
                    ? null
                    : _showAddPortfolioImageDialog,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text(
                  '${profile.portfolioMediaUrls.length}/${AppConstants.maxPortfolioImages}',
                ),
              ),
            ),
            if (profile.portfolioMediaUrls.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'No portfolio images yet. Tap "Add" to showcase your work.',
                  style: TextStyle(color: AppTheme.textDisabled),
                ),
              )
            else
              _PortfolioGrid(
                urls: profile.portfolioMediaUrls,
                onRemove: (index) =>
                    ref.read(workerProfileProvider.notifier).removePortfolioImage(index),
              ),
            const SizedBox(height: 16),

            // ─── Verification Status ──────────────────────────
            _SectionHeader(
              title: 'Verification',
              icon: Icons.verified_outlined,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(
                    profile.isVerified
                        ? Icons.verified_rounded
                        : Icons.gpp_bad_outlined,
                    color: profile.isVerified
                        ? AppTheme.verifiedBadge
                        : AppTheme.textDisabled,
                    size: 28,
                  ),
                  title: Text(
                    profile.isVerified
                        ? 'Verified Account'
                        : 'Not Yet Verified',
                  ),
                  subtitle: Text(
                    profile.isVerified
                        ? 'Your identity has been verified'
                        : 'Verify your ID to earn a trusted badge',
                  ),
                  trailing: profile.isVerified
                      ? null
                      : TextButton(
                          onPressed: () {
                            // TODO: Navigate to ID verification flow
                          },
                          child: const Text('Verify Now'),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ─── Error Message ────────────────────────────────
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.errorColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          style: const TextStyle(color: AppTheme.errorColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────────

/// Profile photo with overlay edit button and stats
class _ProfilePhotoSection extends StatelessWidget {
  final String? photoUrl;
  final String fullName;
  final double rating;
  final int totalJobs;
  final bool isVerified;
  final VoidCallback onTapPhoto;

  const _ProfilePhotoSection({
    required this.photoUrl,
    required this.fullName,
    required this.rating,
    required this.totalJobs,
    required this.isVerified,
    required this.onTapPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: onTapPhoto,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  backgroundImage: photoUrl != null
                      ? NetworkImage(photoUrl!)
                      : null,
                  child: photoUrl == null
                      ? const Icon(Icons.person_rounded,
                          size: 50, color: AppTheme.primaryColor)
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onTapPhoto,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 18, color: Colors.white),
                  ),
                ),
              ),
              if (isVerified)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_rounded,
                        color: AppTheme.verifiedBadge, size: 22),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            fullName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded,
                  size: 16, color: AppTheme.accentColor),
              const SizedBox(width: 4),
              Text(
                rating > 0 ? rating.toStringAsFixed(1) : 'No ratings',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentDark,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.work_history_rounded,
                  size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                '$totalJobs jobs',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Section header with optional trailing widget
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Availability toggle with a grid of selectable chips
class _AvailabilitySelector extends StatelessWidget {
  final AvailabilityStatus currentStatus;
  final ValueChanged<AvailabilityStatus> onChanged;

  const _AvailabilitySelector({
    required this.currentStatus,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
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
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
          selected: isSelected,
          selectedColor: AppTheme.primaryColor,
          backgroundColor: AppTheme.surfaceColor,
          side: BorderSide(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
          ),
          onSelected: (_) => onChanged(status),
        );
      }).toList(),
    );
  }
}

/// Grid of portfolio images with delete overlay
class _PortfolioGrid extends StatelessWidget {
  final List<String> urls;
  final ValueChanged<int> onRemove;

  const _PortfolioGrid({
    required this.urls,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: urls.length,
        itemBuilder: (context, index) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  urls[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppTheme.surfaceColor,
                    child: const Icon(Icons.broken_image_outlined,
                        color: AppTheme.textDisabled),
                  ),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: AppTheme.surfaceColor,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => onRemove(index),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Bottom sheet for AI bio generation input
class _AiBioSheet extends StatelessWidget {
  final TextEditingController aiInputController;
  final VoidCallback onGenerate;

  const _AiBioSheet({
    required this.aiInputController,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
              Icon(Icons.auto_awesome, color: AppTheme.accentColor),
              const SizedBox(width: 8),
              const Text(
                'Let AI write your profile',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Describe your experience in your own words, and we\'ll turn it into a professional bio.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Example: "I worked in construction for 8 years, mostly plumbing and tiling."',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textDisabled,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: aiInputController,
            decoration: const InputDecoration(
              hintText: 'Describe your experience...',
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            maxLength: 500,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onGenerate,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate Bio'),
          ),
        ],
      ),
    );
  }
}
