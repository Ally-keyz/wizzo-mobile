import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/l10n.dart';

import 'package:wizzo_market/core/network/api_client.dart';
import 'package:wizzo_market/core/theme/app_theme.dart';
import 'package:wizzo_market/features/catalog/data/catalog_repository.dart';
import 'package:wizzo_market/features/catalog/models/deal.dart';
import 'package:wizzo_market/features/catalog/models/product.dart';
import 'package:wizzo_market/features/catalog/models/seller.dart';
import 'package:wizzo_market/features/catalog/presentation/home_screen.dart';
import 'package:wizzo_market/features/catalog/presentation/nearby_sellers_screen.dart';
import 'package:wizzo_market/features/catalog/providers/catalog_providers.dart';
import 'package:wizzo_market/features/notifications/data/notification_repository.dart';

/// Offline catalog double: every home rail resolves to an empty list, so the
/// screen exercises its real widget tree without touching the network.
class _EmptyCatalogRepository extends CatalogRepository {
  _EmptyCatalogRepository()
    : super(ApiClient(baseUrl: 'https://example.invalid/api/v1'));

  @override
  Future<Paged<Product>> feed({int limit = 20, String? cursor}) async =>
      const Paged(items: [], page: 1);

  @override
  Future<List<Product>> discountedProducts({int limit = 50}) async => const [];

  @override
  Future<List<Deal>> allActiveDeals() async => const [];

  @override
  Future<List<CategoryNode>> categoryTree() async => const [];

  @override
  Future<List<Seller>> sellers({int limit = 24, String? city}) async =>
      const [];

  @override
  Future<List<Seller>> nearbySellers({
    double? lat,
    double? lng,
    double radiusKm = 50,
    int limit = 50,
  }) async => const [];

  @override
  Future<List<Product>> categoryProducts(
    String slug, {
    int limit = 24,
    int page = 1,
    String? sort,
    Map<String, dynamic>? filters,
  }) async => const [];
}

class _StubFeed extends HomeFeedController {
  @override
  Future<Paged<Product>> build() async =>
      const Paged(items: [_product], page: 1);
}

const _product = Product(
  id: 'prod-1',
  name: 'Sample product',
  slug: 'sample-product',
  images: [],
  price: 12000,
  originalPrice: 15000,
  ratingAvg: 4.5,
  ratingCount: 12,
);

const _seller = Seller(
  id: 'seller-1',
  storeName: 'Sample store',
  storeSlug: 'sample-store',
  verified: true,
);

final _deal = Deal(
  id: 'deal-1',
  title: 'Flash sale',
  type: DealType.flash,
  endsAt: DateTime.now().add(const Duration(hours: 2)),
  products: const [_product],
);

void main() {
  testWidgets('HomeScreen builds its full page without exceptions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      // Skip the first-launch GPS prompt: it is not what this test covers.
      'wizzo_location_prompted': true,
    });
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWith(
            (ref) => _EmptyCatalogRepository(),
          ),
          categoriesProvider.overrideWith(
            (ref) async => const [
              CategoryNode(id: 'cat-1', name: 'Fashion', slug: 'fashion'),
            ],
          ),
          secondHandProductsProvider.overrideWith((ref) async => const []),
          notificationsUnreadProvider.overrideWith((ref) async => 0),
          authDisplayNameProvider.overrideWithValue(null),
        ],
        child: localizedApp(const HomeScreen(), theme: buildLightTheme()),
      ),
    );

    // Let the async rails resolve and lay the page out.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(tester.takeException(), isNull);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Search products, sellers, deals...'), findsOneWidget);
    expect(find.text('Kigali'), findsOneWidget);
    expect(find.text('For You'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
  });

  testWidgets('HomeScreen rails, carousel and scroll stay exception free', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'wizzo_location_prompted': true,
    });
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWith(
            (ref) => _EmptyCatalogRepository(),
          ),
          categoriesProvider.overrideWith(
            (ref) async => const [
              CategoryNode(id: 'cat-1', name: 'Fashion', slug: 'fashion'),
            ],
          ),
          homeFeedProvider.overrideWith(_StubFeed.new),
          homeDealsProvider.overrideWith((ref) async => [_deal, _deal]),
          promotedProductsProvider.overrideWith(
            (ref) async => const [_product],
          ),
          secondHandProductsProvider.overrideWith(
            (ref) async => const [_product],
          ),
          topSellersProvider.overrideWith((ref) async => const [_seller]),
          nearbySellersProvider.overrideWith((ref) async => const [_seller]),
          notificationsUnreadProvider.overrideWith((ref) async => 0),
          authDisplayNameProvider.overrideWithValue(null),
        ],
        child: localizedApp(const HomeScreen(), theme: buildLightTheme()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);

    // Auto-advancing deals carousel.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);

    // Product grid + top sellers + community CTA below the fold.
    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -900),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text('Top Sellers'), findsOneWidget);

    // Let the one-shot countdown refresh timers created while scrolling finish
    // before the test binding checks for pending timers.
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
