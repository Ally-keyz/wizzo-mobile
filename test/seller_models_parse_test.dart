import 'package:flutter_test/flutter_test.dart';

import 'package:wizzo_market/features/seller/data/seller_repository.dart';
import 'package:wizzo_market/features/seller/models/payment_account.dart';
import 'package:wizzo_market/features/seller/models/seller_order.dart';
import 'package:wizzo_market/features/seller/models/store.dart';

/// Mirrors the real `GET /sellers/me` payload: `_id` (lean docs never rename
/// it to `id`), a populated `userId`, `verifiedBadge` and `paymentAccounts`
/// with the raw wire `method` values.
const storePayload = {
  '_id': 'store-1',
  'storeName': 'GreenGrocer Organics',
  'storeSlug': 'seed-store-9',
  'userId': {'_id': 'user-7', 'fullName': 'Owner'},
  'logoUrl': 'https://res.cloudinary.com/x/logo.jpg',
  'aboutStore': 'Fresh farm produce',
  'country': 'Rwanda',
  'district': 'Gasabo',
  'city': 'Kigali',
  'verifiedBadge': true,
  'verificationStatus': 'verified',
  'paymentMethodsAccepted': ['momo', 'cash_on_delivery'],
  'deliveryOptions': ['delivery', 'pickup'],
  'paymentAccounts': [
    {
      'method': 'momo',
      'provider': 'MTN',
      'accountName': 'GreenGrocer',
      'accountNumber': '0788123456',
      'instructions': 'Confirm with the reference',
    },
    {
      'method': 'cash_on_delivery',
      'accountName': 'Cash',
      'accountNumber': 'N/A',
    },
  ],
  'ratingAvg': 4.5,
  'ratingCount': 12,
  'productsCount': 3,
  'followersCount': 8,
  'status': 'active',
};

/// Mirrors a seller order from `GET /orders/seller`: flattened `items` with
/// `productId` as a raw id string and a `statusHistory` timeline.
const sellerOrderPayload = {
  '_id': 'order-42',
  'orderNumber': 'WZ-20260906-000123',
  'buyerId': 'user-9',
  'items': [
    {
      'productId': 'prod-1',
      'name': 'Drip Irrigation System',
      'image': 'https://res.cloudinary.com/x/a.jpg',
      'quantity': 2,
      'priceAtPurchase': 15473,
    },
  ],
  'subtotal': 30946,
  'shippingFee': 2000,
  'total': 32946,
  'deliveryOption': 'delivery',
  'deliveryAddress': {
    'fullName': 'Jane Buyer',
    'phone': '0722000000',
    'street': 'KG 11 Ave',
    'city': 'Kigali',
    'country': 'Rwanda',
  },
  'paymentMethod': 'cash_on_delivery',
  'status': 'processing',
  'createdAt': '2026-09-06T07:37:50.291Z',
  'statusHistory': [
    {'status': 'placed', 'at': '2026-09-06T07:37:50.291Z'},
    {'status': 'processing', 'at': '2026-09-06T09:12:00.000Z'},
  ],
};

void main() {
  group('MyStore.fromApi', () {
    test('reads the lean _id and nested userId', () {
      final store = MyStore.fromApi(storePayload);
      expect(store.id, 'store-1');
      expect(store.userId, 'user-7');
      expect(store.storeName, 'GreenGrocer Organics');
      expect(store.storeSlug, 'seed-store-9');
      expect(store.logoUrl, 'https://res.cloudinary.com/x/logo.jpg');
    });

    test('maps verifiedBadge and verificationStatus', () {
      final store = MyStore.fromApi(storePayload);
      expect(store.verified, isTrue);
      expect(store.isVerified, isTrue);
      expect(store.verificationStatus, 'verified');
    });

    test('parses paymentAccounts wire methods', () {
      final store = MyStore.fromApi(storePayload);
      expect(store.paymentAccounts, hasLength(2));
      expect(store.paymentAccounts.first.method, PaymentMethodKind.mobileMoney);
      expect(store.paymentAccounts.first.provider, 'MTN');
      expect(store.paymentAccounts.first.accountNumber, '0788123456');
      expect(
        store.paymentAccounts.last.method,
        PaymentMethodKind.cashOnDelivery,
      );
      expect(store.locationLabel, contains('Kigali'));
    });

    test('serializes payment accounts back to wire values', () {
      final json = storePayload['paymentAccounts'] as List;
      final parsed = json.map(PaymentAccount.fromApi).toList();
      expect(parsed.first.toJson()['method'], 'momo');
      expect(parsed.last.toJson()['method'], 'cash_on_delivery');
    });
  });

  group('SellerOrder.fromApi', () {
    test('parses a seller order payload', () {
      final order = SellerOrder.fromApi(sellerOrderPayload);
      expect(order.id, 'order-42');
      expect(order.orderNumber, 'WZ-20260906-000123');
      expect(order.buyerId, 'user-9');
      expect(order.items, hasLength(1));
      expect(order.items.first.name, 'Drip Irrigation System');
      expect(order.items.first.quantity, 2);
      expect(order.items.first.lineTotal, 30946);
      expect(order.grandTotal, 32946);
      expect(order.deliveryAddress?.summary, 'KG 11 Ave, Kigali, Rwanda');
      expect(order.status, SellerOrderStatus.processing);
      expect(order.statusHistory, hasLength(2));
    });

    test('flags pickup and cash-on-delivery', () {
      final pickup = SellerOrder.fromApi({
        ...sellerOrderPayload,
        'deliveryOption': 'pickup',
      });
      expect(pickup.isPickup, isTrue);
      expect(pickup.isDelivery, isFalse);
      final cod = SellerOrder.fromApi(sellerOrderPayload);
      expect(cod.isCashOnDelivery, isTrue);
    });

    test('settling statuses drive the Pending amount', () {
      for (final s in settlingStatuses) {
        final order = SellerOrder.fromApi({
          '_id': s,
          'orderNumber': 'WZ-1',
          'items': const [],
          'subtotal': 100,
          'status': s,
          'createdAt': '2026-09-06T07:37:50.291Z',
        });
        expect(settlingStatuses.contains(order.status), isTrue, reason: s);
      }
    });

    test('bucket matching covers every wire status', () {
      for (final s in SellerOrderStatus.all) {
        final hits = OrderBucket.values.where((b) => b.matches(s)).length;
        expect(hits, greaterThan(0), reason: s);
      }
    });
  });

  group('ProductInput.toJson', () {
    const input = ProductInput(
      name: '  Drip Irrigation System ',
      categoryId: 'cat-1',
      description: 'Self-watering kit',
      price: 15000,
      discountPrice: 12000,
      stock: 5,
      images: ['https://res.cloudinary.com/x/a.jpg'],
      brand: 'AgriTech',
    );

    test('create payload uses trimmed name and categoryId', () {
      final json = input.toJson();
      expect(json['name'], 'Drip Irrigation System');
      expect(json['categoryId'], 'cat-1');
      expect(json['discountPrice'], 12000);
      expect(json['price'], 15000);
      expect(json['stock'], 5);
      expect(json.containsKey('subcategoryId'), isFalse);
    });

    test('update clears a zeroed discount price to null', () {
      const cleared = ProductInput(
        name: 'Drip Irrigation System',
        categoryId: 'cat-1',
        description: 'Self-watering kit',
        price: 15000,
        discountPrice: 0,
        stock: 5,
        images: ['https://res.cloudinary.com/x/a.jpg'],
      );
      final json = cleared.toJson(isUpdate: true);
      expect(json['discountPrice'], isNull);
      expect(json['discountEndsAt'], isNull);
    });
  });
}
