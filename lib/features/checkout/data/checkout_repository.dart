import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_providers.dart';

import '../models/checkout.dart';

class CheckoutRepository {
  CheckoutRepository(this._api);

  final ApiClient _api;

  Future<PlacementSummary> placeOrder({
    required List<Map<String, dynamic>> sellerPayments,
    String deliveryOption = 'delivery',
    String? deliveryAddressId,
    String? paymentMethod,
    Map<String, dynamic>? paymentDetails,
  }) async {
    final data = await _api.post('/orders/checkout', body: {
      'sellerPaymentSelection': sellerPayments,
      'deliveryOption': deliveryOption,
      if (deliveryAddressId != null && deliveryAddressId.isNotEmpty)
        'deliveryAddressId': deliveryAddressId,
      if (paymentMethod != null && paymentMethod.isNotEmpty)
        'paymentMethod': paymentMethod,
      if (paymentDetails != null && paymentDetails.isNotEmpty)
        'paymentDetails': paymentDetails,
    });
    return PlacementSummary.fromApi(data);
  }

  /// Pay-in instructions for a set of seller user ids (mirrors the web
  /// `/sellers/payment-accounts` call used on checkout and confirmation).
  Future<List<SellerPaymentInfo>> getSellersPaymentAccounts(
    List<String> sellerUserIds,
  ) async {
    final ids = sellerUserIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const [];
    final data = await _api.get(
      '/sellers/payment-accounts',
      query: {'ids': ids.join(',')},
    );
    final items = data is List ? data : const <dynamic>[];
    return items.map(SellerPaymentInfo.fromApi).toList();
  }
}

final checkoutRepositoryProvider = Provider<CheckoutRepository>((ref) {
  return CheckoutRepository(ref.watch(apiClientProvider));
});