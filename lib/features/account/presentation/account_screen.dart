import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/currency/currency_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/coming_soon_sheet.dart';
import '../../auth/models/user.dart';
import '../../auth/providers/auth_provider.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('account.title'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              icon: const Icon(Icons.menu),
            ),
          ),
        ],
      ),
      endDrawer: _AccountDrawer(user: user),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _profileHeader(context, ref, user),
          const SizedBox(height: 18),
          _statsRow(context, ref),
          const SizedBox(height: 22),
          _menuGroup(
            context,
            items: [
              _MenuItem(
                Icons.receipt_long_outlined,
                context.tr('account.myOrders'),
                () => context.push('/orders'),
                trailing: context.tr('orders.viewAll'),
              ),
              _MenuItem(
                Icons.favorite_outline,
                context.tr('account.myWishlist'),
                () => context.push('/wishlist'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _sellingSection(context),
          const SizedBox(height: 22),
          _menuGroup(
            context,
            title: context.tr('account.paymentsDelivery'),
            items: [
              _MenuItem(
                Icons.location_on_outlined,
                context.tr('account.deliveryAddress'),
                () => context.push('/addresses'),
              ),
              _MenuItem(
                Icons.account_balance_wallet_outlined,
                context.tr('account.paymentMethods'),
                () => context.push('/payment-methods'),
              ),
              _MenuItem(
                Icons.savings_outlined,
                context.tr('account.wallet'),
                () => context.push('/wallet'),
              ),
              _MenuItem(
                Icons.rate_review_outlined,
                context.tr('account.myReviews'),
                () => context.push('/reviews'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _menuGroup(
            context,
            title: context.tr('account.more'),
            items: [
              _MenuItem(
                Icons.help_outline,
                context.tr('account.helpCenter'),
                () => context.push('/help'),
              ),
              _MenuItem(
                Icons.language_outlined,
                context.tr('account.language'),
                () => context.push('/language'),
              ),
              _MenuItem(
                Icons.currency_exchange_outlined,
                context.tr('account.currency'),
                () => context.push('/currency'),
                trailing: currencyController.value.code,
              ),
              _MenuItem(
                Icons.brightness_medium_outlined,
                context.tr('account.appearance'),
                () => context.push('/appearance'),
              ),
              _MenuItem(
                Icons.info_outline,
                context.tr('account.aboutMarket'),
                () => context.push('/about'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _deluxeBanner(context),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout, size: 18),
            label: Text(context.tr('common.logOut')),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(
                color: theme.colorScheme.error.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileHeader(BuildContext context, WidgetRef ref, User? user) {
    final theme = Theme.of(context);
    final name = user?.fullName ?? context.tr('account.guest');
    final email = user?.email ?? context.tr('account.signInPrompt');
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Palette.gold,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Text(
            user?.shortName ?? 'W',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => context.push('/edit-profile'),
          icon: const Icon(Icons.edit_outlined, size: 20),
        ),
      ],
    );
  }

  Widget _statsRow(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = [
      (context.tr('account.myItems'), '0', () => context.go('/seller')),
      (
        context.tr('account.favourites'),
        '0',
        () => ComingSoonSheet.show(
          context,
          title: context.tr('account.favourites'),
          description: context.tr('account.favouritesComingSoon'),
          icon: Icons.favorite_outline,
        ),
      ),
      (
        context.tr('account.following'),
        '0',
        () => ComingSoonSheet.show(
          context,
          title: context.tr('account.following'),
          description: context.tr('account.followingComingSoon'),
          icon: Icons.people_outline,
        ),
      ),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 34,
                color: theme.colorScheme.outlineVariant,
              ),
            Expanded(
              child: InkWell(
                onTap: stats[i].$3,
                child: Column(
                  children: [
                    Text(
                      stats[i].$2,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Palette.gold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stats[i].$1,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sellingSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr('account.sellingTools'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.appColors.goldSoft),
          ),
          child: _menuGroup(
            context,
            items: [
              _MenuItem(
                Icons.inventory_2_outlined,
                context.tr('account.myItems'),
                () => context.go('/seller'),
              ),
              _MenuItem(
                Icons.storefront_outlined,
                context.tr('account.mySelling'),
                () => context.go('/seller'),
              ),
              _MenuItem(
                Icons.dashboard_outlined,
                context.tr('account.sellerDashboard'),
                () => context.go('/seller'),
              ),
              _MenuItem(
                Icons.account_balance_wallet_outlined,
                context.tr('account.sellerFunds'),
                () => context.go('/seller'),
              ),
              _MenuItem(
                Icons.campaign_outlined,
                context.tr('account.promotions'),
                () => context.go('/seller'),
              ),
              _MenuItem(
                Icons.receipt_outlined,
                context.tr('account.billingTax'),
                () => _locked(context, context.tr('account.billingTax')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _locked(BuildContext context, String title) {
    ComingSoonSheet.show(
      context,
      title: title,
      description: context.tr(
        'account.sellerLockedTemplate',
        namedArgs: {'title': title},
      ),
      icon: Icons.storefront_outlined,
    );
  }

  Widget _menuGroup(
    BuildContext context, {
    String? title,
    required List<_MenuItem> items,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 52,
                    color: theme.colorScheme.outlineVariant,
                  ),
                InkWell(
                  onTap: items[i].onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          items[i].icon,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            items[i].label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (items[i].trailing != null)
                          Text(
                            items[i].trailing!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _deluxeBanner(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => ComingSoonSheet.show(
        context,
        title: context.tr('account.deluxeTitle'),
        description: context.tr('account.deluxeComingSoon'),
        icon: Icons.workspace_premium_outlined,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Palette.gold,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.workspace_premium_outlined,
              color: Colors.black,
              size: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('account.buyDeluxe'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    context.tr('account.deluxeBenefits'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 16),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem(this.icon, this.label, this.onTap, {this.trailing});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailing;
}

class _AccountDrawer extends ConsumerWidget {
  const _AccountDrawer({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Drawer(
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: ListView(
          children: [
            Container(
              color: theme.colorScheme.surface,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(
                            'account.hiThere',
                            namedArgs: {
                              'name':
                                  user?.fullName?.split(' ').first ??
                                  context.tr('account.guest'),
                            },
                          ),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(),
            _drawerItem(
              context,
              Icons.notifications_outlined,
              context.tr('account.notificationSettings'),
              () {
                Navigator.pop(context);
                context.push('/notification-settings');
              },
            ),
            _drawerItem(
              context,
              Icons.alternate_email_outlined,
              context.tr('account.changeEmail'),
              () {
                Navigator.pop(context);
                context.push('/change-email');
              },
            ),
            _drawerItem(
              context,
              Icons.lock_outline,
              context.tr('account.changePassword'),
              () {
                Navigator.pop(context);
                context.push('/change-password');
              },
            ),
            const Divider(),
            _drawerItem(
              context,
              Icons.logout,
              context.tr('common.logOut'),
              () async {
                Navigator.pop(context);
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
              color: theme.colorScheme.error,
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: color ?? theme.colorScheme.onSurfaceVariant),
      title: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(color: color),
      ),
      onTap: onTap,
    );
  }
}
