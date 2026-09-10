import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../catalog/models/product.dart';
import '../models/order.dart';
import '../models/profile.dart';

class AccountRepository {
  AccountRepository(this._api);

  final ApiClient _api;

  // -- Profile -----------------------------------------------------------
  Future<Map<String, dynamic>> me() async {
    final data = await _api.get('/users/me');
    return data is Map<String, dynamic> ? data : const {};
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> body) async {
    final data = await _api.patch('/users/me', body: body);
    return data is Map<String, dynamic> ? data : const {};
  }

  Future<AddressBook> addresses() async {
    final data = await _api.get('/users/me/addresses');
    final items = data is List ? data : (data is Map ? (data['addresses'] ?? const []) : const <dynamic>[]);
    return AddressBook.parse(items);
  }

  /// Adds a delivery address and returns its server-assigned id.
  Future<String> addAddress(Map<String, dynamic> body) async {
    final data = await _api.post('/users/me/addresses', body: body);
    if (data is Map<String, dynamic>) {
      return data['id']?.toString() ?? data['_id']?.toString() ?? '';
    }
    return '';
  }

  // -- Orders ---------------------------------------------------------------
  Future<List<Order>> orders() async {
    final data = await _api.get('/orders');
    final items = data is List
        ? data
        : (data is Map ? (data['orders'] ?? data['items'] ?? data['data']) : const []);
    if (items is! List) return const [];
    return items.map(Order.fromApi).toList();
  }

  Future<Order> order(String id) async {
    final data = await _api.get('/orders/$id');
    return Order.fromApi(data);
  }

  Future<void> cancelOrder(String id, {String? reason}) async {
    await _api.post('/orders/$id/cancel', body: {
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  Future<void> confirmDelivery(String id) async {
    await _api.post('/orders/$id/pickup-confirm');
  }

  Future<void> requestReturn(String id, {String? reason}) async {
    await _api.post('/orders/$id/return', body: {
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  // -- Wishlist ---------------------------------------------------------------
  /// Paginated wishlist (max 100) whose `productId` is a populated Product doc.
  Future<List<Product>> wishlistProducts() async {
    final data = await _api.get('/wishlist');
    final items = data is List
        ? data
        : (data is Map ? (data['items'] ?? const <dynamic>[]) : const <dynamic>[]);
    if (items is! List) return const [];
    final products = <Product>[];
    for (final e in items) {
      if (e is! Map) continue;
      final p = e['productId'];
      if (p is Map) {
        try {
          products.add(Product.fromApi(p));
        } catch (_) {
          // Ignore malformed entries rather than failing the whole list.
        }
      }
    }
    return products;
  }

  Future<List<String>> wishlistIds() async {
    final products = await wishlistProducts();
    return products.map((p) => p.id).toList();
  }

  /// POST /wishlist toggles between add and remove server-side and reports
  /// whether the item ended up added (`{added: true}`).
  Future<bool> toggleWishlist(String productId) async {
    final data = await _api.post('/wishlist', body: {'productId': productId});
    if (data is Map) return data['added'] == true;
    return true;
  }

  // -- Payments ---------------------------------------------------------------
  Future<List<PaymentMethod>> paymentMethods() async {
    final data = await _api.get('/payments/methods');
    if (data is List) return data.map(PaymentMethod.fromApi).toList();
    // Fall back to the server's known list when the endpoint is missing.
    return PaymentMethod.defaults;
  }

  // -- Wallet ----------------------------------------------------------------
  Future<Wallet> wallet() async {
    Map<String, dynamic>? data;
    try {
      final result = await _api.get('/wallet');
      if (result is Map<String, dynamic>) data = result;
    } on ApiException catch (e) {
      // The backend does not expose a wallet endpoint yet; render the wallet
      // shell with zeroed balances rather than failing the whole screen.
      if (!e.isNotFound) rethrow;
    }
    return Wallet.fromApi(data ?? const {});
  }

  // -- Reviews ----------------------------------------------------------------
  /// The signed-in user's own reviews (GET /reviews/my, paginated).
  Future<List<Review>> reviews() async {
    final data = await _api.get('/reviews/my');
    final items = data is List
        ? data
        : (data is Map ? (data['reviews'] ?? data['items'] ?? data['data'] ?? const []) : const <dynamic>[]);
    if (items is! List) return const [];
    return items.map(Review.fromApi).toList();
  }

  /// Reviews for a single product (used on the product detail screen).
  Future<List<Review>> productReviews(String productId) async {
    final data = await _api.get(
      '/reviews',
      query: {'type': 'product', 'targetId': productId},
    );
    final items = data is List
        ? data
        : (data is Map ? (data['reviews'] ?? data['items'] ?? data['data'] ?? const []) : const <dynamic>[]);
    if (items is! List) return const [];
    return items.map(Review.fromApi).toList();
  }

  /// Creates a product review (`type=product`). Returns nothing on success.
  Future<void> submitReview({
    required String productId,
    required int rating,
    String? comment,
  }) async {
    await _api.post('/reviews', body: {
      'type': 'product',
      'targetId': productId,
      'rating': rating,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
    });
  }
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(apiClientProvider));
});

/// Orders list.
final ordersProvider = FutureProvider<List<Order>>((ref) {
  return ref.watch(accountRepositoryProvider).orders();
});

final orderProvider = FutureProvider.family<Order, String>((ref, id) {
  return ref.watch(accountRepositoryProvider).order(id);
});