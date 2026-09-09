import '../../../core/network/api_client.dart';
import '../models/deal.dart';
import '../models/product.dart';
import '../models/seller.dart';

/// Products, categories, deals, sellers and search against the live API.
class CatalogRepository {
  CatalogRepository(this._api);

  final ApiClient _api;

  // -- Products -----------------------------------------------------------
  Future<Paged<Product>> feed({int limit = 20, String? cursor}) async {
    final data = await _api.get(
      '/products/feed',
      query: {'limit': limit, if (cursor != null) 'cursor': cursor},
    );
    final List items = data is Map
        ? ((data['items'] ?? const []) as List)
        : (data is List ? data : const []);
    return Paged(
      items: items.map(Product.fromApi).toList(),
      page: 1,
      hasNext: data is Map ? (data['hasMore'] as bool? ?? false) : false,
      nextCursor: data is Map ? data['nextCursor'] as String? : null,
    );
  }

  Future<List<Product>> products({
    int limit = 24,
    int page = 1,
    String? sort,
    String? categorySlug,
    String? search,
  }) async {
    final data = await _api.get(
      '/products',
      query: {
        'limit': limit,
        'page': page,
        if (sort != null) 'sort': sort,
        if (categorySlug != null) 'category': categorySlug,
        if (search != null) 'search': search,
      },
    );
    return _productList(data);
  }

  Future<Product> product(String id) async {
    final data = await _api.get('/products/$id');
    return Product.fromApi(data);
  }

  Future<List<Product>> related(String id, {int limit = 10}) async {
    final data = await _api.get(
      '/products/$id/related',
      query: {'limit': limit},
    );
    return _productList(data);
  }

  Future<List<Product>> categoryProducts(
    String slug, {
    int limit = 24,
    int page = 1,
    String? sort,
    Map<String, dynamic>? filters,
  }) async {
    final data = await _api.get(
      '/categories/$slug/products',
      query: {
        'limit': limit,
        'page': page,
        if (sort != null) 'sort': sort,
        ...?filters,
      },
    );
    return _productList(data);
  }

  // -- Search ---------------------------------------------------------------
  Future<List<Product>> searchProducts(String q, {int limit = 24}) async {
    final data = await _api.get(
      '/search',
      query: {'q': q, 'type': 'products', 'limit': limit},
    );
    return _productList(data);
  }

  // -- Categories ----------------------------------------------------------
  Future<List<CategoryNode>> categoryTree() async {
    final data = await _api.get('/categories/tree');
    return CategoryNode.parseTree(data);
  }

  // -- Sellers ---------------------------------------------------------------
  Future<List<Seller>> sellers({int limit = 24, String? city}) async {
    final data = await _api.get(
      '/sellers',
      query: {
        'limit': limit,
        if (city != null && city.isNotEmpty) 'city': city,
      },
    );
    return _sellerList(data);
  }

  Future<List<Seller>> nearbySellers({
    double? lat,
    double? lng,
    double radiusKm = 50,
    int limit = 50,
  }) async {
    final data = await _api.get(
      '/sellers/nearby',
      query: {
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'radius': radiusKm,
        'limit': limit,
      },
    );
    return _sellerList(data);
  }

  Future<Seller> seller(String storeSlug) async {
    final data = await _api.get('/sellers/$storeSlug');
    return Seller.fromApi(data);
  }

  Future<List<Product>> sellerProducts(
    String storeSlug, {
    int limit = 24,
    int page = 1,
  }) async {
    final data = await _api.get(
      '/products',
      query: {'store': storeSlug, 'limit': limit, 'page': page},
    );
    return _productList(data);
  }

  Future<void> followSeller(String sellerId) async {
    await _api.post('/sellers/$sellerId/follow');
  }

  Future<void> unfollowSeller(String sellerId) async {
    await _api.delete('/sellers/$sellerId/follow');
  }

  // -- Deals -----------------------------------------------------------------
  /// Active flash deals (public endpoint, used for the home "Exclusive Deals"
  /// rail). The plain `/deals` route is admin-only and 401s for app users.
  Future<List<Deal>> deals() async {
    final data = await _api.get('/deals/flash');
    return _dealList(data);
  }

  /// Today's deals (public endpoint, used by the "All Deals" page).
  Future<List<Deal>> todayDeals() async {
    final data = await _api.get('/deals/today');
    return _dealList(data);
  }

  // -- Helpers ---------------------------------------------------------------
  List<Deal> _dealList(dynamic data) {
    final List list = data is Map
        ? (data['deals'] ?? const []) as List
        : (data as List);
    return list.map(Deal.fromApi).toList();
  }

  List<Product> _productList(dynamic data) {
    if (data is List) return data.map(Product.fromApi).toList();
    if (data is Map) {
      final items = data['products'] ?? data['items'] ?? data['data'];
      if (items is List) {
        return items.map(Product.fromApi).toList();
      }
      if (data['results'] is List) {
        return (data['results'] as List).map(Product.fromApi).toList();
      }
    }
    return const [];
  }

  List<Seller> _sellerList(dynamic data) {
    if (data is List) return data.map(Seller.fromApi).toList();
    if (data is Map) {
      final items =
          data['sellers'] ?? data['items'] ?? data['data'] ?? data['results'];
      if (items is List) return items.map(Seller.fromApi).toList();
    }
    return const [];
  }
}

// Paged{...} helper for infinite lists.
class Paged<T> {
  const Paged({
    required this.items,
    required this.page,
    this.hasNext = false,
    this.nextCursor,
  });

  final List<T> items;
  final int page;
  final bool hasNext;
  final String? nextCursor;

  factory Paged.empty() => const Paged(items: [], page: 1);
}
