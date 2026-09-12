import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/coming_soon_sheet.dart';
import '../../../core/widgets/w_image.dart';
import '../../../core/widgets/w_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../messages/providers/chat_providers.dart';
import '../data/account_repository.dart';
import '../models/order.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _startingChat = false;

  Future<void> _openChat(Order order) async {
    final seller = order.seller;
    if (seller?.id == null || seller!.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('orders.noSellerToChat'))),
      );
      return;
    }
    setState(() => _startingChat = true);
    try {
      final conversation =
          await ref.read(chatRepositoryProvider).start(seller.id!);
      if (!mounted) return;
      context.push('/conversation/${conversation.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('orders.chatFailed', namedArgs: {'error': '${e}'}))),
        );
      }
    } finally {
      if (mounted) setState(() => _startingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orderAsync = ref.watch(orderProvider(widget.orderId));
    final selfId = ref.read(authControllerProvider).user?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('orders.detailTitle'),
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${context.tr('orders.loadFailed')}: ${e}')),
        data: (order) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _OrderHeader(
              order: order,
              selfId: selfId,
              startingChat: _startingChat,
              onChat: () => _openChat(order),
            ),
            const SizedBox(height: 16),
            _TrackingCard(order: order),
            const SizedBox(height: 16),
            _ItemsCard(order: order),
            const SizedBox(height: 16),
            _PaymentCard(order: order),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => ComingSoonSheet.show(
                context,
                title: context.tr('orders.contactSupport'),
                description: context.tr('orders.contactSupportDescription'),
                icon: Icons.support_agent,
                ctaLabel: context.tr('common.gotIt'),
              ),
              icon: const Icon(Icons.support_agent, size: 18),
              label: Text(context.tr('orders.needHelp')),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({
    required this.order,
    required this.selfId,
    required this.startingChat,
    required this.onChat,
  });

  final Order order;
  final String? selfId;
  final bool startingChat;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seller = order.seller;
    final canceled = order.status?.toLowerCase().contains('cancel') == true ||
        order.status?.toLowerCase().contains('reject') == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.orderNumber ?? '#${order.id}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              _StatusPill(label: _label(context, order.status), color: _color(context)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                formatDateTime(order.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (order.summary != null && order.summary!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              order.summary!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (seller != null) ...[
            const Divider(height: 26),
            Row(
              children: [
                _sellerAvatar(context, seller),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        seller.name ?? context.tr('common.wizzoSeller'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (seller.verified) ...[
                            const Icon(
                              Icons.verified,
                              size: 13,
                              color: Palette.infoBlueBright,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              seller.verified ? context.tr('orders.verifiedSeller') : context.tr('orders.sellerFallback'),
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    (seller.id == null || seller.id == selfId || startingChat)
                        ? null
                        : onChat,
                icon: startingChat
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.chat_bubble_outline, size: 18),
                label: Text(
                  startingChat ? context.tr('orders.openingChat') : context.tr('orders.chatWithSeller'),
                ),
              ),
            ),
          ],
          if (canceled && order.status != null) ...[
            const SizedBox(height: 12),
            Text(
              context.tr('orders.cancelledInfo', namedArgs: {'status': order.status!}),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sellerAvatar(BuildContext context, OrderSeller seller) {
    final theme = Theme.of(context);
    return Container(
      width: 44,
      height: 44,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: seller.logo != null && seller.logo!.isNotEmpty
          ? WImage(url: seller.logo, fit: BoxFit.cover)
          : Center(
              child: Text(
                (seller.name ?? 'W').characters.first.toUpperCase(),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Palette.gold,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
    );
  }

  String _label(BuildContext context, String? status) {
    if (status == null) return context.tr('orders.statusPlacedUpper');
    return _orderStatusLabel(context, status);
  }

  Color _color(BuildContext context) {
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final canceled = order.status?.toLowerCase().contains('cancel') == true ||
        order.status?.toLowerCase().contains('reject') == true;
    final statusText = order.status == null
        ? context.tr('orders.statusPlacedUpper')
        : _orderStatusLabel(context, order.status!);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.tr('orders.tracking'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (order.progressSteps.isNotEmpty)
                _StatusPill(
                  label: context.tr('orders.stepProgress', namedArgs: {
                    'step': '${order.currentStep + 1}',
                    'total': '${order.progressSteps.length}',
                  }),
                  color: canceled ? colors.warning : colors.info,
                ),
            ],
          ),
          const SizedBox(height: 16),
          WStepIndicator(
            steps: order.progressSteps,
            current: order.currentStep,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: canceled
                  ? colors.warningContainer
                  : colors.successContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  canceled
                      ? Icons.info_outline
                      : Icons.check_circle_outline,
                  size: 18,
                  color:
                      canceled ? colors.onWarningContainer : colors.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('orders.currentStatus', namedArgs: {'status': statusText}),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: canceled
                          ? colors.onWarningContainer
                          : colors.onSuccessContainer,
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
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.tr('orders.items'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${order.items.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in order.items)
            _ItemTile(item: item, last: order.items.last == item),
          const Divider(height: 26),
          Row(
            children: [
              Text(context.tr('common.subtotal'), style: theme.textTheme.bodyMedium),
              const Spacer(),
              Text(
                formatMoney(order.subtotal ?? order.total ?? 0),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                context.tr('common.total'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                formatMoney(order.total ?? order.subtotal ?? 0),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Palette.gold,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.last});

  final OrderItem item;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = item.product;
    final amount = item.lineTotal ?? product.price * item.quantity;

    return Padding(
      padding: EdgeInsets.only(top: 8, bottom: last ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: WImage(
              url: product.images.isNotEmpty ? product.images.first : null,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('orders.qty', namedArgs: {'count': '${item.quantity}'}),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatMoney(amount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Palette.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ã— ${item.quantity}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('orders.paymentDelivery'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _infoRow(context, context.tr('orders.methodLabel'), order.paymentMethod ?? context.tr('orders.cashOnDelivery')),
          _infoRow(context, context.tr('orders.deliveryLabel'), order.deliveryOption ?? context.tr('orders.pickupLabel')),
          if (order.seller != null)
            _infoRow(context, context.tr('orders.soldBy'), order.seller!.name ?? context.tr('common.wizzoSeller')),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded summary card used across the order detail sections.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: child,
    );
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