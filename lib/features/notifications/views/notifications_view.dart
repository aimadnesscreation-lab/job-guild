import 'package:flutter/material.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';

/// Notifications screen showing new job matches, messages, application updates,
/// and job status changes.
class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  // Filter: all, unread, or a specific type
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'All'
        ? _notifications
        : _notifications
            .where((n) => _filter == 'Unread' ? !n.isRead : n.type == _filter)
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: Mark all as read
              setState(() {});
            },
            child: const Text('Mark All Read'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Filter chips ──────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 6),
                  _buildFilterChip('Unread'),
                  const SizedBox(width: 6),
                  _buildFilterChip('Messages'),
                  const SizedBox(width: 6),
                  _buildFilterChip('Jobs'),
                  const SizedBox(width: 6),
                  _buildFilterChip('Reviews'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // ─── List ──────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_rounded,
                            size: 48, color: AppTheme.textDisabled),
                        SizedBox(height: 12),
                        Text(
                          'No notifications',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      final notif = filtered[index];
                      return _NotificationTile(notification: notif);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filter == label;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
      onSelected: (_) => setState(() => _filter = label),
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
      ),
    );
  }
}

// ─── Notification Models ────────────────────────────────────────────────

class _Notification {
  final String title;
  final String body;
  final String time;
  final String type;
  final IconData icon;
  final Color iconColor;
  final bool isRead;

  const _Notification({
    required this.title,
    required this.body,
    required this.time,
    required this.type,
    required this.icon,
    required this.iconColor,
    this.isRead = false,
  });
}

final List<_Notification> _notifications = [
  _Notification(
    title: 'New job match!',
    body: 'A new plumbing job was posted 1.2 km from you',
    time: '2 min ago',
    type: 'Jobs',
    icon: Icons.work_rounded,
    iconColor: AppTheme.primaryColor,
  ),
  _Notification(
    title: 'Ahmed Khan sent a message',
    body: 'Yes, I can come tomorrow morning',
    time: '5 min ago',
    type: 'Messages',
    icon: Icons.chat_rounded,
    iconColor: AppTheme.verifiedBadge,
  ),
  _Notification(
    title: 'Application updated',
    body: 'Your application for AC repair was shortlisted',
    time: '1 hour ago',
    type: 'Jobs',
    icon: Icons.person_search_rounded,
    iconColor: AppTheme.accentColor,
  ),
  _Notification(
    title: 'Job marked as complete',
    body: 'Plumber job was marked complete. Leave a review!',
    time: '3 hours ago',
    type: 'Reviews',
    icon: Icons.rate_review_rounded,
    iconColor: AppTheme.primaryDark,
  ),
  _Notification(
    title: 'New review received',
    body: 'You received a 5-star rating from Sana Malik',
    time: '1 day ago',
    type: 'Reviews',
    icon: Icons.star_rounded,
    iconColor: AppTheme.accentColor,
  ),
  _Notification(
    title: 'Worker interested in your job',
    body: 'Imran Ali is interested in your AC repair job',
    time: '2 days ago',
    type: 'Jobs',
    icon: Icons.thumb_up_rounded,
    iconColor: AppTheme.primaryColor,
    isRead: true,
  ),
  _Notification(
    title: 'Welcome to Local Services!',
    body: 'Complete your profile to get started',
    time: '1 week ago',
    type: 'All',
    icon: Icons.handyman_rounded,
    iconColor: AppTheme.accentColor,
    isRead: true,
  ),
];

// ─── Notification Tile ──────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final _Notification notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: notification.iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(notification.icon,
            color: notification.iconColor, size: 22),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight:
              notification.isRead ? FontWeight.normal : FontWeight.bold,
          fontSize: 14,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notification.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            notification.time,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textDisabled,
            ),
          ),
        ],
      ),
      trailing: notification.isRead
          ? null
          : Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
            ),
      onTap: () {
        // TODO: Navigate to relevant screen based on type
      },
    );
  }
}
