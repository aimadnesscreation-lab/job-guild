import 'package:flutter/material.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';

/// Employer Dashboard — active jobs, applicants per job, completed job history, saved workers.
class EmployerDashboard extends StatelessWidget {
  const EmployerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Stats Row ─────────────────────────────────────
          Row(
            children: [
              _StatCard(
                icon: Icons.work_outline,
                value: '3',
                label: 'Active Jobs',
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              _StatCard(
                icon: Icons.people_outline,
                value: '7',
                label: 'Applicants',
                color: AppTheme.accentColor,
              ),
              const SizedBox(width: 8),
              _StatCard(
                icon: Icons.check_circle_outline,
                value: '12',
                label: 'Completed',
                color: AppTheme.verifiedBadge,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ─── Active Jobs ───────────────────────────────────
          Text(
            'Active Jobs',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _ActiveJobCard(
            title: 'Plumber needed for bathroom fixing',
            applicants: 3,
            budget: 'PKR 2,000 - 3,000',
            daysAgo: 1,
          ),
          const SizedBox(height: 6),
          _ActiveJobCard(
            title: 'AC repair and maintenance',
            applicants: 2,
            budget: 'PKR 3,500',
            daysAgo: 2,
          ),
          const SizedBox(height: 6),
          _ActiveJobCard(
            title: 'Tutor for Class 10 Mathematics',
            applicants: 2,
            budget: 'PKR 500/hr',
            daysAgo: 3,
          ),
          const SizedBox(height: 20),

          // ─── Saved Workers ─────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Saved Workers',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('See All'),
              ),
            ],
          ),
          SizedBox(
            height: 72,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                _SavedWorkerAvatar(name: 'Ahmed K.', rating: 4.8),
                SizedBox(width: 12),
                _SavedWorkerAvatar(name: 'Imran A.', rating: 4.5),
                SizedBox(width: 12),
                _SavedWorkerAvatar(name: 'Sana M.', rating: 4.9),
                SizedBox(width: 12),
                _SavedWorkerAvatar(name: 'Faisal A.', rating: 4.6),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── Recent Activity ───────────────────────────────
          Text(
            'Recent Activity',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _ActivityTile(
            icon: Icons.person_add_rounded,
            text: 'Ahmed Khan applied for Plumbing job',
            time: '2 hours ago',
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 4),
          _ActivityTile(
            icon: Icons.check_circle_rounded,
            text: 'Plumbing job marked as complete',
            time: '1 day ago',
            color: AppTheme.primaryDark,
          ),
          const SizedBox(height: 4),
          _ActivityTile(
            icon: Icons.star_rounded,
            text: 'You received a 5-star review',
            time: '2 days ago',
            color: AppTheme.accentColor,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveJobCard extends StatelessWidget {
  final String title;
  final int applicants;
  final String budget;
  final int daysAgo;

  const _ActiveJobCard({
    required this.title,
    required this.applicants,
    required this.budget,
    required this.daysAgo,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.work_outline,
              color: AppTheme.primaryColor, size: 22),
        ),
        title: Text(title,
            style: const TextStyle(fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            Text('$applicants applicants',
                style: const TextStyle(fontSize: 12, color: AppTheme.accentDark)),
            const SizedBox(width: 8),
            Text(budget,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        trailing: Text('$daysAgo d',
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textDisabled)),
        onTap: () {},
      ),
    );
  }
}

class _SavedWorkerAvatar extends StatelessWidget {
  final String name;
  final double rating;

  const _SavedWorkerAvatar({required this.name, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
          child: Text(
            name[0],
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(name,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded,
                size: 10, color: AppTheme.accentColor),
            const SizedBox(width: 2),
            Text(rating.toStringAsFixed(1),
                style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
          ],
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final String text;
  final String time;
  final Color color;

  const _ActivityTile({
    required this.icon,
    required this.text,
    required this.time,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: color, size: 20),
        title: Text(text,
            style: const TextStyle(fontSize: 13)),
        trailing: Text(time,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textDisabled)),
      ),
    );
  }
}
