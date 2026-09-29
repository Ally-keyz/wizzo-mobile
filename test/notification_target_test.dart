import 'package:flutter_test/flutter_test.dart';

import 'package:wizzo_market/features/notifications/models/notification.dart';

/// Tapping a notification has to land on the thing it is about. The server
/// communicates that through the free-form `data` payload, so these cover the
/// parsing of that payload into a routable target.
void main() {
  group('AppNotification.fromApi', () {
    test('reads the data payload the server attaches', () {
      final n = AppNotification.fromApi({
        '_id': 'n1',
        'type': 'new_message',
        'title': 'Alice',
        'body': 'Is this still available?',
        'isRead': false,
        'data': {'conversationId': 'c9', 'senderId': 'u2'},
      });

      expect(n.data['conversationId'], 'c9');
      expect(n.type, NotificationType.chat);
      expect(n.target?.kind, NotificationTargetKind.conversation);
      expect(n.target?.id, 'c9');
    });

    test('tolerates a missing or malformed data payload', () {
      expect(AppNotification.fromApi({'id': 'a'}).data, isEmpty);
      expect(AppNotification.fromApi({'id': 'a', 'data': 'nope'}).data, isEmpty);
      expect(AppNotification.fromApi({'id': 'a'}).target, isNull);
    });

    test('stringifies non-string ids', () {
      final n = AppNotification.fromApi({
        'id': 'a',
        'data': {'orderId': 12345},
      });
      expect(n.target?.id, '12345');
    });
  });

  group('target', () {
    test('routes chat notices to the conversation', () {
      final n = AppNotification.fromApi({
        'id': 'a',
        'type': 'new_message',
        'data': {'conversationId': 'c1', 'senderId': 'u1'},
      });
      expect(n.target?.kind, NotificationTargetKind.conversation);
      expect(n.target?.id, 'c1');
    });

    test('routes order notices to the order', () {
      for (final type in [
        'new_order',
        'order_placed',
        'payment_submitted',
        'payment_confirmed',
        'payment_rejected',
        'order_status_changed',
      ]) {
        final n = AppNotification.fromApi({
          'id': 'a',
          'type': type,
          'data': {'orderId': 'o1', 'orderNumber': 'WZO-1'},
        });
        expect(n.target?.kind, NotificationTargetKind.order, reason: type);
        expect(n.target?.id, 'o1', reason: type);
      }
    });

    test('routes follows to the storefront', () {
      final n = AppNotification.fromApi({
        'id': 'a',
        'type': 'follow',
        'data': {'storeId': 's1', 'storeSlug': 'bright-kicks'},
      });
      expect(n.target?.kind, NotificationTargetKind.store);
      expect(n.target?.id, 'bright-kicks');
    });

    test('falls back to the store id when no slug was sent', () {
      final n = AppNotification.fromApi({
        'id': 'a',
        'type': 'follow',
        'data': {'storeId': 's1', 'storeSlug': ''},
      });
      expect(n.target?.kind, NotificationTargetKind.store);
      expect(n.target?.id, 's1');
    });

    test('prefers the order over the store it was bought from', () {
      final n = AppNotification.fromApi({
        'id': 'a',
        'type': 'new_order',
        'data': {'orderId': 'o1', 'storeSlug': 'bright-kicks'},
      });
      expect(n.target?.kind, NotificationTargetKind.order);
    });

    test('prefers the conversation over the sender id', () {
      final n = AppNotification.fromApi({
        'id': 'a',
        'type': 'new_message',
        'data': {'conversationId': 'c1', 'senderId': 'u1'},
      });
      expect(n.target?.kind, NotificationTargetKind.conversation);
    });

    test('has no target when the server sent no ids', () {
      final n = AppNotification.fromApi({
        'id': 'a',
        'type': 'price_drop',
        'title': 'Price drop',
        'data': {'productName': 'Headphones', 'oldPrice': '40000'},
      });
      expect(n.target, isNull);
    });

    test('ignores blank ids', () {
      final n = AppNotification.fromApi({
        'id': 'a',
        'type': 'order_placed',
        'data': {'orderId': '', 'orderNumber': 'WZO-2'},
      });
      expect(n.target, isNull);
    });
  });

  group('NotificationType', () {
    test('maps the server type strings', () {
      String typeOf(String raw) =>
          AppNotification.fromApi({'id': 'a', 'type': raw}).type.name;

      expect(typeOf('new_order'), 'order');
      expect(typeOf('order_status_changed'), 'order');
      expect(typeOf('payment_confirmed'), 'order');
      expect(typeOf('new_message'), 'chat');
      expect(typeOf('message'), 'chat');
      expect(typeOf('price_drop'), 'promo');
      expect(typeOf('otp'), 'system');
      expect(typeOf('follow'), 'system');
    });
  });
}
