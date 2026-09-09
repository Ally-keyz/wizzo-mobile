import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/w_async.dart';
import '../../catalog/models/product.dart';
import '../data/seller_repository.dart';
import '../providers/seller_providers.dart';
import 'seller_ui.dart';

class MyProductsScreen extends ConsumerStatefulWidget {
  const MyProductsScreen({super.key});

  @override
  ConsumerState<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends ConsumerState<MyProductsScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final productsAsync = ref.watch(myProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('seller.myItems')),
        actions: [
          IconButton(
            tooltip: context.tr('seller.addProduct'),
            onPressed: () => context.push('/seller/product/new'),
            icon: const Icon(Icons.add_box_outlined),
          ),
        ],
      ),
      body: WAsyncView(
        value: productsAsync,
        onRetry: () => ref.invalidate(myProductsProvider),
        builder: (context, products) {
          final filtered = _filter == 'All'
              ? products
              : products.where((p) => p.status == _filter).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr(
                          'seller.itemCount',
                          namedArgs: {'count': '${products.length}'},
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => context.push('/seller/product/new'),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(context.tr('seller.addProduct')),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final status in [
                      'All',
                      'active',
                      'draft',
                      'pending',
                      'rejected',
                      'sold_out',
                    ]) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: _filter == status,
                          onSelected: (_) => setState(() => _filter = status),
                          showCheckmark: false,
                          label: Text(
                            status == 'All'
                                ? context.tr('seller.bucket.all')
                                : StatusBadge.statusLabel(context, status),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: _filter == status
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          selectedColor: scheme.primary,
                          labelStyle: TextStyle(
                            color: _filter == status
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
                          ),
                          backgroundColor: scheme.surface,
                          side: BorderSide(color: scheme.outlineVariant),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyItems(status: _filter)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final product = filtered[index];
                          return _ProductCard(
                            product: product,
                            onTap: () => context.push(
                              '/seller/product/${product.id}/edit',
                              extra: product,
                            ),
                            onMenu: _menuFor,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _menuFor(Product product) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        void act(VoidCallback fn) {
          Navigator.of(context).pop();
          fn();
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(context.tr('seller.editItem')),
                leading: const Icon(Icons.edit_outlined),
                onTap: () => act(
                  () => context.push(
                    '/seller/product/${product.id}/edit',
                    extra: product,
                  ),
                ),
              ),
              if (product.status == 'active') ...[
                ListTile(
                  title: Text(context.tr('seller.pauseListing')),
                  leading: const Icon(Icons.pause_outlined),
                  onTap: () => act(() => _setStatus(product, 'draft')),
                ),
              ] else if (product.status == 'draft') ...[
                ListTile(
                  title: Text(context.tr('seller.publish')),
                  leading: const Icon(Icons.play_arrow_outlined),
                  onTap: () => act(() => _setStatus(product, 'active')),
                ),
              ],
              ListTile(
                title: Text(context.tr('seller.deleteItem')),
                leading: Icon(Icons.delete_outline, color: scheme.error),
                titleTextStyle: TextStyle(
                  color: scheme.error,
                  fontWeight: FontWeight.w600,
                ),
                onTap: () => act(() => _confirmDelete(product)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _setStatus(Product product, String status) async {
    try {
      await ref
          .read(sellerRepositoryProvider)
          .updateProductStatus(product.id, status);
      ref.invalidate(myProductsProvider);
      ref.invalidate(sellerStatsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _confirmDelete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('seller.deleteItemTitle')),
        content: Text(
          context.tr(
            'seller.deleteItemBodyWizzo',
            namedArgs: {'name': product.name},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(sellerRepositoryProvider).deleteProduct(product.id);
      ref.invalidate(myProductsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onMenu,
  });

  final Product product;
  final VoidCallback onTap;
  final void Function(Product) onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stock = product.stock ?? 0;
    final lowStock = product.isAvailable && stock > 0 && stock < 5;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: product.images.isNotEmpty
                        ? Image.network(
                            product.images.first,
                            cacheWidth: 64,
                            cacheHeight: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: scheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                size: 22,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : Container(
                            color: scheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              size: 22,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            formatMoney(product.price),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                          ),
                          if (product.isOnSale) ...[
                            const SizedBox(width: 6),
                            Text(
                              formatMoney(product.originalPrice),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          StatusBadge(status: product.status, dense: true),
                          const SizedBox(width: 8),
                          if (lowStock)
                            Text(
                              context.tr(
                                'seller.lowStock',
                                namedArgs: {'count': '$stock'},
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: context.appColors.warning,
                              ),
                            )
                          else
                            Text(
                              context.tr(
                                'seller.inStock',
                                namedArgs: {'count': '$stock'},
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => onMenu(product),
                  icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyItems extends StatelessWidget {
  const _EmptyItems({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 44,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              context.tr(
                status == 'All'
                    ? 'seller.noItemsTitle'
                    : 'seller.noStatusItemsTitle',
                namedArgs: status == 'All' ? null : {'status': status},
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr(
                status == 'All'
                    ? 'seller.noItemsBody'
                    : 'seller.noStatusItemsBody',
                namedArgs: status == 'All' ? null : {'status': status},
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (status == 'All') ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.push('/seller/product/new'),
                icon: const Icon(Icons.add),
                label: Text(context.tr('seller.addFirstItem')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
