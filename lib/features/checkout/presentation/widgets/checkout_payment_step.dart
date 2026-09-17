import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/w_widgets.dart';
import '../../../cart/models/cart.dart';
import '../../models/checkout.dart';
import 'checkout_shared.dart';

class PaymentStep extends StatelessWidget {
  const PaymentStep({
    super.key,
    required this.cart,
    required this.method,
    required this.momoPhone,
    required this.totalAmount,
    required this.termsAccepted,
    this.error,
    this.placing = false,
    required this.onMethodSelected,
    required this.onMomoPhoneChanged,
    required this.onChatWithSellers,
    required this.onToggleTerms,
    required this.onPayNow,
  });

  final CartData cart;

  /// One payment method for the whole order — the platform collects the total
  /// once and settles each seller's share afterwards.
  final PaymentKind method;
  final String momoPhone;
  final num totalAmount;
  final bool termsAccepted;
  final String? error;
  final bool placing;
  final void Function(PaymentKind kind) onMethodSelected;
  final void Function(String phone) onMomoPhoneChanged;
  final VoidCallback onChatWithSellers;
  final VoidCallback onToggleTerms;
  final VoidCallback onPayNow;

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
        for (final option in PaymentOption.all)
          _PaymentMethodTile(
            option: option,
            selected: method == option.kind,
            onTap: () => onMethodSelected(option.kind),
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
          const SizedBox(height: 10),
          _Note(
            icon: Icons.schedule_outlined,
            color: colors.warning,
            text: context.tr('checkout.momoSubmittedNote'),
          ),
        ],
        if (method == PaymentKind.card) ...[
          const SizedBox(height: 4),
          _Note(
            icon: Icons.credit_card_outlined,
            color: colors.info,
            text: context.tr('checkout.stripeCardNote'),
          ),
        ],
        if (method == PaymentKind.momo) ...[
          const SizedBox(height: 4),
          _Note(
            icon: Icons.phone_android_outlined,
            color: colors.info,
            text: context.tr('checkout.momoChargeNote'),
          ),
        ],
        const SizedBox(height: 12),

        // ── How the money is handled ─────────────────────────────────────
        _Note(
          icon: Icons.account_balance_wallet_outlined,
          color: colors.success,
          text: context.tr('checkout.wizzoCollectsNote'),
        ),
        const SizedBox(height: 16),

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
        InkWell(
          onTap: onToggleTerms,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  termsAccepted
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  size: 20,
                  color: termsAccepted
                      ? colors.success
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('checkout.termsAgreement'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: (placing || !termsAccepted) ? null : onPayNow,
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

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
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
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? colors.goldSoft.withValues(alpha: 0.6)
              : theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _PaymentIcon(kind: option.kind, size: 36),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paymentKindLabel(context, option.kind),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    paymentKindDescription(context, option.kind),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? Palette.gold : Colors.transparent,
                border: Border.all(
                  color: selected ? Palette.gold : theme.colorScheme.outline,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
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
    final theme = Theme.of(context);

    if (kind == PaymentKind.card) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.credit_card_outlined,
          size: 20,
          color: Color(0xFF635BFF),
        ),
      );
    }

    if (kind == PaymentKind.momo) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFCC00), Color(0xFFFDB913)],
          ),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        alignment: Alignment.center,
        child: const Text(
          'M',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0066B2),
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(
        kind == PaymentKind.bank
            ? Icons.account_balance_outlined
            : Icons.payments_outlined,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
