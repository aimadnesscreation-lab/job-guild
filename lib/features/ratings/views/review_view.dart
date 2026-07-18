import 'package:flutter/material.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';

/// Two-way ratings & reviews screen triggered after a job is marked complete.
/// Both employer and worker rate each other with 1-5 stars + comment.
class ReviewView extends StatefulWidget {
  final String jobTitle;
  final String otherPartyName;
  final bool isReviewingWorker; // false = worker reviewing employer

  const ReviewView({
    super.key,
    required this.jobTitle,
    required this.otherPartyName,
    this.isReviewingWorker = true,
  });

  @override
  State<ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends State<ReviewView>
    with SingleTickerProviderStateMixin {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitted = false;
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

  void _onSubmit() {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating first')),
      );
      return;
    }
    setState(() => _isSubmitted = true);
    // TODO: Save review to Supabase
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitted) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Submitted')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 80, color: AppTheme.primaryColor),
                const SizedBox(height: 16),
                const Text(
                  'Thank you for your review!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your feedback helps build trust in the community.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Rate Your Experience')),
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
                  const Icon(Icons.work_outline,
                      size: 28, color: AppTheme.primaryColor),
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
                    'with ${widget.otherPartyName}',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ─── Rating stars ────────────────────────────────
            const Text(
              'How was your experience?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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
              _rating > 0 ? _ratingLabels[_rating - 1] : 'Tap a star to rate',
              style: TextStyle(
                color: _rating > 0
                    ? AppTheme.accentDark
                    : AppTheme.textDisabled,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),

            // ─── Comment ─────────────────────────────────────
            const Text(
              'Leave a comment (optional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: 'Share your experience...',
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
                onPressed: _onSubmit,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Submit Review',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _ratingLabels = [
    'Poor — Needs improvement',
    'Fair — Below average',
    'Good — Satisfactory',
    'Very Good — Above average',
    'Excellent — Outstanding!',
  ];
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
