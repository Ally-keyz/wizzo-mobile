import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/w_widgets.dart';
import '../../catalog/presentation/product_card.dart';
import '../../catalog/providers/catalog_providers.dart';

/// Full-screen "All Deals" browse — every discounted product currently on
/// promotion (flash + today's deals), biggest savings first.
class DealsAllScreen extends ConsumerWidget {
  const DealsAllScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final productsAsync = ref.watch(allDealsProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('deals.all'),
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: productsAsync.when(
        loading: () => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            childAspectRatio: 0.62,
          ),
          itemCount: 6,
          itemBuilder: (_, _) => const ProductCardSkeleton(),
        ),
        error: (e, _) => WEmptyState(
          icon: Icons.cloud_off,
          title: context.tr('deals.loadFailed'),
          subtitle: '${e}',
          actionLabel: context.tr('common.retry'),
          onAction: () => ref.invalidate(allDealsProductsProvider),
        ),
        data: (products) {
          if (products.isEmpty) {
            return WEmptyState(
              icon: Icons.local_offer_outlined,
              title: context.tr('deals.none'),
              subtitle: context.tr('deals.noneHint'),
            );
          }
          final maxDiscount = products.fold<int>(
            0,
            (max, p) => p.discount > max ? p.discount : max,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department,
                      size: 20, color: Palette.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('deals.productsUpToOff', namedArgs: {
                        'count': '${products.length}',
                        'percent': '$maxDiscount',
                      }),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.62,
                ),
                itemCount: products.length,
                itemBuilder: (_, i) => ProductCard(product: products[i]),
              ),
            ],
          );
        },
      ),
    );
  }
}