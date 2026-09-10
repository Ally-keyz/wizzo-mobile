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
  'provider': 'stripe',
  'data': {
    'gateway': 'stripe',
    'stripe:version': '2024-12-18',
    'stripe:publishableKey': AppConfig.stripePublishableKey,
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

  /// Pay-in instructions keyed by seller user id (and seller document id).
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
        WPageTitle(context.tr('checkout.paymentTitle'), subtitle: context.tr('checkout.paymentHint')),
        const SizedBox(height: 14),
        for (final group in cart.groups) _sellerCard(context, theme, group),
        SectionCard(
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 20, color: context.appColors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('checkout.paymentsGoDirectly'),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sellerCard(BuildContext context, ThemeData theme, CartSellerGroup group) {
    final method = methods[group.sellerId] ?? PaymentKind.momo;
    final proof = proofs[group.sellerId];
    final isOnlineMethod = method == PaymentKind.googlePay;
    final needsPhone = method == PaymentKind.momo;
    final needsProof = !isOnlineMethod && method != PaymentKind.cashOnDelivery;
    final account = accountFor(group.sellerId, method);
    return SectionCard(
      title: group.sellerName ?? context.tr('common.seller'),
      trailing: Text(
        formatMoney(group.subtotal),
        style: theme.textTheme.bodyMedium?.copyWith(color: Palette.gold, fontWeight: FontWeight.w700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final option in PaymentOption.all)
            CheckoutPaymentTile(
              option: option,
              selected: method == option.kind,
              onTap: () => onMethodSelected(group.sellerId, option.kind),
            ),
          if (needsPhone) ...[
            const SizedBox(height: 8),
            TextField(
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Your MoMo phone number',
                hintText: 'e.g. 0788123456',
                prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                isDense: true,
              ),
              onChanged: onMomoPhoneChanged,
            ),
          ],
          if (isOnlineMethod) ...[
            const SizedBox(height: 4),
            PaymentInstructionsCard(
              method: method,
              amount: group.subtotal,
            ),
            if (method == PaymentKind.googlePay) ...[
              const SizedBox(height: 12),
              pay.GooglePayButton(
                paymentConfiguration: pay.PaymentConfiguration.fromJsonString(
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
                margin: const EdgeInsets.only(top: 8),
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
            ],
          ],
          if (needsProof) ...[
            const SizedBox(height: 4),
            PaymentInstructionsCard(
              method: method,
              account: account,
              amount: group.subtotal,
            ),
            const Divider(height: 20),
            const SizedBox(height: 4),
            if (proof != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.appColors.successContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_outlined, size: 18, color: context.appColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr('checkout.proofAttached', namedArgs: {
                          'details': proof.proofName != null ? ': ${proof.proofName}' : '',
                        }),
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () => onRemoveProof(group.sellerId),
                      child: Text(context.tr('common.remove')),
                    ),
                  ],
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: () => onUploadProof(group.sellerId),
                icon: const Icon(Icons.attach_file_outlined, size: 18),
                label: Text(context.tr('checkout.attachProof', namedArgs: {'amount': formatMoney(group.subtotal)})),
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