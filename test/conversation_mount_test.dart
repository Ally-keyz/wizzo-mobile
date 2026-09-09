import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n.dart';

import 'package:wizzo_market/core/network/api_client.dart';
import 'package:wizzo_market/core/network/chat_socket.dart';
import 'package:wizzo_market/core/theme/app_theme.dart';
import 'package:wizzo_market/features/messages/data/chat_repository.dart';
import 'package:wizzo_market/features/messages/models/chat.dart';
import 'package:wizzo_market/features/messages/presentation/conversation_screen.dart';
import 'package:wizzo_market/features/messages/providers/chat_providers.dart';

class _StubConversations extends ConversationController {
  @override
  Future<List<Conversation>> build() async => const [];
}

class _StubMessages extends ConversationMessagesController {
  _StubMessages(super.conversationId);

  @override
  ConversationMessagesState build() =>
      const (messages: [], loaded: true, failed: false);
}

class _NoopSocket extends ChatSocketService {
  @override
  Future<void> connect() async {}

  @override
  void disconnect() {}

  @override
  void dispose() {}

  @override
  void on(String event, ChatSocketListener listener) {}

  @override
  void remove(String event, ChatSocketListener listener) {}

  @override
  void joinConversation(String conversationId) {}

  @override
  void leaveConversation(String conversationId) {}

  @override
  void markMessageDelivered(String conversationId, String messageId) {}
}

class _FakeChatRepository extends ChatRepository {
  _FakeChatRepository()
    : super(ApiClient(baseUrl: 'https://example.invalid/api/v1'));

  @override
  Future<void> markRead(String conversationId) async {}

  @override
  Future<List<Conversation>> conversations(String? selfId) async => const [];

  @override
  Future<List<ChatMessage>> messages(
    String conversationId, {
    String? selfId,
  }) async => const <ChatMessage>[];
}

void main() {
  testWidgets('ConversationScreen mounts without provider errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationsProvider.overrideWith(_StubConversations.new),
          chatRepositoryProvider.overrideWith((ref) => _FakeChatRepository()),
          conversationMessagesProvider.overrideWith2(_StubMessages.new),
          chatSocketProvider.overrideWith((ref) => _NoopSocket()),
        ],
        child: localizedApp(
          const ConversationScreen(conversationId: 'conv-1'),
          theme: buildLightTheme(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ConversationScreen), findsOneWidget);
  });
}
