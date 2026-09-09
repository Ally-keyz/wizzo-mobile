import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/w_widgets.dart';
import '../models/product.dart';
import '../models/seller.dart';
import '../providers/catalog_providers.dart';
import 'product_card.dart';

enum _Sort { featured, newest, priceLow, priceHigh, rating }

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({
    super.key,
    required this.slug,
    this.title,
    this.subCategories = const [],
  });

  final String slug;
  final String? title;
  final List<CategoryNode> subCategories;

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  String? _sub;
  _Sort _sort = _Sort.featured;
  bool _showFilters = false;
  num? _priceMin;
  num? _priceMax;
  final _minController = TextEditingController();
  final _maxController = TextEditingController();

  List<Product>? _cacheSource;
  _Sort _cacheSort = _Sort.featured;
  num? _cacheMin;
  num? _cacheMax;
  List<Product>? _cacheResult;

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  /// Sort + price-filter are memoized so that unrelated rebuilds (parent
  /// frames, scroll, locale) do not re-sort the product list every time.
  List<Product> _sortedFiltered(List<Product> source) {
    if (identical(_cacheSource, source) &&
        _cacheSort == _sort &&
        _cacheMin == _priceMin &&
        _cacheMax == _priceMax &&
        _cacheResult != null) {
      return _cacheResult!;
    }
    final result = _applyFilters(_sorted(source));
    _cacheSource = source;
    _cacheSort = _sort;
    _cacheMin = _priceMin;
    _cacheMax = _priceMax;
    _cacheResult = result;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveSlug = _sub ?? widget.slug;
    final products = ref.watch(categoryProductsProvider(effectiveSlug));

    final sorted = _sortedFiltered(products.value ?? const []);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title ?? _titleForSlug(effectiveSlug),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            Text(
              context.tr(
                'browse.itemCount',
                namedArgs: {'count': '${sorted.length}'},
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (widget.subCategories.isNotEmpty)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  WChip(
                    label: context.tr('browse.all'),
                    selected: _sub == null,
                    onTap: () => setState(() => _sub = null),
                  ),
                  for (final sub in widget.subCategories)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: WChip(
                        label: sub.name,
                        selected: _sub == sub.slug,
                        onTap: () => setState(() => _sub = sub.slug),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _SortChip(
                  label: context.tr('browse.sort'),
                  icon: Icons.swap_vert,
                  onTap: _pickSort,
                ),
                const SizedBox(width: 10),
                _SortChip(
                  label: context.tr('browse.filters'),
                  icon: Icons.tune,
                  onTap: () => setState(() => _showFilters = !_showFilters),
                ),
                const Spacer(),
                Text(
                  _sortLabel(context),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (_showFilters)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  color: theme.colorScheme.surfaceContainerLow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('browse.priceRange'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: context.tr('browse.min'),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              prefixText: '₦ ',
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('–'),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _maxController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: context.tr('browse.max'),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              prefixText: '₦ ',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _clearFilters,
                          child: Text(context.tr('common.clear')),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Palette.gold,
                            foregroundColor: Palette.navy,
                          ),
                          onPressed: _applyPriceFilters,
                          child: Text(context.tr('common.apply')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: products.when(
              loading: () => const _GridSkeleton(),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 40, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text('${e}'),
                    TextButton(
                      onPressed: () => ref.invalidate(
                        categoryProductsProvider(effectiveSlug),
                      ),
                      child: Text(context.tr('common.retry')),
                    ),
                  ],
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return WEmptyState(
                    icon: Icons.search_off,
                    title: context.tr('browse.noItems'),
                    subtitle: context.tr('browse.noItemsHint'),
                    actionLabel: context.tr('browse.browseEverything'),
                    onAction: () => context.push('/search'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(
                    categoryProductsProvider(effectiveSlug).future,
                  ),
                  child: GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.62,
                        ),
                    itemCount: sorted.length,
                    itemBuilder: (_, i) => ProductCard(product: sorted[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _titleForSlug(String slug) {
    final parts = slug.split('-');
    return parts
        .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
        .join(' ');
  }

  String _sortLabel(BuildContext context) => switch (_sort) {
    _Sort.featured => context.tr('browse.sortFeatured'),
    _Sort.newest => context.tr('browse.sortNewest'),
    _Sort.priceLow => context.tr('browse.sortPriceLowHigh'),
    _Sort.priceHigh => context.tr('browse.sortPriceHighLow'),
    _Sort.rating => context.tr('browse.sortTopRated'),
  };

  List<Product> _sorted(List<Product> list) {
    final copy = [...list];
    switch (_sort) {
      case _Sort.featured:
        copy.sort((a, b) => (b.featured ? 1 : 0) - (a.featured ? 1 : 0));
      case _Sort.newest:
        break;
      case _Sort.priceLow:
        copy.sort((a, b) => a.price.compareTo(b.price));
      case _Sort.priceHigh:
        copy.sort((a, b) => b.price.compareTo(a.price));
      case _Sort.rating:
        copy.sort((a, b) => (b.ratingAvg ?? 0).compareTo(a.ratingAvg ?? 0));
    }
    return copy;
  }

  List<Product> _applyFilters(List<Product> list) {
    if (_priceMin == null && _priceMax == null) return list;
    return list.where((p) {
      final withinMin = _priceMin == null || p.price >= _priceMin!;
      final withinMax = _priceMax == null || p.price <= _priceMax!;
      return withinMin && withinMax;
    }).toList();
  }

  void _applyPriceFilters() {
    final min = _parsePrice(_minController.text);
    final max = _parsePrice(_maxController.text);
    setState(() {
      _priceMin = min;
      _priceMax = max;
    });
    if (min != null || max != null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('browse.priceFilterApplied')),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _clearFilters() {
    _minController.clear();
    _maxController.clear();
    setState(() {
      _priceMin = null;
      _priceMax = null;
    });
  }

  static num? _parsePrice(String text) {
    final t = text.trim().replaceAll(',', '');
    if (t.isEmpty) return null;
    return num.tryParse(t);
  }

  void _pickSort() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                context.tr('browse.sortBy'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            for (final s in _Sort.values)
              RadioListTile<_Sort>(
                value: s,
                groupValue: _sort,
                activeColor: Palette.gold,
                title: Text(_labelFor(context, s)),
                onChanged: (v) {
                  setState(() => _sort = v ?? _Sort.featured);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  String _labelFor(BuildContext context, _Sort s) => switch (s) {
    _Sort.featured => context.tr('browse.sortFeatured'),
    _Sort.newest => context.tr('browse.sortNewest'),
    _Sort.priceLow => context.tr('browse.sortPriceLowHigh'),
    _Sort.priceHigh => context.tr('browse.sortPriceHighLow'),
    _Sort.rating => context.tr('browse.sortTopRated'),
  };
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => const ProductCardSkeleton(),
    );
  }
}
