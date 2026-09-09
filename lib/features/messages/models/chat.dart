import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

import '../../../core/utils/formatters.dart';

enum MessageDirection { incoming, outgoing }

/// A person (seller / buyer / admin) you can start a conversation with.
class ChatContact {
  const ChatContact({
    required this.id,
    required this.fullName,
    this.displayName,
    this.avatarUrl,
    this.role = 'buyer',
  });

  final String id;
  final String fullName;
  final String? displayName;
  final String? avatarUrl;

  /// buyer | seller | admin
  final String role;

  bool get isAdmin => role == 'admin';
  bool get isSeller => role == 'seller';

  factory ChatContact.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid contact');
    }
    return ChatContact(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      fullName: (json['fullName'] ?? json['storeName'] ?? 'Unknown').toString(),
      displayName: json['displayName']?.toString(),
      avatarUrl: (json['avatarUrl'] ?? json['logo'] ?? json['logoUrl'])
          ?.toString(),
      role: json['role']?.toString() ?? 'buyer',
    );
  }
}

class Conversation {
  const Conversation({
    required this.id,
    this.sellerId,
    this.sellerName,
    this.sellerSlug,
    this.sellerLogo,
    this.online = false,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.productTitle,
    this.productImage,
  });

  final String id;
  final String? sellerId;
  final String? sellerName;
  final String? sellerSlug;
  final String? sellerLogo;
  final bool online;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final String? productTitle;
  final String? productImage;

  String displayName(BuildContext context) =>
      (sellerName != null && sellerName!.isNotEmpty)
      ? sellerName!
      : context.tr('common.seller');

  Conversation copyWith({
    String? id,
    String? sellerId,
    String? sellerName,
    String? sellerSlug,
    String? sellerLogo,
    bool? online,
    String? lastMessage,
    DateTime? lastMessageAt,
  }) {
    return Conversation(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      sellerSlug: sellerSlug ?? this.sellerSlug,
      sellerLogo: sellerLogo ?? this.sellerLogo,
      online: online ?? this.online,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount,
      productTitle: productTitle,
      productImage: productImage,
    );
  }

  factory Conversation.fromApi(dynamic json, {String? selfId}) {
    if (json is! Map<String, dynamic>)
      throw const FormatException('Invalid conversation');
    final seller = json['seller'] is Map<String, dynamic>
        ? json['seller'] as Map<String, dynamic>
        : const <String, dynamic>{};

    // The server stores both users in participantIds (populated ChatUsers).
    // Resolve the "other side" robustly by EXCLUDING the current user rather
    // than relying on array order (which is not guaranteed [self, other]).
    Map<String, dynamic>? other;
    final participants = json['participantIds'];
    if (participants is List && participants.isNotEmpty) {
      final list = participants.whereType<Map<String, dynamic>>().toList();
      if (selfId != null && selfId.isNotEmpty) {
        final others = list
            .where((p) =>
                (p['id'] ?? p['_id'])?.toString() != selfId &&
                (p['id'] ?? p['_id'])?.toString() != null)
            .toList();
        other = others.isNotEmpty ? others.first : (list.isNotEmpty ? list.last : null);
      } else {
        // Legacy fallback: last entry historically matched creation order.
        other = list.isNotEmpty ? list.last : null;
      }
    }
    final otherName = other?['fullName']?.toString();
    final otherAvatar = other?['avatarUrl']?.toString();
    final otherId = other?['id']?.toString() ?? other?['_id']?.toString();

    final lastMsg = json['lastMessage'];
    final lastMessageText = lastMsg is Map<String, dynamic>
        ? lastMsg['content']?.toString()
        : lastMsg?.toString();

    return Conversation(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      sellerId:
          json['sellerId']?.toString() ?? seller['id']?.toString() ?? otherId,
      sellerName:
          seller['storeName']?.toString() ??
          json['sellerName']?.toString() ??
          otherName,
      sellerSlug: seller['storeSlug']?.toString(),
      sellerLogo:
          (seller['logoUrl'] ?? seller['avatar'])?.toString() ?? otherAvatar,
      online: seller['online'] == true,
      lastMessage: lastMessageText,
      lastMessageAt: tryParseDate(json['lastMessageAt'] ?? json['updatedAt']),
      unreadCount: parseUnread(json['unreadCount'], selfId),
      productTitle: json['productTitle']?.toString(),
      productImage: json['productImage']?.toString(),
    );
  }

  /// unreadCount arrives as a map keyed by participant id (server) or a plain
  /// number (legacy). Surface THIS user's own unread count only — the other
  /// entries in the map are the counterpart's unread (e.g. messages we sent),
  /// which must never count against us.
  static int parseUnread(dynamic v, String? selfId) {
    if (v is num) return v.toInt();
    if (v is Map) {
      if (selfId != null) {
        final own = v[selfId];
        if (own is num) return own.toInt();
      }
      return 0;
    }
    return 0;
  }
}

enum MessageType { text, product, image, document }

/// Delivery state of an outgoing message (WhatsApp-style ticks).
///
///  - [sent]: persisted server-side but not yet received by the sender
///  - [delivered]: fetched by the recipient's device (two grey ticks)
///  - [read]: opened by the recipient (two blue ticks)
enum MessageStatus { sent, delivered, read }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.content,
    required this.direction,
    this.sentAt,
    this.type = MessageType.text,
    this.mediaUrl,
    this.productId,
    this.productImage,
    this.productTitle,
    this.productPrice,
    this.readAt,
    this.deliveredAt,
  });

  final String id;
  final String content;
  final MessageDirection direction;
  final DateTime? sentAt;
  final MessageType type;
  final String? mediaUrl;
  final String? productId;
  final String? productImage;
  final String? productTitle;
  final num? productPrice;
  final DateTime? readAt;
  final DateTime? deliveredAt;

  bool get isMedia => type == MessageType.image || type == MessageType.document;

  MessageStatus get status {
    if (readAt != null) return MessageStatus.read;
    if (deliveredAt != null) return MessageStatus.delivered;
    return MessageStatus.sent;
  }

  ChatMessage copyWith({
    String? id,
    String? content,
    MessageDirection? direction,
    DateTime? sentAt,
    MessageType? type,
    String? mediaUrl,
    String? productId,
    String? productImage,
    String? productTitle,
    num? productPrice,
    DateTime? readAt,
    DateTime? deliveredAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      direction: direction ?? this.direction,
      sentAt: sentAt ?? this.sentAt,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      productId: productId ?? this.productId,
      productImage: productImage ?? this.productImage,
      productTitle: productTitle ?? this.productTitle,
      productPrice: productPrice ?? this.productPrice,
      readAt: readAt ?? this.readAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
    );
  }

  factory ChatMessage.fromApi(dynamic json, {required String selfId}) {
    if (json is! Map<String, dynamic>)
      throw const FormatException('Invalid message');
    // The API populates senderId into { _id, fullName, avatarUrl } for both
    // history fetches and live socket events, so pull the raw id in all forms.
    final rawSender = json['senderId'] ?? json['sender'];
    final senderId = rawSender is Map
        ? (rawSender['_id'] ?? rawSender['id'] ?? rawSender['senderId'])
                  ?.toString() ??
              ''
        : rawSender?.toString() ?? '';
    final isOutgoing = senderId == selfId;
    final typeRaw = json['type']?.toString() ?? 'text';
    return ChatMessage(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      direction: isOutgoing
          ? MessageDirection.outgoing
          : MessageDirection.incoming,
      sentAt: tryParseDate(json['createdAt'] ?? json['sentAt']),
      type: typeRaw.contains('product')
          ? MessageType.product
          : typeRaw.contains('image')
          ? MessageType.image
          : typeRaw.contains('document')
          ? MessageType.document
          : MessageType.text,
      mediaUrl: json['mediaUrl']?.toString(),
      productId: json['productId']?.toString(),
      productImage: json['productImage']?.toString(),
      productTitle: json['productTitle']?.toString(),
      productPrice: (json['productPrice'] as num?)?.toDouble(),
      readAt: tryParseDate(json['readAt']),
      deliveredAt: tryParseDate(json['deliveredAt']),
    );
  }
}
