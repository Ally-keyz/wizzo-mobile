import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/models/product.dart';
import '../data/account_repository.dart';
import '../models/profile.dart';

/// Wishlist products (freshly populated from the server) + toggle logic.
class WishlistController extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() => ref.watch(accountRepositoryProvider).wishlistProducts();

  /// Optimistically removes an item that is being un-heart-ed, then syncs.
  Future<void> toggle(String productId) async {
    final current = state.value ?? const <Product>[];
    final had = current.any((p) => p.id == productId);
    state = AsyncData(had ? current.where((p) => p.id != productId).toList() : current);
    try {
      await ref.read(accountRepositoryProvider).toggleWishlist(productId);
      state = await AsyncValue.guard(
        () => ref.read(accountRepositoryProvider).wishlistProducts(),
      );
    } catch (_) {
      state = await AsyncValue.guard(
        () => ref.read(accountRepositoryProvider).wishlistProducts(),
      );
    }
  }
}

final wishlistProvider =
    AsyncNotifierProvider<WishlistController, List<Product>>(WishlistController.new);

/// Ids of currently-wished products (set for O(1) heart lookups).
final wishlistIdsProvider = Provider<Set<String>>((ref) {
  final value = ref.watch(wishlistProvider).value;
  return value == null ? const <String>{} : value.map((p) => p.id).toSet();
});

/// Reviews for a specific product (product detail screen).
final productReviewsProvider = FutureProvider.family<List<Review>, String>((ref, id) {
  return ref.watch(accountRepositoryProvider).productReviews(id);
});