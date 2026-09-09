import 'package:flutter_test/flutter_test.dart';

import 'package:wizzo_market/features/messages/models/chat.dart';

void main() {
  ChatMessage msg({DateTime? readAt, DateTime? deliveredAt}) =>
      ChatMessage.fromApi({
        'id': 'm1',
        'content': 'Hello',
        'senderId': 'me',
        'createdAt': '2026-09-06T10:00:00.000Z',
        if (readAt != null) 'readAt': readAt.toIso8601String(),
        if (deliveredAt != null) 'deliveredAt': deliveredAt.toIso8601String(),
      }, selfId: 'me');

  test('outgoing message without receipts shows a single "sent" tick', () {
    expect(msg().status, MessageStatus.sent);
  });

  test('deliveredAt alone means two delivered (grey) ticks', () {
    expect(msg(deliveredAt: DateTime(2026)).status, MessageStatus.delivered);
  });

  test(
    'readAt wins and shows two blue ticks even when delivered at is set',
    () {
      final m = msg(
        readAt: DateTime(2026, 9, 7),
        deliveredAt: DateTime(2026, 9, 6),
      );
      expect(m.status, MessageStatus.read);
    },
  );

  test('incoming messages keep direction incoming', () {
    final m = ChatMessage.fromApi({
      'id': 'm2',
      'content': 'Hi',
      'senderId': 'other',
    }, selfId: 'me');
    expect(m.direction, MessageDirection.incoming);
  });
}
