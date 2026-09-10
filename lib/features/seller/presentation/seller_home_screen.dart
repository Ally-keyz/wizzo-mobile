import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/w_async.dart';
import '../../../core/widgets/w_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/seller_order.dart';
import '../models/store.dart';
import '../providers/seller_providers.dart';
import 'seller_ui.dart';

/// '/seller' gate: sends guests to login, buyers to the become-a-seller pitch,
/// and sellers to their dashboard.
class SellerGateScreen extends ConsumerWidget {
  const SellerGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.isSignedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/login?ref=create-store');
      });
      return const Scaffold(body: Center(child: WInlineLoader()));
    }

    final storeAsync = ref.watch(myStoreProvider);
    if (auth.user?.isSeller != true &&
        storeAsync.hasValue &&
        storeAsync.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ref.read(authControllerProvider.notifier).syncRoleWithStore();
        }
      });
    }
    return WAsyncView(
      value: storeAsync,
      onRetry: () => ref.invalidate(myStoreProvider),
      builder: (context, store) {
        if (store == null) return const _BecomeSellerView();
        return SellerDashboard(store: store);
      },
    );
  }
}

/// Pre-filled "become a seller" pitch for signed-in buyers without a store.
class _BecomeSellerView extends ConsumerWidget {
  const _BecomeSellerView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = ref.watch(authControllerProvider).user;
    final perks = <(IconData, String)>[
      (Icons.stars_outlined, context.tr('seller.perk1')),
      (Icons.payments_outlined, context.tr('seller.perk2')),
      (Icons.insights_outlined, context.tr('seller.perk3')),
      (Icons.storefront_outlined, context.tr('seller.perk4')),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('seller.sellOnWizzo'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: WAppMark(size: 52)),
                  const SizedBox(height: 20),
                  Text(
                    context.tr('seller.becomeHeadline'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      'seller.sellingAs',
                      namedArgs: {
                        'name': user?.fullName ?? context.tr('seller.you'),
                        'email': user?.email ?? '',
                      },
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (final (icon, text) in perks) ...[
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, size: 20, color: scheme.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            text,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () => context.go('/seller/create-store'),
                      icon: const Icon(Icons.storefront_outlined),
                      label: Text(context.tr('seller.becomeSeller')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SellerDashboard extends ConsumerWidget {
  const SellerDashboard({super.key, required this.store});

  final MyStore store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statsAsync = ref.watch(sellerStatsProvider);

    final quickActions = <(IconData, String, String)>[
      (
        Icons.inventory_2_outlined,
        context.tr('seller.myItems'),
        '/seller/products',
      ),
      (
        Icons.add_box_outlined,
        context.tr('seller.addProduct'),
        '/seller/product/new',
      ),
      (
        Icons.receipt_long_outlined,
        context.tr('seller.ordersTitle'),
        '/seller/orders',
      ),
      (
        Icons.payments_outlined,
        context.tr('seller.earningsTitle'),
        '/seller/earnings',
      ),
      (
        Icons.settings_outlined,
        context.tr('seller.settingsTitle'),
        '/seller/settings',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('seller.sellerDashboard')),
        actions: [
          IconButton(
            tooltip: context.tr('seller.settingsTooltip'),
            onPressed: () => context.push('/seller/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myStoreProvider);
          ref.invalidate(sellerStatsProvider);
          ref.invalidate(sellerOrdersProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _StoreHeader(store: store),
            const SizedBox(height: 16),
            WAsyncView(
              value: statsAsync,
              onRetry: () => ref.invalidate(sellerStatsProvider),
              loading: const WSkeletonColumn(),
              builder: (context, stats) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NeedsActionBanner(
                      count: stats.needsAction,
                      onTap: () => context.push('/seller/orders'),
                    ),
                    const SizedBox(height: 12),
                    _statsCards(context, theme, scheme, stats),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            Text(
              context.tr('common.manage'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
              children: [
                for (final (icon, label, route) in quickActions)
                  _ActionCard(
                    icon: icon,
                    label: label,
                    onTap: () => context.push(route),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              context.tr('seller.recentOrders'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _RecentOrders(),
          ],
        ),
      ),
    );
  }

  Widget _statsCards(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    SellerStats stats,
  ) {
    Widget card(String label, String value, {Color? color, String? note}) {
      return Container(
        height: 92,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color ?? scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: color == null
              ? Border.all(color: scheme.outlineVariant)
              : null,
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
                color: color == null
                    ? null
                    : scheme.onPrimary.withValues(alpha: 0.9),
              ),
            ),
            if (note != null) ...[
              const SizedBox(height: 2),
              Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color == null
                      ? scheme.onSurfaceVariant
                      : scheme.onPrimary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: card(
                context.tr('seller.available'),
                formatMoneyCompact(stats.available),
                color: scheme.primary,
                note: context.tr('seller.availableForPayout'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: card(
                context.tr('seller.pending'),
                formatMoneyCompact(stats.pending),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: card(
                context.tr('seller.lifetime'),
                formatMoneyCompact(stats.lifetime),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.store});

  final MyStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Palette.gold, scheme.secondaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 58,
              height: 58,
              child: store.logoUrl != null
                  ? Image.network(
                      store.logoUrl!,
                      cacheWidth: 58,
                      cacheHeight: 58,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.transparent,
                      child: Center(
                        child: Icon(
                          Icons.storefront,
                          size: 30,
                          color: Colors.black.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        store.storeName,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (store.isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified,
                        size: 16,
                        color: Color(0xFF1D4ED8),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  store.locationLabel.isEmpty
                      ? context.tr('seller.noLocationSet')
                      : store.locationLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _stat(
                      context.tr('seller.itemsStat'),
                      store.productsCount ?? 0,
                    ),
                    const SizedBox(width: 14),
                    _stat(
                      context.tr('seller.followersStat'),
                      store.followersCount ?? 0,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, int value) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black.withValues(alpha: 0.75),
        ),
        children: [
          TextSpan(
            text: '$value ',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: label),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: scheme.primary),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentOrders extends ConsumerWidget {
  const _RecentOrders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ordersAsync = ref.watch(sellerOrdersProvider);
    return WAsyncView(
      value: ordersAsync,
      onRetry: () => ref.invalidate(sellerOrdersProvider),
      loading: const WSkeletonColumn(),
      builder: (context, orders) {
        final latest = orders.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final items = latest.take(3).toList();
        if (items.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 34,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr('seller.noOrdersYet'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('seller.noOrdersBody'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final order in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OrderRow(order: order),
              ),
            if (latest.length > 3)
              TextButton(
                onPressed: () => context.push('/seller/orders'),
                child: Text(context.tr('seller.viewAllOrders')),
              ),
          ],
        );
      },
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final SellerOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final first = order.items.isNotEmpty ? order.items.first : null;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => context.push('/seller/order/${order.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: first?.image != null
                      ? Image.network(
                          first!.image!,
                          cacheWidth: 48,
                          cacheHeight: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: scheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              size: 20,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : Container(
                          color: scheme.surfaceContainerHighest,
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            size: 20,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      first == null
                          ? order.items.length.toString()
                          : order.items.length > 1
                          ? '${first.name} ${context.tr('seller.moreItems', namedArgs: {'count': '${order.items.length - 1}'})}'
                          : first.name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    StatusBadge(status: order.status, dense: true),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatMoney(order.grandTotal),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable column of skeletons for the dashboard async sections.
class WSkeletonColumn extends StatelessWidget {
  const WSkeletonColumn({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const WSkeleton(width: double.infinity, height: 96, radius: 14),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: WSkeleton(width: double.infinity, height: 84, radius: 14),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: WSkeleton(width: double.infinity, height: 84, radius: 14),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: WSkeleton(width: double.infinity, height: 84, radius: 14),
            ),
          ],
        ),
      ],
    );
  }
}
