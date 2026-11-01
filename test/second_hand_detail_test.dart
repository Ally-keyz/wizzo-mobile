import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wizzo_market/core/network/api_client.dart';
import 'package:wizzo_market/features/catalog/data/catalog_repository.dart';
import 'package:wizzo_market/features/catalog/models/product.dart';
import 'package:wizzo_market/features/catalog/providers/catalog_providers.dart';

/// Second-hand listings are now real database records, so every lookup goes
/// over the network exactly like any other product. These tests pin that
/// behaviour — no local demo fallback, no special-casing of `demo-*` ids.
class _StubCatalogRepository extends CatalogRepository {
  _StubCatalogRepository({
    this.listings = const <Product>[],
    this.offline = false,
  }) : super(ApiClient(baseUrl: 'https://example.invalid/api/v1'));

  final List<Product> listings;
  final bool offline;

  @override
  Future<List<Product>> secondHandProducts({
    int limit = 24,
    int page = 1,
  }) async {
    if (offline) throw StateError('offline');
    return listings;
  }

  @override
  Future<Product> product(String id) async => Product.fromApi({
    '_id': id,
    'name': 'Product $id',
    'slug': 'product-$id',
    'price': 1000,
    'listingType': 'second_hand',
    'condition': 'used',
  });

  @override
  Future<List<Product>> related(String id, {int limit = 10}) async {
    return [
      Product.fromApi({
        '_id': 'related-1',
        'name': 'Related item',
        'slug': 'related-1',
        'price': 500,
        'listingType': 'second_hand',
        'condition': 'used',
      }),
    ];
  }
}

void main() {
  ProviderContainer containerFor(CatalogRepository repo) => ProviderContainer.test(
    overrides: [catalogRepositoryProvider.overrideWith((ref) => repo)],
  );

  group('second-hand products provider', () {
    test('returns the server listings verbatim (no demo fallback)', () async {
      final real = Product.fromApi({
        '_id': 'real-1',
        'name': 'Real used bike',
        'slug': 'real-used-bike',
        'price': 120000,
        'listingType': 'second_hand',
        'condition': 'used',
      });

      final container = containerFor(_StubCatalogRepository(listings: [real]));
      final products = await container.read(secondHandProductsProvider.future);

      expect(products.map((p) => p.id), ['real-1']);
    });

    test('returns an empty list when the marketplace has no listings', () async {
      final container = containerFor(_StubCatalogRepository());
      final products = await container.read(secondHandProductsProvider.future);

      expect(products, isEmpty);
    });

    test('propagates the error when the request fails', () async {
      final container = containerFor(_StubCatalogRepository(offline: true));

      await expectLater(
        container.read(secondHandProductsProvider.future),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('second-hand product detail', () {
    test('resolves the product over /products/:id', () async {
      final container = containerFor(_StubCatalogRepository());
      final product = await container.read(productProvider('real-1').future);

      expect(product.id, 'real-1');
      expect(product.isSecondHand, isTrue);
    });

    test('resolves the related rail over /products/:id/related', () async {
      final container = containerFor(_StubCatalogRepository());
      final related = await container.read(
        relatedProductsProvider('real-1').future,
      );

      expect(related, isNotEmpty);
      expect(related.first.id, 'related-1');
    });
  });
}
