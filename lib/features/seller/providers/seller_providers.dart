import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/models/product.dart';
import '../data/seller_repository.dart';
import '../models/seller_order.dart';
import '../models/store.dart';

/// The signed-in user's store profile, or null when they have no store yet.
final myStoreProvider = FutureProvider<MyStore?>((ref) {
  return ref.watch(sellerRepositoryProvider).myStore();
});

final myProductsProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(sellerRepositoryProvider).myProducts();
});

final sellerOrdersProvider = FutureProvider<List<SellerOrder>>((ref) {
  return ref.watch(sellerRepositoryProvider).sellerOrders();
});

/// Allowed next statuses for a specific order.
final orderStatusOptionsProvider =
    FutureProvider.family<List<String>, String>((ref, orderId) {
  return ref.watch(sellerRepositoryProvider).orderStatusOptions(orderId);
});

/// Earnings / KPI aggregates computed locally from the seller's orders, in the
/// same way the web seller Earnings + Dashboard screens compute them.
class SellerStats {
  const SellerStats({
    this.available = 0,
    this.pending = 0,
    this.lifetime = 0,
    this.aov = 0,
    this.orderCount = 0,
    this.needsAction = 0,
    this.productsTotal = 0,
    this.productsActive = 0,
    this.productsLowStock = 0,
    this.productsSoldOut = 0,
  });

  final num available;
  final num pending;
  final num lifetime;
  final num aov;
  final int orderCount;
  final int needsAction;
  final int productsTotal;
  final int productsActive;
  final int productsLowStock;
  final int productsSoldOut;
}

const lowStockThreshold = 5;

final sellerStatsProvider = FutureProvider<SellerStats>((ref) async {
  final orders = await ref.watch(sellerOrdersProvider.future);
  final products = await ref.watch(myProductsProvider.future);

  var available = 0.0;
  var pending = 0.0;
  var lifetime = 0.0;
  var validCount = 0;
  var needsAction = 0;

  for (final order in orders) {
    final s = order.status;
    if (s == SellerOrderStatus.cancelled) continue;
    validCount += 1;
    lifetime += order.subtotal;
    if (order.subtotal == 0) continue;
    if (s == SellerOrderStatus.delivered || s == SellerOrderStatus.completed) {
      available += order.subtotal;
    } else if (settlingStatuses.contains(s)) {
      pending += order.subtotal;
    }
    if (s == SellerOrderStatus.placed ||
        s == SellerOrderStatus.paymentSubmitted) {
      needsAction += 1;
    }
  }

  var active = 0;
  var low = 0;
  var soldOut = 0;
  for (final p in products) {
    if (p.status == 'active') active += 1;
    final stock = p.stock ?? 0;
    if (stock <= 0) soldOut += 1;
    if (stock > 0 && stock <= lowStockThreshold) low += 1;
  }

  return SellerStats(
    available: available,
    pending: pending,
    lifetime: lifetime,
    aov: validCount > 0 ? lifetime / validCount : 0,
    orderCount: validCount,
    needsAction: needsAction,
    productsTotal: products.length,
    productsActive: active,
    productsLowStock: low,
    productsSoldOut: soldOut,
  );
});