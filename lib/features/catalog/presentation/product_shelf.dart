import 'package:flutter/material.dart';

import '../models/product.dart';
import 'product_card.dart';

const double _kShelfSpacing = 12;
const double _kShelfHPadding = 16;
const double _kShelfDetailsBudget = 100;

/// A single horizontally-swipeable row of products.
///
/// Fits [visibleCount] cards (default 3) in the viewport; swiping right reveals
/// the rest of [products] in the same row so the shelf never overflows.
class ProductShelf extends StatelessWidget {
  const ProductShelf({
    super.key,
    required this.products,
    this.visibleCount = 3,
    this.imageAspectRatio = 3 / 4,
    this.spacing = _kShelfSpacing,
  }) : assert(visibleCount > 0);

  final List<Product> products;
  final int visibleCount;
  final double imageAspectRatio;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final width = MediaQuery.sizeOf(context).width;
    final available = width - _kShelfHPadding * 2;
    final cardWidth = (available - spacing * (visibleCount - 1)) / visibleCount;
    return SizedBox(
      height: cardWidth / imageAspectRatio + _kShelfDetailsBudget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _kShelfHPadding),
        itemCount: products.length,
        separatorBuilder: (_, _) => SizedBox(width: spacing),
        itemBuilder: (_, i) => SizedBox(
          width: cardWidth,
          child: ProductCard(
            product: products[i],
            imageAspectRatio: imageAspectRatio,
          ),
        ),
      ),
    );
  }
}

/// Stacks products into multiple [ProductShelf] rows (each 3-visible) so a full
/// catalog page scrolls vertically without ever overflowing horizontally.
class ProductShelves extends StatelessWidget {
  const ProductShelves({
    super.key,
    required this.products,
    this.shelfSize = 12,
    this.imageAspectRatio = 3 / 4,
  }) : assert(shelfSize > 0);

  final List<Product> products;
  final int shelfSize;
  final double imageAspectRatio;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final shelves = <List<Product>>[
      for (var i = 0; i < products.length; i += shelfSize)
        products.sublist(i, (i + shelfSize).clamp(0, products.length)),
    ];
    return Column(
      children: [
        for (var i = 0; i < shelves.length; i++) ...[
          if (i > 0) const SizedBox(height: 20),
          ProductShelf(
            products: shelves[i],
            imageAspectRatio: imageAspectRatio,
          ),
        ],
      ],
    );
  }
}

/// Loading placeholder matching [ProductShelf]'s 3-visible geometry.
class ProductShelfSkeleton extends StatelessWidget {
  const ProductShelfSkeleton({
    super.key,
    this.visibleCount = 3,
    this.imageAspectRatio = 3 / 4,
    this.spacing = _kShelfSpacing,
  });

  final int visibleCount;
  final double imageAspectRatio;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final available = width - _kShelfHPadding * 2;
    final cardWidth = (available - spacing * (visibleCount - 1)) / visibleCount;
    return SizedBox(
      height: cardWidth / imageAspectRatio + _kShelfDetailsBudget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: _kShelfHPadding),
        itemCount: visibleCount,
        separatorBuilder: (_, _) => SizedBox(width: spacing),
        itemBuilder: (_, _) => SizedBox(width: cardWidth, child: const ProductCardSkeleton()),
      ),
    );
  }
}
