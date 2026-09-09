import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/w_image.dart';
import '../../../core/widgets/w_widgets.dart';
import '../../messages/providers/chat_providers.dart';
import '../models/seller.dart';
import '../presentation/product_card.dart';
import '../providers/catalog_providers.dart';

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key, required this.storeSlug});

  final String storeSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sellerAsync = ref.watch(sellerProvider(storeSlug));
    final productsAsync = ref.watch(sellerProductsProvider(storeSlug));

    return Scaffold(
      body: sellerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _shopScaffold(
          context,
          title:
              (sellerAsync.value?.storeName ??
              context.tr('shop.fallbackTitle')),
          child: WEmptyState(
            icon: Icons.cloud_off,
            title: context.tr('shop.openFailed'),
            subtitle: '${e}',
            actionLabel: context.tr('common.retry'),
            onAction: () => ref.invalidate(sellerProvider(storeSlug)),
          ),
        ),
        data: (seller) => _shopScaffold(
          context,
          title: seller.storeName,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShopHeader(seller: seller),
                    _ShopStats(seller: seller),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Material(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => context.push('/shorts?store=$storeSlug'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  context.tr('common.viewShorts'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(
                                  Icons.navigate_next,
                                  color: Colors.white70,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(
                            context.tr('shop.products'),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          if (seller.productsCount != null)
                            Text(
                              context.tr(
                                'shop.productCount',
                                namedArgs: {
                                  'count': '${seller.productsCount ?? 0}',
                                },
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    productsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          context.tr(
                            'shop.productsLoadFailed',
                            namedArgs: {'error': '$e'},
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      data: (products) => products.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: WEmptyState(
                                icon: Icons.inventory_2_outlined,
                                title: context.tr('shop.noProducts'),
                                subtitle: context.tr('shop.noProductsHint'),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              if (productsAsync.value case final products?
                  when products.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.62,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => ProductCard(product: products[i]),
                      childCount: products.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shopScaffold(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: child,
    );
  }
}

class _ShopHeader extends ConsumerWidget {
  const _ShopHeader({required this.seller});

  final Seller seller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      color: seller.coverUrl != null
          ? Colors.transparent
          : theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: seller.logoUrl != null
                      ? WImage(url: seller.logoUrl, fit: BoxFit.cover)
                      : ColoredBox(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Center(
                            child: Text(
                              seller.storeName.characters.first.toUpperCase(),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Palette.gold,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            seller.storeName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (seller.verified) ...[
                          const SizedBox(width: 6),
                          VerifiedBadge(),
                        ],
                      ],
                    ),
                    if (seller.locationLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            seller.locationLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GoldCTA(
            onTap: () => _openChat(context, ref),
            icon: Icons.chat,
            label: context.tr('shop.talkToSeller'),
            subtitle: seller.responseRate != null
                ? context.tr(
                    'shop.responseRate',
                    namedArgs: {'percent': '${seller.responseRate!.round()}'},
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _openChat(BuildContext context, WidgetRef ref) async {
    final conv = await ref
        .read(chatRepositoryProvider)
        .start(seller.userId ?? seller.id);
    if (context.mounted && conv.id.isNotEmpty) {
      context.push('/conversation/${conv.id}');
    }
  }
}

class _ShopStats extends StatelessWidget {
  const _ShopStats({required this.seller});

  final Seller seller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <(IconData, String, String)>[
      (
        Icons.star_rounded,
        seller.ratingAvg != null ? seller.ratingAvg!.toStringAsFixed(1) : '—',
        context.tr('shop.statRating'),
      ),
      (
        Icons.inventory_2_outlined,
        '${seller.productsCount ?? 0}',
        context.tr('shop.statProducts'),
      ),
      (
        Icons.group_outlined,
        '${seller.followersCount ?? 0}',
        context.tr('shop.statFollowers'),
      ),
      (
        Icons.bolt_outlined,
        seller.responseRate != null ? '${seller.responseRate!.round()}%' : '—',
        context.tr('shop.statResponse'),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: Column(
                children: [
                  Icon(item.$1, color: Palette.gold, size: 18),
                  const SizedBox(height: 4),
                  Text(
                    item.$2,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    item.$3,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
