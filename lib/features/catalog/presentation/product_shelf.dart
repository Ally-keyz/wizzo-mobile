import 'package:flutter/material.dart';

import '../models/product.dart';
import 'product_card.dart';

/// Grid spacing/padding shared by every product listing.
const double _kGridSpacing = 12;
const double _kGridHPadding = 16;

/// Space reserved under the image inside a [ProductCard] for its price, title
/// and seller row (see the bounded branch in [ProductCard.build]).
const double _kCardDetailsBudget = 100;

const EdgeInsets _kGridPadding = EdgeInsets.symmetric(
  horizontal: _kGridHPadding,
);

/// Two products per row, like the Amazon shopping app.
///
/// The card image is portrait (3:4) and its cell height is derived from the
/// available width so the details block never overflows on narrow screens.
class ProductGrid extends StatelessWidget {
  const ProductGrid({
    super.key,
    required this.products,
    this.crossAxisCount = 2,
    this.imageAspectRatio = 3 / 4,
    this.spacing = _kGridSpacing,
    this.padding = _kGridPadding,
  }) : assert(crossAxisCount > 0);

  final List<Product> products;
  final int crossAxisCount;
  final double imageAspectRatio;
  final double spacing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final ratio = _cellAspectRatio(
          width: constraints.maxWidth,
          crossAxisCount: crossAxisCount,
          spacing: spacing,
          imageAspectRatio: imageAspectRatio,
          padding: padding,
        );
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: ratio,
          ),
          itemCount: products.length,
          itemBuilder: (_, i) => ProductCard(
            product: products[i],
            imageAspectRatio: imageAspectRatio,
          ),
        );
      },
    );
  }
}

/// Sliver form of [ProductGrid], so a product listing can live directly inside
/// a [CustomScrollView] and build lazily as the page scrolls.
class SliverProductGrid extends StatelessWidget {
  const SliverProductGrid({
    super.key,
    required this.products,
    this.crossAxisCount = 2,
    this.imageAspectRatio = 3 / 4,
    this.spacing = _kGridSpacing,
    this.padding = _kGridPadding,
  }) : assert(crossAxisCount > 0);

  final List<Product> products;
  final int crossAxisCount;
  final double imageAspectRatio;
  final double spacing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final ratio = _cellAspectRatio(
          width: constraints.crossAxisExtent,
          crossAxisCount: crossAxisCount,
          spacing: spacing,
          imageAspectRatio: imageAspectRatio,
          padding: padding,
        );
        return SliverPadding(
          padding: padding,
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childAspectRatio: ratio,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) => ProductCard(
                product: products[i],
                imageAspectRatio: imageAspectRatio,
              ),
              childCount: products.length,
            ),
          ),
        );
      },
    );
  }
}

/// Loading placeholder matching [ProductGrid]'s two-per-row geometry.
class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({
    super.key,
    this.crossAxisCount = 2,
    this.itemCount = 6,
    this.imageAspectRatio = 3 / 4,
    this.spacing = _kGridSpacing,
    this.padding = _kGridPadding,
  }) : assert(crossAxisCount > 0);

  final int crossAxisCount;
  final int itemCount;
  final double imageAspectRatio;
  final double spacing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ratio = _cellAspectRatio(
          width: constraints.maxWidth,
          crossAxisCount: crossAxisCount,
          spacing: spacing,
          imageAspectRatio: imageAspectRatio,
          padding: padding,
        );
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: ratio,
          ),
          itemCount: itemCount,
          itemBuilder: (_, _) => const ProductCardSkeleton(),
        );
      },
    );
  }
}

/// Cell aspect ratio (width / height) that makes a grid cell exactly tall
/// enough for the card image plus its price/title/seller block.
double _cellAspectRatio({
  required double width,
  required int crossAxisCount,
  required double spacing,
  required double imageAspectRatio,
  required EdgeInsets padding,
}) {
  final available = width - padding.horizontal;
  final cardWidth =
      (available - spacing * (crossAxisCount - 1)) / crossAxisCount;
  if (cardWidth <= 0) return 1;
  final cellHeight = cardWidth / imageAspectRatio + _kCardDetailsBudget;
  return cardWidth / cellHeight;
}
