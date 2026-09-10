import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/w_image.dart';
import '../../../../core/widgets/w_widgets.dart';
import '../../../account/models/profile.dart';
import '../../../cart/models/cart.dart';
import '../../models/checkout.dart';
import 'checkout_shared.dart';

class ReviewStep extends StatelessWidget {
  const ReviewStep({
    super.key,
    required this.cart,
    required this.address,
    required this.delivery,
    required this.methods,
    required this.proofs,
    required this.couponDiscount,
    required this.termsAccepted,
    required this.error,
    required this.onToggleTerms,
    this.onEditShipping,
  });

  final CartData cart;
  final Address address;
  final DeliveryKind delivery;
  final Map<String, PaymentKind> methods;
  final Map<String, PaymentProof> proofs;
  final num couponDiscount;
  final bool termsAccepted;
  final String? error;
  final VoidCallback onToggleTerms;
  final VoidCallback? onEditShipping;

  DeliveryOption get _option =>
      DeliveryOption.all.firstWhere((o) => o.id == delivery);
  String get _deliveryName => _option.name;
  String get _deliveryInfo => '$_deliveryName • ${_option.timing}';
  num get _deliveryFee => _option.price;
  num get _total => cart.subtotal - couponDiscount + _deliveryFee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WPageTitle(context.tr('checkout.reviewTitle'), subtitle: context.tr('checkout.reviewHint')),
        const SizedBox(height: 14),
        SectionCard(
          title: context.tr('checkout.shippingAddress'),
          trailing: onEditShipping == null
              ? const Icon(Icons.location_on_outlined)
              : TextButton.icon(
                  onPressed: onEditShipping,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(context.tr('common.edit')),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                address.fullName ?? address.label ?? context.tr('common.address'),
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (address.phone != null)
                Text(address.phone!, style: theme.textTheme.bodySmall),
              Text(
                [address.street, address.city, address.country]
                    .where((e) => e != null && e.isNotEmpty)
                    .join(', '),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        SectionCard(
          title: context.tr('checkout.delivery'),
          trailing: const Icon(Icons.local_shipping_outlined),
          child: Row(
            children: [
              const Icon(Icons.bolt_outlined, size: 18, color: Palette.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _deliveryInfo,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatMoney(_deliveryFee),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Palette.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        SectionCard(
          title: context.tr('wallet.paymentMethods'),
          trailing: const Icon(Icons.payments_outlined),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final group in cart.groups)
                _paymentLine(context, theme, group),
            ],
          ),
        ),
        SectionCard(
          title: context.tr('checkout.items'),
          child: Column(
            children: [
              for (final group in cart.groups) _groupItems(context, theme, group),
            ],
          ),
        ),
        SectionCard(
          title: context.tr('cart.summary'),
          child: Column(
            children: [
              CheckoutSummaryRow(label: context.tr('common.subtotal'), value: formatMoney(cart.subtotal)),
              if (couponDiscount > 0)
                CheckoutSummaryRow(
                  label: context.tr('checkout.couponDiscount'),
                  value: '-${formatMoney(couponDiscount)}',
                  valueColor: context.appColors.success,
                ),
              CheckoutSummaryRow(label: context.tr('checkout.deliveryFee'), value: formatMoney(_deliveryFee)),
              const Divider(height: 20),
              CheckoutSummaryRow(label: context.tr('common.total'), value: formatMoney(_total), bold: true),
            ],
          ),
        ),
        InkWell(
          onTap: onToggleTerms,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  termsAccepted ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 20,
                  color: termsAccepted ? Palette.gold : theme.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('checkout.termsAgreement'),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onErrorContainer)),
          ),
        ],
      ],
    );
  }

  Widget _paymentLine(BuildContext context, ThemeData theme, CartSellerGroup group) {
    final method = methods[group.sellerId] ?? PaymentKind.momo;
    final label = PaymentOption.all.firstWhere((o) => o.kind == method).label;
    final hasProof = method != PaymentKind.cashOnDelivery && proofs[group.sellerId] != null;
    final colors = context.appColors;

    final IconData icon;
    final Color color;
    final String status;
    if (method == PaymentKind.cashOnDelivery) {
      icon = Icons.payments_outlined;
      color = colors.info;
      status = formatMoney(group.subtotal);
    } else if (hasProof) {
      icon = Icons.verified_outlined;
      color = colors.success;
      status = context.tr('checkout.proofAttachedShort');
    } else {
      icon = Icons.schedule_outlined;
      color = colors.warning;
      status = context.tr('checkout.awaitingProof');
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: group == cart.groups.last ? 0 : 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.sellerName ?? context.tr('common.seller'),
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  status,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupItems(BuildContext context, ThemeData theme, CartSellerGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.sellerName ?? context.tr('common.seller'),
          style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        for (final item in group.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  height: 38,
                  child: WImage(
                    url: item.product.images.isNotEmpty ? item.product.images.first : null,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${item.product.name} × ${item.quantity}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Text(
                  formatMoney(item.lineTotal),
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        if (group != cart.groups.last) const Divider(height: 16),
      ],
    );
  }
}