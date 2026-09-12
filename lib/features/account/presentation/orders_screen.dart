import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/w_image.dart';
import '../../../core/widgets/w_widgets.dart';
import '../data/account_repository.dart';
import '../models/order.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final orders = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('orders.title'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
      body: orders.when(
        loading: () => const SizedBox(height: 300, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => WEmptyState(
          icon: Icons.cloud_off,
          title: context.tr('orders.loadFailed'),
          subtitle: '${e}',
          actionLabel: context.tr('common.retry'),
          onAction: () => ref.invalidate(ordersProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return WEmptyState(
              icon: Icons.receipt_long_outlined,
              title: context.tr('orders.empty'),
              subtitle: context.tr('orders.emptyHint'),
              actionLabel: context.tr('common.startShopping'),
              onAction: () => context.go('/home'),
            );
          }
          final sorted = [...list]..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(ordersProvider);
              await Future<void>.delayed(const Duration(milliseconds: 300));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              itemBuilder: (context, i) {
                final order = sorted[i];
                return _OrderCard(order: order);
              },
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstItem = order.items.isNotEmpty ? order.items.first.product : null;
    final moreCount = order.items.length > 1 ? order.items.length - 1 : 0;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/order/${order.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    _statusLabel(context, order.status),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _statusColor(context),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  order.orderNumber ?? '#${order.id}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            if (order.summary != null) ...[
              const SizedBox(height: 8),
              Text(
                order.summary!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (firstItem != null)
                  Container(
                    width: 56,
                    height: 56,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: WImage(
                      url: firstItem.images.isNotEmpty ? firstItem.images.first : null,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstItem?.name ?? context.tr('orders.orderFallback'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      if (moreCount > 0)
                        Text(
                          context.tr('orders.moreItems', namedArgs: {'count': '$moreCount'}),
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        formatMoney(order.total),
                        style: theme.textTheme.titleSmall?.copyWith(color: Palette.gold, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                if (order.needsReview)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Palette.gold,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      context.tr('orders.reviewChip'),
                      style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                Icon(Icons.chevron_right, size: 20, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(BuildContext context, String? status) {
    if (status == null) return context.tr('orders.statusPlaced');
    return _orderStatusLabel(context, status);
  }

  Color _statusColor(BuildContext context) {
    final colors = context.appColors;
    switch (order.status?.toLowerCase()) {
      case 'cancelled':
      case 'rejected':
        return colors.warning;
      case 'completed':
      case 'delivered':
        return colors.success;
      default:
        return colors.info;
    }
  }
}

const _knownOrderStatuses = <String>{
  'placed',
  'seller_confirmed',
  'payment_submitted',
  'payment_confirmed',
  'processing',
  'shipped',
  'out_for_delivery',
  'delivered',
  'completed',
  'cancelled',
  'returned',
  'ready_for_pickup',
};

String _orderStatusLabel(BuildContext context, String status) {
  final key = status.toLowerCase();
  if (_knownOrderStatuses.contains(key)) {
    return context.tr('orders.status.$key');
  }
  return status.replaceAll('_', ' ').toUpperCase();
}