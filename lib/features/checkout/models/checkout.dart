import '../../account/models/profile.dart';

/// Buyer-selected delivery method.
enum DeliveryKind {
  standard,
  express,
  pickup;

  /// Value sent to the backend checkout endpoint.
  String get apiValue => switch (this) {
        DeliveryKind.standard => 'delivery',
        DeliveryKind.express => 'delivery',
        DeliveryKind.pickup => 'pickup',
      };
}

class DeliveryOption {
  const DeliveryOption({
    required this.id,
    required this.name,
    required this.price,
    required this.timing,
  });

  final DeliveryKind id;
  final String name;
  final num price;
  final String timing;

  bool get isFree => price <= 0;

  static const List<DeliveryOption> all = [
    DeliveryOption(
      id: DeliveryKind.standard,
      name: 'Standard Delivery',
      price: 0,
      timing: '5-7 business days',
    ),
    DeliveryOption(
      id: DeliveryKind.express,
      name: 'Express Delivery',
      price: 5000,
      timing: '2-3 business days',
    ),
    DeliveryOption(
      id: DeliveryKind.pickup,
      name: 'Pickup Point',
      price: 0,
      timing: 'Available today',
    ),
  ];
}

enum PaymentKind {
  momo,
  bank,
  cashOnDelivery,
  card;

  String get apiValue => switch (this) {
        PaymentKind.momo => 'momo',
        PaymentKind.bank => 'bank',
        PaymentKind.cashOnDelivery => 'cash_on_delivery',
        PaymentKind.card => 'card',
      };
}

class PaymentOption {
  const PaymentOption({
    required this.kind,
    required this.label,
    required this.description,
    required this.providers,
  });

  final PaymentKind kind;
  final String label;
  final String description;
  final List<String> providers;

  String get apiValue => switch (kind) {
        PaymentKind.momo => 'momo',
        PaymentKind.bank => 'bank',
        PaymentKind.cashOnDelivery => 'cash_on_delivery',
        PaymentKind.card => 'card',
      };

  static const List<PaymentOption> all = [
    PaymentOption(
      kind: PaymentKind.momo,
      label: 'Mobile Money',
      description: 'Pay directly via MTN MoMo or Airtel Money',
      providers: ['MTN MoMo', 'Airtel Money'],
    ),
    PaymentOption(
      kind: PaymentKind.card,
      label: 'Card / Stripe',
      description: 'Pay securely by debit or credit card',
      providers: ['Card', 'Google Pay', 'Apple Pay'],
    ),
  ];
}

/// Seller-configured destination for a manual payment (mobile money / bank).
class SellerPaymentAccount {
  const SellerPaymentAccount({
    required this.method,
    this.provider,
    required this.accountName,
    required this.accountNumber,
    this.instructions,
  });

  final PaymentKind method;
  final String? provider;
  final String accountName;
  final String accountNumber;
  final String? instructions;

  factory SellerPaymentAccount.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) throw const FormatException('Invalid account');
    return SellerPaymentAccount(
      method: _kindFrom(json['method']?.toString()) ?? PaymentKind.momo,
      provider: json['provider']?.toString(),
      accountName: json['accountName']?.toString() ?? '',
      accountNumber: json['accountNumber']?.toString() ?? '',
      instructions: json['instructions']?.toString(),
    );
  }
}

/// Pay-in instructions for one store (indexed by sellerUserId / sellerId).
class SellerPaymentInfo {
  const SellerPaymentInfo({
    required this.sellerUserId,
    this.sellerId,
    this.storeName,
    this.paymentAccounts = const [],
  });

  final String sellerUserId;
  final String? sellerId;
  final String? storeName;
  final List<SellerPaymentAccount> paymentAccounts;

  factory SellerPaymentInfo.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) throw const FormatException('Invalid payment info');
    final raw = json['paymentAccounts'];
    return SellerPaymentInfo(
      sellerUserId: json['sellerUserId']?.toString() ?? '',
      sellerId: json['sellerId']?.toString(),
      storeName: json['storeName']?.toString(),
      paymentAccounts: raw is List
          ? raw.map(SellerPaymentAccount.fromApi).toList()
          : const [],
    );
  }
}

/// One SellerOrder created by checkout recursion — who to pay, how, and how much.
class SellerOrderReceipt {
  const SellerOrderReceipt({
    required this.id,
    required this.sellerUserId,
    this.paymentMethod,
    this.subtotal = 0,
  });

  final String id;
  final String sellerUserId;
  final PaymentKind? paymentMethod;
  final num subtotal;

  bool get isCashOnDelivery => paymentMethod == PaymentKind.cashOnDelivery;

  factory SellerOrderReceipt.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) throw const FormatException('Invalid seller order');
    return SellerOrderReceipt(
      id: (json['id'] ?? json['_id']).toString(),
      sellerUserId: (json['sellerUserId'] ?? json['sellerId']).toString(),
      paymentMethod: _kindFrom(json['paymentMethod']?.toString()),
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
    );
  }
}

PaymentKind? _kindFrom(String? raw) {
  if (raw == null) return null;
  final v = raw.toLowerCase();
  if (v.contains('momo')) return PaymentKind.momo;
  if (v.contains('bank')) return PaymentKind.bank;
  if (v.contains('cash')) return PaymentKind.cashOnDelivery;
  // Cards are paid via the Stripe-hosted checkout page (replaces Google Pay);
  // legacy orders still report 'google_pay'.
  if (v.contains('card') ||
      v.contains('stripe') ||
      v.contains('google_pay') ||
      v.contains('googlepay') ||
      v.contains('google')) {
    return PaymentKind.card;
  }
  return null;
}

/// Lifecycle of an online gateway charge at placement time.
enum PaymentStatus {
  /// Payment initiated but NOT yet settled (MoMo async — awaiting USSD/PIN).
  submitted,

  /// Payment settled — money moved.
  confirmed,
}

PaymentStatus? _statusFrom(String? raw) {
  if (raw == null) return null;
  final v = raw.toLowerCase();
  if (v.contains('confirm')) return PaymentStatus.confirmed;
  if (v.contains('submit')) return PaymentStatus.submitted;
  return null;
}

class PlacementSummary {
  const PlacementSummary({
    required this.orderId,
    this.orderNumber,
    this.total,
    this.grandTotal,
    this.paymentKind,
    this.paymentStatus,
    this.email,
    this.deliveryAddress,
    this.sellerOrders = const [],
  });

  final String orderId;

  /// Group order number derived from the order group id (e.g. WZ-XXXXXXXX).
  final String? orderNumber;
  final num? total;

  /// Grand total for the whole group (all seller orders + delivery).
  final num? grandTotal;

  /// How the buyer paid (momo / google_pay / ...) — derived from the server's
  /// `paymentKind` or the per-seller `paymentMethod` when absent.
  final PaymentKind? paymentKind;

  /// Whether the placed order is still awaiting settlement (`submitted`) or
  /// already settled (`confirmed`). Null for manual methods (bank / COD).
  final PaymentStatus? paymentStatus;
  final String? email;
  final Address? deliveryAddress;

  /// Per-seller orders created by checkout — used on the confirmation page.
  final List<SellerOrderReceipt> sellerOrders;

  factory PlacementSummary.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const PlacementSummary(orderId: '');
    }
    final order = json['order'] is Map<String, dynamic>
        ? json['order'] as Map<String, dynamic>
        : json;
    final rawSellers = json['sellerOrders'] ?? order['sellerOrders'];
    final sellerOrders = rawSellers is List
        ? rawSellers.map(SellerOrderReceipt.fromApi).toList()
        : const <SellerOrderReceipt>[];
    final kindRaw =
        (json['paymentKind'] ?? order['paymentMethod'])?.toString() ?? '';
    final kind = _kindFrom(kindRaw) ??
        sellerOrders.map((o) => o.paymentMethod).firstOrNull;
    final statusRaw = (json['paymentStatus'] ?? order['paymentStatus'] ?? order['status'])
        ?.toString();
    return PlacementSummary(
      orderId: (json['orderId'] ?? order['id'] ?? order['_id'])?.toString() ?? '',
      orderNumber: (json['orderNumber'] ?? order['orderNumber'])?.toString(),
      total: (json['total'] ?? order['total'] ?? json['grandTotal']) is num
          ? (json['total'] ?? order['total'] ?? json['grandTotal']) as num
          : null,
      grandTotal: (json['grandTotal'] ?? order['grandTotal']) is num
          ? (json['grandTotal'] ?? order['grandTotal']) as num
          : null,
      paymentKind: kind,
      paymentStatus: _statusFrom(statusRaw),
      email: json['email']?.toString(),
      deliveryAddress: json['deliveryAddress'] is Map<String, dynamic>
          ? Address.fromApi(json['deliveryAddress'])
          : null,
      sellerOrders: sellerOrders,
    );
  }
}

/// Server response for `POST /orders/stripe/checkout-session` — the hosted
/// Stripe Checkout page to open plus the intent id used to poll status.
class StripeCheckoutResult {
  const StripeCheckoutResult({required this.url, required this.intentId});

  final String url;
  final String intentId;

  factory StripeCheckoutResult.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid Stripe checkout response');
    }
    return StripeCheckoutResult(
      url: json['url']?.toString() ?? '',
      intentId: json['intentId']?.toString() ?? '',
    );
  }
}

/// Result of polling `GET /orders/stripe/checkout/status/:intentId`.
class StripeCheckoutStatusResult {
  const StripeCheckoutStatusResult({
    required this.status,
    this.summary,
  });

  /// open | processing | paid | expired
  final String status;

  /// Present once the webhook has confirmed the payment and created the order.
  final PlacementSummary? summary;

  bool get isPaid => status == 'paid';
  bool get isExpired => status == 'expired';

  factory StripeCheckoutStatusResult.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const StripeCheckoutStatusResult(status: 'open');
    }
    final summary =
        json['status'] == 'paid' ? PlacementSummary.fromApi(json) : null;
    return StripeCheckoutStatusResult(
      status: json['status']?.toString() ?? 'open',
      summary: summary,
    );
  }
}