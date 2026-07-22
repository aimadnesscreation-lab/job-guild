import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';
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

/// Enum-based filter type — NOT localized string, so the filter logic works
/// correctly regardless of the current locale (Urdu/English).
enum _NotifFilter { all, unread, messages, jobs, reviews }

class _NotificationsViewState extends ConsumerState<NotificationsView> {
  List<Map<String, dynamic>> _items = const [];
  _NotifFilter _filter = _NotifFilter.all;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _refresh() async {
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final userId = ref.read(currentUserProvider)?.id;
    final repo = ref.read(supabaseRepositoryProvider);
    final list = userId != null
        ? (await repo.getNotifications(
            userId,
          )).map((n) => Map<String, dynamic>.from(n)).toList()
        : <Map<String, dynamic>>[];
    if (context.mounted) {
      setState(() {
        _items = list;
        _loading = false;
      });
    }
  }

  Future<void> _markRead(String id) async {
    final repo = ref.read(supabaseRepositoryProvider);
    await repo.markNotificationRead(id);
    if (context.mounted) {
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
    await repo.markAllNotificationsRead(userId);
    if (context.mounted) {
      setState(() {
        _items = _items.map((n) => {...n, 'is_read': true}).toList();
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    switch (_filter) {
      case _NotifFilter.all:
        return _items;
      case _NotifFilter.unread:
        return _items.where((n) => n['is_read'] != true).toList();
      case _NotifFilter.messages:
        return _items.where((n) => n['type'] == 'Messages').toList();
      case _NotifFilter.jobs:
        return _items.where((n) => n['type'] == 'Jobs').toList();
      case _NotifFilter.reviews:
        return _items.where((n) => n['type'] == 'Reviews').toList();
    }
  }

  static IconData _iconForType(String type) {
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

  static Color _colorForType(String type) {
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
        title: Text(ref.watch(appStringsProvider).notifications),
        actions: [
          TextButton(
            onPressed: _loading ? null : _markAllRead,
            child: Text(ref.watch(appStringsProvider).markAllRead),
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
                  _buildFilterChip(
                    ref.watch(appStringsProvider).all,
                    _NotifFilter.all,
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    ref.watch(appStringsProvider).unread,
                    _NotifFilter.unread,
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    ref.watch(appStringsProvider).messages,
                    _NotifFilter.messages,
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    ref.watch(appStringsProvider).jobsNotif,
                    _NotifFilter.jobs,
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    ref.watch(appStringsProvider).reviews,
                    _NotifFilter.reviews,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: filtered.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.25,
                              ),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.notifications_off_rounded,
                                      size: 48,
                                      color: AppTheme.textDisabled,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      ref
                                          .watch(appStringsProvider)
                                          .noNotifications,
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, indent: 72),
                            itemBuilder: (context, index) {
                              final n = filtered[index];
                              final isRead = n['is_read'] == true;
                              // Notifications are stored with a JSONB payload;
                              // title and body live inside it, not as top-level columns.
                              final payload =
                                  n['payload'] as Map<String, dynamic>? ?? {};
                              final title = payload['title'] as String? ??
                                  n['title'] as String? ??
                                  '';
                              final body = payload['body'] as String? ??
                                  n['body'] as String? ??
                                  '';
                              return _NotificationTile(
                                title: title,
                                body: body,
                                time: _formatTime(n['created_at']),
                                type: n['type'] as String? ?? 'All',
                                icon: _iconForType(
                                  n['type'] as String? ?? 'All',
                                ),
                                iconColor: _colorForType(
                                  n['type'] as String? ?? 'All',
                                ),
                                isRead: isRead,
                                onTap: isRead
                                    ? null
                                    : () => _markRead(n['id'] as String),
                              );
                            },
                          ),
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
      final s = ref.read(appStringsProvider);
      if (diff.inMinutes < 1) return s.now;
      if (diff.inMinutes < 60) {
        final n = diff.inMinutes;
        return '$n${s.minAbbrev}';
      }
      if (diff.inHours < 24) {
        final n = diff.inHours;
        return '$n${s.hoursAbbrev}';
      }
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  Widget _buildFilterChip(String label, _NotifFilter filterValue) {
    final isSelected = _filter == filterValue;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
      onSelected: (_) => setState(() => _filter = filterValue),
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
            style: const TextStyle(fontSize: 11, color: AppTheme.textDisabled),
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
