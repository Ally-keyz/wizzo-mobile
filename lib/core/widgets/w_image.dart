import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

/// Shared network-image with shimmer placeholder and a graceful error state.
///
/// Decodes network images at the render size (via [memCacheWidth] /
/// [memCacheHeight]) instead of full resolution, which keeps memory usage low
/// in grids, rails and chat bubbles. An explicit override wins over the
/// inferred layout size.
class WImage extends StatelessWidget {
  const WImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.backgroundColor,
    this.errorIcon = Icons.image_not_supported_outlined,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final IconData errorIcon;
  final int? memCacheWidth;
  final int? memCacheHeight;

  static int? _logicalPx(double? value) {
    if (value == null || !value.isFinite || value <= 0) return null;
    return value.round().clamp(16, 2048).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safe = url == null || url!.isEmpty ? null : url;
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: ColoredBox(
        color: backgroundColor ?? Colors.transparent,
        child: safe == null
            ? _placeholder(scheme, errorIcon)
            : LayoutBuilder(
                builder: (context, constraints) {
                  final targetWidth =
                      memCacheWidth ??
                      _logicalPx(width) ??
                      (constraints.hasBoundedWidth
                          ? _logicalPx(constraints.maxWidth)
                          : null);
                  final targetHeight =
                      memCacheHeight ??
                      _logicalPx(height) ??
                      (constraints.hasBoundedHeight
                          ? _logicalPx(constraints.maxHeight)
                          : null);
                  return CachedNetworkImage(
                    imageUrl: safe,
                    width: width,
                    height: height,
                    fit: fit,
                    memCacheWidth: targetWidth,
                    memCacheHeight: targetHeight,
                    placeholder: (_, _) =>
                        Container(color: scheme.surfaceContainerHighest),
                    errorWidget: (_, _, _) => _placeholder(scheme, errorIcon),
                  );
                },
              ),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme, IconData icon) {
    return Container(
      width: width,
      height: height,
      color: scheme.surfaceContainerHighest,
      child: Icon(icon, color: scheme.onSurfaceVariant, size: 28),
    );
  }
}

/// Price row: gold current price + struck-through original price.
class PriceRow extends StatelessWidget {
  const PriceRow({
    super.key,
    required this.price,
    this.originalPrice,
    this.bold = true,
    this.currentStyle,
    this.originalStyle,
  });

  final num price;
  final num? originalPrice;
  final bool bold;
  final TextStyle? currentStyle;
  final TextStyle? originalStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.titleLarge!.copyWith(
      color: Palette.gold,
      fontWeight: FontWeight.w700,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          formatMoney(price),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: currentStyle ?? base,
        ),
        if (originalPrice != null && originalPrice! > price) ...[
          const SizedBox(width: 8),
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              formatMoney(originalPrice),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style:
                  originalStyle ??
                  theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: theme.colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Gold star rating row with optional review count.
class RatingRow extends StatelessWidget {
  const RatingRow({
    super.key,
    this.rating,
    this.reviewCount,
    this.showEmpty = true,
    this.iconSize = 13,
    this.showCount = true,
  });

  final double? rating;
  final int? reviewCount;
  final bool showEmpty;
  final double iconSize;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRating = rating != null && rating! > 0;
    if (!hasRating && !showEmpty) return const SizedBox.shrink();

    final stars = hasRating ? rating! : 0.0;
    final countText = reviewCount != null && reviewCount! > 0
        ? context.tr('common.reviewCount', namedArgs: {'count': '$reviewCount'})
        : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasRating) ...[
          Text(
            stars.toStringAsFixed(1),
            style: theme.textTheme.bodySmall?.copyWith(
              color: Palette.gold,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 2),
        ],
        ...List.generate(5, (i) {
          final filled = i < stars.floor();
          return Icon(
            filled ? Icons.star : Icons.star_border,
            size: iconSize,
            color: Palette.gold,
          );
        }),
        if (showCount && countText != null) ...[
          const SizedBox(width: 6),
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              '($countText)',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Blue "Verified" pill.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.label, this.showLabel = true});

  final String? label;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.infoContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 12, color: colors.info),
          if (showLabel) ...[
            const SizedBox(width: 3),
            Text(
              label ?? context.tr('common.verified'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: colors.info,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Horizontal trust badges band (icons + labels).
class TrustBand extends StatelessWidget {
  const TrustBand({super.key, this.items, this.twoColumn = false});

  List<(IconData, String)> _defaultItems(BuildContext context) => [
    (Icons.verified_user_outlined, context.tr('common.trustVerifiedSellers')),
    (Icons.shield_outlined, context.tr('common.trustSecurePayments')),
    (Icons.location_on_outlined, context.tr('common.trustLocalPickup')),
    (Icons.support_agent, context.tr('common.trustSupport')),
  ];

  final List<(IconData, String)>? items;
  final bool twoColumn;

  @override
  Widget build(BuildContext context) {
    final cells = (items ?? _defaultItems(context))
        .map((e) => _TrustItem(icon: e.$1, label: e.$2))
        .toList();
    return Column(
      children: [
        for (var i = 0; i < cells.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(child: cells[i]),
                const SizedBox(width: 12),
                Expanded(
                  child: cells.length > i + 1 ? cells[i + 1] : const SizedBox(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: context.appColors.success),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
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
}

/// Rounded gold call-to-action tile (e.g. "Join Wizzo Community").
class GoldCTA extends StatelessWidget {
  const GoldCTA({
    super.key,
    required this.label,
    required this.icon,
    this.subtitle,
    this.onTap,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Palette.gold,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.black, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, color: Colors.black, size: 20),
          ],
        ),
      ),
    );
  }
}
