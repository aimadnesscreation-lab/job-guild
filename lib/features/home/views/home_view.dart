import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
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
import 'package:local_services_marketplace/features/worker/views/worker_public_profile_view.dart';
import 'package:local_services_marketplace/features/worker/providers/worker_provider.dart';

/// Main home screen — entry point after authentication.
/// Connects all real screens: feed, search, post job, messages, dashboard.
class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  int _currentTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Only show AppBar for Home and Dashboard tabs — child screens have their own
      appBar: _currentTabIndex == 0 || _currentTabIndex == 4
          ? AppBar(
              title: Text(
                _currentTabIndex == 0
                    ? 'Local Services Marketplace'
                    : _tabTitles[_currentTabIndex],
              ),
              actions: [
                if (_currentTabIndex == 0) ...[
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const NotificationsView()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.person_outline),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const EditWorkerProfileView()),
              ),
            ),
          ],
                if (_currentTabIndex == 4) ...[
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsView()),
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
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search_rounded),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle_rounded),
            label: 'Post Job',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_outlined),
            activeIcon: Icon(Icons.chat_rounded),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
        ],
      ),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PostJobView()),
              ),
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  static const _tabTitles = [
    '', // Home - uses app name
    'Find Workers',
    'Post a Job',
    'Messages',
    'Dashboard',
  ];
}

/// Home feed tab with live job feed from Supabase Realtime
class _HomeFeedTab extends ConsumerWidget {
  const _HomeFeedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(openJobsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        // Force-refresh by invalidating the provider
        ref.invalidate(liveJobFeedProvider);
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Welcome card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome to Local Services Marketplace',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Find nearby professionals or post a job to get started.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PostJobView()),
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Post a Job'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const SearchWorkersView()),
                          ),
                          icon: const Icon(Icons.person_search_rounded),
                          label: const Text('Find Workers'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Job Feed',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              // Connection status indicator
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
          // Live job cards from Supabase Realtime
          jobsAsync.when(
            data: (jobs) {
              if (jobs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.work_off_outlined,
                            size: 48, color: AppTheme.textDisabled),
                        SizedBox(height: 12),
                        Text(
                          'No open jobs nearby',
                          style: TextStyle(
                              color: AppTheme.textSecondary),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Post a job to get started',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textDisabled),
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
                    child: _RealtimeJobCard(job: job),
                  );
                }).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off_rounded,
                        size: 48, color: AppTheme.errorColor),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load jobs: $err',
                      style: const TextStyle(
                          color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(liveJobFeedProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Quick links
          Row(
            children: [
              Expanded(
                child: _QuickLinkCard(
                  icon: Icons.star_rounded,
                  label: 'My Reviews',
                  color: AppTheme.accentColor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Reviews')),
                        body: const Center(
                            child: Text('Reviews coming soon')),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickLinkCard(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  color: AppTheme.textSecondary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SettingsView()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickLinkCard(
                  icon: Icons.verified_rounded,
                  label: 'Public Profile',
                  color: AppTheme.verifiedBadge,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const WorkerPublicProfileView()),
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
class _RealtimeJobCard extends StatelessWidget {
  final Job job;

  const _RealtimeJobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final isUrgent = job.isInstant;
    final budgetStr = job.budgetDisplay;
    final urgencyStr = _urgencyDisplay(job.urgency);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Job Details')),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(job.description,
                        style: const TextStyle(
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.monetization_on_outlined, size: 16),
                        const SizedBox(width: 4),
                        Text(budgetStr),
                        const Spacer(),
                        const Icon(Icons.access_time_rounded, size: 16),
                        const SizedBox(width: 4),
                        Text(urgencyStr),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
                          horizontal: 8, vertical: 2),
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
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Cat #${job.categoryId}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 2),
                  Text(
                    job.locationText ?? 'Nearby',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary),
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
                  const Icon(Icons.monetization_on_outlined,
                      size: 16, color: AppTheme.accentDark),
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
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Job Details')),
                          body: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(job.description),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('View Details'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _urgencyDisplay(Urgency u) {
    switch (u) {
      case Urgency.instant:
        return 'Now';
      case Urgency.today:
        return 'Today';
      case Urgency.scheduled:
        return 'Scheduled';
    }
  }
}

/// Dashboard tab toggles between employer and worker view, defaulting to the
/// tab that matches the current user's role (a worker profile present means
/// the user is acting as a worker).
class _DashboardContainer extends ConsumerStatefulWidget {
  const _DashboardContainer();

  @override
  ConsumerState<_DashboardContainer> createState() => _DashboardContainerState();
}

class _DashboardContainerState extends ConsumerState<_DashboardContainer>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Once the worker profile resolves, switch to the matching dashboard tab.
    ref.listenManual(myWorkerProfileProvider, (_, next) {
      final isWorker = next.value != null;
      final target = isWorker ? 1 : 0;
      if (_tabController.index != target) _tabController.index = target;
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
            tabs: const [
              Tab(text: 'Employer'),
              Tab(text: 'Worker'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              EmployerDashboard(),
              WorkerDashboard(),
            ],
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
