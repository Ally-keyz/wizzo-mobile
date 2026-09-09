import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/variant_selector.dart';
import '../../../core/widgets/w_image.dart';
import '../../cart/providers/cart_provider.dart';
import '../../catalog/models/product.dart';
import '../models/video_short.dart';
import 'comment_sheet.dart';
import 'shorts_video_view.dart';

/// One full-screen vertical video with the right action rail, bottom-left
/// overlay and shoppable product chip. Tapping toggles play/pause; double-tap
/// likes with a heart burst.
class ShortVideoPage extends ConsumerStatefulWidget {
  const ShortVideoPage({
    super.key,
    required this.short,
    required this.active,
    required this.onLike,
    required this.onSave,
  });

  final VideoShort short;
  final bool active;
  final void Function(VideoShort pageShort) onLike;
  final void Function(VideoShort pageShort) onSave;

  @override
  ConsumerState<ShortVideoPage> createState() => _ShortVideoPageState();
}

class _ShortVideoPageState extends ConsumerState<ShortVideoPage> {
  bool _showCenterPlayIcon = false;
  bool _showHeartBurst = false;
  bool _userPaused = false;
  bool _expanded = false;
  Timer? _playFlashTimer;

  @override
  void didUpdateWidget(ShortVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Returning to this page (or swiping away) resets any manual pause so the
    // video autoplays again like TikTok.
    if (oldWidget.active && !widget.active && _userPaused) {
      _userPaused = false;
    }
  }

  @override
  void dispose() {
    _playFlashTimer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _userPaused = !_userPaused;
      _showCenterPlayIcon = true;
    });
    _playFlashTimer?.cancel();
    _playFlashTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _showCenterPlayIcon = false);
    });
  }

  void _onDoubleTap() {
    if (!widget.short.likedByMe) widget.onLike(widget.short);
    setState(() => _showHeartBurst = true);
    Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showHeartBurst = false);
    });
  }

  void _openComments() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (_) => CommentSheet(productId: widget.short.product.id),
    );
  }

  Future<void> _quickAdd() async {
    final product = widget.short.product;
    final needsVariant =
        product.sizeOptions.isNotEmpty || product.colorOptions.isNotEmpty;

    String? size = product.sizeOptions.isNotEmpty
        ? product.sizeOptions.first
        : null;
    String? color = product.colorOptions.isNotEmpty
        ? product.colorOptions.first
        : null;

    if (needsVariant) {
      final variant = await showModalBottomSheet<VariantChoice>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        showDragHandle: true,
        builder: (_) => _VariantSheet(
          product: product,
          initialSize: size,
          initialColor: color,
        ),
      );
      if (variant == null) return;
      size = variant.size;
      color = variant.color;
    }

    // Optimistic: show the confirmation immediately, add in the background.
    final prevCount = ref.read(cartCountProvider);
    ref
        .read(cartProvider.notifier)
        .addItem(productId: product.id, quantity: 1, size: size, color: color)
        .then((_) {})
        .catchError((_) {
          if (mounted) _toast('Could not add to cart');
        });
    _showAddedToCart(prevCount + 1);
  }

  void _showAddedToCart(int count) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFF06A00),
          duration: const Duration(milliseconds: 1600),
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Added to cart ($count)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  void _openShop() {
    final slug = widget.short.product.seller?.storeSlug;
    if (slug != null && slug.isNotEmpty) {
      context.push('/shop/$slug');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final short = widget.short;
    final product = short.product;
    final seller = product.seller;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Immersive full-black video canvas (regardless of app theme).
        GestureDetector(
          onTap: _togglePlay,
          onDoubleTap: _onDoubleTap,
          child: Container(
            color: Colors.black,
            child: (product.video != null && product.video!.isNotEmpty)
                ? ShortsVideoView(
                    url: product.video!,
                    active: widget.active && !_userPaused,
                  )
                : const Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      color: Colors.white70,
                      size: 64,
                    ),
                  ),
          ),
        ),

        // Center play/pause flash on tap.
        if (_showCenterPlayIcon)
          Center(
            child: Icon(
              _userPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              size: 72,
              color: Colors.white70,
            ),
          ),

        // Persistent play affordance while the video is paused.
        if (_userPaused)
          const IgnorePointer(
            child: Center(
              child: Icon(
                Icons.play_circle_fill,
                size: 56,
                color: Colors.white38,
              ),
            ),
          ),

        // Heart burst on double-tap.
        if (_showHeartBurst)
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1.35),
              duration: const Duration(milliseconds: 550),
              curve: Curves.easeOut,
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: (1.35 - value).clamp(0.0, 1.0),
                  child: const Icon(
                    Icons.favorite,
                    color: Color(0xFFE0245E),
                    size: 96,
                  ),
                ),
              ),
            ),
          ),

        // Bottom-left overlay + shoppable chip.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _openShop,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (seller?.logoUrl != null &&
                          seller!.logoUrl!.isNotEmpty)
                        WImage(
                          url: seller.logoUrl,
                          width: 32,
                          height: 32,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text(
                          seller?.displayName ?? 'Wizzo Seller',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (seller?.verified ?? false) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified,
                          color: Palette.gold,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    product.description == null || product.description!.isEmpty
                        ? product.name
                        : product.description!,
                    maxLines: _expanded ? null : 3,
                    overflow: _expanded ? null : TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _ProductChip(
                  product: product,
                  onTap: () => _openProductSheet(product),
                ),
              ],
            ),
          ),
        ),

        // Right action rail. Painted last so it sits above the bottom gradient
        // overlay and stays fully tappable (hit-test order follows paint order).
        Positioned(
          right: 10,
          bottom: 130,
          child: _ActionRail(
            short: short,
            onLike: () => widget.onLike(short),
            onSave: () => widget.onSave(short),
            onComment: _openComments,
            onAddToCart: _quickAdd,
          ),
        ),
      ],
    );
  }

  void _openProductSheet(Product product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (_) => _ProductSheet(product: product, onAddToCart: _quickAdd),
    );
  }
}

class _ActionRail extends StatelessWidget {
  const _ActionRail({
    required this.short,
    required this.onLike,
    required this.onSave,
    required this.onComment,
    required this.onAddToCart,
  });

  final VideoShort short;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onComment;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final seller = short.product.seller;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            final slug = seller?.storeSlug;
            if (slug != null && slug.isNotEmpty) {
              context.push('/shop/$slug');
            }
          },
          child: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white24,
            backgroundImage:
                (seller?.logoUrl != null && seller!.logoUrl!.isNotEmpty)
                ? ResizeImage.resizeIfNeeded(
                    80,
                    80,
                    NetworkImage(seller.logoUrl!),
                  )
                : null,
            child: (seller?.logoUrl == null || seller!.logoUrl!.isEmpty)
                ? const Icon(Icons.storefront, color: Colors.white, size: 22)
                : null,
          ),
        ),
        const SizedBox(height: 16),
        _RailAction(
          icon: short.likedByMe ? Icons.favorite : Icons.favorite_border,
          color: short.likedByMe ? const Color(0xFFE0245E) : Colors.white,
          label: _Count(short.likeCount),
          onTap: onLike,
        ),
        const SizedBox(height: 14),
        _RailAction(
          icon: short.savedByMe ? Icons.bookmark : Icons.bookmark_border,
          color: short.savedByMe ? Palette.gold : Colors.white,
          label: _Count(short.saveCount),
          onTap: onSave,
        ),
        const SizedBox(height: 14),
        _RailAction(
          icon: Icons.chat_bubble_outline,
          color: Colors.white,
          label: _Count(short.commentCount),
          onTap: onComment,
        ),
        const SizedBox(height: 14),
        _RailAction(
          icon: Icons.shopping_bag_outlined,
          color: Palette.gold,
          label: const Text(
            'Cart',
            style: TextStyle(color: Colors.white, fontSize: 11),
          ),
          onTap: onAddToCart,
        ),
      ],
    );
  }
}

class _RailAction extends StatelessWidget {
  const _RailAction({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Widget label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 30,
            shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
          ),
          const SizedBox(height: 2),
          label,
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.value);
  final int value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value > 999 ? '${(value / 1000).toStringAsFixed(1)}k' : '$value',
      style: const TextStyle(color: Colors.white, fontSize: 11),
    );
  }
}

class _ProductChip extends StatelessWidget {
  const _ProductChip({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (product.images.isNotEmpty)
              WImage(
                url: product.images.first,
                width: 38,
                height: 38,
                borderRadius: BorderRadius.circular(8),
              ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 190),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatMoney(product.price),
                    style: const TextStyle(
                      color: Palette.gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Text(
                'Shop',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VariantChoice {
  const VariantChoice({this.size, this.color});
  final String? size;
  final String? color;
}

class _VariantSheet extends StatefulWidget {
  const _VariantSheet({
    required this.product,
    required this.initialSize,
    required this.initialColor,
  });

  final Product product;
  final String? initialSize;
  final String? initialColor;

  @override
  State<_VariantSheet> createState() => _VariantSheetState();
}

class _VariantSheetState extends State<_VariantSheet> {
  late String? _size = widget.initialSize;
  late String? _color = widget.initialColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.product;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              formatMoney(product.price),
              style: theme.textTheme.titleLarge?.copyWith(
                color: Palette.gold,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            if (product.sizeOptions.isNotEmpty) ...[
              VariantSelector(
                title: 'Select Size',
                options: product.sizeOptions,
                value: _size,
                onSelect: (v) => setState(() => _size = v),
              ),
              const SizedBox(height: 16),
            ],
            if (product.colorOptions.isNotEmpty) ...[
              VariantSelector(
                title: 'Select Color',
                options: product.colorOptions,
                value: _color,
                onSelect: (v) => setState(() => _color = v),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              onPressed: () => Navigator.of(
                context,
              ).pop(VariantChoice(size: _size, color: _color)),
              child: const Text(
                'Add to Cart',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductSheet extends StatelessWidget {
  const _ProductSheet({required this.product, required this.onAddToCart});

  final Product product;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = product.images.isNotEmpty ? product.images.first : null;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (image != null)
                  WImage(
                    url: image,
                    width: 72,
                    height: 72,
                    borderRadius: BorderRadius.circular(12),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatMoney(product.price),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Palette.gold,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (product.description != null &&
                product.description!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                product.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push('/product/${product.id}'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              child: const Text(
                'View Full Details',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onAddToCart,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
              child: const Text('Add to Cart'),
            ),
          ],
        ),
      ),
    );
  }
}
