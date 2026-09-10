import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../data/checkout_repository.dart';
import '../models/checkout.dart';
import 'widgets/checkout_shared.dart';

/// Post-checkout screen (mirrors the web `OrderConfirmationScreen`): shows the
/// order reference, a success header, money totals, and one card per seller
/// with the pay-in details.
class OrderConfirmationScreen extends ConsumerStatefulWidget {
  const OrderConfirmationScreen({super.key, this.summary});

  final PlacementSummary? summary;

  @override
  ConsumerState<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState
    extends ConsumerState<OrderConfirmationScreen> {
  final Map<String, SellerPaymentInfo> _paymentAccounts = {};

  PlacementSummary? get summary => widget.summary;

  @override
  void initState() {
    super.initState();
    _loadPaymentAccounts();
  }

  Future<void> _loadPaymentAccounts() async {
    final sellers = summary?.sellerOrders.map((o) => o.sellerUserId).toList();
    if (sellers == null || sellers.isEmpty) return;
    try {
      final infos = await ref
          .read(checkoutRepositoryProvider)
          .getSellersPaymentAccounts(sellers);
      if (!mounted) return;
      setState(() {
        for (final info in infos) {
          _paymentAccounts[info.sellerUserId] = info;
          if (info.sellerId != null && info.sellerId!.isNotEmpty) {
            _paymentAccounts[info.sellerId!] = info;
          }
        }
      });
    } catch (_) {
      // Cards fall back to a "no account listed" hint when offline.
    }
  }

  SellerPaymentAccount? _accountFor(SellerOrderReceipt order) {
    final info = _paymentAccounts[order.sellerUserId];
    if (info == null) return null;
    final method = order.paymentMethod ?? PaymentKind.momo;
    for (final account in info.paymentAccounts) {
      if (account.method == method) return account;
    }
    return null;
  }

  String? _storeNameFor(SellerOrderReceipt order) =>
      _paymentAccounts[order.sellerUserId]?.storeName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final s = summary;
    final orderId = s?.orderNumber ?? s?.orderId ?? '';

    final itemsTotal = s == null
        ? null
        : (s.sellerOrders.isNotEmpty
              ? s.sellerOrders.fold<num>(0, (acc, o) => acc + o.subtotal)
              : s.total);
    final grandTotal = s?.grandTotal ?? s?.total;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('checkout.confirmationTitle'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (orderId.isNotEmpty)
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  orderId.toUpperCase().startsWith('WZ')
                      ? orderId.toUpperCase()
                      : 'WZ-${orderId.toUpperCase()}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.surface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Center(
              child: Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.successContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 52,
                  color: colors.success,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('checkout.orderPlaced'),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('checkout.orderPlacedHint'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            if (grandTotal != null) ...[
              const SizedBox(height: 12),
              Text(
                formatMoney(grandTotal),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Palette.gold,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (s?.deliveryAddress != null)
              Text(
                context.tr(
                  'checkout.deliveringTo',
                  namedArgs: {
                    'address': [
                      s!.deliveryAddress!.street,
                      s.deliveryAddress!.city,
                      s.deliveryAddress!.country,
                    ].where((e) => e != null && e.isNotEmpty).join(', '),
                  },
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 24),
            if (s != null && s.sellerOrders.isNotEmpty) ...[
              Row(
                children: [
                  Text(
                    context.tr('checkout.payments'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    context.tr(
                      'checkout.storeCount',
                      namedArgs: {'count': '${s.sellerOrders.length}'},
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final order in s.sellerOrders)
                _sellerCard(
                  context,
                  theme,
                  order,
                ),
              const SizedBox(height: 16),
              SectionCard(
                title: context.tr('checkout.orderSummary'),
                child: Column(
                  children: [
                    if (itemsTotal != null)
                      CheckoutSummaryRow(
                        label: context.tr('checkout.itemsTotal'),
                        value: formatMoney(itemsTotal),
                      ),
                    CheckoutSummaryRow(
                      label: context.tr('checkout.orderTotalInclDelivery'),
                      value: formatMoney(grandTotal ?? itemsTotal ?? 0),
                      bold: true,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.go('/orders'),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: Text(context.tr('checkout.viewMyOrders')),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go('/home'),
                child: Text(context.tr('common.continueShopping')),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sellerCard(
    BuildContext context,
    ThemeData theme,
    SellerOrderReceipt order,
  ) {
    final isCod = order.isCashOnDelivery;
    final method = order.paymentMethod ?? PaymentKind.momo;
    final methodLabel = PaymentOption.all
        .firstWhere(
          (o) => o.kind == method,
          orElse: () => PaymentOption.all.first,
        )
        .label;

    return SectionCard(
      title: _storeNameFor(order) ?? context.tr('common.seller'),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatMoney(order.subtotal),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Palette.gold,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            methodLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCod)
            PaymentInstructionsCard(
              method: PaymentKind.cashOnDelivery,
              amount: order.subtotal,
            )
          else
            PaymentInstructionsCard(
              method: method,
              account: _accountFor(order),
              amount: order.subtotal,
            ),
        ],
      ),
    );
  }
}
