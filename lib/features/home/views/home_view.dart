import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/utils/responsive.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';
import 'package:local_services_marketplace/core/providers/tutorial_provider.dart';
import 'package:local_services_marketplace/core/services/supabase_repository.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/core/widgets/coach_mark_overlay.dart';
import 'package:local_services_marketplace/features/home/providers/role_provider.dart';
import 'package:local_services_marketplace/features/chat/views/chat_list_view.dart';
import 'package:local_services_marketplace/features/home/views/employer_dashboard.dart';
import 'package:local_services_marketplace/features/home/views/favorites_view.dart';
import 'package:local_services_marketplace/features/home/views/worker_dashboard.dart';
import 'package:local_services_marketplace/features/jobs/models/job_model.dart';
import 'package:local_services_marketplace/features/jobs/providers/job_feed_provider.dart';
import 'package:local_services_marketplace/features/jobs/views/post_job_view.dart';
import 'package:local_services_marketplace/features/jobs/providers/job_provider.dart';
import 'package:local_services_marketplace/features/jobs/views/search_workers_view.dart';
import 'package:local_services_marketplace/features/notifications/views/notifications_view.dart';
import 'package:local_services_marketplace/features/settings/views/settings_view.dart';
import 'package:local_services_marketplace/features/worker/views/edit_worker_profile_view.dart';
import 'package:local_services_marketplace/features/jobs/views/job_detail_view.dart';
import 'package:local_services_marketplace/features/jobs/views/job_detail_worker_view.dart';

import 'package:local_services_marketplace/core/widgets/shimmer_loading.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';

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
        final role = ref.watch(currentRoleProvider);
        final isWorker = role == AppRole.worker;

        Widget scaffold = Scaffold(
      appBar: _currentTabIndex == 0 || _currentTabIndex == 3
          ? AppBar(
              title: Text(
                _currentTabIndex == 0
                    ? ref.watch(appStringsProvider).appName
                    : _tabTitle(_currentTabIndex),
              ),
              actions: [
                if (_currentTabIndex == 0 && !isWorker) ...[
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
                if (_currentTabIndex == 0 && isWorker) ...[
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
                if (_currentTabIndex == 3) ...[
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
        children: isWorker
            ? const [
                _HomeFeedTab(),        // Job feed (index 0)
                SearchWorkersContent(), // Search jobs (index 1)
                ChatListView(),        // Messages (index 2)
                WorkerDashboard(),     // Dashboard (index 3)
              ]
            : const [
                EmployerDashboard(),   // Dashboard (index 0)
                SearchWorkersContent(), // Find Workers (index 1)
                _PostJobRoute(),        // Post a Job (index 2)
                ChatListView(),         // Messages (index 3)
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
        items: isWorker
            ? [
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
                  icon: const Icon(Icons.chat_outlined),
                  activeIcon: const Icon(Icons.chat_rounded),
                  label: ref.watch(appStringsProvider).tabMessages,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.dashboard_outlined),
                  activeIcon: const Icon(Icons.dashboard_rounded),
                  label: ref.watch(appStringsProvider).tabDashboard,
                ),
              ]
            : [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.space_dashboard_outlined),
                  activeIcon: const Icon(Icons.space_dashboard_rounded),
                  label: ref.watch(appStringsProvider).tabDashboard,
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
              ],
      ),
      floatingActionButton: _currentTabIndex == 0 && !isWorker
          ? FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const _PostJobRoute()),
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
      error: (e, st) => Scaffold(
        body: Center(child: Text(ref.read(appStringsProvider).tutorialLoadFailed)),
      ),
    );
  }

  String _tabTitle(int index) {
    final s = ref.watch(appStringsProvider);
    if (ref.watch(currentRoleProvider) == AppRole.worker) {
      switch (index) {
        case 0:
          return s.nearbyJobs;
        case 1:
          return s.tabSearch;
        case 2:
          return s.tabMessages;
        case 3:
          return s.tabDashboard;
        default:
          return '';
      }
    }
    switch (index) {
      case 0:
        return ''; // Dashboard - uses app name
      case 1:
        return s.findWorkersTitle;
      case 2:
        return s.postAJob;
      case 3:
        return s.tabMessages;
      default:
        return '';
    }
  }
}

/// Home feed tab — shows nearby job listings for workers.
/// This widget is only used in the worker IndexedStack, so it always
/// renders the worker-side content (job feed with welcome card).
class _HomeFeedTab extends ConsumerWidget {
  const _HomeFeedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Worker mode: show live job feed with a worker-specific welcome card.
    final jobsAsync = ref.watch(openJobsProvider);
    final strings = ref.watch(appStringsProvider);
    final width = MediaQuery.of(context).size.width;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(liveJobFeedProvider);
        final completer = Completer<void>();
        bool hadError = false;
        Object? capturedError;
        final sub = ref.listenManual<AsyncValue<List<Job>>>(
          liveJobFeedProvider,
          (_, next) {
            if (next.hasError) {
              hadError = true;
              capturedError = next.error;
            }
            if (next.isLoading) return;
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
        );
        try {
          await completer.future.timeout(const Duration(seconds: 5));
          if (hadError && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${strings.couldNotLoadJobs} $capturedError',
                ),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        } catch (_) {
          // Timeout — stream keeps trying in background.
        } finally {
          sub.close();
        }
      },
      child: ListView(
        padding: Breakpoints.horizontalPadding(width),
        children: [
          // Worker welcome card
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
                      child: Text(
                        s.urgentBadge,
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
                      (() {
                        final entry = categoryNameToId.entries
                            .firstWhere(
                              (e) => e.value == job.categoryId,
                              orElse: () => const MapEntry('', 0),
                            );
                        return entry.key.isNotEmpty
                            ? entry.key
                            : s.categoryFallback(job.categoryId);
                      })(),
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

/// Proper job detail screen routing based on ownership + current role.
class _JobDetailScreen extends ConsumerWidget {
  final Job job;

  const _JobDetailScreen({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);

    // Workers see the worker view (with "I'm Interested" button).
    // Employers see the employer view (applicants, hire, etc).
    if (role == AppRole.worker) {
      return JobDetailWorkerView(job: job);
    }
    return JobDetailView(job: job);
  }
}

/// Route wrapper that gives every pushed PostJobView its own [postJobProvider]
/// instance so it cannot share stale form state with the bottom-nav tab.
class _PostJobRoute extends StatelessWidget {
  const _PostJobRoute();

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        postJobProvider.overrideWith(() => PostJobNotifier()),
      ],
      child: const PostJobView(),
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


