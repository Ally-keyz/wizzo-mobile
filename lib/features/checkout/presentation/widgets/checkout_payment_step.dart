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
    'environment': 'TEST',
  },
};

class PaymentStep extends StatelessWidget {
  const PaymentStep({
    super.key,
    required this.cart,
    required this.methods,
    required this.proofs,
    required this.paymentAccounts,
    required this.momoPhone,
    required this.totalAmount,
    required this.onMethodSelected,
    required this.onUploadProof,
    required this.onRemoveProof,
    required this.onMomoPhoneChanged,
    required this.onGooglePayResult,
  });

  final CartData cart;
  final Map<String, PaymentKind> methods;
  final Map<String, PaymentProof> proofs;
  final Map<String, SellerPaymentInfo> paymentAccounts;
  final String momoPhone;
  final num totalAmount;
  final void Function(String sellerId, PaymentKind kind) onMethodSelected;
  final void Function(String sellerId) onUploadProof;
  final void Function(String sellerId) onRemoveProof;
  final void Function(String phone) onMomoPhoneChanged;
  final void Function(Map<String, dynamic> result) onGooglePayResult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WPageTitle(context.tr('checkout.paymentTitle'),
            subtitle: context.tr('checkout.paymentHint')),
        const SizedBox(height: 16),
        for (final group in cart.groups) _sellerCard(context, theme, group),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.lock_outline,
                size: 16, color: context.appColors.success),
            const SizedBox(width: 8),
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
    final proof = proofs[group.sellerId];
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: onMomoPhoneChanged,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (isOnlineMethod) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
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
          if (method == PaymentKind.momo &&
              method != PaymentKind.cashOnDelivery) ...[
            Padding(
              padding: const.fromLTRB(20, 0, 20, 16),
              child: _ProofSection(
                sellerId: group.sellerId,
                proof: proof,
                amount: group.subtotal,
                onUpload: onUploadProof,
                onRemove: onRemoveProof,
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
    final isMomo = option.kind == PaymentKind.momo;

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
                color: selected
                    ? Palette.gold
                    : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? Palette.gold
                      : theme.colorScheme.outline,
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
            fontFamily: 'Google Sans',
          ),
        ),
      );
    }

    if (kind == PaymentKind.momo) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFCC00), Color(0xFFFDB913)],
          ),
          borderRadius: BorderRadius.circular(10),
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
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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

class _ProofSection extends StatelessWidget {
  const _ProofSection({
    required this.sellerId,
    required this.proof,
    required this.amount,
    required this.onUpload,
    required this.onRemove,
  });

  final String sellerId;
  final PaymentProof? proof;
  final num amount;
  final void Function(String sellerId) onUpload;
  final void Function(String sellerId) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    if (proof != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.successContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_outlined,
                size: 18, color: colors.success),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Payment proof attached${proof!.proofName != null ? ': ${proof!.proofName}' : ''}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            GestureDetector(
              onTap: () => onRemove(sellerId),
              child: Icon(Icons.close,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => onUpload(sellerId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.attach_file_outlined,
                size: 18, color: colors.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Attach payment receipt',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              formatMoney(amount),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Palette.gold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
