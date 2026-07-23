import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';
import 'package:local_services_marketplace/core/services/supabase_repository.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';

/// Provider that fetches all reviews where the current user is either
/// the reviewer or the reviewee.
final userReviewsListProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final repo = ref.watch(supabaseRepositoryProvider);
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return [];
  return repo.getUserReviews(userId);
});

/// Reviews list screen — shows all reviews where the current user is
/// either the reviewer or the reviewee, with tabs to filter by direction.
/// Works for both workers (reviews from employers) and employers (reviews
/// from workers for completed jobs).
class ReviewsListView extends ConsumerStatefulWidget {
  const ReviewsListView({super.key});

  @override
  ConsumerState<ReviewsListView> createState() => _ReviewsListViewState();
}

class _ReviewsListViewState extends ConsumerState<ReviewsListView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  VoidCallback? _tabListener;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabListener = () {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    };
    _tabController.addListener(_tabListener!);
  }

  @override
  void dispose() {
    if (_tabListener != null) {
      _tabController.removeListener(_tabListener!);
    }
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final userId = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.myReviews),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          tabs: [
            Tab(text: s.reviewAllTab),
            Tab(text: s.reviewGivenTab),
            Tab(text: s.reviewReceivedTab),
          ],
        ),
      ),
      body: ref
          .watch(userReviewsListProvider)
          .when(
            data: (reviews) {
              if (reviews.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.rate_review_outlined,
                          size: 64,
                          color: AppTheme.textDisabled,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          s.noReviewsYet,
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.reviewsAppearAfterJobs,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textDisabled,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Filter by tab
              final filtered = switch (_tabController.index) {
                1 => reviews.where((r) => r['reviewer_id'] == userId).toList(),
                2 => reviews.where((r) => r['reviewee_id'] == userId).toList(),
                _ => reviews,
              };

              if (filtered.isEmpty) {
                final emptyMsg = _tabController.index == 1
                    ? s.noGivenReviews
                    : s.noReceivedReviews;
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.rate_review_outlined,
                          size: 64,
                          color: AppTheme.textDisabled,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          emptyMsg,
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(userReviewsListProvider);
                  await Future.delayed(const Duration(milliseconds: 300));
                },
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final review = filtered[index];
                    final isGiven = review['reviewer_id'] == userId;
                    final otherParty =
                        (isGiven ? review['reviewee'] : review['reviewer'])
                            as Map<String, dynamic>?;
                    final otherName =
                        otherParty?['full_name'] as String? ?? 'Unknown';
                    final jobInfo = review['jobs'] as Map<String, dynamic>?;
                    final jobTitle = jobInfo?['title'] as String? ?? '';
                    final rating = review['rating'] as int? ?? 0;
                    final comment = review['comment'] as String?;
                    final createdAt = review['created_at'] as String?;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header: direction badge + date
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isGiven
                                          ? AppTheme.primaryColor.withValues(
                                              alpha: 0.1,
                                            )
                                          : AppTheme.accentColor.withValues(
                                              alpha: 0.1,
                                            ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isGiven
                                          ? s.reviewsGiven
                                          : s.reviewsReceived,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isGiven
                                            ? AppTheme.primaryColor
                                            : AppTheme.accentDark,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatDate(createdAt),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textDisabled,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Other party name
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppTheme.surfaceColor,
                                    child: Text(
                                      otherName.isNotEmpty
                                          ? otherName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      otherName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Star rating
                              Row(
                                children: List.generate(5, (i) {
                                  return Icon(
                                    i < rating
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    size: 18,
                                    color: i < rating
                                        ? AppTheme.accentColor
                                        : AppTheme.textDisabled,
                                  );
                                }),
                              ),

                              // Job reference
                              if (jobTitle.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  '${s.reviewsForJob} $jobTitle',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],

                              // Comment
                              if (comment != null && comment.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    comment,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textPrimary,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 48,
                      color: AppTheme.errorColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${ref.watch(appStringsProvider).error}: $err',
                      style: const TextStyle(color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.invalidate(userReviewsListProvider),
                      child: Text(ref.watch(appStringsProvider).retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  String _formatDate(String? iso) {
    final dt = DateTime.tryParse(iso ?? '');
    if (dt == null) return '';
    final months = ref.read(appStringsProvider).monthsShort;
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
