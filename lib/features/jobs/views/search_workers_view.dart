import 'package:flutter/material.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';

/// Search and browse workers screen with filters: category, distance,
/// price range, rating, availability, verified-only.
class SearchWorkersView extends StatefulWidget {
  const SearchWorkersView({super.key});

  @override
  State<SearchWorkersView> createState() => _SearchWorkersViewState();
}

class _SearchWorkersViewState extends State<SearchWorkersView> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  double _maxDistance = 15;
  double _minRating = 3.0;
  bool _verifiedOnly = false;
  String _selectedAvailability = 'Any';

  final _categories = [
    'All', 'Plumbing', 'Electrical', 'Painting', 'Carpentry',
    'Cleaning', 'Tutor', 'Mechanic', 'Moving', 'Cook',
    'Photographer', 'General Labor',
  ];

  final _availabilityOptions = [
    'Any', 'Today', 'Tomorrow', 'Weekdays', 'Weekends', 'Morning', 'Evening',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Workers'),
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
                hintText: 'Search by name, skill, or category...',
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
                    label: _verifiedOnly ? 'Verified ✓' : 'Verified Only',
                    icon: Icons.verified_rounded,
                    isSelected: _verifiedOnly,
                    onTap: () => setState(() => _verifiedOnly = !_verifiedOnly),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Min ${_minRating.toStringAsFixed(1)} ⭐',
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
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                    onSelected: (_) =>
                        setState(() => _selectedCategory = cat),
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
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _searchResults
                  .where((w) =>
                      _selectedCategory == 'All' ||
                      w.category == _selectedCategory)
                  .where((w) => w.rating >= _minRating)
                  .where((w) => !_verifiedOnly || w.isVerified)
                  .map((worker) => _WorkerResultCard(worker: worker))
                  .toList(),
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
              const Text('Minimum Rating',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
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
                  Text('${_minRating.toStringAsFixed(1)} ⭐',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentDark)),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Apply'),
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
              const Text('Maximum Distance',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
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
                  Text('${_maxDistance.toInt()} km',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor)),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Apply'),
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
            const Text('Availability',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availabilityOptions.map((opt) {
                final isSelected = _selectedAvailability == opt;
                return ChoiceChip(
                  label: Text(opt),
                  selected: isSelected,
                  selectedColor:
                      AppTheme.primaryColor.withValues(alpha: 0.15),
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

  // ─── Mock Data ─────────────────────────────────────────────

  static final _searchResults = [
    _WorkerResult(
      name: 'Ahmed Khan',
      rating: 4.8,
      totalJobs: 127,
      distance: '1.2 km',
      hourlyRate: 'Rs. 500/hr',
      category: 'Plumbing',
      isVerified: true,
      availability: 'Today',
    ),
    _WorkerResult(
      name: 'Imran Ali',
      rating: 4.5,
      totalJobs: 83,
      distance: '2.5 km',
      hourlyRate: 'Rs. 400/hr',
      category: 'Electrical',
      isVerified: true,
      availability: 'Today',
    ),
    _WorkerResult(
      name: 'Sana Malik',
      rating: 4.9,
      totalJobs: 210,
      distance: '3.2 km',
      hourlyRate: 'Rs. 600/hr',
      category: 'Tutor',
      isVerified: true,
      availability: 'Weekdays',
    ),
    _WorkerResult(
      name: 'Sajid Mehmood',
      rating: 4.2,
      totalJobs: 45,
      distance: '3.8 km',
      hourlyRate: 'Rs. 350/hr',
      category: 'Painting',
      isVerified: false,
      availability: 'Weekends',
    ),
    _WorkerResult(
      name: 'Faisal Ahmed',
      rating: 4.6,
      totalJobs: 98,
      distance: '0.8 km',
      hourlyRate: 'Rs. 450/hr',
      category: 'Cleaning',
      isVerified: true,
      availability: 'Today',
    ),
    _WorkerResult(
      name: 'Bilal Hussain',
      rating: 4.3,
      totalJobs: 62,
      distance: '4.1 km',
      hourlyRate: 'Rs. 300/hr',
      category: 'General Labor',
      isVerified: false,
      availability: 'Morning',
    ),
  ];
}

// ─── Supporting types & widgets ──────────────────────────────────────────

class _WorkerResult {
  final String name;
  final double rating;
  final int totalJobs;
  final String distance;
  final String hourlyRate;
  final String category;
  final bool isVerified;
  final String availability;

  const _WorkerResult({
    required this.name,
    required this.rating,
    required this.totalJobs,
    required this.distance,
    required this.hourlyRate,
    required this.category,
    required this.isVerified,
    required this.availability,
  });
}

class _WorkerResultCard extends StatelessWidget {
  final _WorkerResult worker;

  const _WorkerResultCard({required this.worker});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // TODO: Navigate to public profile
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Text(
                  worker.name[0],
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (worker.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded,
                              size: 16, color: AppTheme.verifiedBadge),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
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
                        const Icon(Icons.star_rounded,
                            size: 14, color: AppTheme.accentColor),
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
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: AppTheme.textSecondary),
                        const SizedBox(width: 2),
                        Text(
                          worker.distance,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.access_time_rounded,
                            size: 12, color: AppTheme.textSecondary),
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
                      // TODO: Navigate to profile
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('View',
                        style: TextStyle(fontSize: 11)),
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
      avatar: Icon(icon, size: 14,
          color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary),
      label: Text(label, style: TextStyle(
          fontSize: 12,
          color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary)),
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
