import '../../../core/utils/formatters.dart';

enum NotificationType { order, chat, promo, system }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    this.message,
    this.type = NotificationType.system,
    this.read = false,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? message;
  final NotificationType type;
  final bool read;
  final DateTime? createdAt;

  factory AppNotification.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>)
      throw const FormatException('Invalid notification');
    final typeRaw = json['type']?.toString().toLowerCase() ?? '';
    final type = typeRaw.contains('order')
        ? NotificationType.order
        : typeRaw.contains('chat') || typeRaw.contains('message')
        ? NotificationType.chat
        : typeRaw.contains('promo') || typeRaw.contains('deal')
        ? NotificationType.promo
        : NotificationType.system;
    return AppNotification(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: resolveString(json['title'], fallback: ''),
      message: resolveString(json['message'] ?? json['body']),
      type: type,
      read: json['read'] == true || json['isRead'] == true,
      createdAt: tryParseDate(json['createdAt'] ?? json['sentAt']),
    );
  }
}
