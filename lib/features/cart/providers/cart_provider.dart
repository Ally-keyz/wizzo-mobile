import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';

import '../../catalog/models/product.dart';
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
    required Product product,
    int quantity = 1,
    String? size,
    String? color,
  }) async {
    final previous = state.value;
    if (previous != null) {
      state = AsyncData(_withAdded(previous, product, quantity, size, color));
    }
    try {
      await _reconcile(
        () => ref.read(cartRepositoryProvider).addItem(
              productId: product.id,
              quantity: quantity,
              size: size,
              color: color,
            ),
      );
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
      await _reconcile(
        () => ref.read(cartRepositoryProvider).updateQuantity(itemId, quantity),
      );
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
      await _reconcile(
        () => ref.read(cartRepositoryProvider).removeItem(itemId),
      );
    } catch (_) {
      if (state.value != null) state = AsyncData(current);
    }
  }

  Future<void> clear() async {
    state = const AsyncData(CartData.empty);
    await ref.read(cartRepositoryProvider).clear();
  }

  /// Adopts the cart a mutating endpoint returned, avoiding the extra
  /// `GET /cart` that used to follow every add/update/remove.
  ///
  /// Falls back to [refresh] when the response came back unpopulated, which
  /// happens if the app is installed against a server build that still answers
  /// mutating cart calls without populating products.
  Future<void> _reconcile(Future<CartData> Function() mutation) async {
    final server = await mutation();
    if (server.isPopulated) {
      state = AsyncData(server);
    } else {
      await refresh();
    }
  }
}

/// Returns a copy of [data] with [product] added, matching the server's
/// semantics: re-adding a product already in the cart increments its quantity
/// rather than creating a second row. Totals are recomputed locally so the row
/// and the totals appear in the same frame.
CartData _withAdded(
  CartData data,
  Product product,
  int quantity,
  String? size,
  String? color,
) {
  bool matches(CartItem i) => i.id == product.id || i.product.id == product.id;

  final groups = data.groups.map((g) {
    final idx = g.items.indexWhere(matches);
    if (idx < 0) return g;
    final items = [...g.items];
    final existing = items[idx];
    items[idx] = CartItem(
      id: existing.id,
      product: existing.product,
      quantity: existing.quantity + quantity,
      variantSize: size ?? existing.variantSize,
      variantColor: color ?? existing.variantColor,
      sellerId: existing.sellerId,
      sellerName: existing.sellerName,
      sellerLogo: existing.sellerLogo,
      sellerVerified: existing.sellerVerified,
      productPopulated: existing.productPopulated,
    );
    return g.copyWith(items: items);
  }).toList();

  if (groups.any((g) => g.items.any(matches))) return _rebuild(groups, data);

  final seller = product.seller;
  final sellerId = seller?.id ?? '';
  final item = CartItem(
    id: product.id,
    product: product,
    quantity: quantity,
    variantSize: size,
    variantColor: color,
    sellerId: sellerId.isEmpty ? null : sellerId,
    sellerName: seller?.storeName,
    sellerLogo: seller?.logoUrl,
    sellerVerified: seller?.verified ?? false,
  );

  final groupIndex = groups.indexWhere((g) => g.sellerId == sellerId);
  if (groupIndex >= 0) {
    groups[groupIndex] = groups[groupIndex].copyWith(
      items: [...groups[groupIndex].items, item],
    );
  } else {
    groups.add(
      CartSellerGroup(
        sellerId: sellerId,
        sellerName: seller?.storeName,
        sellerSlug: seller?.storeSlug,
        sellerLogo: seller?.logoUrl,
        verified: seller?.verified ?? false,
        items: [item],
      ),
    );
  }
  return _rebuild(groups, data);
}

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
        productPopulated: item.productPopulated,
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