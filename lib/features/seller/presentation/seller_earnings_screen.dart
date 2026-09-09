import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/w_async.dart';
import '../models/seller_order.dart';
import '../providers/seller_providers.dart';
import 'seller_ui.dart';

class SellerEarningsScreen extends ConsumerWidget {
  const SellerEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statsAsync = ref.watch(sellerStatsProvider);
    final ordersAsync = ref.watch(sellerOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('seller.earningsTitle'))),
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(sellerStatsProvider);
          ref.invalidate(sellerOrdersProvider);
          return Future.value();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            WAsyncView(
              value: statsAsync,
              onRetry: () => ref.invalidate(sellerStatsProvider),
              loading: const _EarningsSkeleton(),
              builder: (context, stats) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _heroCard(context, theme, scheme, stats.available),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          theme,
                          scheme,
                          context.tr('seller.pending'),
                          formatMoneyCompact(stats.pending),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _statCard(
                          theme,
                          scheme,
                          context.tr('seller.lifetime'),
                          formatMoneyCompact(stats.lifetime),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          theme,
                          scheme,
                          context.tr('seller.avgOrder'),
                          formatMoneyCompact(stats.aov),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.appColors.infoContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: context.appColors.onInfoContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr('seller.getPaidNote'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.appColors.onInfoContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/seller/funds'),
              icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
              label: Text(context.tr('seller.managePaymentAccounts')),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
            ),
            const SizedBox(height: 22),
            Text(
              context.tr('seller.ordersProgress'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            WAsyncView(
              value: ordersAsync,
              onRetry: () => ref.invalidate(sellerOrdersProvider),
              loading: const WSkeleton(
                width: double.infinity,
                height: 120,
                radius: 14,
              ),
              builder: (context, orders) {
                final byStatus = <String, int>{};
                for (final o in orders) {
                  if (o.status == SellerOrderStatus.cancelled) continue;
                  byStatus[o.status] = (byStatus[o.status] ?? 0) + 1;
                }
                if (byStatus.isEmpty) {
                  return _emptyRow(
                    theme,
                    scheme,
                    context.tr('seller.noSettledOrders'),
                  );
                }
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      for (final entry
                          in SellerOrderStatus.all
                              .where(byStatus.containsKey)
                              .map((s) => (s, byStatus[s]!)))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: statusColor(entry.$1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  SellerOrderStatus.label(context, entry.$1),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              Text(
                                '${entry.$2}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroCard(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    num available,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Palette.gold, Color(0xFFFFE95C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('seller.availableBalance'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatMoney(available),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('seller.availableForPayout'),
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    ThemeData theme,
    ColorScheme scheme,
    String label,
    String value,
  ) {
    return Container(
      height: 92,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyRow(ThemeData theme, ColorScheme scheme, String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            Icons.insights_outlined,
            size: 34,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsSkeleton extends StatelessWidget {
  const _EarningsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const WSkeleton(width: double.infinity, height: 150, radius: 18),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(
              child: WSkeleton(width: double.infinity, height: 84, radius: 14),
            ),
            SizedBox(width: 10),
            Expanded(
              child: WSkeleton(width: double.infinity, height: 84, radius: 14),
            ),
            SizedBox(width: 10),
            Expanded(
              child: WSkeleton(width: double.infinity, height: 84, radius: 14),
            ),
          ],
        ),
      ],
    );
  }
}
