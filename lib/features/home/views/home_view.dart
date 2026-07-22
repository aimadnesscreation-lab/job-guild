import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/utils/responsive.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';
import 'package:local_services_marketplace/core/providers/tutorial_provider.dart';
import 'package:local_services_marketplace/core/services/supabase_repository.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/core/widgets/coach_mark_overlay.dart';
import 'package:local_services_marketplace/features/home/providers/role_provider.dart';
import 'package:local_services_marketplace/features/worker/models/worker_profile_model.dart';
import 'package:local_services_marketplace/features/chat/views/chat_list_view.dart';
import 'package:local_services_marketplace/features/home/views/employer_dashboard.dart';
import 'package:local_services_marketplace/features/home/views/worker_dashboard.dart';
import 'package:local_services_marketplace/features/jobs/models/job_model.dart';
import 'package:local_services_marketplace/features/jobs/providers/job_feed_provider.dart';
import 'package:local_services_marketplace/features/jobs/views/post_job_view.dart';
import 'package:local_services_marketplace/features/jobs/views/search_workers_view.dart';
import 'package:local_services_marketplace/features/notifications/views/notifications_view.dart';
import 'package:local_services_marketplace/features/settings/views/settings_view.dart';
import 'package:local_services_marketplace/features/worker/views/edit_worker_profile_view.dart';
import 'package:local_services_marketplace/features/jobs/views/job_detail_view.dart';
import 'package:local_services_marketplace/features/jobs/views/job_detail_worker_view.dart';
import 'package:local_services_marketplace/features/worker/views/worker_public_profile_view.dart';
import 'package:local_services_marketplace/features/worker/providers/worker_provider.dart';
import 'package:local_services_marketplace/core/widgets/shimmer_loading.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';
import 'package:local_services_marketplace/features/ratings/views/reviews_list_view.dart';

/// Main home screen — entry point after authentication.
/// Connects all real screens: feed, search, post job, messages, dashboard.
class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  int _currentTabIndex = 0;
  final _navBarGlobalKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Rebuild after layout so CoachMarkOverlay can read nav bar dimensions.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final tutorialAsync = ref.watch(tutorialCompletedProvider);
    final unreadCount =
        ref.watch(unreadNotificationCountProvider).asData?.value ?? 0;

    return tutorialAsync.when(
      data: (tutorialCompleted) {
        Widget scaffold = Scaffold(
      // Only show AppBar for Home and Dashboard tabs — child screens have their own
      appBar: _currentTabIndex == 0 || _currentTabIndex == 4
          ? AppBar(
              title: Text(
                _currentTabIndex == 0
                    ? ref.watch(appStringsProvider).appName
                    : _tabTitle(_currentTabIndex),
              ),
              actions: [
                if (_currentTabIndex == 0) ...[
                  // Role toggle — seamless employer/worker switch
                  IconButton(
                    icon: Icon(
                      ref.watch(currentRoleProvider) == AppRole.worker
                          ? Icons.work_rounded
                          : Icons.work_outline,
                      color: ref.watch(currentRoleProvider) == AppRole.worker
                          ? AppTheme.primaryColor
                          : null,
                    ),
                    tooltip:
                        'Switch to ${ref.watch(currentRoleProvider) == AppRole.employer ? 'Worker' : 'Employer'} mode',
                    onPressed: () {
                      ref.read(currentRoleProvider.notifier).toggle();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.favorite_border_rounded),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FavoritesView()),
                    ),
                  ),
                  Badge(
                    isLabelVisible: unreadCount > 0,
                    label: Text(
                      '$unreadCount',
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsView(),
                          ),
                        );
                        // Refresh the badge after returning from notifications
                        if (context.mounted) {
                          ref.invalidate(unreadNotificationCountProvider);
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.person_outline),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditWorkerProfileView(),
                      ),
                    ),
                  ),
                ],
                if (_currentTabIndex == 4) ...[
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsView()),
                    ),
                  ),
                ],
              ],
            )
          : null,
      body: IndexedStack(
        index: _currentTabIndex,
        children: const [
          _HomeFeedTab(),
          SearchWorkersView(),
          PostJobView(),
          ChatListView(),
          _DashboardContainer(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        key: _navBarGlobalKey,
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home_rounded),
            label: ref.watch(appStringsProvider).tabHome,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.search_outlined),
            activeIcon: const Icon(Icons.search_rounded),
            label: ref.watch(appStringsProvider).tabSearch,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.add_circle_outline),
            activeIcon: const Icon(Icons.add_circle_rounded),
            label: ref.watch(appStringsProvider).tabPostJob,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_outlined),
            activeIcon: const Icon(Icons.chat_rounded),
            label: ref.watch(appStringsProvider).tabMessages,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard_outlined),
            activeIcon: const Icon(Icons.dashboard_rounded),
            label: ref.watch(appStringsProvider).tabDashboard,
          ),
        ],
      ),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PostJobView(resetOnInit: true)),
              ),
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );

        // Wrap scaffold in a Stack to overlay coach marks on first launch
        if (!tutorialCompleted) {
          return Stack(
            children: [
              scaffold,
              // Measure the bottom nav bar using its GlobalKey, then show overlay
              CoachMarkOverlay(
                bottomNavWidth:
                    _navBarGlobalKey.currentContext?.size?.width ??
                    MediaQuery.of(context).size.width,
                bottomNavHeight:
                    _navBarGlobalKey.currentContext?.size?.height ??
                    MediaQuery.of(context).size.height * 0.08,
              ),
            ],
          );
        }

        return scaffold;
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => const Scaffold(
        body: Center(child: Text('Failed to load tutorial state')),
      ),
    );
  }

  String _tabTitle(int index) {
    final s = ref.watch(appStringsProvider);
    switch (index) {
      case 0:
        return ''; // Home - uses app name
      case 1:
        return s.findWorkersTitle;
      case 2:
        return s.postAJob;
      case 3:
        return s.tabMessages;
      case 4:
        return s.tabDashboard;
      default:
        return '';
    }
  }
}

/// Home feed tab — adapts content based on current role.
/// In worker mode: shows nearby job listings.
/// In employer mode: shows worker search and browse.
class _HomeFeedTab extends ConsumerWidget {
  const _HomeFeedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);

    // Employer mode: show worker search/browse
    if (role == AppRole.employer) {
      return const SearchWorkersView();
    }

    // Worker mode: show live job feed
    final jobsAsync = ref.watch(openJobsProvider);
    final strings = ref.watch(appStringsProvider);
    final width = MediaQuery.of(context).size.width;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(liveJobFeedProvider);
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView(
        padding: Breakpoints.horizontalPadding(width),
        children: [
          // Welcome card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.welcomeTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.welcomeSubtitle,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PostJobView(),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(strings.postAJob),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SearchWorkersView(),
                            ),
                          ),
                          icon: const Icon(Icons.person_search_rounded),
                          label: Text(strings.findWorkers),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                strings.nearbyJobs,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              jobsAsync.isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 8),
          jobsAsync.when(
            data: (jobs) {
              if (jobs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.work_off_outlined,
                          size: 48,
                          color: AppTheme.textDisabled,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          strings.noOpenJobs,
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strings.postJobToStart,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textDisabled,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: jobs.take(10).map((job) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RealtimeJobCard(
                      job: job,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _JobDetailScreen(job: job),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: JobFeedShimmer(),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 48,
                      color: AppTheme.errorColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${strings.couldNotLoadJobs} $err',
                      style: const TextStyle(color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.invalidate(liveJobFeedProvider),
                      child: Text(ref.watch(appStringsProvider).retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _QuickLinkCard(
                  icon: Icons.star_rounded,
                  label: ref.watch(appStringsProvider).myReviews,
                  color: AppTheme.accentColor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReviewsListView()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickLinkCard(
                  icon: Icons.settings_rounded,
                  label: ref.watch(appStringsProvider).settings,
                  color: AppTheme.textSecondary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsView()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickLinkCard(
                  icon: Icons.verified_rounded,
                  label: ref.watch(appStringsProvider).publicProfile,
                  color: AppTheme.verifiedBadge,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WorkerPublicProfileView(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A job card that syncs live via Realtime
class _RealtimeJobCard extends ConsumerWidget {
  final Job job;
  final VoidCallback? onTap;

  const _RealtimeJobCard({required this.job, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUrgent = job.isInstant;
    final budgetStr = job.budgetDisplay;
    final s = ref.watch(appStringsProvider);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isUrgent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '⚡ URGENT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (isUrgent) const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      categoryNameToId.entries
                              .firstWhere(
                                (e) => e.value == job.categoryId,
                                orElse: () => const MapEntry('', 0),
                              )
                              .key
                              .isNotEmpty
                          ? categoryNameToId.entries
                                .firstWhere((e) => e.value == job.categoryId)
                                .key
                          : 'Cat #${job.categoryId}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    job.locationText ?? 'Nearby',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                job.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.monetization_on_outlined,
                    size: 16,
                    color: AppTheme.accentDark,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    budgetStr,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentDark,
                    ),
                  ),
                  const Spacer(),
                  TextButton(onPressed: onTap, child: Text(s.viewDetails)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashboard tab toggles between employer and worker view, synced with the
/// global [currentRoleProvider] so the role toggle in the app bar is reflected
/// here too.
class _DashboardContainer extends ConsumerStatefulWidget {
  const _DashboardContainer();

  @override
  ConsumerState<_DashboardContainer> createState() =>
      _DashboardContainerState();
}

class _DashboardContainerState extends ConsumerState<_DashboardContainer>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Sync with global role provider
    ref.listenManual(currentRoleProvider, (_, next) {
      final target = next == AppRole.worker ? 1 : 0;
      if (_tabController.index != target) _tabController.index = target;
    });
    // Also sync from worker profile
    ref.listenManual(myWorkerProfileProvider, (_, next) {
      final isWorker = next.value != null;
      if (isWorker) {
        ref.read(currentRoleProvider.notifier).setRole(AppRole.worker);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primaryColor,
            tabs: [
              Tab(text: ref.watch(appStringsProvider).employer),
              Tab(text: ref.watch(appStringsProvider).worker),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [EmployerDashboard(), WorkerDashboard()],
          ),
        ),
      ],
    );
  }
}

class _QuickLinkCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickLinkCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Proper job detail screen routing based on ownership + current role.
class _JobDetailScreen extends ConsumerWidget {
  final Job job;

  const _JobDetailScreen({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isMyJob = user?.id == job.employerId;

    // Navigate to the employer view if this user posted the job, otherwise
    // show the worker view with the "I'm Interested" button.
    Widget child;
    if (isMyJob) {
      child = JobDetailView(job: job);
    } else {
      child = JobDetailWorkerView(job: job);
    }

    return child;
  }
}

/// Favorites view — shows the user's saved/favorite workers.
class FavoritesView extends ConsumerWidget {
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesListProvider);
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.savedWorkers)),
      body: favoritesAsync.when(
        data: (favorites) {
          if (favorites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.favorite_border_rounded,
                    size: 64,
                    color: AppTheme.textDisabled,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.noSavedWorkers,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.favoritesHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textDisabled,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final worker = favorites[index];
              // The getFavorites() query returns data nested under favorited_user_id
              // with worker_profiles as a sub-object.
              final Map<String, dynamic> favoritedUser =
                  (worker['favorited_user_id'] as Map<String, dynamic>?) ??
                  worker;
              final Map<String, dynamic>? wp =
                  favoritedUser['worker_profiles'] as Map<String, dynamic>?;
              final name = favoritedUser['full_name'] as String? ?? 'Worker';
              final headline = wp?['headline'] as String? ?? '';
              final workerId = favoritedUser['id'] as String? ?? '';
              final isVerified = favoritedUser['is_verified'] as bool? ?? false;
              final averageRating =
                  (wp?['average_rating'] as num?)?.toDouble() ?? 0;
              final totalJobsCompleted =
                  (wp?['total_jobs_completed'] as num?)?.toInt() ?? 0;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(name),
                subtitle: headline.isNotEmpty ? Text(headline) : null,
                trailing: IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppTheme.textDisabled,
                  ),
                  onPressed: () {
                    final userId = ref.read(currentUserProvider)?.id;
                    if (userId != null && workerId.isNotEmpty) {
                      ref
                          .read(supabaseRepositoryProvider)
                          .toggleFavorite(userId, workerId)
                          .then((_) => ref.invalidate(favoritesListProvider));
                    }
                  },
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkerPublicProfileView(
                        profile: WorkerProfile(
                          userId: workerId,
                          fullName: name,
                          headline: headline,
                          averageRating: averageRating,
                          totalJobsCompleted: totalJobsCompleted,
                          isVerified: isVerified,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
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
                  '${s.error}: $err',
                  style: const TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(favoritesListProvider),
                  child: Text(s.retry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Provider that fetches the unread notification count for the bell badge.
final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(supabaseRepositoryProvider);
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return 0;
  return repo.getUnreadNotificationCount(userId);
});

/// Provider that fetches the current user's favorite workers
final favoritesListProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final repo = ref.watch(supabaseRepositoryProvider);
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return [];
  return repo.getFavorites(userId);
});
