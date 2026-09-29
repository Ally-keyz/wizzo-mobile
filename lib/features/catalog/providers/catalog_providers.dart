import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';

import '../data/catalog_repository.dart';
import '../models/deal.dart';
import '../models/product.dart';
import '../models/seller.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(apiClientProvider));
});

/// Home feed ("For You") with cursor-based pagination. Pull-to-refresh resets
/// to the first page; [HomeFeedController.loadMore] appends the next cursor
/// page for the endless scroll.
class HomeFeedController extends AsyncNotifier<Paged<Product>> {
  static const int _pageSize = 10;

  @override
  Future<Paged<Product>> build() async {
    final repo = ref.watch(catalogRepositoryProvider);
    return repo.feed(limit: _pageSize);
  }

  /// Appends the next cursor page of products to the feed. No-op while
  /// already loading, after an error, or when there is no next page.
  Future<void> loadMore() async {
    final data = state.value;
    if (state.isLoading ||
        state.hasError ||
        data == null ||
        !data.hasNext ||
        data.nextCursor == null) {
      return;
    }
    try {
      final more = await ref
          .read(catalogRepositoryProvider)
          .feed(limit: _pageSize, cursor: data.nextCursor);
      final seen = data.items.map((p) => p.id).toSet();
      final merged = <Product>[...data.items];
      for (final p in more.items) {
        if (seen.add(p.id)) merged.add(p);
      }
      state = AsyncData(
        Paged(
          items: merged,
          page: 1,
          hasNext: more.hasNext,
          nextCursor: more.nextCursor,
        ),
      );
    } catch (_) {
      // Keep the previous page; the button stays tappable to retry.
    }
  }
}

final homeFeedProvider =
    AsyncNotifierProvider<HomeFeedController, Paged<Product>>(
      HomeFeedController.new,
    );

/// Every active deal (flash + today + limited + clearance), merged & deduped,
/// ending soonest first. Each endpoint degrades independently, so one failing
/// route no longer blanks the whole "Exclusive Deals" rail.
final allDealsProvider = FutureProvider<List<Deal>>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final merged = await repo.allActiveDeals();
  merged.sort((a, b) {
    final at = a.endsAt?.millisecondsSinceEpoch;
    final bt = b.endsAt?.millisecondsSinceEpoch;
    if (at == null && bt == null) return 0;
    if (at == null) return 1;
    if (bt == null) return -1;
    return at.compareTo(bt);
  });
  return merged;
});

/// Deals backing the home "Exclusive Deals" carousel.
final homeDealsProvider = FutureProvider<List<Deal>>(
  (ref) => ref.watch(allDealsProvider.future),
);

/// Everything currently on promotion: products attached to any active deal,
/// unioned with every discounted product from `/products?discount=true`,
/// deduped and sorted by biggest saving first.
///
/// The union matters because a product can be discounted without sitting under
/// a deal banner, and a deal banner can exist with no active end date. Relying
/// on deal banners alone is what left the rail empty.
final promotedProductsProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final results = await Future.wait([
    ref.watch(allDealsProvider.future).then(
          (deals) => [for (final d in deals) ...d.products],
          onError: (_) => <Product>[],
        ),
    repo.discountedProducts().then(
          (products) => products,
          onError: (_) => <Product>[],
        ),
  ]);

  final seen = <String>{};
  final products = <Product>[];
  for (final p in [...results[0], ...results[1]]) {
    if (p.id.isEmpty) continue;
    if (seen.add(p.id)) products.add(p);
  }
  products.sort((a, b) => b.discount.compareTo(a.discount));
  return products;
});

/// Every discounted product across all active deals (flash + today),
/// biggest savings first. Backs the "All Deals" page.
final allDealsProductsProvider =
    FutureProvider<List<Product>>((ref) => ref.watch(promotedProductsProvider.future));


/// Category tree (2 levels).
final categoriesProvider = FutureProvider<List<CategoryNode>>((ref) async {
  return ref.watch(catalogRepositoryProvider).categoryTree();
});

/// Curated sellers for the "Top Sellers" home rail.
final topSellersProvider = FutureProvider<List<Seller>>((ref) async {
  return ref.watch(catalogRepositoryProvider).sellers(limit: 10);
});

/// Single product detail (watch with the product id).
final productProvider = FutureProvider.family<Product, String>((ref, id) async {
  return ref.watch(catalogRepositoryProvider).product(id);
});

/// Related products row under a product page.
final relatedProductsProvider = FutureProvider.family<List<Product>, String>((
  ref,
  id,
) async {
  return ref.watch(catalogRepositoryProvider).related(id);
});

/// Products inside a category (subsection slug).
final categoryProductsProvider = FutureProvider.family<List<Product>, String>((
  ref,
  slug,
) {
  return ref.watch(catalogRepositoryProvider).categoryProducts(slug, limit: 24);
});

/// Seller profile page.
final sellerProvider = FutureProvider.family<Seller, String>((
  ref,
  storeSlug,
) async {
  return ref.watch(catalogRepositoryProvider).seller(storeSlug);
});

/// Products by a given seller (store slug).
final sellerProductsProvider = FutureProvider.family<List<Product>, String>((
  ref,
  storeSlug,
) {
  return ref
      .watch(catalogRepositoryProvider)
      .sellerProducts(storeSlug, limit: 24);
});

/// Search-as-you-type products.
final searchResultsProvider = FutureProvider.family<List<Product>, String>((
  ref,
  query,
) async {
  final q = query.trim();
  if (q.isEmpty) return const [];
  return ref.watch(catalogRepositoryProvider).searchProducts(q);
});
