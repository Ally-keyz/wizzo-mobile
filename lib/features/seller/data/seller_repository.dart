import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_providers.dart';
import '../../catalog/models/product.dart';
import '../models/coupon.dart';
import '../models/payment_account.dart';
import '../models/seller_order.dart';
import '../models/store.dart';
import 'upload_service.dart';

/// Input payload for the seller's product create/update endpoints.
class ProductInput {
  const ProductInput({
    required this.name,
    required this.categoryId,
    this.subcategoryId,
    required this.description,
    required this.price,
    this.discountPrice,
    this.discountEndsAt,
    required this.stock,
    required this.images,
    this.brand,
    this.condition = 'new',
    this.sizeOptions = const [],
    this.deliveryOptions = const [],
    this.tags = const [],
    this.video,
  });

  final String name;
  final String categoryId;
  final String? subcategoryId;
  final String description;
  final num price;
  final num? discountPrice;
  final DateTime? discountEndsAt;
  final int stock;
  final List<String> images;
  final String? brand;
  final String condition;
  final List<String> sizeOptions;
  final List<String> deliveryOptions;
  final List<String> tags;
  final String? video;

  Map<String, dynamic> toJson({bool isUpdate = false}) => {
        'name': name.trim(),
        'categoryId': categoryId,
        if (subcategoryId != null && subcategoryId!.trim().isNotEmpty)
          'subcategoryId': subcategoryId,
        'description': description.trim(),
        'price': price,
        if (discountPrice != null && discountPrice! > 0)
          'discountPrice': discountPrice,
        if (discountEndsAt != null) 'discountEndsAt': discountEndsAt!.toIso8601String(),
        if (isUpdate && discountPrice != null && discountPrice! <= 0) 'discountPrice': null,
        'stock': stock,
        'images': images,
        if (brand != null && brand!.trim().isNotEmpty) 'brand': brand!.trim(),
        'condition': condition,
        if (sizeOptions.isNotEmpty) 'sizeOptions': sizeOptions,
        if (deliveryOptions.isNotEmpty) 'deliveryOptions': deliveryOptions,
        if (tags.isNotEmpty) 'tags': tags,
        if (video != null && video!.trim().isNotEmpty) 'video': video!.trim(),
      };
}

/// All seller dashboard API calls.
class SellerRepository {
  SellerRepository(this._api, this._uploads);

  final ApiClient _api;
  final UploadService _uploads;

  // -- Store ----------------------------------------------------------------
  Future<MyStore> registerStore({
    required String storeName,
    String? aboutStore,
    String? logoUrl,
    String? country,
    String? district,
    String? city,
    double? longitude,
    double? latitude,
  }) async {
    final data = await _api.post('/sellers/register', body: {
      'storeName': storeName.trim(),
      if (aboutStore != null && aboutStore.trim().isNotEmpty)
        'aboutStore': aboutStore.trim(),
      if (logoUrl != null && logoUrl.isNotEmpty) 'logoUrl': logoUrl,
      if (country != null && country.trim().isNotEmpty)
        'country': country.trim(),
      if (district != null && district.trim().isNotEmpty)
        'district': district.trim(),
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (longitude != null) 'longitude': longitude,
      if (latitude != null) 'latitude': latitude,
    });
    return MyStore.fromApi(_unwrap(data));
  }

  /// Returns the current user's store, or null when they have none.
  Future<MyStore?> myStore() async {
    try {
      final data = await _api.get('/sellers/me');
      return MyStore.fromApi(_unwrap(data));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  Future<MyStore> updateStore(String storeId, Map<String, dynamic> body) async {
    final data = await _api.patch('/sellers/$storeId', body: body);
    return MyStore.fromApi(_unwrap(data));
  }

  Future<void> updatePaymentAccounts(List<PaymentAccount> accounts) async {
    await _api.patch('/sellers/me/payment-accounts', body: {
      'paymentAccounts': accounts.take(10).map((a) => a.toJson()).toList(),
    });
  }

  // -- Products ---------------------------------------------------------------
  Future<List<Product>> myProducts() async {
    final data = await _api.get('/products/mine', query: {'page': '1', 'limit': '100'});
    final items = _extractList(data);
    return items.map(Product.fromApi).toList();
  }

  Future<Product> createProduct(ProductInput input) async {
    final data = await _api.post('/products', body: input.toJson());
    return Product.fromApi(_unwrap(data));
  }

  Future<Product> updateProduct(String id, ProductInput input) async {
    final data = await _api.patch('/products/$id', body: input.toJson(isUpdate: true));
    return Product.fromApi(_unwrap(data));
  }

  /// Flips listing state without touching product fields (active/draft/pending).
  Future<void> updateProductStatus(String id, String status) async {
    await _api.patch('/products/$id', body: {'status': status});
  }

  Future<void> deleteProduct(String id) async {
    await _api.delete('/products/$id');
  }

  // -- Orders ---------------------------------------------------------------
  Future<List<SellerOrder>> sellerOrders() async {
    final data = await _api.get('/orders/seller', query: {'page': '1', 'limit': '100'});
    final items = _extractList(data);
    return items.map(SellerOrder.fromApi).toList();
  }

  Future<SellerOrder> sellerOrder(String id) async {
    final data = await _api.get('/orders/$id');
    return SellerOrder.fromApi(_unwrap(data));
  }

  /// {currentStatus, allowedNextStatuses}.
  Future<List<String>> orderStatusOptions(String id) async {
    final data = await _api.get('/orders/$id/status-options');
    if (data is Map<String, dynamic>) {
      final next = data['allowedNextStatuses'];
      if (next is List) {
        return next.map((e) => e.toString()).toList();
      }
    }
    return const [];
  }

  Future<void> updateOrderStatus(String id, String status, {String? note}) async {
    await _api.patch('/orders/$id/status', body: {
      'status': status,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  Future<void> confirmPayment(String id) async {
    await _api.post('/orders/$id/confirm-payment');
  }

  Future<void> rejectPayment(String id, {String? note}) async {
    await _api.post('/orders/$id/reject-payment', body: {
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  // -- Coupons ----------------------------------------------------------------
  Future<List<Coupon>> myCoupons() async {
    final data = await _api.get('/coupons/mine');
    final items = _extractList(data);
    return items.map(Coupon.fromApi).toList();
  }

  Future<Coupon> createCoupon(CouponInput input) async {
    final data = await _api.post('/coupons', body: input.toJson());
    return Coupon.fromApi(_unwrap(data));
  }

  Future<Coupon> updateCoupon(String id, Map<String, dynamic> body) async {
    final data = await _api.patch('/coupons/$id', body: body);
    return Coupon.fromApi(_unwrap(data));
  }

  Future<void> deleteCoupon(String id) async {
    await _api.delete('/coupons/$id');
  }

  // -- Uploads ---------------------------------------------------------------
  Future<String> uploadImage(String path, {String folder = 'wizzo/products'}) {
    return _uploads.uploadImage(path, folder: folder);
  }

  Future<String> uploadVideo(
    String path, {
    String folder = 'wizzo/products/videos',
  }) {
    return _uploads.uploadVideo(path, folder: folder);
  }

  static dynamic _unwrap(dynamic data) {
    if (data is Map<String, dynamic> && data.containsKey('seller')) {
      return data['seller'];
    }
    if (data is Map<String, dynamic> && data.containsKey('product')) {
      return data['product'];
    }
    if (data is Map<String, dynamic> && data.containsKey('order')) {
      return data['order'];
    }
    if (data is Map<String, dynamic> && data.containsKey('coupon')) {
      return data['coupon'];
    }
    if (data is Map<String, dynamic> &&
        data.containsKey('data') &&
        data['data'] is Map) {
      return data['data'];
    }
    return data;
  }

  static List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      for (final key in ['items', 'orders', 'products', 'coupons', 'payments', 'reviews']) {
        if (data[key] is List) return data[key] as List;
      }
      final nested = data['data'];
      if (nested is List) return nested;
      if (nested is Map<String, dynamic>) {
        for (final key in ['items', 'orders', 'products', 'coupons']) {
          if (nested[key] is List) return nested[key] as List;
        }
      }
      if (data['results'] is List) return data['results'] as List;
    }
    return const [];
  }
}

final sellerRepositoryProvider = Provider((ref) {
  return SellerRepository(
    ref.watch(apiClientProvider),
    ref.watch(uploadServiceProvider),
  );
});