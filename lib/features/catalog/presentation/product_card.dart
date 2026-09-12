import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/product.dart';
import '../models/seller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/geo.dart';
import '../../../core/widgets/fly_to_cart.dart';
import '../../../core/widgets/w_async.dart';
import '../../../core/widgets/w_image.dart';
import '../../account/providers/account_providers.dart';
import '../../cart/providers/cart_provider.dart';

class ProductCard extends ConsumerWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.width,
    this.priceStyle,
  });

  final Product product;
  final VoidCallback? onTap;
  final double? width;
  final TextStyle? priceStyle;

  void _addToCart(BuildContext context, WidgetRef ref) {
    final box = context.findRenderObject();
    if (box is RenderBox) {
      final origin = box.localToGlobal(Offset.zero);
      final imageRect = Rect.fromLTWH(
        origin.dx,
        origin.dy,
        box.size.width,
        box.size.width,
      );
      flyToCartController.fly(
        context: context,
        productId: product.id,
        source: imageRect,
        imageUrl: product.images.isNotEmpty ? product.images.first : null,
        onLand: () => _commitAdd(ref),
      );
    } else {
      _commitAdd(ref);
    }
  }

  Future<void> _commitAdd(WidgetRef ref) async {
    try {
      await ref.read(cartProvider.notifier).addItem(productId: product.id);
    } catch (_) {
      // The badge stays honest thanks to the optimistic rollback in the
      // cart controller; failures are best-effort here.
    }
  }

  Future<void> _toggleWishlist(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(wishlistProvider.notifier).toggle(product.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('common.wishlistUpdateFailed'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final inWishlist = ref.watch(
      wishlistIdsProvider.select((ids) => ids.contains(product.id)),
    );
    final currentStyle =
        priceStyle ??
        theme.textTheme.titleMedium?.copyWith(
          color: Palette.gold,
          fontWeight: FontWeight.w700,
        );
    final nameStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w500,
      height: 1.25,
    );
    final sellerStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    Widget imageStack() => RepaintBoundary(
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            WImage(
              url: product.images.isNotEmpty ? product.images.first : null,
              fit: BoxFit.cover,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            if (product.discount > 0)
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Palette.gold,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '-${product.discount}%',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 8,
              top: 8,
              child: Semantics(
                label: context.tr('common.toggleWishlist'),
                button: true,
                child: _CircleOverlay(
                  onTap: () => _toggleWishlist(context, ref),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      inWishlist ? Icons.favorite : Icons.favorite_border,
                      key: ValueKey<bool>(inWishlist),
                      size: 17,
                      color: inWishlist
                          ? const Color(0xFFEF4444)
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: _CircleOverlay(
                onTap: () => _addToCart(context, ref),
                backgroundColor: Palette.gold,
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  size: 16,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Widget sellerRow() => Row(
      children: [
        Flexible(
          child: Text(
            product.seller?.displayName ?? context.tr('common.wizzoSeller'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: sellerStyle,
          ),
        ),
        if (product.seller?.verified ?? false) ...[
          const SizedBox(width: 4),
          const Icon(Icons.verified, size: 12, color: Color(0xFF3B82F6)),
        ],
        if (product.rating != null) ...[
          const Spacer(),
          RatingRow(rating: product.rating, iconSize: 11, showCount: false),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.hasBoundedHeight;
        return GestureDetector(
          onTap: onTap ?? () => context.push('/product/${product.id}'),
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                imageStack(),
                const SizedBox(height: 10),
                if (bounded)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PriceRow(
                          price: product.price,
                          originalPrice: product.originalPrice,
                          currentStyle: currentStyle,
                        ),
                        const SizedBox(height: 4),
                        Flexible(
                          child: Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: nameStyle,
                          ),
                        ),
                        const SizedBox(height: 6),
                        sellerRow(),
                      ],
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PriceRow(
                        price: product.price,
                        originalPrice: product.originalPrice,
                        currentStyle: currentStyle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: nameStyle,
                      ),
                      const SizedBox(height: 6),
                      sellerRow(),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Tappable circular overlay used on the product image (wishlist heart and
/// add-to-cart).
class _CircleOverlay extends StatelessWidget {
  const _CircleOverlay({
    required this.onTap,
    required this.child,
    this.backgroundColor = const Color(0x73000000),
  });

  final VoidCallback onTap;
  final Widget child;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(width: 32, height: 32, child: Center(child: child)),
      ),
    );
  }
}

/// Mini seller card used in horizontal home rails.
class SellerMiniCard extends StatelessWidget {
  const SellerMiniCard({super.key, required this.seller, this.onTap});

  final Seller seller;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slug = seller.storeSlug.isNotEmpty ? seller.storeSlug : seller.id;
    return GestureDetector(
      onTap: onTap ?? () => context.push('/shop/$slug'),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: seller.logoUrl != null
                ? WImage(url: seller.logoUrl!, fit: BoxFit.cover)
                : Icon(
                    Icons.storefront,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (seller.verified) ...[
                const Icon(Icons.verified, size: 12, color: Color(0xFF3B82F6)),
                const SizedBox(width: 3),
              ],
              Text(
                seller.storeName,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Row layout of a seller's shop (products count, rating, location).
class SellerStatsRow extends StatelessWidget {
  const SellerStatsRow({super.key, required this.seller});

  final Seller seller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        RatingRow(
          rating: seller.ratingAvg,
          reviewCount: seller.ratingCount,
          showCount: false,
        ),
        if (seller.productsCount != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                context.tr(
                  'shop.productsCountLabel',
                  namedArgs: {'count': '${seller.productsCount}'},
                ),
                style: style,
              ),
            ],
          ),
        if (seller.followersCount != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.people_outline,
                size: 14,
                color: Color(0xFF3B82F6),
              ),
              const SizedBox(width: 4),
              Text(
                context.tr(
                  'shop.followersCountLabel',
                  namedArgs: {'count': '${seller.followersCount}'},
                ),
                style: style,
              ),
            ],
          ),
      ],
    );
  }
}

/// Distance chip for nearby sellers.
class DistanceLabel extends StatelessWidget {
  const DistanceLabel({super.key, required this.distanceKm});

  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    if (distanceKm == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on, size: 14, color: context.appColors.info),
        const SizedBox(width: 3),
        Text(
          Geo.formatKm(distanceKm!),
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.appColors.info,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Loading skeleton for a product grid.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key, this.width});

  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: 1, child: WSkeleton(radius: 12)),
          SizedBox(height: 10),
          WSkeleton(width: 110, height: 18),
          SizedBox(height: 6),
          WSkeleton(height: 14),
          SizedBox(height: 4),
          WSkeleton(height: 14, width: 80),
        ],
      ),
    );
  }
}
