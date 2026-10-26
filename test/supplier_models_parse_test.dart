import 'package:flutter_test/flutter_test.dart';

import 'package:wizzo_market/features/seller/data/seller_repository.dart';
import 'package:wizzo_market/features/seller/models/supplier.dart';

void main() {
  group('SupplierSummary.fromApi', () {
    test('reads Mongo _id and the public directory fields', () {
      final supplier = SupplierSummary.fromApi({
        '_id': 'sup1',
        'name': 'Kigali Wholesale',
        'company': 'KW Ltd',
        'logo': 'https://res.cloudinary.com/x/logo.jpg',
        'email': 'orders@kw.rw',
        'phone': '+250788000000',
        'currency': 'usd',
      });

      expect(supplier.id, 'sup1');
      expect(supplier.name, 'Kigali Wholesale');
      expect(supplier.company, 'KW Ltd');
      expect(supplier.logo, 'https://res.cloudinary.com/x/logo.jpg');
      expect(supplier.email, 'orders@kw.rw');
      expect(supplier.currency, 'USD');
    });
  });

  group('SupplierItem.fromApi', () {
    test('reads catalog fields and prefers the images gallery', () {
      final item = SupplierItem.fromApi({
        '_id': 'item1',
        'name': 'Wireless Earbuds',
        'sku': 'SKU-1',
        'description': 'Bluetooth 5.3',
        'image': 'https://res.cloudinary.com/x/cover.jpg',
        'images': [
          'https://res.cloudinary.com/x/a.jpg',
          'https://res.cloudinary.com/x/b.jpg',
        ],
        'cost': 12.5,
        'currency': 'usd',
        'stock': 8,
      });

      expect(item.id, 'item1');
      expect(item.name, 'Wireless Earbuds');
      expect(item.sku, 'SKU-1');
      expect(item.cost, 12.5);
      expect(item.currency, 'USD');
      expect(item.stock, 8);
      expect(item.gallery, [
        'https://res.cloudinary.com/x/a.jpg',
        'https://res.cloudinary.com/x/b.jpg',
      ]);
      expect(item.inStock, isTrue);
    });

    test('falls back to the legacy image cover when images is empty', () {
      final item = SupplierItem.fromApi({
        '_id': 'item2',
        'name': 'Phone Case',
        'image': 'https://res.cloudinary.com/x/cover.jpg',
        'cost': 3,
      });

      expect(item.gallery, ['https://res.cloudinary.com/x/cover.jpg']);
    });

    test('treats a null stock as available and zero as out of stock', () {
      expect(SupplierItem.fromApi({'_id': 'a', 'name': 'A'}).inStock, isTrue);
      expect(
        SupplierItem.fromApi({'_id': 'b', 'name': 'B', 'stock': 0}).inStock,
        isFalse,
      );
    });
  });

  group('ProductInput dropship fields', () {
    const input = ProductInput(
      name: 'Wireless Earbuds',
      categoryId: 'cat1',
      description: 'Bluetooth',
      price: 25000,
      stock: 8,
      images: ['https://res.cloudinary.com/x/a.jpg'],
      supplierId: 'sup1',
      supplierItemId: 'item1',
    );

    test('sends supplier refs on product creation', () {
      final json = input.toJson();
      expect(json['supplierId'], 'sup1');
      expect(json['supplierItemId'], 'item1');
    });

    test('never resends supplier refs on product updates', () {
      final json = input.toJson(isUpdate: true);
      expect(json.containsKey('supplierId'), isFalse);
      expect(json.containsKey('supplierItemId'), isFalse);
    });
  });
}
