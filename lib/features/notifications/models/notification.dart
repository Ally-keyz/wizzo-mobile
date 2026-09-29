import '../../../core/utils/formatters.dart';

enum NotificationType { order, chat, promo, system }

/// The kind of screen a notification should open when tapped.
enum NotificationTargetKind { conversation, order, store, product }

class NotificationTarget {
  const NotificationTarget(this.kind, this.id);

  final NotificationTargetKind kind;
  final String id;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    this.message,
    this.type = NotificationType.system,
    this.read = false,
    this.createdAt,
    this.data = const {},
  });

  final String id;
  final String title;
  final String? message;
  final NotificationType type;
  final bool read;
  final DateTime? createdAt;

  /// Free-form payload describing what the notice is about. The server fills
  /// this in per type: `{conversationId}` for chat, `{orderId, orderNumber}`
  /// for orders, `{storeId, storeSlug}` for follows, and so on.
  final Map<String, String> data;

  /// The screen this notification belongs to, or null when the server didn't
  /// say (announcements, system notices) — tapping those just marks them read.
  ///
  /// Order of checks matters: an order notification also carries the store it
  /// came from, and a chat notice carries the sender, so the most specific
  /// identifier has to win.
  NotificationTarget? get target {
    final conversationId = _field('conversationId');
    if (conversationId != null) {
      return NotificationTarget(
        NotificationTargetKind.conversation,
        conversationId,
      );
    }
    final orderId = _field('orderId');
    if (orderId != null) {
      return NotificationTarget(NotificationTargetKind.order, orderId);
    }
    // /shop/:slug accepts the store id as a fallback, same as the seller cards.
    final store = _field('storeSlug') ?? _field('storeId');
    if (store != null) {
      return NotificationTarget(NotificationTargetKind.store, store);
    }
    final productId = _field('productId');
    if (productId != null) {
      return NotificationTarget(NotificationTargetKind.product, productId);
    }
    return null;
  }

  String? _field(String key) {
    final value = data[key];
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  factory AppNotification.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>)
      throw const FormatException('Invalid notification');
    final typeRaw = json['type']?.toString().toLowerCase() ?? '';
    // `payment_*` notices are about an order, they just don't say "order" in
    // the type — without this they fell through to the generic system icon.
    final type = typeRaw.contains('order') || typeRaw.contains('payment')
        ? NotificationType.order
        : typeRaw.contains('chat') || typeRaw.contains('message')
        ? NotificationType.chat
        : typeRaw.contains('promo') ||
              typeRaw.contains('deal') ||
              typeRaw.contains('price')
        ? NotificationType.promo
        : NotificationType.system;
    return AppNotification(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: resolveString(json['title'], fallback: ''),
      message: resolveString(json['message'] ?? json['body']),
      type: type,
      read: json['read'] == true || json['isRead'] == true,
      createdAt: tryParseDate(json['createdAt'] ?? json['sentAt']),
      data: _parseData(json['data']),
    );
  }

  /// Mongoose types the payload as `Mixed`, so it can arrive as a map of
  /// anything. Only the string ids we route on are useful.
  static Map<String, String> _parseData(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, String>{};
    raw.forEach((key, value) {
      if (value != null) {
        out[key.toString()] = value.toString();
      }
    });
    return out;
  }
}
