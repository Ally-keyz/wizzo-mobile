import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/w_async.dart';
import '../../messages/providers/chat_providers.dart';
import '../data/seller_repository.dart';
import '../models/seller_order.dart';
import '../providers/seller_providers.dart';
import 'seller_ui.dart';

class SellerOrderDetailScreen extends ConsumerWidget {
  const SellerOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ordersAsync = ref.watch(sellerOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('seller.orderDetailsTitle'))),
      body: WAsyncView(
        value: ordersAsync,
        onRetry: () => ref.invalidate(sellerOrdersProvider),
        builder: (context, orders) {
          final order = orders.where((o) => o.id == orderId).firstOrNull;
          if (order == null) {
            return Center(
              child: Text(
                context.tr('seller.orderNotFound'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(sellerOrdersProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                _TopCard(order: order),
                const SizedBox(height: 16),
                if (order.buyerId != null) ...[
                  _ChatWithBuyerCard(order: order),
                  const SizedBox(height: 16),
                ],
                _ItemsCard(order: order),
                const SizedBox(height: 16),
                if (order.deliveryAddress != null)
                  _Card(
                    icon: Icons.local_shipping_outlined,
                    title: order.isPickup
                        ? context.tr('orders.pickupLabel')
                        : context.tr('checkout.deliveryAddress'),
                    child: _DeliveryInfo(order: order),
                  ),
                const SizedBox(height: 16),
                _Card(
                  icon: Icons.account_balance_wallet_outlined,
                  title: context.tr('checkout.paymentTitle'),
                  child: _PaymentInfo(order: order),
                ),
                const SizedBox(height: 16),
                if (order.status != SellerOrderStatus.completed &&
                    order.status != SellerOrderStatus.cancelled)
                  _ActionsCard(order: order),
                if (order.statusHistory.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _Timeline(order: order),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TopCard extends StatelessWidget {
  const _TopCard({required this.order});

  final SellerOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.orderNumber,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(
                    'seller.placedAt',
                    namedArgs: {'date': formatDateTime(order.createdAt)},
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                StatusBadge(status: order.status),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                context.tr('common.total'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatMoney(order.grandTotal),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatWithBuyerCard extends ConsumerStatefulWidget {
  const _ChatWithBuyerCard({required this.order});

  final SellerOrder order;

  @override
  ConsumerState<_ChatWithBuyerCard> createState() => _ChatWithBuyerCardState();
}

class _ChatWithBuyerCardState extends ConsumerState<_ChatWithBuyerCard> {
  bool _starting = false;

  Future<void> _openChat() async {
    final buyerId = widget.order.buyerId;
    if (buyerId == null || buyerId.isEmpty || _starting) return;
    setState(() => _starting = true);
    try {
      final conversation = await ref
          .read(chatRepositoryProvider)
          .start(buyerId);
      if (mounted && conversation.id.isNotEmpty) {
        context.push('/conversation/${conversation.id}');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('seller.errorOpenChat'))),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final buyer = widget.order.deliveryAddress?.fullName;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: scheme.secondaryContainer,
            child: Icon(
              Icons.person_outline,
              size: 20,
              color: scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  buyer ?? context.tr('seller.buyer'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr(
                    'seller.orderNumberLabel',
                    namedArgs: {'number': widget.order.orderNumber},
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: _starting ? null : _openChat,
            icon: _starting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chat_bubble_outline, size: 18),
            label: Text(
              _starting
                  ? context.tr('seller.opening')
                  : context.tr('seller.chatWithBuyer'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order});

  final SellerOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                context.tr('orders.items'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: item.image != null
                          ? Image.network(
                              item.image!,
                              cacheWidth: 44,
                              cacheHeight: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: scheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 18,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : Container(
                              color: scheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                size: 18,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.variantLabel.isNotEmpty)
                          Text(
                            item.variantLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${item.quantity} × ${formatMoney(item.priceAtPurchase)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),
          _amountRow(
            theme,
            scheme,
            context.tr('common.subtotal'),
            formatMoney(order.subtotal),
          ),
          if (order.shippingFee != null && order.shippingFee! > 0)
            _amountRow(
              theme,
              scheme,
              context.tr('checkout.deliveryFee'),
              formatMoney(order.shippingFee),
            ),
          _amountRow(
            theme,
            scheme,
            context.tr('common.total'),
            formatMoney(order.grandTotal),
            emphasize: true,
          ),
        ],
      ),
    );
  }

  Widget _amountRow(
    ThemeData theme,
    ColorScheme scheme,
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: emphasize ? FontWeight.w800 : null,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: emphasize ? scheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryInfo extends StatelessWidget {
  const _DeliveryInfo({required this.order});

  final SellerOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final address = order.deliveryAddress!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (order.trackingNumber != null &&
            order.trackingNumber!.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.qr_code_2, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                context.tr(
                  'seller.tracking',
                  namedArgs: {'number': order.trackingNumber!},
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Text(
          [
            address.fullName,
            address.phone,
          ].whereType<String>().where((e) => e.trim().isNotEmpty).join(' · '),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          address.summary,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PaymentInfo extends ConsumerWidget {
  const _PaymentInfo({required this.order});

  final SellerOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final proof = order.paymentProof;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              order.paymentMethod?.toUpperCase() ??
                  context.tr('checkout.paymentTitle').toUpperCase(),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              order.isCashOnDelivery
                  ? context.tr('orders.cashOnDelivery')
                  : formatMoney(order.grandTotal),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (proof != null &&
            (proof.proofUrl != null || proof.transactionReference != null)) ...[
          const SizedBox(height: 10),
          Text(
            context.tr('seller.paymentProofLabel'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          if (proof.transactionReference != null)
            Text(
              context.tr(
                'seller.paymentRef',
                namedArgs: {'ref': proof.transactionReference!},
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          if (proof.proofUrl != null) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => Dialog(
                  clipBehavior: Clip.antiAlias,
                  child: InteractiveViewer(
                    child: Image.network(proof.proofUrl!, cacheWidth: 1024),
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  proof.proofUrl!,
                  height: 140,
                  width: double.infinity,
                  cacheWidth: 720,
                  cacheHeight: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 140,
                    color: scheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
        if (order.status == SellerOrderStatus.paymentSubmitted) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _reject(ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                  ),
                  icon: Icon(Icons.close, size: 16),
                  label: Text(context.tr('seller.reject')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _confirm(ref),
                  icon: Icon(Icons.check, size: 16, color: Colors.black),
                  label: Text(
                    context.tr('seller.confirmPayment'),
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _confirm(WidgetRef ref) async {
    final message = ref.context.tr('seller.paymentConfirmed');
    try {
      await ref.read(sellerRepositoryProvider).confirmPayment(order.id);
      _refresh(ref, message);
    } catch (e) {
      _notify(ref, e.toString());
    }
  }

  Future<void> _reject(WidgetRef ref) async {
    final note = await _askNote(ref.context);
    if (note == null) return;
    final message = ref.context.tr('seller.paymentRejected');
    try {
      await ref
          .read(sellerRepositoryProvider)
          .rejectPayment(order.id, note: note);
      _refresh(ref, message);
    } catch (e) {
      _notify(ref, e.toString());
    }
  }

  void _refresh(WidgetRef ref, String message) {
    ref.invalidate(sellerOrdersProvider);
    ref.invalidate(orderStatusOptionsProvider(order.id));
    ScaffoldMessenger.of(
      ref.context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _notify(WidgetRef ref, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.context.mounted) {
        ScaffoldMessenger.of(
          ref.context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    });
  }

  Future<String?> _askNote(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('seller.rejectPaymentTitle')),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: context.tr('seller.reasonOptional'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.tr('seller.reject')),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

class _ActionsCard extends ConsumerWidget {
  const _ActionsCard({required this.order});

  final SellerOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final optionsAsync = ref.watch(orderStatusOptionsProvider(order.id));
    return WAsyncView(
      value: optionsAsync,
      onRetry: () => ref.invalidate(orderStatusOptionsProvider(order.id)),
      loading: const Center(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      builder: (context, next) {
        if (next.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('seller.updateStatus'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final status in next)
                  FilledButton(
                    onPressed: () => _advance(ref, status),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    child: Text(
                      SellerOrderStatus.label(context, status),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _advance(WidgetRef ref, String status) async {
    final themeContext = ref.context;
    final note = status == SellerOrderStatus.cancelled
        ? await _askNote(themeContext)
        : null;
    if (status == SellerOrderStatus.cancelled && note == null) return;
    try {
      await ref
          .read(sellerRepositoryProvider)
          .updateOrderStatus(order.id, status, note: note);
      if (themeContext.mounted) {
        ref.invalidate(sellerOrdersProvider);
        ref.invalidate(orderStatusOptionsProvider(order.id));
        ScaffoldMessenger.of(themeContext).showSnackBar(
          SnackBar(
            content: Text(
              themeContext.tr(
                'seller.orderMarkedAs',
                namedArgs: {
                  'status': SellerOrderStatus.label(
                    themeContext,
                    status,
                  ).toLowerCase(),
                },
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (themeContext.mounted) {
        ScaffoldMessenger.of(
          themeContext,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<String?> _askNote(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('seller.noteOptional')),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: context.tr('seller.reason'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.tr('common.continue')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(context.tr('common.cancel')),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.order});

  final SellerOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final events = [
      ...order.statusHistory.reversed,
    ].where((e) => e['status'] != null).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('seller.history'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final event in events)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      color: statusColor(event['status'].toString()),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          SellerOrderStatus.label(
                            context,
                            event['status'].toString(),
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (event['changedAt'] != null)
                          Text(
                            formatDateTime(tryParseDate(event['changedAt'])),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
