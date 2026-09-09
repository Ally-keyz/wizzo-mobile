import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/w_widgets.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../catalog/presentation/product_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _showTray = true;

  List<String> _recentSearches(BuildContext context) => [
        context.tr('search.recentLaptop'),
        context.tr('search.recentSmartphone'),
        context.tr('search.recentHomeBar'),
        context.tr('search.recentFurniture'),
        context.tr('search.recentKitchenAppliances'),
        context.tr('search.recentVehicles'),
      ];

  List<String> _trending(BuildContext context) => [
        context.tr('search.trendingFlashDeals'),
        context.tr('search.trendingIphone'),
        context.tr('search.trendingSofaSet'),
        context.tr('search.trendingGenerators'),
        context.tr('search.trendingWeddingDresses'),
      ];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {
      _query = value;
      _showTray = value.trim().isEmpty;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() {});
    });
  }

  void _clear() {
    _controller.clear();
    _onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searching = !_showTray;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Container(
          height: 42,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: _onChanged,
                  decoration: InputDecoration(
                    hintText: context.tr('search.placeholder'),
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: true,
                    fillColor: Colors.transparent,
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              if (_query.isNotEmpty)
                GestureDetector(
                  onTap: _clear,
                  child: const Icon(Icons.close, size: 18),
                ),
            ],
          ),
        ),
      ),
      body: searching ? _results() : _tray(context),
    );
  }

  Widget _tray(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          context.tr('search.recentTitle'),
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final s in _recentSearches(context))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.history, color: theme.colorScheme.onSurfaceVariant),
            title: Text(s),
            trailing: Icon(Icons.arrow_outward, size: 18, color: theme.colorScheme.onSurfaceVariant),
            onTap: () {
              _controller.text = s;
              _onChanged(s);
            },
          ),
        const SizedBox(height: 16),
        Text(
          context.tr('search.trendingTitle'),
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in _trending(context))
              WChip(
                label: t,
                icon: Icons.local_fire_department,
                onTap: () {
                  _controller.text = t;
                  _onChanged(t);
                },
              ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.appColors.goldSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.local_offer_outlined, color: context.appColors.onGoldSoft),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr('search.typeAnything'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.appColors.onGoldSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _results() {
    final theme = Theme.of(context);
    final products = ref.watch(searchResultsProvider(_query.trim()));

    return products.when(
      data: (list) {
        if (list.isEmpty) {
          return WEmptyState(
            icon: Icons.search_off,
            title: context.tr('search.noResults'),
            subtitle: context.tr('search.noResultsHint'),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.tr('search.resultsFor', namedArgs: {
                  'count': '${list.length}',
                  'query': _query.trim(),
                }),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.62,
                ),
                itemCount: list.length,
                itemBuilder: (_, i) => ProductCard(product: list[i]),
              ),
            ),
          ],
        );
      },
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
        title: context.tr('search.failed'),
        subtitle: '${e}',
        actionLabel: context.tr('common.retry'),
        onAction: () => ref.invalidate(searchResultsProvider(_query.trim())),
      ),
    );
  }
}