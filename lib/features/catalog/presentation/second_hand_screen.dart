import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/w_async.dart';
import '../models/product.dart';
import '../providers/catalog_providers.dart';
import 'product_shelf.dart';

/// Full grid of pre-owned marketplace listings (`listingType=second_hand`).
/// Opened from the "View all" action on the home second-hand rail.
class SecondHandScreen extends ConsumerWidget {
  const SecondHandScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final productsAsync = ref.watch(secondHandProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('secondHand.title'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: WAsyncView<List<Product>>(
        value: productsAsync,
        onRetry: () => ref.invalidate(secondHandProductsProvider),
        loading: const SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.only(top: 12, bottom: 24),
          child: ProductGridSkeleton(itemCount: 8),
        ),
        builder: (context, _) {
          final products = productsAsync.value ?? const [];
          if (products.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Palette.gold.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.recycling_rounded,
                        size: 40,
                        color: Palette.gold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('secondHand.empty'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(secondHandProductsProvider);
              await ref.read(secondHandProductsProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 8, bottom: 28),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.recycling_rounded,
                        size: 18,
                        color: Palette.gold,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.tr('secondHand.count', namedArgs: {
                          'count': '${products.length}',
                        }),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                ProductGrid(products: products),
              ],
            ),
          );
        },
      ),
    );
  }
}
