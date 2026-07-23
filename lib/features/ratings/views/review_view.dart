// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';
import 'package:local_services_marketplace/core/services/supabase_repository.dart';

/// Two-way ratings & reviews screen triggered after a job is marked complete.
/// Both employer and worker rate each other with 1-5 stars + comment.
class ReviewView extends ConsumerStatefulWidget {
  final String jobId;
  final String jobTitle;
  final String otherPartyName;
  final String otherPartyId;
  final bool isReviewingWorker;

  const ReviewView({
    super.key,
    required this.jobId,
    required this.jobTitle,
    required this.otherPartyName,
    required this.otherPartyId,
    this.isReviewingWorker = true,
  });

  @override
  ConsumerState<ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends ConsumerState<ReviewView>
    with SingleTickerProviderStateMixin {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitted = false;
  bool _isSaving = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onStarTap(int star) {
    setState(() => _rating = star);
    _animController.forward(from: 0);
  }

  void _onSubmit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(appStringsProvider).pleaseSelectRating),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(appStringsProvider).youMustBeSignedIn),
          ),
        );
      }
      setState(() => _isSaving = false);
      return;
    }

    try {
      await ref
          .read(supabaseRepositoryProvider)
          .submitReview(
            jobId: widget.jobId,
            reviewerId: userId,
            revieweeId: widget.otherPartyId,
            rating: _rating,
            comment: _commentController.text.trim(),
          );
      if (!context.mounted) return;
      setState(() {
        _isSubmitted = true;
        _isSaving = false;
      });
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${ref.read(appStringsProvider).reviewSubmitFailed}$e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitted) {
      return Scaffold(
        appBar: AppBar(
          title: Text(ref.watch(appStringsProvider).reviewSubmitted),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 80,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  ref.watch(appStringsProvider).reviewThanks,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  ref.watch(appStringsProvider).reviewCommunityMsg,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(ref.watch(appStringsProvider).done),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(ref.watch(appStringsProvider).rateExperience)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // ─── Job info ────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.work_outline,
                    size: 28,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.jobTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${ref.watch(appStringsProvider).reviewWith}${widget.otherPartyName}',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ─── Rating stars ────────────────────────────────
            Text(
              ref.watch(appStringsProvider).howWasExperience,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ScaleTransition(
              scale: _scaleAnim,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starNum = index + 1;
                  final isFilled = starNum <= _rating;
                  return GestureDetector(
                    onTap: () => _onStarTap(starNum),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          isFilled
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          key: ValueKey(isFilled),
                          size: 44,
                          color: isFilled
                              ? AppTheme.accentColor
                              : AppTheme.textDisabled,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _rating > 0
                  ? ref.watch(appStringsProvider).ratingLabels[_rating - 1]
                  : ref.watch(appStringsProvider).tapStarToRate,
              style: TextStyle(
                color: _rating > 0
                    ? AppTheme.accentDark
                    : AppTheme.textDisabled,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),

            // ─── Comment ─────────────────────────────────────
            Text(
              ref.watch(appStringsProvider).leaveComment,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: ref.watch(appStringsProvider).shareExperienceHint,
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              maxLength: 300,
            ),
            const SizedBox(height: 32),

            // ─── Submit ──────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _onSubmit,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isSaving
                      ? ref.watch(appStringsProvider).submitting
                      : ref.watch(appStringsProvider).submitReview,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable star rating display widget (read-only, for profile cards)
class StarRatingDisplay extends StatelessWidget {
  final double rating;
  final double size;
  final int starCount;

  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.size = 16,
    this.starCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(starCount, (index) {
        final starValue = index + 1;
        final fill = rating >= starValue
            ? 1.0
            : rating > starValue - 1
            ? rating - (starValue - 1)
            : 0.0;
        return Icon(
          fill >= 0.75
              ? Icons.star_rounded
              : fill >= 0.25
              ? Icons.star_half_rounded
              : Icons.star_outline_rounded,
          size: size,
          color: AppTheme.accentColor,
        );
      }),
    );
  }
}
