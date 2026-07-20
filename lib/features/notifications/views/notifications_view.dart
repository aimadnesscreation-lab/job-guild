import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/core/services/supabase_repository.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';

/// Notifications screen showing new job matches, messages, application updates,
/// and job status changes. Reads from Supabase and persists read state.
class NotificationsView extends ConsumerStatefulWidget {
  const NotificationsView({super.key});

  @override
  ConsumerState<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends ConsumerState<NotificationsView> {
  List<Map<String, dynamic>> _items = const [];
  String _filter = 'All';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final userId = ref.read(currentUserProvider)?.id;
    final repo = ref.read(supabaseRepositoryProvider);
    final list = userId != null
        ? (await repo.getNotifications(userId))
            .map((n) => Map<String, dynamic>.from(n))
            .toList()
        : <Map<String, dynamic>>[];
    if (mounted) {
      setState(() {
        _items = list;
        _loading = false;
      });
    }
  }

  Future<void> _markRead(String id) async {
    final repo = ref.read(supabaseRepositoryProvider);
    await repo.markNotificationRead(id);
    if (mounted) {
      setState(() {
        _items = _items
            .map((n) => n['id'] == id ? {...n, 'is_read': true} : n)
            .toList();
      });
    }
  }

  Future<void> _markAllRead() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    final repo = ref.read(supabaseRepositoryProvider);
    for (final n in _items.where((n) => n['is_read'] != true)) {
      await repo.markNotificationRead(n['id'] as String);
    }
    if (mounted) {
      setState(() {
        _items = _items.map((n) => {...n, 'is_read': true}).toList();
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'All') return _items;
    if (_filter == 'Unread') {
      return _items.where((n) => n['is_read'] != true).toList();
    }
    return _items.where((n) => n['type'] == _filter).toList();
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'Messages':
        return Icons.chat_rounded;
      case 'Jobs':
        return Icons.work_rounded;
      case 'Reviews':
        return Icons.rate_review_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'Messages':
        return AppTheme.verifiedBadge;
      case 'Jobs':
        return AppTheme.primaryColor;
      case 'Reviews':
        return AppTheme.accentColor;
      default:
        return AppTheme.accentDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _markAllRead,
            child: const Text('Mark All Read'),
          ),
        ],
      ),
      body: Column(
        children: [
          // — Filter chips —
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
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_off_rounded,
                                size: 48, color: AppTheme.textDisabled),
                            SizedBox(height: 12),
                            Text('No notifications',
                                style: TextStyle(color: AppTheme.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 72),
                        itemBuilder: (context, index) {
                          final n = filtered[index];
                          final isRead = n['is_read'] == true;
                          return _NotificationTile(
                            title: n['title'] as String? ?? '',
                            body: n['body'] as String? ?? '',
                            time: _formatTime(n['created_at']),
                            type: n['type'] as String? ?? 'All',
                            icon: _iconFor(n['type'] as String? ?? 'All'),
                            iconColor: _colorFor(n['type'] as String? ?? 'All'),
                            isRead: isRead,
                            onTap: isRead
                                ? null
                                : () => _markRead(n['id'] as String),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic createdAt) {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt as String);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
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

class _NotificationTile extends StatelessWidget {
  final String title;
  final String body;
  final String time;
  final String type;
  final IconData icon;
  final Color iconColor;
  final bool isRead;
  final VoidCallback? onTap;

  const _NotificationTile({
    required this.title,
    required this.body,
    required this.time,
    required this.type,
    required this.icon,
    required this.iconColor,
    required this.isRead,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          fontSize: 14,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            time,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textDisabled,
            ),
          ),
        ],
      ),
      trailing: isRead
          ? null
          : Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
            ),
      onTap: onTap,
    );
  }
}
