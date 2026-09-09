import '../../../core/utils/formatters.dart';
import '../../catalog/models/product.dart';

class Order {
  const Order({
    required this.id,
    this.orderNumber,
    this.createdAt,
    this.status,
    this.summary,
    this.items = const [],
    this.seller,
    this.deliveryOption,
    this.paymentMethod,
    this.total,
    this.subtotal,
    this.progressSteps = const [],
    this.currentStep = 0,
  });

  final String id;
  final String? orderNumber;
  final DateTime? createdAt;
  final String? status;
  final String? summary;
  final List<OrderItem> items;
  final OrderSeller? seller;
  final String? deliveryOption;
  final String? paymentMethod;
  final num? total;
  final num? subtotal;
  final List<String> progressSteps;
  final int currentStep;

  bool get needsReview => status == 'needs_review' || status == 'pending_confirmation';

  factory Order.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) throw const FormatException('Invalid order');
    final seller = OrderSeller.tryParse(json['seller'] ?? json['store'] ?? json['sellerId']);
    final rawItems = json['items'];
    final items = rawItems is List ? rawItems.map(OrderItem.fromApi).toList() : const <OrderItem>[];

    final status = json['status']?.toString() ?? 'placed';
    final steps = orderStepsFor(status);

    return Order(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      orderNumber: json['orderNumber']?.toString(),
      createdAt: tryParseDate(json['createdAt']),
      status: status,
      summary: json['summary']?.toString(),
      items: items,
      seller: seller,
      deliveryOption: json['deliveryOption']?.toString(),
      paymentMethod: json['paymentMethod']?.toString(),
      total: (json['total'] as num?)?.toDouble(),
      subtotal: (json['subtotal'] as num?)?.toDouble(),
      progressSteps: steps,
      currentStep: orderStepIndex(status),
    );
  }

  static const _flow = [
    'Placed',
    'Confirmed',
    'Processing',
    'Preparing',
    'Ready for Pickup',
    'Completed',
  ];

  static List<String> orderStepsFor(String status) {
    final s = status.toLowerCase();
    if (s.contains('cancelled')) return [..._flow, 'Cancelled'];
    if (s.contains('rejected')) return [..._flow, 'Rejected'];
    return _flow;
  }

  static int orderStepIndex(String status) {
    final s = status.toLowerCase();
    if (s.contains('placed')) return 0;
    if (s.contains('confirmed')) return 1;
    if (s.contains('process')) return 2;
    if (s.contains('picked') || s.contains('prepar')) return 3;
    if (s.contains('ready') || s.contains('shipped') || s.contains('delivered')) return 4;
    return 0;
  }
}

class OrderItem {
  const OrderItem({required this.product, this.quantity = 1, this.lineTotal});

  final Product product;
  final int quantity;
  final num? lineTotal;

  factory OrderItem.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) throw const FormatException('Invalid order item');
    final raw = json['product'] ?? json['productId'];
    final Product product;
    if (raw is Map<String, dynamic>) {
      product = Product.fromApi(raw);
    } else {
      // Seller order items may come flattened: productId is a raw id string
      // with name/image/priceAtPurchase alongside. Build a usable product.
      final rawImg = json['image']?.toString() ?? '';
      product = Product(
        id: raw?.toString() ?? json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Item',
        slug: '',
        images: rawImg.isEmpty ? const [] : [rawImg],
        price: (json['priceAtPurchase'] as num?)?.toDouble() ??
            (json['price'] as num?)?.toDouble() ??
            0,
      );
    }
    final quantity = (json['quantity'] as num?)?.toInt() ?? 1;
    final lineTotal = json['lineTotal'] ??
        json['total'] ??
        (json['priceAtPurchase'] as num?)?.toDouble() ??
        (json['price'] as num?)?.toDouble();
    return OrderItem(product: product, quantity: quantity, lineTotal: lineTotal is num ? lineTotal : null);
  }
}

class OrderSeller {
  const OrderSeller({this.id, this.name, this.slug, this.logo, this.verified = false});

  final String? id;
  final String? name;
  final String? slug;
  final String? logo;
  final bool verified;

  factory OrderSeller.tryParse(dynamic json) {
    if (json is! Map<String, dynamic>) return const OrderSeller();
    return OrderSeller(
      id: json['id']?.toString(),
      name: json['storeName']?.toString() ?? json['fullName']?.toString() ?? json['name']?.toString(),
      slug: json['storeSlug']?.toString(),
      logo: json['logoUrl']?.toString() ?? json['avatarUrl']?.toString(),
      verified: json['verifiedBadge'] == true,
    );
  }
}