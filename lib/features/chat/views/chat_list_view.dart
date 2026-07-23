import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/features/chat/providers/chat_provider.dart';
import 'package:local_services_marketplace/features/chat/views/chat_detail_view.dart';

/// Shows the list of active conversations.
class ChatListView extends ConsumerWidget {
  const ChatListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatProvider);
    final s = ref.watch(appStringsProvider);

    if (state.conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: AppTheme.textDisabled,
            ),
            const SizedBox(height: 16),
            Text(
              s.noConversations,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.noConvSubtitle,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textDisabled,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.conversations.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final conv = state.conversations[index];
        final isUnread = conv.unreadCount > 0;
        final timeStr = _formatTime(conv.updatedAt, ref);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
            child: Text(
              conv.otherUserName.isNotEmpty
                  ? conv.otherUserName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  conv.otherUserName,
                  style: TextStyle(
                    fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 12,
                  color: isUnread
                      ? AppTheme.primaryColor
                      : AppTheme.textDisabled,
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (conv.lastMessage != null)
                Text(
                  conv.lastMessage!.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isUnread
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                    fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                conv.jobTitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textDisabled,
                ),
              ),
            ],
          ),
          trailing: isUnread
              ? Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${conv.unreadCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
          onTap: () {
            ref.read(chatProvider.notifier).markAsRead(conv.id);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatDetailView(
                  conversationId: conv.id,
                  otherUserName: conv.otherUserName,
                  jobTitle: conv.jobTitle,
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime dt, WidgetRef ref) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    final s = ref.read(appStringsProvider);
    if (diff.inMinutes < 1) return s.now;
    if (diff.inMinutes < 60) return s.relativeTimeMinutes(diff.inMinutes);
    if (diff.inHours < 24) return s.relativeTimeHours(diff.inHours);
    if (diff.inDays < 7) return s.relativeTimeDays(diff.inDays);
    return '${dt.day}/${dt.month}';
  }
}
