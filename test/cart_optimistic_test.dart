import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wizzo_market/features/cart/data/cart_repository.dart';
import 'package:wizzo_market/features/cart/models/cart.dart';
import 'package:wizzo_market/features/cart/providers/cart_provider.dart';
import 'package:wizzo_market/features/catalog/models/product.dart';

Product _product({
  String id = 'p1',
  String name = 'Nike Air Max',
  num price = 40,
  String? sellerId = 's1',
}) {
  return Product(
    id: id,
    name: name,
    slug: id,
    images: const ['https://img.example/nike.png'],
    price: price,
    seller: sellerId == null
        ? null
        : ProductSeller(
            id: sellerId,
            storeName: 'Kicks Rwanda',
            storeSlug: 'kicks',
            logoUrl: 'https://img.example/logo.png',
            verified: true,
          ),
  );
}

/// A populated cart item, as the server sends it after the populate fix.
Map<String, dynamic> _serverItem({String productId = 'p1', int quantity = 1}) => {
      '_id': productId,
      'productId': productId,
      'sellerId': 's1',
      'quantity': quantity,
      'priceSnapshot': 40,
      'product': {
        'id': productId,
        'name': 'Nike Air Max',
        'slug': productId,
        'images': ['https://img.example/nike.png'],
        'price': 40,
      },
    };

/// The same row as an unpopulated mutating endpoint used to return it: only
/// ids and a price snapshot, no product document.
Map<String, dynamic> _unpopulatedItem({String productId = 'p1'}) => {
      'productId': productId,
      'sellerId': 's1',
      'quantity': 1,
      'priceSnapshot': 40,
    };

/// Holds every mutation open so a test can inspect the cart while the request
/// is still in flight, which is the window the user was complaining about.
class _FakeCartRepository implements CartRepository {
  _FakeCartRepository({this.onAdd});

  final Future<CartData> Function()? onAdd;
  final pending = <Completer<CartData>>[];
  int fetchCalls = 0;
  CartData? seeded;

  @override
  Future<CartData> fetch() async {
    fetchCalls++;
    return seeded ?? CartData.fromItems(const []);
  }

  @override
  Future<CartData> addItem({
    required String productId,
    int quantity = 1,
    String? size,
    String? color,
  }) {
    final hook = onAdd;
    if (hook != null) return hook();
    final completer = Completer<CartData>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<CartData> updateQuantity(String productId, int quantity) async =>
      CartData.fromItems([_serverItem(productId: productId, quantity: quantity)]);

  @override
  Future<CartData> removeItem(String productId) async =>
      CartData.fromItems(const []);

  @override
  Future<void> clear() async {}

  @override
  Future<Map<String, dynamic>> totals() async => const {};
}

Future<ProviderContainer> _container(_FakeCartRepository repo) async {
  final container = ProviderContainer(
    overrides: [cartRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  await container.read(cartProvider.future);
  return container;
}

/// The single cart row, whichever group it landed in.
CartItem? _onlyItem(ProviderContainer container) {
  final cart = container.read(cartProvider).value;
  if (cart == null) return null;
  return cart.groups.expand((g) => g.items).firstOrNull;
}

void main() {
  group('CartController.addItem', () {
    test('shows the row immediately, before the server replies', () async {
      final repo = _FakeCartRepository();
      final container = await _container(repo);
      expect(repo.pending, isEmpty);

      // Deliberately not awaited: the row has to be there while the POST is
      // still in flight, which is the whole point of the optimistic insert.
      final pending = container.read(cartProvider.notifier).addItem(product: _product());
      await Future<void>.delayed(Duration.zero);

      final item = _onlyItem(container);
      expect(item, isNotNull, reason: 'item must render before the POST returns');
      expect(item!.product.name, 'Nike Air Max');
      expect(item.product.images, isNotEmpty);
      expect(item.sellerName, 'Kicks Rwanda');
      expect(repo.pending, hasLength(1), reason: 'POST is still in flight');

      repo.pending.single.complete(CartData.fromItems([_serverItem()]));
      await pending;
    });

    test('badge count, subtotal and total track the optimistic row', () async {
      final repo = _FakeCartRepository();
      final container = await _container(repo);

      final pending = container.read(cartProvider.notifier).addItem(
            product: _product(),
            quantity: 2,
          );
      await Future<void>.delayed(Duration.zero);

      final cart = container.read(cartProvider).value!;
      expect(cart.itemCount, 2);
      expect(cart.subtotal, 80);
      expect(cart.total, 80);
      // The badge is derived from the same state, so it can never disagree
      // with the visible list.
      expect(container.read(cartCountProvider), 2);

      repo.pending.single.complete(CartData.fromItems([_serverItem(quantity: 2)]));
      await pending;
    });

    test('re-adding the same product increments one row, not a second', () async {
      final repo = _FakeCartRepository();
      final container = await _container(repo);

      final first = container.read(cartProvider.notifier).addItem(product: _product());
      await Future<void>.delayed(Duration.zero);
      repo.pending.removeAt(0).complete(CartData.fromItems([_serverItem()]));
      await first;

      final second = container.read(cartProvider.notifier).addItem(
            product: _product(),
            quantity: 3,
          );
      await Future<void>.delayed(Duration.zero);

      final cart = container.read(cartProvider).value!;
      expect(cart.groups.expand((g) => g.items), hasLength(1));
      expect(cart.itemCount, 4);
      expect(cart.subtotal, 160);
      expect(_onlyItem(container)!.quantity, 4);

      repo.pending.single.complete(CartData.fromItems([_serverItem(quantity: 4)]));
      await second;
    });

    test('starts a seller group for a seller not yet in the cart', () async {
      final repo = _FakeCartRepository();
      final container = await _container(repo);

      final pending = container.read(cartProvider.notifier).addItem(product: _product());
      await Future<void>.delayed(Duration.zero);

      final group = container.read(cartProvider).value!.groups.single;
      expect(group.sellerId, 's1');
      expect(group.sellerName, 'Kicks Rwanda');
      expect(group.verified, isTrue);
      expect(group.subtotal, 40);

      repo.pending.single.complete(CartData.fromItems([_serverItem()]));
      await pending;
    });

    test('adopts the populated response instead of refetching', () async {
      final repo = _FakeCartRepository();
      final container = await _container(repo);
      final fetchesBefore = repo.fetchCalls;

      final pending = container.read(cartProvider.notifier).addItem(
            product: _product(),
            quantity: 2,
          );
      await Future<void>.delayed(Duration.zero);
      repo.pending.single.complete(
        CartData.fromItems([_serverItem(quantity: 2)]),
      );
      await pending;

      expect(repo.fetchCalls, fetchesBefore, reason: 'no extra GET /cart');
      expect(container.read(cartProvider).value!.itemCount, 2);
    });

    test('refetches when the response comes back unpopulated', () async {
      // A new app build can run against a server that has not shipped the
      // populate fix; adopting those rows would replace a good optimistic row
      // with a blank "Product" placeholder.
      final repo = _FakeCartRepository(
        onAdd: () async => CartData.fromItems([_unpopulatedItem()]),
      );
      final container = await _container(repo);
      final fetchesBefore = repo.fetchCalls;
      // What the fallback GET /cart will find.
      repo.seeded = CartData.fromItems([_serverItem()]);

      await container.read(cartProvider.notifier).addItem(product: _product());

      expect(repo.fetchCalls, fetchesBefore + 1, reason: 'fell back to GET /cart');
      final item = _onlyItem(container);
      expect(item!.product.name, 'Nike Air Max', reason: 'real product, not a placeholder');
    });

    test('rolls the optimistic row back when the request fails', () async {
      final repo = _FakeCartRepository();
      final container = await _container(repo);

      final pending = container.read(cartProvider.notifier).addItem(product: _product());
      await Future<void>.delayed(Duration.zero);
      expect(_onlyItem(container), isNotNull);

      repo.pending.single.completeError(Exception('offline'));
      await expectLater(pending, throwsA(isA<Exception>()));

      expect(container.read(cartProvider).value!.groups, isEmpty);
      expect(container.read(cartCountProvider), 0);
    });
  });
}
