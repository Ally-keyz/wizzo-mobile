import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/variant_selector.dart';
import '../../../core/widgets/w_async.dart';
import '../../../core/widgets/w_image.dart';
import '../../../core/widgets/coming_soon_sheet.dart';
import '../../../core/widgets/fly_to_cart.dart';
import '../../account/data/account_repository.dart';
import '../../account/models/profile.dart';
import '../../account/providers/account_providers.dart';
import '../../cart/providers/cart_provider.dart';
import '../models/product.dart';
import '../providers/catalog_providers.dart';
import 'product_card.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _imageIndex = 0;
  String? _size;
  String? _color;
  bool _addingToCart = false;
  int _quantity = 1;
  bool _showReviews = false;
  int _reviewRating = 0;
  bool _submittingReview = false;
  final _reviewController = TextEditingController();
  final GlobalKey _addToCartKey = GlobalKey();

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = ref.watch(productProvider(widget.productId));

    return Scaffold(
      body: product.when(
        loading: () => const _DetailSkeleton(),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 44, color: Colors.grey),
              const SizedBox(height: 12),
              Text(context.tr('product.loadFailed')),
              const SizedBox(height: 4),
              Text('${e}', style: theme.textTheme.bodySmall),
              TextButton(
                onPressed: () =>
                    ref.invalidate(productProvider(widget.productId)),
                child: Text(context.tr('common.retry')),
              ),
            ],
          ),
        ),
        data: (p) => _buildProduct(context, theme, p),
      ),
    );
  }

  Widget _buildProduct(BuildContext context, ThemeData theme, Product product) {
    final inWishlist = ref.watch(wishlistIdsProvider).contains(product.id);
    return Stack(
      children: [
        // Scrollable content
        ListView(
          padding: EdgeInsets.zero,
          children: [
            _imageCarousel(context, product),
            if (product.video != null && product.video!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Material(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/shorts?product=${product.id}'),
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
                            context.tr('product.watchShort'),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          product.condition.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (product.discount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Palette.gold,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '-${product.discount}% OFF',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Semantics(
                        label: context.tr('common.toggleWishlist'),
                        button: true,
                        child: IconButton(
                          onPressed: () => _toggleWishlist(context, product),
                          icon: Icon(
                            inWishlist ? Icons.favorite : Icons.favorite_border,
                            color: inWishlist ? const Color(0xFFEF4444) : null,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _share(context, product),
                        icon: const Icon(Icons.share_outlined),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PriceRow(
                    price: product.price,
                    originalPrice: product.originalPrice,
                    currentStyle: theme.textTheme.headlineSmall?.copyWith(
                      color: Palette.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  RatingRow(
                    rating: product.rating,
                    reviewCount: product.ratingCount,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        context.tr(
                          'product.soldCount',
                          namedArgs: {'count': '${product.salesCount ?? 0}'},
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (product.viewsCount != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          context.tr(
                            'product.viewsCount',
                            namedArgs: {'count': '${product.viewsCount ?? 0}'},
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (product.sellerLocationLabel != null) ...[
                        const SizedBox(width: 10),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 13,
                              color: context.appColors.info,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              product.sellerLocationLabel!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: context.appColors.info,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 20),
                  _sellerCard(context, product),

                  if (product.sizeOptions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    VariantSelector(
                      title: context.tr('product.selectSize'),
                      options: product.sizeOptions,
                      value: _size,
                      onSelect: (v) => setState(() => _size = v),
                    ),
                  ],
                  if (product.colorOptions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    VariantSelector(
                      title: context.tr('product.selectColor'),
                      options: product.colorOptions,
                      value: _color,
                      onSelect: (v) => setState(() => _color = v),
                    ),
                  ],

                  const SizedBox(height: 20),
                  _deliveryRow(context, product),

                  const SizedBox(height: 24),
                  _quantitySelector(context, theme),

                  const SizedBox(height: 24),
                  _infoTabs(context, theme, product),

                  const SizedBox(height: 24),
                  Text(
                    context.tr('product.relatedForYou'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _relatedSection(context, product),
                ],
              ),
            ),
          ],
        ),

        // Floating top bar
        _floatingBar(context, product),

        // Bottom action bar
        _bottomBar(context, product),
      ],
    );
  }

  Widget _floatingBar(BuildContext context, Product product) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _roundButton(
                context,
                Icons.arrow_back,
                () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              _roundButton(
                context,
                Icons.shopping_cart_outlined,
                () => context.push('/cart'),
                key: flyToCartController.cartTargetKey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundButton(
    BuildContext context,
    IconData icon,
    VoidCallback onTap, {
    Key? key,
  }) {
    return Material(
      key: key,
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
      elevation: 1,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _imageCarousel(BuildContext context, Product product) {
    final images = product.images.isNotEmpty
        ? product.images
        : const <String>[];
    return SizedBox(
      height: 320,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _imageIndex = i),
            itemBuilder: (_, i) => WImage(
              url: images[i],
              fit: BoxFit.cover,
              errorIcon: Icons.image_not_supported_outlined,
            ),
          ),
          if (images.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (i) {
                  final active = i == _imageIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: active ? Palette.gold : Colors.white70,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sellerCard(BuildContext context, Product product) {
    final theme = Theme.of(context);
    final seller = product.seller;
    final name = seller?.displayName ?? context.tr('common.wizzoSeller');
    final slug = seller?.storeSlug?.isNotEmpty == true
        ? seller!.storeSlug!
        : seller?.id;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (slug != null && slug.isNotEmpty) context.push('/shop/$slug');
        },
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: seller?.logoUrl != null
                  ? WImage(url: seller!.logoUrl!, fit: BoxFit.cover)
                  : Icon(
                      Icons.storefront,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (seller?.verified ?? false) ...[
                        const SizedBox(width: 5),
                        const VerifiedBadge(showLabel: false),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  _onlineRow(context, seller?.online ?? false),
                  const SizedBox(height: 3),
                  if (seller?.ratingAvg != null)
                    RatingRow(
                      rating: seller!.ratingAvg,
                      iconSize: 11,
                      showCount: false,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Palette.gold,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                context.tr('product.viewShop'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _onlineRow(BuildContext context, bool online) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: online
                ? context.appColors.success
                : context.appColors.warning,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            context.tr(online ? 'common.onlineNow' : 'product.replyWithinHour'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _deliveryRow(BuildContext context, Product product) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.local_shipping_outlined,
            color: context.appColors.info,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('product.deliveryPickup'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                product.deliveryOptions.isEmpty
                    ? context.tr('product.contactSeller')
                    : product.deliveryOptions.join(' • '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quantitySelector(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        Text(
          context.tr('product.quantity'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _qtyButton(
                context,
                Icons.remove,
                enabled: _quantity > 1,
                onTap: () => setState(() => _quantity--),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '$_quantity',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _qtyButton(
                context,
                Icons.add,
                onTap: () => setState(() => _quantity++),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _qtyButton(
    BuildContext context,
    IconData icon, {
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? theme.colorScheme.onSurface
              : theme.colorScheme.outline,
        ),
      ),
    );
  }

  /// Segmented "About this item | Reviews" switch controlling the lower body.
  Widget _infoTabs(BuildContext context, ThemeData theme, Product product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _tabButton(
                context,
                product,
                label: context.tr('product.aboutTab'),
                active: !_showReviews,
              ),
              _tabButton(
                context,
                product,
                label: context.tr(
                  'product.reviewsTab',
                  namedArgs: {'count': '${product.ratingCount ?? 0}'},
                ),
                active: _showReviews,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_showReviews)
          _reviewsSection(context, theme, product)
        else
          _aboutBody(context, theme, product),
      ],
    );
  }

  Widget _tabButton(
    BuildContext context,
    Product product, {
    required String label,
    required bool active,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _showReviews = !_showReviews),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? theme.colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _aboutBody(BuildContext context, ThemeData theme, Product product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (product.specs.isNotEmpty) ...[
          Text(
            context.tr('product.specifications'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _specsTable(context, product),
        ],
        if (product.description != null &&
            (product.description!.isNotEmpty && product.specs.isEmpty)) ...[
          Text(
            context.tr('product.description'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.description!,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
        ],
      ],
    );
  }

  Widget _reviewsSection(
    BuildContext context,
    ThemeData theme,
    Product product,
  ) {
    final reviewsAsync = ref.watch(productReviewsProvider(product.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _writeReviewCard(context, theme, product),
        const SizedBox(height: 20),
        reviewsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            context.tr('product.reviewsLoadFailed', namedArgs: {'error': '$e'}),
            style: theme.textTheme.bodySmall,
          ),
          data: (reviewsReversed) {
            final reviews = reviewsReversed.reversed.toList();
            if (reviews.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  context.tr('product.noReviews'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final review in reviews)
                  _reviewTile(context, theme, review),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _writeReviewCard(
    BuildContext context,
    ThemeData theme,
    Product product,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('product.rateThisProduct'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (i) {
              final filled = i < _reviewRating;
              return InkWell(
                onTap: () => setState(() => _reviewRating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 32,
                    color: filled ? Palette.gold : theme.colorScheme.outline,
                  ),
                ),
              );
            }),
          ),
          if (_reviewRating > 0) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _reviewController,
              maxLines: 3,
              minLines: 2,
              decoration: InputDecoration(
                hintText: context.tr('product.reviewHint'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _submittingReview
                    ? null
                    : () => _submitReview(context, product),
                child: _submittingReview
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(context.tr('product.submitReview')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submitReview(BuildContext context, Product product) async {
    if (_reviewRating == 0) return;
    setState(() => _submittingReview = true);
    try {
      await ref
          .read(accountRepositoryProvider)
          .submitReview(
            productId: product.id,
            rating: _reviewRating,
            comment: _reviewController.text,
          );
      ref.invalidate(productReviewsProvider(product.id));
      if (mounted) {
        setState(() {
          _submittingReview = false;
          _reviewRating = 0;
          _reviewController.clear();
        });
        _toast(context, context.tr('product.reviewThanks'));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submittingReview = false);
        _toast(
          context,
          context.tr('product.reviewSubmitFailed', namedArgs: {'error': '$e'}),
        );
      }
    }
  }

  Widget _reviewTile(BuildContext context, ThemeData theme, Review review) {
    final name = review.authorName?.isNotEmpty == true
        ? review.authorName!
        : context.tr('common.customer');
    final rating = review.rating?.toInt() ?? 0;
    final date = review.createdAt?.toLocal();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: Text(
                  name.substring(0, 1).toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (date != null)
                      Text(
                        '${date.day}/${date.month}/${date.year}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 16,
                    color: i < rating
                        ? Palette.gold
                        : theme.colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              review.comment!,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _specsTable(BuildContext context, Product product) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < product.specs.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: i.isEven
                    ? theme.colorScheme.surface
                    : theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      product.specs[i].name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      product.specs[i].value,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _relatedSection(BuildContext context, Product product) {
    return Consumer(
      builder: (context, ref, _) {
        final related = ref.watch(relatedProductsProvider(product.id));
        return SizedBox(
          height: 260,
          child: related.when(
            data: (list) => list.isEmpty
                ? const SizedBox()
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: list.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 170,
                        child: ProductCard(product: list[i]),
                      ),
                    ),
                  ),
            loading: () => ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                ProductCardSkeleton(width: 170),
                SizedBox(width: 12),
                ProductCardSkeleton(width: 170),
                SizedBox(width: 12),
                ProductCardSkeleton(width: 170),
              ],
            ),
            error: (_, _) => const SizedBox(),
          ),
        );
      },
    );
  }

  Widget _bottomBar(BuildContext context, Product product) {
    final theme = Theme.of(context);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: SafeArea(
          top: false,
          child: FilledButton.icon(
            key: _addToCartKey,
            onPressed: _addingToCart
                ? null
                : () => _addToCart(context, product),
            icon: _addingToCart
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.shopping_cart_outlined, size: 18),
            label: Text(
              context.tr(
                _addingToCart ? 'product.adding' : 'product.addToCart',
              ),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  String? _missingOption(BuildContext context, Product product) {
    if (product.sizeOptions.isNotEmpty && _size == null)
      return context.tr('product.selectSizeFirst');
    if (product.colorOptions.isNotEmpty && _color == null)
      return context.tr('product.selectColorFirst');
    return null;
  }

  Future<void> _addToCart(BuildContext context, Product product) async {
    final optionError = _missingOption(context, product);
    if (optionError != null) {
      _toast(context, optionError);
      return;
    }
    Future<void> commit() async {
      try {
        await ref
            .read(cartProvider.notifier)
            .addItem(
              productId: product.id,
              quantity: _quantity,
              size: _size,
              color: _color,
            );
        if (context.mounted) _toast(context, context.tr('product.addedToCart'));
      } catch (e) {
        if (context.mounted)
          _toast(
            context,
            context.tr('product.addToCartFailed', namedArgs: {'error': '$e'}),
          );
      }
    }

    setState(() => _addingToCart = true);
    final buttonContext = _addToCartKey.currentContext;
    Rect? source;
    if (buttonContext != null) {
      final box = buttonContext.findRenderObject();
      if (box is RenderBox) source = box.localToGlobal(Offset.zero) & box.size;
    }
    if (source == null) {
      await commit();
    } else {
      flyToCartController.fly(
        context: context,
        productId: product.id,
        source: source,
        imageUrl: product.images.isNotEmpty ? product.images.first : null,
        onLand: () => commit(),
      );
    }
    if (mounted) setState(() => _addingToCart = false);
  }

  Future<void> _toggleWishlist(BuildContext context, Product product) async {
    try {
      await ref.read(wishlistProvider.notifier).toggle(product.id);
    } catch (e) {
      if (context.mounted)
        _toast(context, context.tr('common.wishlistUpdateFailed'));
    }
  }

  void _share(BuildContext context, Product product) {
    ComingSoonSheet.show(
      context,
      title: context.tr('product.share'),
      description: context.tr('product.shareComingSoon'),
      icon: Icons.share_outlined,
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          height: 320,
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SizedBox(height: 12),
              WSkeleton(width: 120, height: 22),
              SizedBox(height: 12),
              WSkeleton(width: 200, height: 28),
              SizedBox(height: 10),
              WSkeleton(width: 80, height: 16),
              SizedBox(height: 24),
              WSkeleton(height: 48),
              SizedBox(height: 24),
              WSkeleton(width: 100, height: 18),
            ],
          ),
        ),
      ],
    );
  }
}
