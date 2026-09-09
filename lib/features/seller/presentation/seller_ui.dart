import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/seller_order.dart';

/// Work-safe accent per status, readable on light and dark.
Color statusColor(String status) => switch (status) {
  'placed' || 'seller_confirmed' || 'pending' => const Color(0xFFF59E0B),
  'payment_submitted' || 'payment_confirmed' => const Color(0xFFF97316),
  'processing' || 'ready_for_pickup' => const Color(0xFF3B82F6),
  'shipped' || 'out_for_delivery' => const Color(0xFF14B8A6),
  'delivered' || 'completed' || 'active' => const Color(0xFF22C55E),
  'cancelled' || 'draft' => const Color(0xFF9CA3AF),
  _ => const Color(0xFFEF4444),
};

/// A coloured pill showing a seller-side order/product status, styled like the
/// web admin badges (works on light and dark).
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.dense = false});

  final String status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        statusLabel(context, status),
        style: TextStyle(
          fontSize: dense ? 11 : 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  static String statusLabel(BuildContext context, String status) {
    if (SellerOrderStatus.all.contains(status)) {
      return SellerOrderStatus.label(context, status);
    }
    // Product statuses share the same visual language.
    return switch (status) {
      'active' => context.tr('seller.status.active'),
      'pending' => context.tr('seller.status.pending'),
      'draft' => context.tr('seller.status.draft'),
      'rejected' => context.tr('seller.status.rejected'),
      'sold_out' => context.tr('seller.status.sold_out'),
      _ => status.replaceAll('_', ' ').toUpperCase(),
    };
  }
}

/// Banner shown when a new order needs confirmation / payment approval.
class NeedsActionBanner extends StatelessWidget {
  const NeedsActionBanner({
    super.key,
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (count <= 0) return const SizedBox.shrink();
    return Material(
      color: scheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.bolt, size: 20, color: scheme.onTertiaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr(
                    'seller.needsActionBanner',
                    namedArgs: {'count': '$count'},
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact status-chip filter row used by the seller orders screen.
class OrderBucketBar extends StatelessWidget {
  const OrderBucketBar({
    super.key,
    required this.current,
    required this.counts,
    required this.onChanged,
  });

  final OrderBucket current;
  final Map<OrderBucket, int> counts;
  final ValueChanged<OrderBucket> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final bucket in OrderBucket.values) ...[
            _chip(context, scheme, bucket, counts[bucket] ?? 0),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    ColorScheme scheme,
    OrderBucket bucket,
    int count,
  ) {
    final selected = bucket == current;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onChanged(bucket),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(bucket.label(context)),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? scheme.onPrimary : scheme.primary,
              ),
            ),
          ],
        ],
      ),
      selectedColor: scheme.primary,
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
      ),
      checkmarkColor: scheme.onPrimary,
      showCheckmark: false,
      backgroundColor: scheme.surface,
      side: BorderSide(color: scheme.outlineVariant),
    );
  }
}
