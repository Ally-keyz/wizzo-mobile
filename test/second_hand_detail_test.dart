import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wizzo_market/core/network/api_client.dart';
import 'package:wizzo_market/features/catalog/data/catalog_repository.dart';
import 'package:wizzo_market/features/catalog/data/second_hand_demo.dart';
import 'package:wizzo_market/features/catalog/models/product.dart';
import 'package:wizzo_market/features/catalog/providers/catalog_providers.dart';

/// Fails loudly if anything tries to reach the API. The bundled second-hand
/// demo listings only exist on the device, so looking them up over the network
/// (which answers 400 for their `demo-*` ids) is exactly the bug being fixed.
class _NoNetworkCatalogRepository extends CatalogRepository {
  _NoNetworkCatalogRepository()
    : super(ApiClient(baseUrl: 'https://example.invalid/api/v1'));

  @override
  Future<Product> product(String id) async =>
      throw StateError('Unexpected network lookup for "$id"');

  @override
  Future<List<Product>> related(String id, {int limit = 10}) async =>
      throw StateError('Unexpected network lookup for "$id"');
}

/// Returns whatever the test hands it, so the provider's demo fallback can be
/// exercised without a server.
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
}

void main() {
  final demo = secondHandDemoProducts.first;

  test('localSecondHandProduct matches by id and slug', () {
    expect(localSecondHandProduct(demo.id), same(demo));
    expect(localSecondHandProduct(demo.slug), same(demo));
    expect(localSecondHandProduct('missing-product'), isNull);
  });

  group('demo second-hand detail', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer.test(
        overrides: [
          catalogRepositoryProvider.overrideWith(
            (ref) => _NoNetworkCatalogRepository(),
          ),
        ],
      );
    });

    test(
      'resolves the product locally instead of calling /products/:id',
      () async {
        final product = await container.read(productProvider(demo.id).future);
        expect(product.id, demo.id);
        expect(product.name, demo.name);
        expect(product.isSecondHand, isTrue);
      },
    );

    test('builds the related rail from the bundled listings', () async {
      final related = await container.read(
        relatedProductsProvider(demo.id).future,
      );
      expect(related, isNotEmpty);
      expect(related.any((p) => p.id == demo.id), isFalse);
      expect(related.every((p) => p.isSecondHand), isTrue);
    });
  });

  group('second-hand rail demo fallback', () {
    ProviderContainer containerFor(CatalogRepository repo) =>
        ProviderContainer.test(
          overrides: [catalogRepositoryProvider.overrideWith((ref) => repo)],
        );

    final real = Product.fromApi({
      '_id': 'real-1',
      'name': 'Real used bike',
      'slug': 'real-used-bike',
      'price': 120000,
      'listingType': 'second_hand',
      'condition': 'used',
    });

    test('shows the real listing and drops the demo set', () async {
      final container = containerFor(_StubCatalogRepository(listings: [real]));
      final products = await container.read(secondHandProductsProvider.future);

      expect(products.map((p) => p.id), ['real-1']);
      expect(products.any((p) => p.id.startsWith('demo-')), isFalse);
    });

    test('falls back to the demo set while the marketplace is empty', () async {
      final container = containerFor(_StubCatalogRepository());
      final products = await container.read(secondHandProductsProvider.future);

      expect(products, secondHandDemoProducts);
    });

    test('falls back to the demo set when the request fails', () async {
      final container = containerFor(_StubCatalogRepository(offline: true));
      final products = await container.read(secondHandProductsProvider.future);

      expect(products, secondHandDemoProducts);
    });
  });
}
