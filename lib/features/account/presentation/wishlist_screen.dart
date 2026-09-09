import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/w_widgets.dart';
import '../../catalog/presentation/product_card.dart';
import '../providers/account_providers.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final wishlist = ref.watch(wishlistProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('account.myWishlist'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
      body: wishlist.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => WEmptyState(
          icon: Icons.cloud_off,
          title: context.tr('wishlist.loadFailed'),
          subtitle: '$e',
          actionLabel: context.tr('common.retry'),
          onAction: () => ref.invalidate(wishlistProvider),
        ),
        data: (products) {
          if (products.isEmpty) {
            return WEmptyState(
              icon: Icons.favorite_border,
              title: context.tr('wishlist.empty'),
              subtitle: context.tr('wishlist.emptyHint'),
              actionLabel: context.tr('wishlist.browseProducts'),
              onAction: () => context.go('/home'),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.62,
            ),
            itemCount: products.length,
            itemBuilder: (_, i) => ProductCard(product: products[i]),
          );
        },
      ),
    );
  }
}