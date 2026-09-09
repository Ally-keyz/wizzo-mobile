import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/coming_soon_sheet.dart';
import '../providers/account_pay_providers.dart';

class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final methods = ref.watch(paymentMethodsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('account.paymentMethodsTitle'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: methods.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(context.tr('account.paymentMethodsLoadFailed'), style: theme.textTheme.bodyMedium),
          ),
        ),
        data: (list) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              context.tr('account.paymentMethodsHint'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            for (final method in list)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(
                      method.mobileMoney ? Icons.phone_android_outlined : Icons.account_balance_outlined,
                      color: Palette.gold,
                    ),
                    const SizedBox(width: 12),
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
                    const Icon(Icons.check_circle, size: 18, color: Color(0xFF22C55E)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => ComingSoonSheet.show(
                context,
                title: context.tr('account.addPaymentMethod'),
                description: context.tr('account.addPaymentMethodComingSoon'),
                icon: Icons.add_card,
              ),
              icon: const Icon(Icons.add),
              label: Text(context.tr('account.addPaymentMethod')),
            ),
          ],
        ),
      ),
    );
  }
}