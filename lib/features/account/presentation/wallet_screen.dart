import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/coming_soon_sheet.dart';
import '../../../core/widgets/w_widgets.dart';
import '../models/profile.dart';
import '../providers/account_pay_providers.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final walletAsync = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('wallet.title'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: walletAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => WEmptyState(
          icon: Icons.cloud_off,
          title: context.tr('wallet.loadFailed'),
          subtitle: '$e',
          actionLabel: context.tr('common.retry'),
          onAction: () => ref.invalidate(walletProvider),
        ),
        data: (wallet) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0B0E1A), Color(0xFF1F2B4D)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wallet.membership ?? context.tr('wallet.membershipFallback'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Palette.gold,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatMoney(wallet.balance),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.local_fire_department, size: 16, color: Palette.gold),
                      const SizedBox(width: 6),
                      Text(
                        '${wallet.points} ${context.tr('wallet.points')}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _walletAction(context, Icons.add, context.tr('wallet.addFunds'), () => ComingSoonSheet.show(
                    context,
                    title: context.tr('wallet.addFunds'),
                    description: context.tr('wallet.addFundsComingSoon'),
                    icon: Icons.add,
                  )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _walletAction(context, Icons.arrow_upward, context.tr('wallet.withdraw'), () => ComingSoonSheet.show(
                    context,
                    title: context.tr('wallet.withdraw'),
                    description: context.tr('wallet.withdrawComingSoon'),
                    icon: Icons.arrow_upward,
                  )),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(context.tr('wallet.paymentMethods'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ..._paymentMethods(context, ref),
            const SizedBox(height: 20),
            Text(context.tr('wallet.recentActivity'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text(
                context.tr('wallet.noTransactions'),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _paymentMethods(BuildContext context, WidgetRef ref) {
    return _paymentMethodTiles(context, _combinedPaymentMethods(context, ref));
  }

  List<PaymentMethod> _combinedPaymentMethods(BuildContext context, WidgetRef ref) {
    // Server-configured methods first (falls back to the app's defaults when
    // the provider has not loaded yet), then the device wallet methods that
    // only exist on the platform this app is running on.
    final existing = ref.watch(paymentMethodsProvider).value ?? PaymentMethod.defaults;
    final combined = <PaymentMethod>[...existing];
    if (Platform.isAndroid) {
      combined.removeWhere((m) => m.id == 'google_pay');
      combined.insert(0, PaymentMethod(
        id: 'google_pay',
        name: context.tr('wallet.googlePay'),
        description: context.tr('wallet.googlePayDescription'),
      ));
    }
    if (Platform.isIOS) {
      combined.removeWhere((m) => m.id == 'apple_pay');
      combined.insert(0, PaymentMethod(
        id: 'apple_pay',
        name: context.tr('wallet.applePay'),
        description: context.tr('wallet.applePayDescription'),
      ));
    }
    return combined;
  }

  List<Widget> _paymentMethodTiles(BuildContext context, List<PaymentMethod> methods) {
    final theme = Theme.of(context);
    return [
      for (final method in methods)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(
                method.mobileMoney ? Icons.phone_android_outlined : Icons.account_balance_outlined,
                color: Palette.gold,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(method.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    if (method.description != null)
                      Text(method.description!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const Icon(Icons.check_circle, size: 16, color: Color(0xFF22C55E)),
            ],
          ),
        ),
    ];
  }

  Widget _walletAction(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(icon, color: Palette.gold),
            const SizedBox(height: 6),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}