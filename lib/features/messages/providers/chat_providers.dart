import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../../../core/network/chat_socket.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/chat_repository.dart';
import '../models/chat.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(apiClientProvider));
});

/// The single socket.io connection used by all chat screens.
final chatSocketProvider = Provider<ChatSocketService>((ref) {
  final service = ChatSocketService();
  ref.onDispose(service.dispose);
  return service;
});

/// Applies app-wide realtime events (presence + incoming messages) to the
/// conversation list. Wired exactly once per app run; the socket itself is
/// connected/disconnected on sign-in/sign-out.
class ChatSocketLifecycle {
  ChatSocketLifecycle(this.ref);

  final Ref ref;
  bool _wired = false;

  void wire() {
    if (_wired) return;
    _wired = true;
    final service = ref.read(chatSocketProvider);
    service.on('message:new', (_) {
      ref.read(conversationsProvider.notifier).reloadSilently();
    });
    service.on('presence', _onPresence);
  }

  Future<void> connected() => ref.read(chatSocketProvider).connect();

  void disconnected() => ref.read(chatSocketProvider).disconnect();

  void _onPresence(dynamic data) {
    if (data is! Map) return;
    final userId = data['userId']?.toString();
    final online = data['isOnline'] == true;
    if (userId == null) return;
    ref.read(conversationsProvider.notifier).setOnline(userId, online);
  }
}

/// Keeps the socket alive for a signed-in session. Watching this provider
/// (e.g. at the app root) is what starts the connection.
final chatSocketLifecycleProvider = Provider<ChatSocketLifecycle>((ref) {
  final auth = ref.watch(authControllerProvider);
  final lifecycle = ChatSocketLifecycle(ref);
  lifecycle.wire();
  if (auth.isSignedIn) {
    lifecycle.connected();
  } else {
    lifecycle.disconnected();
  }
  return lifecycle;
});

class ConversationController extends AsyncNotifier<List<Conversation>> {
  @override
  Future<List<Conversation>> build() {
    final selfId = ref.watch(authControllerProvider).user?.id;
    return ref.watch(chatRepositoryProvider).conversations(selfId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      final selfId = ref.read(authControllerProvider).user?.id;
      return ref.read(chatRepositoryProvider).conversations(selfId);
    });
  }

  /// Refreshes the list without a loading flash, keeping the previous data on
  /// error. Used for realtime events so the UI never flickers mid-session.
  Future<void> reloadSilently() async {
    final result = await AsyncValue.guard(() {
      final selfId = ref.read(authControllerProvider).user?.id;
      return ref.read(chatRepositoryProvider).conversations(selfId);
    });
    if (ref.mounted && result.hasValue) {
      state = result;
    }
  }

  /// Flips the online dot for a participant in-place when a presence event
  /// arrives over the socket.
  void setOnline(String userId, bool online) {
    final list = state.value;
    if (list == null) return;
    var changed = false;
    final next = [
      for (final c in list)
        if (c.sellerId == userId && c.online != online)
          () {
            changed = true;
            return c.copyWith(online: online);
          }()
        else
          c,
    ];
    if (changed) state = AsyncData(next);
  }
}

final conversationsProvider = AsyncNotifierProvider<ConversationController, List<Conversation>>(
  ConversationController.new,
);

/// Contacts for the "New chat" picker.
final chatContactsProvider = FutureProvider<List<ChatContact>>((ref) async {
  return ref.watch(chatRepositoryProvider).contacts();
});

/// Sum of unread conversation counts (used by the Messages nav badge).
final messagesUnreadProvider = FutureProvider<int>((ref) async {
  final value = await ref.watch(conversationsProvider.future);
  var total = 0;
  for (final c in value) {
    total += c.unreadCount;
  }
  return total;
});

typedef ConversationMessagesState = ({
  List<ChatMessage> messages,
  bool loaded,
  bool failed,
});

/// Live message list for a conversation. The screen owns the socket listeners;
/// this controller keeps the list state, merges fetched history with anything
/// already on screen, and applies delivered/read receipts as they arrive.
class ConversationMessagesController extends Notifier<ConversationMessagesState> {
  ConversationMessagesController(this.conversationId);

  final String conversationId;

  String get _selfId => ref.read(authControllerProvider).user?.id ?? '';

  @override
  ConversationMessagesState build() {
    _loadHistory(conversationId);
    return (messages: const [], loaded: false, failed: false);
  }

  Future<void> refresh() => _loadHistory(conversationId);

  Future<void> _loadHistory(String conversationId) async {
    try {
      final history = await ref
          .read(chatRepositoryProvider)
          .messages(conversationId, selfId: _selfId);
      if (!ref.mounted) return;
      state = (
        messages: _mergeByTime(_mergeKeepLocal(history, state.messages)),
        loaded: true,
        failed: false,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = (messages: state.messages, loaded: true, failed: true);
    }
  }

  /// Server history is authoritative, but pending (temp-id) messages that the
  /// user already sent must not be dropped.
  static List<ChatMessage> _mergeKeepLocal(
    List<ChatMessage> history,
    List<ChatMessage> current,
  ) {
    final map = <String, ChatMessage>{};
    for (final m in history) {
      map[m.id] = m;
    }
    for (final m in current) {
      if (m.id.isEmpty || m.id.startsWith('local-')) {
        map['__local__${m.sentAt?.microsecondsSinceEpoch}_${m.hashCode}'] = m;
      }
    }
    return map.values.toList();
  }

  static List<ChatMessage> _mergeByTime(List<ChatMessage> list) {
    final sorted = [...list];
    sorted.sort((a, b) {
      final at = a.sentAt;
      final bt = b.sentAt;
      if (at == null) return 1;
      if (bt == null) return -1;
      return at.compareTo(bt);
    });
    return sorted;
  }

  /// Appends a message received over the socket, skipping duplicates (e.g. the
  /// echoed copy of a message this device just POSTed).
  void addIncoming(ChatMessage message) {
    if (message.id.isEmpty) return;
    if (state.messages.any((m) => m.id == message.id)) return;
    state = (
      messages: _mergeByTime([...state.messages, message]),
      loaded: true,
      failed: false,
    );
  }

  /// After a POST succeeds, swap the optimistic temp id for the persisted
  /// server message (or keep the echoed copy if it already arrived).
  void resolveOutgoing(String tempId, ChatMessage saved) {
    var list = state.messages.where((m) => m.id != tempId).toList();
    if (!list.any((m) => m.id == saved.id)) {
      list = _mergeByTime([...list, saved]);
    }
    state = (messages: list, loaded: true, failed: false);
  }

  void removeMessage(String id) {
    state = (
      messages: state.messages.where((m) => m.id != id).toList(),
      loaded: true,
      failed: false,
    );
  }

  /// Two grey ticks: the other side's device received our message.
  void applyDelivered(String messageId, DateTime at) {
    state = (
      messages: [
        for (final m in state.messages)
          if (m.id == messageId &&
              m.direction == MessageDirection.outgoing &&
              m.deliveredAt == null)
            m.copyWith(deliveredAt: at)
          else
            m,
      ],
      loaded: true,
      failed: false,
    );
  }

  /// Two blue ticks: the other side opened the conversation.
  void applyRead(DateTime at) {
    state = (
      messages: [
        for (final m in state.messages)
          if (m.direction == MessageDirection.outgoing && m.readAt == null)
            m.copyWith(readAt: at, deliveredAt: m.deliveredAt ?? at)
          else
            m,
      ],
      loaded: true,
      failed: false,
    );
  }

  Future<bool> send(String content) async {
    final text = content.trim();
    if (text.isEmpty) return false;
    final conversationId = this.conversationId;
    final tempId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    state = (
      messages: [
        ...state.messages,
        ChatMessage(
          id: tempId,
          content: text,
          direction: MessageDirection.outgoing,
          sentAt: DateTime.now(),
        ),
      ],
      loaded: true,
      failed: false,
    );
    await _persist(
      tempId: tempId,
      post: () => ref
          .read(chatRepositoryProvider)
          .sendMessage(conversationId, text, selfId: _selfId),
    );
    return true;
  }

  Future<void> sendMedia({
    required String content,
    required MessageType type,
    required String mediaUrl,
  }) async {
    final conversationId = this.conversationId;
    final tempId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    state = (
      messages: [
        ...state.messages,
        ChatMessage(
          id: tempId,
          content: content,
          direction: MessageDirection.outgoing,
          sentAt: DateTime.now(),
          type: type,
          mediaUrl: mediaUrl,
        ),
      ],
      loaded: true,
      failed: false,
    );
    await _persist(
      tempId: tempId,
      post: () => ref.read(chatRepositoryProvider).sendMessage(
            conversationId,
            content,
            type: type.name,
            mediaUrl: mediaUrl,
            selfId: _selfId,
          ),
    );
  }

  Future<void> _persist({
    required String tempId,
    required Future<ChatMessage> Function() post,
  }) async {
    try {
      final saved = await post();
      if (!ref.mounted) return;
      resolveOutgoing(tempId, saved);
      ref.read(conversationsProvider.notifier).reloadSilently();
    } catch (_) {
      if (ref.mounted) removeMessage(tempId);
      rethrow;
    }
  }
}

final conversationMessagesProvider =
    NotifierProvider.family<ConversationMessagesController, ConversationMessagesState, String>(
  ConversationMessagesController.new,
);

/// Number of chat pages currently on screen (messages list + conversation).
/// The shell hides the chat FAB whenever this is > 0.
class ChatPagesOpenController extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;

  void decrement() => state = state > 0 ? state - 1 : 0;
}

final chatPagesOpenProvider = NotifierProvider<ChatPagesOpenController, int>(ChatPagesOpenController.new);