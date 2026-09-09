import 'package:flutter_test/flutter_test.dart';

import 'package:wizzo_market/features/account/models/order.dart';
import 'package:wizzo_market/features/account/models/profile.dart';
import 'package:wizzo_market/features/cart/models/cart.dart';

/// Mirrors the real `/cart` payload: items carry a populated `sellerId` (a
/// user doc) and the product carries a populated `storeId`; there is no
/// `seller`/`store` key on the product.
const cartPayload = {
  'userId': 'user-1',
  'items': [
    {
      '_id': 'item-1',
      'productId': {
        '_id': 'prod-1',
        'id': 'prod-1',
        'name': 'Drip Irrigation System',
        'slug': 'drip-irrigation-system',
        'price': 15473,
        'currency': 'KES',
        'images': 'a.jpg b.jpg',
        'storeId': {
          '_id': 'store-1',
          'storeName': 'GreenGrocer Organics',
          'storeSlug': 'seed-store-9',
          'logoUrl': 'logo.jpg',
          'verifiedBadge': false,
        },
      },
      'sellerId': {
        '_id': 'seller-user-1',
        'id': 'seller-user-1',
        'fullName': 'GreenGrocer Organics Owner',
        'avatarUrl': 'face.jpg',
      },
      'quantity': 2,
      'priceSnapshot': 15473,
    },
    {
      '_id': 'item-2',
      'productId': {
        '_id': 'prod-2',
        'id': 'prod-2',
        'name': 'Healthy Livestock Starter',
        'slug': 'healthy-livestock-starter',
        'price': 9173,
        'images': 'c.jpg',
      },
      'sellerId': 'seller-user-2',
      'quantity': 1,
      'priceSnapshot': 9173,
    },
  ],
};

/// Mirrors one seller-order item from `GET /orders`: flattened item with
/// `productId` as a raw id string.
const orderPayload = {
  '_id': 'order-1',
  'id': 'order-1',
  'orderNumber': 'WZ-20260906-000001',
  'status': 'placed',
  'createdAt': '2026-09-06T07:37:50.291Z',
  'sellerId': {
    '_id': 'seller-user-1',
    'id': 'seller-user-1',
    'fullName': 'GreenGrocer Organics Owner',
    'avatarUrl': 'face.jpg',
  },
  'items': [
    {
      'productId': 'prod-1',
      'name': 'Drip Irrigation System',
      'image': 'a.jpg',
      'quantity': 2,
      'priceAtPurchase': 15473,
    },
  ],
  'subtotal': 30946,
  'total': 30946,
  'deliveryOption': 'delivery',
  'paymentMethod': 'cash_on_delivery',
};

void main() {
  group('CartData.fromApi', () {
    test('groups items by the item-level seller user id', () {
      final cart = CartData.fromApi(cartPayload);
      expect(cart.groups.length, 2);
      expect(cart.groups.map((g) => g.sellerId), [
        'seller-user-1',
        'seller-user-2',
      ]);
      expect(cart.groups.first.sellerName, 'GreenGrocer Organics');
      expect(cart.groups.first.sellerLogo, 'logo.jpg');
      expect(cart.groups.first.items, hasLength(1));
      expect(cart.groups.first.subtotal, 30946);
      expect(cart.itemCount, 3);
    });

    test('keeps every seller separate (no "other" collapse)', () {
      final cart = CartData.fromApi(cartPayload);
      expect(cart.groups.any((g) => g.sellerId == 'other'), isFalse);
    });
  });

  group('Order.fromApi', () {
    test('parses flattened order items from /orders', () {
      final order = Order.fromApi(orderPayload);
      expect(order.id, 'order-1');
      expect(order.orderNumber, 'WZ-20260906-000001');
      expect(order.seller?.id, 'seller-user-1');
      expect(order.seller?.name, 'GreenGrocer Organics Owner');
      expect(order.items, hasLength(1));
      expect(order.items.first.product.name, 'Drip Irrigation System');
      expect(order.items.first.product.images.first, 'a.jpg');
      expect(order.items.first.product.price, 15473);
      expect(order.items.first.quantity, 2);
    });
  });

  group('Review.fromApi', () {
    test('parses a populated targetId from /reviews/my', () {
      final review = Review.fromApi({
        '_id': 'review-1',
        'rating': 5,
        'comment': 'Exactly what I needed',
        'createdAt': '2026-09-06T10:00:00.000Z',
        'targetId': {
          'name': 'Drip Irrigation System',
          'slug': 'drip-irrigation-system',
        },
      });
      expect(review.id, 'review-1');
      expect(review.rating, 5);
      expect(review.productName, 'Drip Irrigation System');
    });

    test('uses storeName for a seller review', () {
      final review = Review.fromApi({
        '_id': 'review-2',
        'rating': 4,
        'targetId': {
          'storeName': 'GreenGrocer Organics',
          'storeSlug': 'seed-store-9',
        },
      });
      expect(review.sellerName, 'GreenGrocer Organics');
    });
  });
}
