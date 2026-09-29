import 'package:flutter_test/flutter_test.dart';

import 'package:wizzo_market/features/catalog/models/deal.dart';
import 'package:wizzo_market/features/catalog/models/product.dart';

/// Mirrors the real `GET /deals/flash` payload. The deals collection does NOT
/// set `toJSON: { virtuals: true }`, so it serialises with `_id` only — there is
/// no `id` key at all.
Map<String, dynamic> dealPayload(
  String id, {
  String type = 'flash',
  List<Map<String, dynamic>> products = const [],
}) =>
    {
      '_id': id,
      'title': 'Mega Flash Sale',
      'description': 'Up to 50% off',
      'type': type,
      'discountPercent': 50,
      'startsAt': '2026-09-29T09:00:00.000Z',
      'endsAt': '2026-09-30T17:00:00.000Z',
      'isActive': true,
      'products': products,
    };

Map<String, dynamic> productPayload(String id) => {
      'id': id,
      'name': 'iPhone 13',
      'slug': 'iphone-13',
      'images': ['https://res.cloudinary.com/x/a.jpg'],
      'price': 800000,
      'discountPrice': 600000,
      'currency': 'RWF',
      'ratingAvg': 4.5,
      'ratingCount': 12,
      'stock': 3,
      'status': 'active',
    };

void main() {
  group('Deal.fromApi identity', () {
    test('reads the id from _id when the payload has no id field', () {
      final deal = Deal.fromApi(dealPayload('6abba6e4b204cd16a0d88704'));
      expect(deal.id, '6abba6e4b204cd16a0d88704');
    });

    test('prefers an explicit id when the server sends one', () {
      final deal = Deal.fromApi({...dealPayload('abc'), 'id': 'explicit'});
      expect(deal.id, 'explicit');
    });

    // Regression: id used to fall back to the deal *type*, so every flash deal
    // shared the id "flash" and the home rail collapsed to at most two cards.
    test('two deals of the same type keep distinct ids and both survive dedupe', () {
      final deals = [
        Deal.fromApi(dealPayload('flash-a', type: 'flash')),
        Deal.fromApi(dealPayload('flash-b', type: 'flash')),
      ];

      expect(deals.first.id, isNot(deals.last.id));

      final seen = <String>{};
      final merged = <Deal>[];
      for (final d in deals) {
        if (seen.add(d.id)) merged.add(d);
      }
      expect(merged, hasLength(2));
    });
  });

  group('Product.fromApi identity', () {
    test('falls back to _id instead of the literal string "null"', () {
      final p = Product.fromApi({...productPayload('p1')..remove('id'), '_id': 'p1'});
      expect(p.id, 'p1');
    });

    // Regression: `json['id'].toString()` produced "null" for _id-only payloads,
    // which is non-empty and silently collapsed every product into one.
    test('discounted products under a deal do not collapse into a single id', () {
      final products = [
        Deal.fromApi(dealPayload('d1', products: [
          {...productPayload('p1')..remove('id'), '_id': 'p1'},
          {...productPayload('p2')..remove('id'), '_id': 'p2'},
        ])).products,
      ].expand((e) => e).toList();

      expect(products.map((p) => p.id), isNot(contains('null')));
      expect(products.map((p) => p.id).toSet(), hasLength(2));
    });
  });

  group('discount derivation', () {
    test('a discounted product reports a positive percentage', () {
      final p = Product.fromApi(productPayload('p1'));
      expect(p.isOnSale, isTrue);
      expect(p.discount, greaterThan(0));
    });

    test('a full-price product reports no discount', () {
      final payload = productPayload('p2')..remove('discountPrice');
      final p = Product.fromApi(payload);
      expect(p.isOnSale, isFalse);
      expect(p.discount, 0);
    });
  });
}
