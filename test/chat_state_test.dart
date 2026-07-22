import 'package:flutter_test/flutter_test.dart';
import 'package:local_services_marketplace/features/chat/providers/chat_provider.dart';
import 'package:local_services_marketplace/features/chat/models/message_model.dart';

void main() {
  group('ChatState', () {
    test('default constructor sets correct defaults', () {
      final state = ChatState();
      expect(state.conversations, isEmpty);
      expect(state.currentMessages, isEmpty);
      expect(state.activeConversationId, isNull);
      expect(state.isLoading, isFalse);
      expect(state.isSending, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.isTyping, isFalse);
    });

    test('copyWith updates conversations', () {
      final state = ChatState();
      final conv = Conversation(
        id: 'conv-1',
        jobId: 'job-1',
        jobTitle: 'Test Job',
        otherUserId: 'user-1',
        otherUserName: 'Other',
      );
      final updated = state.copyWith(conversations: [conv]);
      expect(updated.conversations.length, 1);
      expect(updated.conversations[0].id, 'conv-1');
    });

    test('copyWith updates messages', () {
      final state = ChatState();
      final msg = Message(id: 'msg-1', content: 'Hello');
      final updated = state.copyWith(currentMessages: [msg]);
      expect(updated.currentMessages.length, 1);
      expect(updated.currentMessages[0].content, 'Hello');
    });

    test('copyWith sets loading and typing states', () {
      final state = ChatState();
      final loading = state.copyWith(isLoading: true);
      expect(loading.isLoading, isTrue);

      final typing = loading.copyWith(isTyping: true);
      expect(typing.isTyping, isTrue);
    });

    test('copyWith clearError removes error', () {
      final state = ChatState(errorMessage: 'Error!');
      final cleared = state.copyWith(clearError: true);
      expect(cleared.errorMessage, isNull);
    });
  });
}
