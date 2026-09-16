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

  /// Starts a Stripe-hosted Checkout session for the whole cart and returns
  /// the page to open. Nothing is charged until the buyer pays on Stripe's
  /// page; the webhook then places the order automatically.
  Future<StripeCheckoutResult> createStripeCheckout({
    required List<Map<String, dynamic>> sellerPayments,
    String deliveryOption = 'delivery',
    String? deliveryAddressId,
  }) async {
    final data = await _api.post('/orders/stripe/checkout-session', body: {
      'sellerPaymentSelection': sellerPayments,
      'deliveryOption': deliveryOption,
      if (deliveryAddressId != null && deliveryAddressId.isNotEmpty)
        'deliveryAddressId': deliveryAddressId,
    });
    return StripeCheckoutResult.fromApi(data);
  }

  /// Polls the checkout intent after the buyer returns from Stripe. `paid`
  /// carries the completed [PlacementSummary] once the webhook has placed
  /// the order.
  Future<StripeCheckoutStatusResult> getStripeCheckoutStatus(
    String intentId,
  ) async {
    final data = await _api.get(
      '/orders/stripe/checkout/status/$intentId',
    );
    return StripeCheckoutStatusResult.fromApi(data);
  }
}

final checkoutRepositoryProvider = Provider<CheckoutRepository>((ref) {
  return CheckoutRepository(ref.watch(apiClientProvider));
});