import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';
import '../storage/app_prefs.dart';

typedef ChatSocketListener = void Function(dynamic data);

/// Thin wrapper over the server's socket.io layer so the rest of the app only
/// talks to a familiar Dart API. Keeps a single live connection per session and
/// fans server events out to registered listeners.
class ChatSocketService {
  io.Socket? _socket;
  final Map<String, List<ChatSocketListener>> _listeners = {};
  final Set<String> _boundEvents = {};

  bool get isConnected => _socket?.connected ?? false;

  String get _socketUrl {
    final base = Uri.parse(AppConfig.apiBaseUrl);
    return '${base.scheme}://${base.host}';
  }

  /// Opens (or reuses) a connection. Reads the JWT from local storage so the
  /// socket authenticates as the signed-in user. No-op when already connected.
  Future<void> connect() async {
    final current = _socket;
    if (current != null) {
      if (!current.connected) current.connect();
      return;
    }

    final token = await AppPrefs.accessToken();
    final socket = io.io(
      _socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token ?? ''})
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(1000)
          .disableAutoConnect()
          .build(),
    );

    _socket = socket;
    // Re-bind dispatch for any listeners registered before the socket existed.
    for (final event in _boundEvents) {
      socket.on(event, (data) => _dispatch(event, data));
    }
    socket.onConnect((_) => _dispatch('connect', null));
    socket.onDisconnect((_) => _dispatch('disconnect', null));
    socket.onConnectError((_) => _dispatch('connect_error', null));
    socket.connect();
  }

  /// Closes the current connection (e.g. on sign-out). The same instance can
  /// be reused later via [connect].
  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _listeners.clear();
    _boundEvents.clear();
  }

  void on(String event, ChatSocketListener listener) {
    _listeners.putIfAbsent(event, () => []).add(listener);
    final socket = _socket;
    if (socket != null && _boundEvents.add(event)) {
      socket.on(event, (data) => _dispatch(event, data));
    }
  }

  void remove(String event, ChatSocketListener listener) {
    _listeners[event]?.remove(listener);
  }

  void _dispatch(String event, dynamic data) {
    final handlers = _listeners[event];
    if (handlers == null) return;
    for (final handler in handlers) {
      try {
        handler(data);
      } catch (_) {
        // A listener error must never break the socket event loop.
      }
    }
  }

  void _emit(String event, dynamic data) {
    final socket = _socket;
    if (socket != null && socket.connected) {
      socket.emit(event, data);
    }
  }

  void joinConversation(String conversationId) {
    _emit('join', {'room': 'conversation:$conversationId'});
  }

  void leaveConversation(String conversationId) {
    _emit('leave', {'room': 'conversation:$conversationId'});
  }

  void markConversationRead(String conversationId) {
    _emit('read', {'conversationId': conversationId});
  }

  void markMessageDelivered(String conversationId, String messageId) {
    _emit('delivered', {
      'conversationId': conversationId,
      'messageId': messageId,
    });
  }
}