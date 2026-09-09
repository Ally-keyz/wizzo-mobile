import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/w_async.dart';
import '../models/seller_order.dart';
import '../providers/seller_providers.dart';
import 'seller_ui.dart';

class SellerOrdersScreen extends ConsumerStatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  ConsumerState<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends ConsumerState<SellerOrdersScreen> {
  OrderBucket _bucket = OrderBucket.all;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(sellerOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('seller.ordersTitle'))),
      body: WAsyncView(
        value: ordersAsync,
        onRetry: () => ref.invalidate(sellerOrdersProvider),
        builder: (context, orders) {
          final counts = <OrderBucket, int>{};
          for (final bucket in OrderBucket.values) {
            counts[bucket] = orders
                .where((o) => bucket.matches(o.status))
                .length;
          }
          final needsAction = orders
              .where(
                (o) =>
                    o.status == SellerOrderStatus.placed ||
                    o.status == SellerOrderStatus.paymentSubmitted,
              )
              .length;
          final filtered =
              orders.where((o) => _bucket.matches(o.status)).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: NeedsActionBanner(
                  count: needsAction,
                  onTap: () => setState(() => _bucket = OrderBucket.fresh),
                ),
              ),
              OrderBucketBar(
                current: _bucket,
                counts: counts,
                onChanged: (b) => setState(() => _bucket = b),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: filtered.isEmpty
                    ? RefreshIndicator(
                        onRefresh: () =>
                            ref.refresh(sellerOrdersProvider.future).then((_) {}),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 120),
                            _EmptyOrders(bucket: _bucket),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.refresh(sellerOrdersProvider.future).then((_) {}),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final order = filtered[index];
                            return _SellerOrderCard(order: order);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SellerOrderCard extends StatelessWidget {
  const _SellerOrderCard({required this.order});

  final SellerOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final first = order.items.isNotEmpty ? order.items.first : null;
    final remoteImage = first?.image;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => context.go('/seller/order/${order.id}'),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: remoteImage != null
                        ? Image.network(
                            remoteImage,
                            cacheWidth: 52,
                            cacheHeight: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _placeholder(scheme, first?.name),
                          )
                        : _placeholder(scheme, first?.name),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderNumber,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr(
                          'seller.orderItemCount',
                          namedArgs: {
                            'count': '${order.items.length}',
                            'date': relativeDate(order.createdAt),
                          },
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      StatusBadge(status: order.status, dense: true),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatMoney(order.grandTotal),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (order.isDelivery)
                      Icon(
                        Icons.local_shipping_outlined,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme, String? name) {
    return Container(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Text(
          (name ?? '?').substring(0, 1).toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders({required this.bucket});

  final OrderBucket bucket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 44,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              bucket == OrderBucket.all
                  ? context.tr('seller.emptyOrdersTitle')
                  : context.tr(
                      'seller.emptyOrdersBucketTitle',
                      namedArgs: {
                        'bucket': bucket.label(context).toLowerCase(),
                      },
                    ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('seller.emptyOrdersBody'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
