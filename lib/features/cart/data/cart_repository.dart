import '../../../core/network/api_client.dart';
import '../models/cart.dart';

/// Cart endpoints mirroring the web `cartService`.
class CartRepository {
  CartRepository(this._api);

  final ApiClient _api;

  Future<CartData> fetch() async {
    final data = await _api.get('/cart');
    return CartData.fromApi(data);
  }

  Future<Map<String, dynamic>> totals() async {
    final data = await _api.get('/cart/totals');
    return data is Map<String, dynamic> ? data : const {};
  }

  Future<CartData> addItem({
    required String productId,
    int quantity = 1,
    String? size,
    String? color,
  }) async {
    final data = await _api.post('/cart/items', body: {
      'productId': productId,
      'quantity': quantity,
      'selectedColor': ?color,
      'selectedSize': ?size,
    });
    return CartData.fromApi(data);
  }

  /// The server keys cart items by product id.
  Future<CartData> updateQuantity(String productId, int quantity) async {
    final data = await _api.patch('/cart/items/$productId', body: {'quantity': quantity});
    return CartData.fromApi(data);
  }

  Future<CartData> removeItem(String productId) async {
    final data = await _api.delete('/cart/items/$productId');
    return CartData.fromApi(data);
  }

  Future<void> clear() async {
    await _api.delete('/cart');
  }
}