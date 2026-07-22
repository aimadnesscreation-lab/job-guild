import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/features/worker/providers/worker_provider.dart';
import 'package:local_services_marketplace/core/widgets/shimmer_loading.dart';
import 'package:local_services_marketplace/features/worker/views/worker_public_profile_view.dart';
import 'package:local_services_marketplace/features/worker/models/worker_profile_model.dart';

/// Search and browse workers screen with filters: category, distance,
/// price range, rating, availability, verified-only. Backed by the live
/// nearby-workers query (PostGIS), with local filtering on top.
class SearchWorkersView extends ConsumerStatefulWidget {
  const SearchWorkersView({super.key});

  @override
  ConsumerState<SearchWorkersView> createState() => _SearchWorkersViewState();
}

class _SearchWorkersViewState extends ConsumerState<SearchWorkersView> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  double _maxDistance = 15;
  double _minRating = 0.0;
  bool _verifiedOnly = false;
  String _selectedAvailability = 'Any';

  final _categories = [
    'All',
    'Plumbing',
    'Electrical',
    'Painting',
    'Carpentry',
    'Cleaning',
    'Tutor',
    'Mechanic',
    'Moving',
    'Cook',
    'Photographer',
    'General Labor',
  ];

  final _availabilityOptions = [
    'Any',
    'Today',
    'Tomorrow',
    'Weekdays',
    'Weekends',
    'Morning',
    'Evening',
  ];

  List<_WorkerResult> get _fromProvider {
    final async = ref.watch(nearbyWorkersProvider);
    final data = async.value ?? [];
    return data.map(_WorkerResult.fromMap).toList();
  }

  List<_WorkerResult> get _filtered {
    final q = _searchController.text.toLowerCase();
    return _fromProvider.where((w) {
      final matchesCategory =
          _selectedCategory == 'All' || w.category == _selectedCategory;
      final matchesRating = w.rating >= _minRating;
      final matchesVerified = !_verifiedOnly || w.isVerified;
      final matchesSearch =
          q.isEmpty ||
          w.name.toLowerCase().contains(q) ||
          w.category.toLowerCase().contains(q);
      final matchesAvailability =
          _selectedAvailability == 'Any' ||
          w.availability.toLowerCase() ==
              _selectedAvailability.toLowerCase();
      // distance_meters is returned by the nearby-workers RPC.
      final distanceKm = w.distanceMeters / 1000.0;
      final matchesDistance = distanceKm <= _maxDistance;
      return matchesCategory &&
          matchesRating &&
          matchesVerified &&
          matchesSearch &&
          matchesAvailability &&
          matchesDistance;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(nearbyWorkersProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(ref.watch(appStringsProvider).findWorkersTitle),
      ),
      body: Column(
        children: [
          // ─── Search Bar ────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: ref.watch(appStringsProvider).searchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // ─── Filter Chips ──────────────────────────────────
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _FilterChip(
                    label: _verifiedOnly
                        ? '${ref.watch(appStringsProvider).verifiedOnly} ✓'
                        : ref.watch(appStringsProvider).verifiedOnly,
                    icon: Icons.verified_rounded,
                    isSelected: _verifiedOnly,
                    onTap: () => setState(() => _verifiedOnly = !_verifiedOnly),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Min ${_minRating.toStringAsFixed(1)} ★',
                    icon: Icons.star_rounded,
                    isSelected: _minRating > 3.0,
                    onTap: () => _showRatingFilter(),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '${_maxDistance.toInt()} km',
                    icon: Icons.near_me_rounded,
                    isSelected: _maxDistance < 50,
                    onTap: () => _showDistanceFilter(),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: _selectedAvailability,
                    icon: Icons.schedule_rounded,
                    isSelected: _selectedAvailability != 'Any',
                    onTap: () => _showAvailabilityFilter(),
                  ),
                ],
              ),
            ),
          ),

          // ─── Category Tabs ─────────────────────────────────
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            color: Colors.white,
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryColor.withValues(
                      alpha: 0.15,
                    ),
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                    side: BorderSide(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.borderColor,
                    ),
                  );
                },
              ),
            ),
          ),

          const Divider(height: 1),

          // ─── Results ───────────────────────────────────────
          Expanded(
            child: async.isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: WorkerSearchShimmer(),
                  )
                : RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(nearbyWorkersProvider),
                    child: _filtered.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.2,
                              ),
                              Center(
                                child: Text(
                                  ref.watch(appStringsProvider).noWorkersMatch,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            children: _filtered
                                .map(
                                  (worker) => _WorkerResultCard(worker: worker),
                                )
                                .toList(),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showRatingFilter() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ref.watch(appStringsProvider).minimumRating,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Slider(
                value: _minRating,
                min: 0,
                max: 5,
                divisions: 10,
                label: _minRating.toStringAsFixed(1),
                onChanged: (val) {
                  setSheetState(() => _minRating = val);
                  setState(() {});
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_minRating.toStringAsFixed(1)} ★',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentDark,
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(ref.watch(appStringsProvider).apply),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDistanceFilter() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ref.watch(appStringsProvider).maximumDistance,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Slider(
                value: _maxDistance,
                min: 1,
                max: 50,
                divisions: 49,
                label: '${_maxDistance.toInt()} km',
                onChanged: (val) {
                  setSheetState(() => _maxDistance = val);
                  setState(() {});
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_maxDistance.toInt()} km',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(ref.watch(appStringsProvider).apply),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAvailabilityFilter() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ref.watch(appStringsProvider).availability,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availabilityOptions.map((opt) {
                final isSelected = _selectedAvailability == opt;
                return ChoiceChip(
                  label: Text(opt),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                  onSelected: (_) {
                    setState(() => _selectedAvailability = opt);
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Result model mapped from the live nearby-workers query.
class _WorkerResult {
  final String id;
  final String name;
  final double rating;
  final int totalJobs;
  final String distance;
  final num distanceMeters;
  final String hourlyRate;
  final String category;
  final bool isVerified;
  final String availability;

  const _WorkerResult({
    required this.id,
    required this.name,
    required this.rating,
    required this.totalJobs,
    required this.distance,
    required this.distanceMeters,
    required this.hourlyRate,
    required this.category,
    required this.isVerified,
    required this.availability,
  });

  factory _WorkerResult.fromMap(Map<String, dynamic> m) {
    final rating = (m['average_rating'] as num?)?.toDouble() ?? 0;
    final distanceM = (m['distance_meters'] as num?)?.toDouble() ?? 0;
    final hourly = (m['hourly_rate_pkr'] as num?)?.toInt();
    return _WorkerResult(
      id: m['id'] as String? ?? '',
      name: m['full_name'] as String? ?? 'Worker',
      rating: rating,
      totalJobs: (m['total_jobs_completed'] as num?)?.toInt() ?? 0,
      distance: distanceM > 0
          ? '${(distanceM / 1000).toStringAsFixed(1)} km'
          : '—',
      distanceMeters: distanceM,
      hourlyRate: hourly != null ? 'Rs. $hourly/hr' : 'Negotiable',
      category: m['category'] as String? ?? 'General Labor',
      isVerified: m['is_verified'] as bool? ?? false,
      availability: m['availability'] as String? ?? 'Today',
    );
  }
}

class _WorkerResultCard extends ConsumerWidget {
  final _WorkerResult worker;

  const _WorkerResultCard({required this.worker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkerPublicProfileView(
                profile: WorkerProfile(
                  userId: worker.id,
                  fullName: worker.name,
                  headline: worker.category,
                  averageRating: worker.rating,
                  totalJobsCompleted: worker.totalJobs,
                  isVerified: worker.isVerified,
                  availabilityStatus: _availabilityFromString(
                    worker.availability,
                  ),
                ),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Text(
                  worker.name.isNotEmpty ? worker.name[0] : '?',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          worker.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (worker.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: AppTheme.verifiedBadge,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            worker.category,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppTheme.accentColor,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${worker.rating}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${worker.totalJobs} jobs)',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          worker.distance,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          worker.availability,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    worker.hourlyRate,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentDark,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WorkerPublicProfileView(
                            profile: WorkerProfile(
                              userId: worker.id,
                              fullName: worker.name,
                              headline: worker.category,
                              averageRating: worker.rating,
                              totalJobsCompleted: worker.totalJobs,
                              isVerified: worker.isVerified,
                              availabilityStatus: _availabilityFromString(
                                worker.availability,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      ref.watch(appStringsProvider).viewDetails,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

AvailabilityStatus _availabilityFromString(String s) {
  for (final v in AvailabilityStatus.values) {
    if (v.name.toLowerCase() == s.toLowerCase()) return v;
  }
  return AvailabilityStatus.today;
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
      ),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
      ),
      backgroundColor: isSelected
          ? AppTheme.primaryColor.withValues(alpha: 0.08)
          : null,
    );
  }
}
