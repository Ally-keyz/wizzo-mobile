import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/city_picker_sheet.dart';
import '../../../../core/widgets/w_widgets.dart';
import '../../../account/models/profile.dart';
import '../../../settings/theme_provider.dart';
import '../../models/checkout.dart';
import 'checkout_shared.dart';

class ShippingStep extends ConsumerStatefulWidget {
  const ShippingStep({
    super.key,
    required this.addresses,
    required this.selectedAddressId,
    required this.creating,
    required this.delivery,
    required this.onSelectAddress,
    required this.onCreateAddress,
    required this.onDeliveryChanged,
  });

  final List<Address> addresses;
  final String? selectedAddressId;
  final bool creating;
  final DeliveryKind delivery;
  final ValueChanged<Address> onSelectAddress;
  final void Function(Address) onCreateAddress;
  final ValueChanged<DeliveryKind> onDeliveryChanged;

  @override
  ConsumerState<ShippingStep> createState() => _ShippingStepState();
}

class _ShippingStepState extends ConsumerState<ShippingStep> {
  final _label = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  late TextEditingController _country;
  final _city = TextEditingController();
  final _street = TextEditingController();
  bool _showForm = false;
  bool _countryReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_countryReady) return;
    // inherited-widget lookups (locale) are only legal after first
    // `didChangeDependencies`, not in initState/dispose.
    _countryReady = true;
    _country = TextEditingController(
      text: context.tr('checkout.countryDefault'),
    );
  }

  @override
  void dispose() {
    _label.dispose();
    _name.dispose();
    _phone.dispose();
    _country.dispose();
    _city.dispose();
    _street.dispose();
    super.dispose();
  }

  void _submit() {
    final label = _label.text.trim().isEmpty
        ? context.tr('checkout.addressDefaultLabel')
        : _label.text.trim();
    final fullName = _name.text.trim();
    final city = _city.text.trim();
    final street = _street.text.trim();
    final phone = _phone.text.trim();
    if (fullName.isEmpty || city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('checkout.recipientCityRequired'))),
      );
      return;
    }
    widget.onCreateAddress(
      Address(
        id: '',
        label: label,
        fullName: fullName,
        phone: phone.isEmpty ? null : phone,
        country: _country.text.trim().isEmpty
            ? context.tr('checkout.countryDefault')
            : _country.text.trim(),
        city: city,
        street: street.isEmpty ? null : street,
      ),
    );
  }

  Future<void> _pickCity() async {
    final picked = await showCityPicker(context, _city.text);
    if (picked != null && mounted) setState(() => _city.text = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = widget.addresses.isEmpty
        ? null
        : widget.addresses.firstWhere(
            (a) => a.id == widget.selectedAddressId,
            orElse: () => widget.addresses.first,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WPageTitle(
          context.tr('checkout.shippingTitle'),
          subtitle: context.tr('checkout.shippingHint'),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: context.tr('checkout.deliveryAddress'),
          trailing: TextButton.icon(
            onPressed: () => setState(() {
              _showForm = !_showForm;
              // Pre-fill the city from the city picked on the home screen.
              if (_showForm && _city.text.isEmpty) {
                final saved = ref.read(lastCityProvider);
                if (saved.isNotEmpty) _city.text = saved;
              }
            }),
            icon: const Icon(Icons.add_location_alt_outlined, size: 16),
            label: Text(
              _showForm
                  ? context.tr('common.cancel')
                  : context.tr('common.addNew'),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.addresses.isNotEmpty && !_showForm) ...[
                for (final address in widget.addresses)
                  _addressTile(theme, address, address.id == selected?.id),
              ] else if (_showForm)
                _addressForm(theme)
              else
                Text(
                  context.tr('checkout.noAddresses'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        SectionCard(
          title: context.tr('checkout.deliveryMethod'),
          child: Column(
            children: [
              for (final option in DeliveryOption.all)
                _deliveryTile(theme, option),
            ],
          ),
        ),
      ],
    );
  }

  Widget _addressTile(ThemeData theme, Address address, bool selected) {
    return InkWell(
      onTap: () => widget.onSelectAddress(address),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? context.appColors.goldSoft
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Palette.gold : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 20,
              color: selected
                  ? Palette.gold
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        address.label ?? context.tr('common.address'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (address.isDefault) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
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
                  const SizedBox(height: 2),
                  Text(
                    address.display,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? Palette.gold : theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _addressForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WTextField(
          controller: _label,
          label: context.tr('checkout.labelField'),
          hint: context.tr('checkout.labelHint'),
        ),
        const SizedBox(height: 12),
        WTextField(
          controller: _name,
          label: context.tr('checkout.fullName'),
          hint: context.tr('checkout.recipientNameHint'),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        WTextField(
          controller: _phone,
          label: context.tr('checkout.phoneField'),
          hint: context.tr('checkout.phoneHint'),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        WTextField(
          controller: _country,
          label: context.tr('checkout.countryField'),
          hint: context.tr('checkout.countryHint'),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        WTextField(
          controller: _city,
          label: context.tr('checkout.cityField'),
          hint: context.tr('checkout.cityHint'),
          textCapitalization: TextCapitalization.words,
          suffix: IconButton(
            icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
            tooltip: context.tr('checkout.pickCity'),
            onPressed: _pickCity,
          ),
        ),
        const SizedBox(height: 12),
        WTextField(
          controller: _street,
          label: context.tr('checkout.streetField'),
          hint: context.tr('checkout.streetHint'),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _submit,
          icon: widget.creating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check, size: 18),
          label: Text(
            widget.creating
                ? context.tr('checkout.saving')
                : context.tr('checkout.saveAddress'),
          ),
        ),
      ],
    );
  }

  Widget _deliveryTile(ThemeData theme, DeliveryOption option) {
    final selected = widget.delivery == option.id;
    return InkWell(
      onTap: () => widget.onDeliveryChanged(option.id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? context.appColors.goldSoft
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Palette.gold : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              switch (option.id) {
                DeliveryKind.standard => Icons.local_shipping_outlined,
                DeliveryKind.express => Icons.flash_on_outlined,
                DeliveryKind.pickup => Icons.storefront_outlined,
              },
              color: selected
                  ? context.appColors.onGoldSoft
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    option.timing,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              option.isFree
                  ? context.tr('checkout.freeDelivery')
                  : formatMoney(option.price),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: option.isFree
                    ? context.appColors.success
                    : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
