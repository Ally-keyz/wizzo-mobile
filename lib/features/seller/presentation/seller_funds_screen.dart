import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/w_async.dart';
import '../models/payment_account.dart';
import '../providers/seller_providers.dart';

/// Funds & Payouts — summary plus the store's connected payment accounts.
class SellerFundsScreen extends ConsumerWidget {
  const SellerFundsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final storeAsync = ref.watch(myStoreProvider);
    final statsAsync = ref.watch(sellerStatsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('seller.fundsTitle'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          WAsyncView(
            value: statsAsync,
            onRetry: () => ref.invalidate(sellerStatsProvider),
            loading: const WSkeleton(
              width: double.infinity,
              height: 120,
              radius: 18,
            ),
            builder: (context, stats) {
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('seller.availableForPayout'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatMoney(stats.available),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr(
                        'seller.pendingSettlement',
                        namedArgs: {'amount': formatMoney(stats.pending)},
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('seller.paymentAccounts'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => context.push('/seller/payment-accounts'),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(context.tr('common.manage')),
              ),
            ],
          ),
          const SizedBox(height: 10),
          WAsyncView(
            value: storeAsync,
            onRetry: () => ref.invalidate(myStoreProvider),
            builder: (context, store) {
              final accounts = store?.paymentAccounts ?? const [];
              if (accounts.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 36,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.tr('seller.noPaymentAccounts'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('seller.noPaymentAccountsBody'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.tonalIcon(
                        onPressed: () =>
                            context.push('/seller/payment-accounts'),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(context.tr('seller.addAccount')),
                      ),
                    ],
                  ),
                );
              }
              return Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    for (final account in accounts)
                      ListTile(
                        leading: Icon(
                          account.method == PaymentMethodKind.mobileMoney
                              ? Icons.phone_android
                              : account.method == PaymentMethodKind.bank
                              ? Icons.account_balance_outlined
                              : Icons.payments_outlined,
                          color: scheme.primary,
                        ),
                        title: Text(account.method.label(context)),
                        subtitle: Text(
                          account.accountName.isNotEmpty
                              ? '${account.accountNumber} · ${account.accountName}'
                              : account.accountNumber,
                        ),
                        onTap: () => context.push('/seller/payment-accounts'),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            context.tr('seller.howPayoutsWork'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _infoRow(context, context.tr('seller.payoutInfo1')),
          _infoRow(context, context.tr('seller.payoutInfo2')),
          _infoRow(context, context.tr('seller.payoutInfo3')),
          _infoRow(context, context.tr('seller.payoutInfo4')),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String text) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 6, color: scheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
