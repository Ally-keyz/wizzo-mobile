import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:pay/pay.dart' as pay;

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/w_widgets.dart';
import '../../../cart/models/cart.dart';
import '../../models/checkout.dart';
import 'checkout_shared.dart';

const _googlePayConfig = {
  'provider': 'google_pay',
  'data': {
    'apiVersion': 2,
    'apiVersionMinor': 0,
    'allowedPaymentMethods': [
      {
        'type': 'CARD',
        'parameters': {
          'allowedCardNetworks': ['MASTERCARD', 'VISA'],
          'allowedAuthMethods': ['PAN_ONLY', 'CRYPTOGRAM_3DS'],
        },
        'tokenizationSpecification': {
          'type': 'PAYMENT_GATEWAY',
          'parameters': {
            'gateway': 'stripe',
            'stripe:version': '2024-12-18',
            'stripe:publishableKey': AppConfig.stripePublishableKey,
          },
        },
      },
    ],
    'merchantInfo': {'merchantName': 'Wizzo'},
    // Required by pay_android: it does `getJSONObject("transactionInfo")`
    // while building the PaymentDataRequest. totalPrice/status are
    // overwritten from the PaymentItem, but the key must exist.
    'transactionInfo': {
      'currencyCode': AppConfig.currencyCode,
      'totalPriceStatus': 'FINAL',
    },
    'environment': 'TEST',
  },
};

class PaymentStep extends StatelessWidget {
  const PaymentStep({
    super.key,
    required this.cart,
    required this.methods,
    required this.paymentAccounts,
    required this.momoPhone,
    required this.totalAmount,
    required this.termsAccepted,
    this.error,
    this.placing = false,
    required this.onMethodSelected,
    required this.onMomoPhoneChanged,
    required this.onToggleTerms,
    required this.onGooglePayResult,
    required this.onPayNow,
  });

  final CartData cart;
  final Map<String, PaymentKind> methods;
  final Map<String, SellerPaymentInfo> paymentAccounts;
  final String momoPhone;
  final num totalAmount;
  final bool termsAccepted;
  final String? error;
  final bool placing;
  final void Function(String sellerId, PaymentKind kind) onMethodSelected;
  final void Function(String phone) onMomoPhoneChanged;
  final VoidCallback onToggleTerms;
  final void Function(Map<String, dynamic> result) onGooglePayResult;
  final VoidCallback onPayNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WPageTitle(context.tr('checkout.paymentTitle'),
            subtitle: context.tr('checkout.paymentHint')),
        const SizedBox(height: 16),
        for (final group in cart.groups) _sellerCard(context, theme, group),
        const SizedBox(height: 12),
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
                    'I agree to the Terms of Service and Privacy Policy',
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
                    'Pay ${formatMoney(totalAmount)}',
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

  Widget _sellerCard(
      BuildContext context, ThemeData theme, CartSellerGroup group) {
    final method = methods[group.sellerId] ?? PaymentKind.momo;
    final isOnlineMethod = method == PaymentKind.googlePay;
    final needsPhone = method == PaymentKind.momo;
    final account = accountFor(group.sellerId, method);
    final colors = context.appColors;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.sellerName ?? context.tr('common.seller'),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  formatMoney(group.subtotal),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Palette.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              children: [
                for (final option in PaymentOption.all)
                  _PaymentMethodTile(
                    option: option,
                    selected: method == option.kind,
                    onTap: () =>
                        onMethodSelected(group.sellerId, option.kind),
                  ),
              ],
            ),
          ),
          if (needsPhone) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                keyboardType: TextInputType.phone,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  labelText: 'MoMo phone number',
                  hintText: '0788 123 456',
                  prefixIcon: Icon(Icons.phone_outlined,
                      size: 20, color: colors.gold),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Palette.gold, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
                onChanged: onMomoPhoneChanged,
              ),
            ),
          ],
          if (isOnlineMethod) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: pay.GooglePayButton(
                paymentConfiguration:
                    pay.PaymentConfiguration.fromJsonString(
                  jsonEncode(_googlePayConfig),
                ),
                paymentItems: [
                  pay.PaymentItem(
                    label: 'Total',
                    amount: totalAmount.toInt().toString(),
                    status: pay.PaymentItemStatus.final_price,
                  ),
                ],
                type: pay.GooglePayButtonType.pay,
                margin: EdgeInsets.zero,
                onPaymentResult: (result) {
                  if (result is Map<String, dynamic>) {
                    onGooglePayResult(result);
                  }
                },
                onError: (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Google Pay: $error',
                        style: const TextStyle(fontSize: 13),
                      ),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                },
                loadingIndicator: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ],
          if (method == PaymentKind.momo && account != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: PaymentInstructionsCard(
                method: method,
                account: account,
                amount: group.subtotal,
              ),
            ),
          ],
        ],
      ),
    );
  }

  SellerPaymentAccount? accountFor(String sellerId, PaymentKind method) {
    final info = paymentAccounts[sellerId];
    if (info == null) return null;
    for (final account in info.paymentAccounts) {
      if (account.method == method) return account;
    }
    return null;
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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    option.label,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.description,
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
                  color:
                      selected ? Palette.gold : theme.colorScheme.outline,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check,
                      size: 14, color: Colors.white)
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

    if (kind == PaymentKind.googlePay) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: const Text(
          'G',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4285F4),
          ),
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
