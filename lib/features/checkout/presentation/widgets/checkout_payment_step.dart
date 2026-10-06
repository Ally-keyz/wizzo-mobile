import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/w_widgets.dart';
import '../../../cart/models/cart.dart';
import '../../models/checkout.dart';
import 'checkout_shared.dart';
import 'payment_marks.dart';

class PaymentStep extends StatelessWidget {
  const PaymentStep({
    super.key,
    required this.cart,
    required this.method,
    required this.momoPhone,
    required this.totalAmount,
    this.error,
    this.placing = false,
    required this.onMethodSelected,
    required this.onMomoPhoneChanged,
    required this.onChatWithSellers,
    required this.onPayNow,
  });

  final CartData cart;

  /// The selected method for the whole order (platform collects the total
  /// once and settles each seller's share afterwards). Null until the buyer
  /// explicitly picks a tile — nothing is pre-selected by default.
  final PaymentKind? method;
  final String momoPhone;
  final num totalAmount;
  final String? error;
  final bool placing;
  final void Function(PaymentKind kind) onMethodSelected;
  final void Function(String phone) onMomoPhoneChanged;
  final VoidCallback onChatWithSellers;
  final VoidCallback onPayNow;

  /// All payment options: MoMo, Visa/Mastercard (Stripe), Google Pay and
  /// Apple Pay. Apple Pay must always be visible alongside Google Pay.
  List<PaymentOption> _visibleOptions() => PaymentOption.all;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final subtotal = cart.groups.fold<num>(0, (sum, g) => sum + g.subtotal);
    final delivery = totalAmount - subtotal;
    final needsPhone = method == PaymentKind.momo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WPageTitle(context.tr('checkout.paymentTitle'),
            subtitle: context.tr('checkout.paymentHint')),
        const SizedBox(height: 16),

        // ── Combined total for the whole order ───────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              CheckoutSummaryRow(
                label: context.tr('checkout.itemsTotal'),
                value: formatMoney(subtotal),
              ),
              CheckoutSummaryRow(
                label: context.tr('checkout.deliveryFee'),
                value: delivery <= 0
                    ? context.tr('checkout.freeDelivery')
                    : formatMoney(delivery),
              ),
              const Divider(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('checkout.totalToPay'),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    formatMoney(totalAmount),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Palette.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Single payment method for the whole order ────────────────────
        Text(
          context.tr('checkout.paymentMethod'),
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 3.4,
          children: [
            for (final option in _visibleOptions())
              _PaymentMethodTile(
                option: option,
                selected: method == option.kind,
                onTap: () => onMethodSelected(option.kind),
              ),
          ],
        ),
        if (needsPhone) ...[
          const SizedBox(height: 4),
          TextField(
            keyboardType: TextInputType.phone,
            style: theme.textTheme.bodyMedium,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12),
            ],
            decoration: InputDecoration(
              labelText: context.tr('checkout.momoPhoneField'),
              hintText: context.tr('checkout.momoPhoneHint'),
              prefixText: '+250 ',
              helperText: context.tr('checkout.momoStkHint'),
              helperMaxLines: 2,
              prefixIcon:
                  Icon(Icons.phone_outlined, size: 20, color: colors.gold),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.45),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Palette.gold, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: onMomoPhoneChanged,
          ),
        ],
        const SizedBox(height: 12),

        // ── Chat with the sellers ────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: placing ? null : onChatWithSellers,
            icon: const Icon(Icons.forum_outlined, size: 18),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            label: Text(context.tr('checkout.chatWithSellers')),
          ),
        ),
        const SizedBox(height: 16),

        if (error != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(error!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onErrorContainer)),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: placing ? null : onPayNow,
            style: FilledButton.styleFrom(
              backgroundColor: Palette.gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: placing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black),
                  )
                : Text(
                    context.tr(
                      'checkout.placeOrder',
                      namedArgs: {'total': formatMoney(totalAmount)},
                    ),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.lock_outline, size: 14, color: colors.success),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                context.tr('checkout.paymentsGoDirectly'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final PaymentOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? colors.goldSoft.withValues(alpha: 0.6)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Palette.gold : theme.colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PaymentIcon(kind: option.kind, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                paymentKindLabel(context, option.kind),
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentIcon extends StatelessWidget {
  const _PaymentIcon({required this.kind, this.size = 36});

  final PaymentKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case PaymentKind.momo:
        return MomoMark(size: size);
      case PaymentKind.card:
        return CardMark(height: size);
      case PaymentKind.googlePay:
        return GooglePayMark(height: size * 0.6);
      case PaymentKind.applePay:
        return ApplePayMark(height: size * 0.6);
      case PaymentKind.bank:
      case PaymentKind.cashOnDelivery:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(
            kind == PaymentKind.bank
                ? Icons.account_balance_outlined
                : Icons.payments_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
    }
  }
}
