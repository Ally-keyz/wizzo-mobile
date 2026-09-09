import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';

import '../data/cart_repository.dart';
import '../models/cart.dart';

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.watch(apiClientProvider));
});

/// Live cart state driving both the badge and the cart screen.
///
/// All mutations are optimistic: the UI updates instantly from the current
/// state and is reconciled against the server in the background, without ever
/// flipping back to a full-screen loading spinner.
class CartController extends AsyncNotifier<CartData> {
  @override
  Future<CartData> build() => ref.watch(cartRepositoryProvider).fetch();

  Future<void> refresh() async {
    try {
      state = AsyncData(await ref.read(cartRepositoryProvider).fetch());
    } catch (_) {
      // Keep the last known cart; a later refresh will reconcile.
    }
  }

  Future<void> addItem({
    required String productId,
    int quantity = 1,
    String? size,
    String? color,
  }) async {
    final previous = state.value;
    if (previous != null) {
      state = AsyncData(_withAddedCount(previous, quantity));
    }
    try {
      await ref.read(cartRepositoryProvider).addItem(
            productId: productId,
            quantity: quantity,
            size: size,
            color: color,
          );
      await refresh();
    } catch (_) {
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> updateQuantity(String itemId, int quantity) async {
    if (quantity < 1) quantity = 1;
    final current = state.value;
    if (current == null) return;
    state = AsyncData(_withQuantity(current, itemId, quantity));
    try {
      await ref.read(cartRepositoryProvider).updateQuantity(itemId, quantity);
      await refresh();
    } catch (_) {
      if (state.value != null) state = AsyncData(current);
    }
  }

  Future<void> removeItem(String itemId) async {
    final current = state.value;
    if (current == null) return;
    final groups = current.groups
        .map((g) => g.copyWith(
              items: g.items
                  .where((i) => i.id != itemId && i.product.id != itemId)
                  .toList(),
            ))
        .where((g) => g.items.isNotEmpty)
        .toList();
    state = AsyncData(_rebuild(groups, current));
    try {
      await ref.read(cartRepositoryProvider).removeItem(itemId);
      await refresh();
    } catch (_) {
      if (state.value != null) state = AsyncData(current);
    }
  }

  Future<void> clear() async {
    state = const AsyncData(CartData.empty);
    await ref.read(cartRepositoryProvider).clear();
  }
}

CartData _withAddedCount(CartData data, int quantity) => CartData(
      groups: data.groups,
      itemCount: data.itemCount + quantity,
      subtotal: data.subtotal,
      deliveryFee: data.deliveryFee,
      total: data.total,
    );

/// Returns a copy of [data] with the matching item's quantity set to [quantity]
/// and all totals recomputed locally so the UI reflects the change instantly.
CartData _withQuantity(CartData data, String itemId, int quantity) {
  final groups = data.groups.map((g) {
    final items = g.items.map((item) {
      if (item.id != itemId && item.product.id != itemId) return item;
      return CartItem(
        id: item.id,
        product: item.product,
        quantity: quantity,
        variantSize: item.variantSize,
        variantColor: item.variantColor,
        sellerId: item.sellerId,
        sellerName: item.sellerName,
        sellerLogo: item.sellerLogo,
        sellerVerified: item.sellerVerified,
      );
    }).toList();
    return g.copyWith(items: items);
  }).toList();
  return _rebuild(groups, data);
}

CartData _rebuild(List<CartSellerGroup> groups, CartData previous) {
  final itemCount =
      groups.fold<int>(0, (s, g) => s + g.items.fold<int>(0, (a, i) => a + i.quantity));
  final subtotal = groups.fold<num>(0, (s, g) => s + g.subtotal);
  return CartData(
    groups: groups,
    itemCount: itemCount,
    subtotal: subtotal,
    deliveryFee: previous.deliveryFee,
    total: subtotal + previous.deliveryFee,
  );
}

final cartProvider =
    AsyncNotifierProvider<CartController, CartData>(CartController.new);

/// Item count for the cart badge.
final cartCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).value?.itemCount ?? 0;
});