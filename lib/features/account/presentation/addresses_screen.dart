import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/coming_soon_sheet.dart';
import '../../../core/widgets/w_widgets.dart';
import '../data/account_repository.dart';
import '../models/profile.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final future = ref.watch(addressesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('addresses.title'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: future.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => WEmptyState(
          icon: Icons.cloud_off,
          title: context.tr('addresses.loadFailed'),
          subtitle: '${e}',
          actionLabel: context.tr('common.retry'),
          onAction: () => ref.invalidate(addressesProvider),
        ),
        data: (book) {
          if (book.addresses.isEmpty) {
            return WEmptyState(
              icon: Icons.location_on_outlined,
              title: context.tr('addresses.empty'),
              subtitle: context.tr('addresses.emptyHint'),
              actionLabel: context.tr('addresses.addAddress'),
              onAction: () => _comingSoon(context, context.tr('addresses.addAddress')),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final address in book.addresses)
                _AddressCard(
                  address: address,
                  onEdit: () => _comingSoon(context, context.tr('addresses.editAddressSheetTitle')),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _comingSoon(context, context.tr('addresses.addAddress')),
                icon: const Icon(Icons.add),
                label: Text(context.tr('addresses.addNewAddress')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _comingSoon(BuildContext context, String title) {
    ComingSoonSheet.show(context, title: title, description: context.tr('addresses.comingSoonTemplate', namedArgs: {'title': title}));
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address, required this.onEdit});

  final Address address;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      address.label ?? context.tr('common.address'),
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (address.isDefault) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.appColors.goldSoft,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          context.tr('common.defaultBadge'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: context.appColors.onGoldSoft,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (address.fullName != null) Text(address.fullName!, style: theme.textTheme.bodyMedium),
          if (address.phone != null)
            Text(address.phone!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(
            address.street ?? address.district ?? address.city ?? '',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

final addressesProvider = FutureProvider<AddressBook>((ref) {
  return ref.watch(accountRepositoryProvider).addresses();
});