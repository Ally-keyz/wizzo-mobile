import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

import '../../../core/utils/formatters.dart';

/// Exact seller-side order statuses from the backend ORDER_STATUS enum.
class SellerOrderStatus {
  SellerOrderStatus._();

  static const placed = 'placed';
  static const sellerConfirmed = 'seller_confirmed';
  static const paymentSubmitted = 'payment_submitted';
  static const paymentConfirmed = 'payment_confirmed';
  static const processing = 'processing';
  static const shipped = 'shipped';
  static const outForDelivery = 'out_for_delivery';
  static const delivered = 'delivered';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
  static const readyForPickup = 'ready_for_pickup';

  static const all = [
    placed,
    sellerConfirmed,
    paymentSubmitted,
    paymentConfirmed,
    processing,
    shipped,
    outForDelivery,
    delivered,
    completed,
    cancelled,
    readyForPickup,
  ];

  static String label(BuildContext context, String status) => switch (status) {
    placed => context.tr('seller.status.placed'),
    sellerConfirmed => context.tr('seller.status.seller_confirmed'),
    paymentSubmitted => context.tr('seller.status.payment_submitted'),
    paymentConfirmed => context.tr('seller.status.payment_confirmed'),
    processing => context.tr('seller.status.processing'),
    shipped => context.tr('seller.status.shipped'),
    outForDelivery => context.tr('seller.status.out_for_delivery'),
    delivered => context.tr('seller.status.delivered'),
    completed => context.tr('seller.status.completed'),
    cancelled => context.tr('seller.status.cancelled'),
    readyForPickup => context.tr('seller.status.ready_for_pickup'),
    _ => context.tr('seller.status.unknown'),
  };
}

/// Status tab buckets, mirroring the web seller orders screen.
enum OrderBucket {
  all,
  fresh,
  payment,
  processing,
  shipping,
  completed,
  cancelled;

  static OrderBucket from(String name) => OrderBucket.values.firstWhere(
    (b) => b.name == name,
    orElse: () => OrderBucket.all,
  );

  String label(BuildContext context) => switch (this) {
    OrderBucket.all => context.tr('seller.bucket.all'),
    OrderBucket.fresh => context.tr('seller.bucket.fresh'),
    OrderBucket.payment => context.tr('seller.bucket.payment'),
    OrderBucket.processing => context.tr('seller.bucket.processing'),
    OrderBucket.shipping => context.tr('seller.bucket.shipping'),
    OrderBucket.completed => context.tr('seller.bucket.completed'),
    OrderBucket.cancelled => context.tr('seller.bucket.cancelled'),
  };

  bool matches(String status) {
    if (this == OrderBucket.all) return true;
    return switch (this) {
      OrderBucket.fresh =>
        status == SellerOrderStatus.placed ||
            status == SellerOrderStatus.sellerConfirmed,
      OrderBucket.payment =>
        status == SellerOrderStatus.paymentSubmitted ||
            status == SellerOrderStatus.paymentConfirmed,
      OrderBucket.processing =>
        status == SellerOrderStatus.processing ||
            status == SellerOrderStatus.readyForPickup,
      OrderBucket.shipping =>
        status == SellerOrderStatus.shipped ||
            status == SellerOrderStatus.outForDelivery,
      OrderBucket.completed =>
        status == SellerOrderStatus.delivered ||
            status == SellerOrderStatus.completed,
      OrderBucket.cancelled => status == SellerOrderStatus.cancelled,
      OrderBucket.all => true,
    };
  }

  /// The granular statuses counted by the "needs action" KPI on the web.
  List<String> get actionableStatuses => switch (this) {
    OrderBucket.fresh => [
      SellerOrderStatus.placed,
      SellerOrderStatus.sellerConfirmed,
    ],
    OrderBucket.payment => [SellerOrderStatus.paymentSubmitted],
    _ => const [],
  };
}

/// Settling statuses per the web earnings screen.
const settlingStatuses = [
  SellerOrderStatus.sellerConfirmed,
  SellerOrderStatus.paymentConfirmed,
  SellerOrderStatus.processing,
  SellerOrderStatus.readyForPickup,
  SellerOrderStatus.shipped,
  SellerOrderStatus.outForDelivery,
];

class SellerOrderItem {
  const SellerOrderItem({
    required this.name,
    required this.quantity,
    required this.priceAtPurchase,
    this.productId,
    this.image,
    this.selectedColor,
    this.selectedSize,
  });

  final String name;
  final int quantity;
  final num priceAtPurchase;
  final String? productId;
  final String? image;
  final String? selectedColor;
  final String? selectedSize;

  num get lineTotal => priceAtPurchase * quantity;

  String get variantLabel {
    final parts = <String>[];
    for (final e in [selectedSize, selectedColor]) {
      if (e != null && e.trim().isNotEmpty) parts.add(e);
    }
    return parts.join(' / ');
  }

  factory SellerOrderItem.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return SellerOrderItem(name: 'Item', quantity: 1, priceAtPurchase: 0);
    }
    final product = json['product'];
    Map<String, dynamic>? productMap;
    String? fallbackName;
    String? fallbackImage;
    if (product is Map<String, dynamic>) {
      productMap = product;
      fallbackName = product['name']?.toString();
      fallbackImage =
          product['image']?.toString() ?? _firstImage(product['images']);
    }
    final rawPrice = json['priceAtPurchase'] ?? productMap?['price'] ?? 0;
    return SellerOrderItem(
      name: json['name']?.toString() ?? fallbackName ?? 'Item',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      priceAtPurchase: (rawPrice as num?)?.toDouble() ?? 0,
      productId: json['productId']?.toString() ?? productMap?['id']?.toString(),
      image: json['image']?.toString() ?? fallbackImage,
      selectedColor: json['selectedColor']?.toString(),
      selectedSize: json['selectedSize']?.toString(),
    );
  }

  static String? _firstImage(dynamic v) {
    if (v is List && v.isNotEmpty) return v.first.toString();
    return null;
  }
}

class SellerPaymentProof {
  const SellerPaymentProof({
    this.method,
    this.transactionReference,
    this.proofUrl,
    this.proofName,
    this.proofType,
    this.submittedAt,
    this.confirmedAt,
  });

  final String? method;
  final String? transactionReference;
  final String? proofUrl;
  final String? proofName;
  final String? proofType;
  final DateTime? submittedAt;
  final DateTime? confirmedAt;

  factory SellerPaymentProof.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) return const SellerPaymentProof();
    return SellerPaymentProof(
      method: json['method']?.toString(),
      transactionReference: json['transactionReference']?.toString(),
      proofUrl: json['proofUrl']?.toString(),
      proofName: json['proofName']?.toString(),
      proofType: json['proofType']?.toString(),
      submittedAt: tryParseDate(json['submittedAt']),
      confirmedAt: tryParseDate(json['confirmedAt']),
    );
  }
}

class SellerDeliveryAddress {
  const SellerDeliveryAddress({
    this.label,
    this.fullName,
    this.phone,
    this.country,
    this.city,
    this.street,
    this.postalCode,
  });

  final String? label;
  final String? fullName;
  final String? phone;
  final String? country;
  final String? city;
  final String? street;
  final String? postalCode;

  String get summary {
    final parts = <String>[];
    for (final e in [street, city, country]) {
      if (e != null && e.trim().isNotEmpty) parts.add(e);
    }
    return parts.isNotEmpty ? parts.join(', ') : 'No address';
  }

  factory SellerDeliveryAddress.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) return const SellerDeliveryAddress();
    return SellerDeliveryAddress(
      label: json['label']?.toString(),
      fullName: json['fullName']?.toString(),
      phone: json['phone']?.toString(),
      country: json['country']?.toString(),
      city: json['city']?.toString(),
      street: json['street']?.toString(),
      postalCode: json['postalCode']?.toString(),
    );
  }
}

class SellerOrder {
  const SellerOrder({
    required this.id,
    required this.orderNumber,
    required this.items,
    required this.subtotal,
    required this.status,
    required this.createdAt,
    this.orderGroupId,
    this.buyerId,
    this.shippingFee,
    this.total,
    this.deliveryOption,
    this.deliveryAddress,
    this.paymentMethod,
    this.paymentProof,
    this.trackingNumber,
    this.statusHistory = const [],
    this.allowedNextStatuses = const [],
  });

  final String id;
  final String orderNumber;
  final String? orderGroupId;
  final String? buyerId;
  final List<SellerOrderItem> items;
  final num subtotal;
  final num? shippingFee;
  final num? total;
  final String? deliveryOption;
  final SellerDeliveryAddress? deliveryAddress;
  final String? paymentMethod;
  final SellerPaymentProof? paymentProof;
  final String status;
  final DateTime createdAt;
  final String? trackingNumber;
  final List<Map<String, dynamic>> statusHistory;
  final List<String> allowedNextStatuses;

  bool get isPickup => deliveryOption == 'pickup';
  bool get isDelivery => deliveryOption == 'delivery';
  bool get isCashOnDelivery => paymentMethod == 'cash_on_delivery';

  num get grandTotal => total ?? (subtotal + (shippingFee ?? 0));

  factory SellerOrder.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid order payload');
    }
    final itemsRaw = json['items'] ?? json['products'];
    final createdAtRaw =
        json['createdAt'] ??
        json['orderDate'] ??
        DateTime.now().toIso8601String();
    return SellerOrder(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? 'ORDER',
      orderGroupId: json['orderGroupId']?.toString(),
      buyerId: _idOf(json['buyerId']) ?? _idOf(json['buyer']),
      items: itemsRaw is List
          ? itemsRaw.map(SellerOrderItem.fromApi).toList()
          : const [],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      shippingFee: (json['shippingFee'] as num?)?.toDouble(),
      total: (json['total'] as num?)?.toDouble(),
      deliveryOption: json['deliveryOption']?.toString(),
      deliveryAddress: SellerDeliveryAddress.fromApi(
        json['deliveryAddress'] ?? json['address'],
      ),
      paymentMethod: json['paymentMethod']?.toString(),
      paymentProof: SellerPaymentProof.fromApi(json['paymentProof']),
      status: json['status']?.toString() ?? SellerOrderStatus.placed,
      createdAt: tryParseDate(createdAtRaw) ?? DateTime.now(),
      trackingNumber: json['trackingNumber']?.toString(),
      statusHistory: json['statusHistory'] is List
          ? (json['statusHistory'] as List)
                .whereType<Map<String, dynamic>>()
                .toList()
          : const [],
      allowedNextStatuses: _stringList(json['allowedNextStatuses']),
    );
  }

  static String? _idOf(dynamic v) {
    if (v is! Map) return v?.toString();
    return (v['id'] ?? v['_id'])?.toString();
  }

  static List<String> _stringList(dynamic v) {
    if (v is List) {
      return v.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }
}
