import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/w_image.dart';
import '../../../core/widgets/w_widgets.dart';
import '../models/cart.dart';
import '../providers/cart_provider.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cartAsync = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('cart.title'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: cartAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => WEmptyState(
          icon: Icons.cloud_off,
          title: context.tr('cart.loadFailed'),
          subtitle: '${e}',
          actionLabel: context.tr('common.retry'),
          onAction: () => ref.read(cartProvider.notifier).refresh(),
        ),
        data: (cart) {
          if (cart.groups.isEmpty) {
            return WEmptyState(
              icon: Icons.shopping_cart_outlined,
              title: context.tr('cart.empty'),
              subtitle: context.tr('cart.emptyHint'),
              actionLabel: context.tr('common.startShopping'),
              onAction: () => context.go('/home'),
            );
          }
          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.read(cartProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: cart.groups.length,
                    itemBuilder: (context, i) => _SellerGroupCard(
                      group: cart.groups[i],
                      onChangedQuantity: (item, q) {
                        ref
                            .read(cartProvider.notifier)
                            .updateQuantity(item.product.id, q);
                      },
                      onRemove: (item) {
                        ref
                            .read(cartProvider.notifier)
                            .removeItem(item.product.id);
                      },
                    ),
                  ),
                ),
              ),
              _SummarryBar(
                itemCount: cart.itemCount,
                subtotal: cart.subtotal,
                onCheckout: () => context.push('/checkout'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummarryBar extends StatelessWidget {
  const _SummarryBar({
    required this.itemCount,
    required this.subtotal,
    required this.onCheckout,
  });

  final int itemCount;
  final num subtotal;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  context.tr('cart.summary'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  context.tr(
                    'cart.itemCountLabel',
                    namedArgs: {'count': '$itemCount'},
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  context.tr('cart.subtotal'),
                  style: theme.textTheme.bodyMedium,
                ),
                const Spacer(),
                Text(
                  formatMoney(subtotal),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Palette.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onCheckout,
                child: Text(context.tr('cart.checkout')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellerGroupCard extends StatelessWidget {
  const _SellerGroupCard({
    required this.group,
    required this.onChangedQuantity,
    required this.onRemove,
  });

  final CartSellerGroup group;
  final void Function(CartItem item, int quantity) onChangedQuantity;
  final void Function(CartItem item) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seller header
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: group.sellerLogo != null
                    ? WImage(url: group.sellerLogo!, fit: BoxFit.cover)
                    : Icon(
                        Icons.storefront,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        group.sellerName ?? context.tr('common.seller'),
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (group.verified) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified,
                        size: 14,
                        color: Color(0xFF3B82F6),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Text(
                      context.tr(
                        'cart.groupItemCount',
                        namedArgs: {'count': '${group.items.length}'},
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 4),
          // Items
          for (final item in group.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: WImage(
                      url: item.product.images.isNotEmpty
                          ? item.product.images.first
                          : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (item.variantSize != null ||
                            item.variantColor != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            [
                              item.variantSize,
                              item.variantColor,
                            ].where((e) => e != null).join(' • '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          formatMoney(item.lineTotal),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Palette.gold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(
                        onPressed: () => onRemove(item),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ),
                      _Stepper(
                        count: item.quantity,
                        onChanged: (q) => onChangedQuantity(item, q),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.count, required this.onChanged});

  final int count;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: count > 1 ? () => onChanged(count - 1) : null,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.remove,
                size: 16,
                color: count > 1
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.outline,
              ),
            ),
          ),
          SizedBox(
            width: 26,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          InkWell(
            onTap: () => onChanged(count + 1),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.add,
                size: 16,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
