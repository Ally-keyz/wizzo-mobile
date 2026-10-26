import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/w_async.dart';
import '../../../core/widgets/w_widgets.dart';
import '../models/supplier.dart';
import '../providers/seller_providers.dart';

/// Two-step dropship picker: choose an active supplier, then one of their
/// catalog products. The chosen item opens the normal product form pre-filled;
/// the seller still sets their own category, description and selling price.
class DropshipPickerScreen extends ConsumerStatefulWidget {
  const DropshipPickerScreen({super.key});

  @override
  ConsumerState<DropshipPickerScreen> createState() =>
      _DropshipPickerScreenState();
}

class _DropshipPickerScreenState extends ConsumerState<DropshipPickerScreen> {
  SupplierSummary? _supplier;
  String _query = '';

  void _openItem(SupplierSummary supplier, SupplierItem item) {
    context.pushReplacement(
      '/seller/product/new',
      extra: DropshipSelection(
        supplierId: supplier.id,
        supplierName: supplier.name,
        item: item,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final supplier = _supplier;

    return Scaffold(
      appBar: AppBar(
        leading: supplier == null
            ? null
            : IconButton(
                tooltip: context.tr('seller.dropshipBackToSuppliers'),
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _supplier = null;
                  _query = '';
                }),
              ),
        title: Text(
          supplier == null
              ? context.tr('seller.dropshipChooseSupplier')
              : context.tr(
                  'seller.dropshipProductsFrom',
                  namedArgs: {'supplier': supplier.name},
                ),
        ),
      ),
      body: supplier == null
          ? _supplierList(theme, scheme)
          : _itemList(theme, scheme, supplier),
    );
  }

  Widget _supplierList(ThemeData theme, ColorScheme scheme) {
    final suppliersAsync = ref.watch(activeSuppliersProvider);
    return WAsyncView(
      value: suppliersAsync,
      onRetry: () => ref.invalidate(activeSuppliersProvider),
      builder: (context, suppliers) {
        if (suppliers.isEmpty) {
          return WEmptyState(
            icon: Icons.local_shipping_outlined,
            title: context.tr('seller.dropshipNoSuppliers'),
            subtitle: context.tr('seller.dropshipNoSuppliersHint'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: suppliers.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr('seller.dropshipChooseSupplierHint'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            final entry = suppliers[index - 1];
            return _SupplierTile(
              supplier: entry,
              onTap: () => setState(() {
                _supplier = entry;
                _query = '';
              }),
            );
          },
        );
      },
    );
  }

  Widget _itemList(
    ThemeData theme,
    ColorScheme scheme,
    SupplierSummary supplier,
  ) {
    final itemsAsync = ref.watch(supplierItemsProvider(supplier.id));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('seller.dropshipChooseProductHint'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: context.tr('seller.dropshipSearchHint'),
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: WAsyncView(
            value: itemsAsync,
            onRetry: () =>
                ref.invalidate(supplierItemsProvider(supplier.id)),
            builder: (context, items) {
              final q = _query.trim().toLowerCase();
              final visible = q.isEmpty
                  ? items
                  : items
                      .where(
                        (item) =>
                            item.name.toLowerCase().contains(q) ||
                            (item.sku ?? '').toLowerCase().contains(q),
                      )
                      .toList();
              if (items.isEmpty) {
                return WEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: context.tr('seller.dropshipNoProducts'),
                  subtitle: context.tr('seller.dropshipNoProductsHint'),
                );
              }
              if (visible.isEmpty) {
                return WEmptyState(
                  icon: Icons.search_off,
                  title: context.tr('seller.dropshipNoMatches'),
                  subtitle: context.tr('seller.dropshipNoMatchesHint'),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                itemCount: visible.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = visible[index];
                  return _SupplierItemTile(
                    item: item,
                    onTap: item.inStock
                        ? () => _openItem(supplier, item)
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SupplierTile extends StatelessWidget {
  const _SupplierTile({required this.supplier, required this.onTap});

  final SupplierSummary supplier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final logo = supplier.logo;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: logo == null
                      ? Container(
                          color: scheme.secondaryContainer,
                          child: Icon(
                            Icons.business_outlined,
                            color: scheme.primary,
                          ),
                        )
                      : Image.network(
                          logo,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: scheme.secondaryContainer,
                            child: Icon(
                              Icons.business_outlined,
                              color: scheme.primary,
                            ),
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
                      supplier.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (supplier.company != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        supplier.company!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (supplier.email != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        supplier.email!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupplierItemTile extends StatelessWidget {
  const _SupplierItemTile({required this.item, required this.onTap});

  final SupplierItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gallery = item.gallery;
    final stock = item.stock;
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: gallery.isNotEmpty
                        ? Image.network(
                            gallery.first,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: scheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : Container(
                            color: scheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.inventory_2_outlined,
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
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (item.sku != null) 'SKU ${item.sku}',
                          stock == null
                              ? context.tr('seller.dropshipInStockUnknown')
                              : stock > 0
                              ? context.tr(
                                  'seller.dropshipInStock',
                                  namedArgs: {'count': '$stock'},
                                )
                              : context.tr('seller.dropshipOutOfStock'),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: stock != null && stock <= 0
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatSupplierCost(item.cost, item.currency),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Palette.gold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('seller.dropshipSupplierCost'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
