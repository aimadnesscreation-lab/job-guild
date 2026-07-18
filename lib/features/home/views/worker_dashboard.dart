import 'package:flutter/material.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';

/// Worker Dashboard — nearby jobs count, applied jobs, messages, ratings,
/// profile views, and an earnings log.
class WorkerDashboard extends StatelessWidget {
  const WorkerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Stats Grid ────────────────────────────────────
          Row(
            children: [
              _StatCard(
                icon: Icons.work_rounded,
                value: '8',
                label: 'Nearby Jobs',
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              _StatCard(
                icon: Icons.thumb_up_alt_rounded,
                value: '3',
                label: 'Applied',
                color: AppTheme.accentColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatCard(
                icon: Icons.chat_rounded,
                value: '2',
                label: 'Messages',
                color: AppTheme.verifiedBadge,
              ),
              const SizedBox(width: 8),
              _StatCard(
                icon: Icons.star_rounded,
                value: '4.5',
                label: 'Rating',
                color: AppTheme.accentDark,
              ),
              const SizedBox(width: 8),
              _StatCard(
                icon: Icons.visibility_rounded,
                value: '47',
                label: 'Profile Views',
                color: AppTheme.primaryDark,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ─── Quick Actions ─────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit Profile',
                      style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.toggle_on_outlined, size: 16),
                  label: const Text('Availability',
                      style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ─── Recent Applications ───────────────────────────
          Text(
            'Recent Applications',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _ApplicationCard(
            jobTitle: 'Plumber needed for bathroom fixing',
            status: 'Shortlisted',
            statusColor: AppTheme.accentColor,
            budget: 'PKR 2,000 - 3,000',
          ),
          const SizedBox(height: 6),
          _ApplicationCard(
            jobTitle: 'AC repair and maintenance',
            status: 'Interested',
            statusColor: AppTheme.primaryColor,
            budget: 'PKR 3,500',
          ),
          const SizedBox(height: 6),
          _ApplicationCard(
            jobTitle: 'Water heater installation',
            status: 'Hired',
            statusColor: AppTheme.primaryDark,
            budget: 'PKR 5,000',
          ),
          const SizedBox(height: 20),

          // ─── Earnings Log ──────────────────────────────────
          Text(
            'Earnings Log',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _EarningEntry(
            jobTitle: 'AC repair - 3 hours',
            amount: 'PKR 1,500',
            date: 'Today',
          ),
          const SizedBox(height: 4),
          _EarningEntry(
            jobTitle: 'Plumbing - 2 hours',
            amount: 'PKR 1,000',
            date: 'Yesterday',
          ),
          const SizedBox(height: 4),
          _EarningEntry(
            jobTitle: 'Electrical work - 4 hours',
            amount: 'PKR 2,000',
            date: '3 days ago',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded,
                    color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text('Total this week: ',
                    style: TextStyle(color: AppTheme.textSecondary)),
                const Text('PKR 4,500',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        fontSize: 16)),
              ],
            ),
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final String jobTitle;
  final String status;
  final Color statusColor;
  final String budget;

  const _ApplicationCard({
    required this.jobTitle,
    required this.status,
    required this.statusColor,
    required this.budget,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.work_outline,
              color: statusColor, size: 20),
        ),
        title: Text(jobTitle,
            style: const TextStyle(fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(budget,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.accentDark)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded,
            size: 18, color: AppTheme.textDisabled),
        onTap: () {},
      ),
    );
  }
}

class _EarningEntry extends StatelessWidget {
  final String jobTitle;
  final String amount;
  final String date;

  const _EarningEntry({
    required this.jobTitle,
    required this.amount,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(jobTitle,
                      style: const TextStyle(fontSize: 13)),
                  Text(date,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textDisabled)),
                ],
              ),
            ),
            Text(
              amount,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
