import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/i18n/localization_helpers.dart';
import '../../../core/location/location_providers.dart';
import '../../../core/location/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/city_picker_sheet.dart';
import '../../../core/widgets/w_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/theme_provider.dart';
import '../data/account_repository.dart';
import '../models/profile.dart';

/// Keeps registration placeholders (`pending_…`, `deleted_…`) out of the
/// address form, and rejects obviously malformed numbers before the API does.
String _usablePhone(String? value) {
  final phone = (value ?? '').trim();
  return RegExp(r'^\+?[0-9\s-]{8,20}$').hasMatch(phone) ? phone : '';
}

/// Delivery address book.
///
/// When the account has no saved address yet, the screen automatically turns
/// the device's current location into the default delivery address. The
/// "add" and "edit" actions open a form with the fields the API requires, so
/// addresses can be saved instead of showing a "coming soon" sheet.
class AddressesScreen extends ConsumerStatefulWidget {
  const AddressesScreen({super.key});

  @override
  ConsumerState<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends ConsumerState<AddressesScreen> {
  bool _autoTried = false;
  bool _autoRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _ensureDefaultAddress(),
    );
  }

  /// Creates a default address from the device location when the account has
  /// none. Runs once per screen visit; failures fall back to the empty state
  /// with a manual "Add address" action.
  Future<void> _ensureDefaultAddress() async {
    if (_autoTried) return;
    _autoTried = true;

    AddressBook book;
    try {
      book = await ref.read(addressesProvider.future);
    } catch (_) {
      return; // The error view offers a retry.
    }
    if (!mounted || book.addresses.isNotEmpty) return;

    setState(() => _autoRunning = true);
    try {
      final result = await ref.read(locationServiceProvider).detect();
      final loc = result.location;
      if (!mounted) return;
      if (loc == null) {
        _showLocationFailure(result.failure);
        return;
      }

      final user = ref.read(authControllerProvider).user;
      final name = (user?.fullName ?? '').trim();
      final emailName = (user?.email ?? '').split('@').first.trim();
      final phone = _usablePhone(user?.phone);
      final body = <String, dynamic>{
        'label': context.tr('addresses.currentLocationLabel'),
        'fullName': name.length >= 2
            ? name
            : (emailName.length >= 2 ? emailName : 'Wizzo customer'),
        'country': loc.country.isNotEmpty
            ? loc.country
            : context.tr('checkout.countryDefault'),
        'city': loc.city.isNotEmpty ? loc.city : AppConfig.defaultCity,
        'street': '',
        'isDefault': true,
        'location': {'longitude': loc.longitude, 'latitude': loc.latitude},
      };
      if (phone.length >= 8) body['phone'] = phone;

      await ref.read(accountRepositoryProvider).addAddress(body);
      if (!mounted) return;
      if (loc.label.isNotEmpty) {
        await ref.read(lastCityProvider.notifier).setCity(loc.label);
      }
      if (!mounted) return;
      ref.invalidate(addressesProvider);
    } catch (e) {
      if (!mounted) return;
      _toast(
        context.tr(
          'addresses.saveFailed',
          namedArgs: {'error': localizeException(context, e)},
        ),
      );
    } finally {
      if (mounted) setState(() => _autoRunning = false);
    }
  }

  void _showLocationFailure(LocationFailure? failure) {
    final denied =
        failure == LocationFailure.denied ||
        failure == LocationFailure.deniedForever;
    final key = denied
        ? 'city.locationDenied'
        : failure == LocationFailure.serviceDisabled
        ? 'city.locationServiceOff'
        : 'city.locationUnavailable';
    _toast(context.tr(key));
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openAddForm() async {
    final saved = await showAddressForm(context);
    if (saved == true && mounted) ref.invalidate(addressesProvider);
  }

  Future<void> _openEditForm(Address address) async {
    final saved = await showAddressForm(context, address: address);
    if (saved == true && mounted) ref.invalidate(addressesProvider);
  }

  Future<void> _setDefault(Address address) async {
    try {
      await ref.read(accountRepositoryProvider).updateAddress(address.id, {
        'isDefault': true,
      });
      if (!mounted) return;
      ref.invalidate(addressesProvider);
      _toast(context.tr('addresses.defaultUpdated'));
    } catch (e) {
      if (!mounted) return;
      _toast(localizeException(context, e));
    }
  }

  Future<void> _delete(Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('addresses.deleteConfirmTitle')),
        content: Text(dialogContext.tr('addresses.deleteConfirmBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(accountRepositoryProvider).deleteAddress(address.id);
      if (!mounted) return;
      ref.invalidate(addressesProvider);
      _toast(context.tr('addresses.deleted'));
    } catch (e) {
      if (!mounted) return;
      _toast(localizeException(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final future = ref.watch(addressesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('addresses.title'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _openAddForm,
            tooltip: context.tr('addresses.addAddress'),
            icon: const Icon(Icons.add_location_alt_outlined),
          ),
        ],
      ),
      body: future.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => WEmptyState(
          icon: Icons.cloud_off,
          title: context.tr('addresses.loadFailed'),
          subtitle: '$e',
          actionLabel: context.tr('common.retry'),
          onAction: () => ref.invalidate(addressesProvider),
        ),
        data: (book) {
          if (book.addresses.isEmpty) {
            if (_autoRunning) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 14),
                    Text(
                      context.tr('addresses.detectingLocation'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }
            return WEmptyState(
              icon: Icons.location_on_outlined,
              title: context.tr('addresses.empty'),
              subtitle: context.tr('addresses.emptyHint'),
              actionLabel: context.tr('addresses.addAddress'),
              onAction: _openAddForm,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final address in book.addresses)
                _AddressCard(
                  address: address,
                  onEdit: () => _openEditForm(address),
                  onSetDefault: address.isDefault
                      ? null
                      : () => _setDefault(address),
                  onDelete: () => _delete(address),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _openAddForm,
                icon: const Icon(Icons.add),
                label: Text(context.tr('addresses.addNewAddress')),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _AddressAction { edit, setDefault, delete }

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    this.onSetDefault,
  });

  final Address address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onSetDefault;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = [
      address.street,
      address.city,
      address.country,
    ].where((e) => e != null && e.trim().isNotEmpty).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: address.isDefault
              ? Palette.gold
              : theme.colorScheme.outlineVariant,
          width: address.isDefault ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        address.label ?? context.tr('common.address'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (address.isDefault) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
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
              ),
              PopupMenuButton<_AddressAction>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (action) {
                  switch (action) {
                    case _AddressAction.edit:
                      onEdit();
                      break;
                    case _AddressAction.setDefault:
                      onSetDefault?.call();
                      break;
                    case _AddressAction.delete:
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _AddressAction.edit,
                    child: Text(context.tr('common.edit')),
                  ),
                  if (onSetDefault != null)
                    PopupMenuItem(
                      value: _AddressAction.setDefault,
                      child: Text(context.tr('addresses.setDefault')),
                    ),
                  PopupMenuItem(
                    value: _AddressAction.delete,
                    child: Text(
                      context.tr('common.delete'),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (address.fullName != null && address.fullName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(address.fullName!, style: theme.textTheme.bodyMedium),
            ),
          if (address.phone != null && address.phone!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                address.phone!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (line.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(line, style: theme.textTheme.bodySmall),
            ),
          ],
        ],
      ),
    );
  }
}

/// Opens the add/edit address form. Returns `true` when the server accepted
/// the change.
Future<bool?> showAddressForm(BuildContext context, {Address? address}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _AddressFormSheet(address: address),
  );
}

class _AddressFormSheet extends ConsumerStatefulWidget {
  const _AddressFormSheet({this.address});

  final Address? address;

  @override
  ConsumerState<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends ConsumerState<_AddressFormSheet> {
  final _label = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _country = TextEditingController();
  final _city = TextEditingController();
  final _street = TextEditingController();

  bool _saving = false;
  bool _locating = false;
  late bool _isDefault;
  double? _latitude;
  double? _longitude;

  bool get _editing => widget.address != null;

  @override
  void initState() {
    super.initState();
    final address = widget.address;
    final user = ref.read(authControllerProvider).user;
    // The city picker stores a "City, Country" label; split it so the form
    // still has separate city and country fields.
    final savedCity = ref.read(lastCityProvider);
    final parts = savedCity.split(',');
    final savedCityName = parts.first.trim();
    final savedCountry = parts.length > 1 ? parts[1].trim() : '';

    _label.text = address?.label ?? '';
    _name.text = address?.fullName ?? user?.fullName ?? '';
    _phone.text = _usablePhone(address?.phone ?? user?.phone);
    _country.text = address?.country?.isNotEmpty == true
        ? address!.country!
        : (savedCountry.isNotEmpty ? savedCountry : AppConfig.defaultCountry);
    _city.text = address?.city?.isNotEmpty == true
        ? address!.city!
        : (savedCityName.isNotEmpty ? savedCityName : AppConfig.defaultCity);
    _street.text = address?.street ?? '';
    final existing =
        ref.read(addressesProvider).value?.addresses ?? const <Address>[];
    _isDefault = address?.isDefault ?? existing.isEmpty;
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

  Future<void> _pickCity() async {
    final picked = await showCityPicker(context, _city.text);
    if (picked == null || !mounted) return;
    final parts = picked.split(',');
    setState(() {
      _city.text = parts.first.trim();
      if (parts.length > 1 && parts[1].trim().isNotEmpty) {
        _country.text = parts[1].trim();
      }
    });
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final result = await ref.read(locationServiceProvider).detect();
      if (!mounted) return;
      final loc = result.location;
      if (loc == null) {
        _showLocationFailure(result.failure);
        return;
      }
      setState(() {
        if (loc.city.isNotEmpty) _city.text = loc.city;
        if (loc.country.isNotEmpty) _country.text = loc.country;
        _latitude = loc.latitude;
        _longitude = loc.longitude;
        if (_label.text.trim().isEmpty) {
          _label.text = context.tr('addresses.currentLocationLabel');
        }
      });
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showLocationFailure(LocationFailure? failure) {
    final denied =
        failure == LocationFailure.denied ||
        failure == LocationFailure.deniedForever;
    final key = denied
        ? 'city.locationDenied'
        : failure == LocationFailure.serviceDisabled
        ? 'city.locationServiceOff'
        : 'city.locationUnavailable';
    _toast(context.tr(key));
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final label = _label.text.trim().isEmpty
        ? context.tr('checkout.addressDefaultLabel')
        : _label.text.trim();
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final country = _country.text.trim();
    final city = _city.text.trim();
    final street = _street.text.trim();

    if (name.length < 2 || city.isEmpty || country.isEmpty) {
      _toast(context.tr('addresses.requiredFields'));
      return;
    }
    if (phone.isNotEmpty && !RegExp(r'^\+?[0-9\s-]{8,20}$').hasMatch(phone)) {
      _toast(context.tr('common.errors.invalidPhone'));
      return;
    }

    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'label': label,
        'fullName': name,
        'phone': phone,
        'country': country,
        'city': city,
        'street': street,
        'isDefault': _isDefault,
        if (_latitude != null && _longitude != null)
          'location': {'longitude': _longitude, 'latitude': _latitude},
      };
      final repo = ref.read(accountRepositoryProvider);
      final editing = widget.address;
      if (editing == null) {
        await repo.addAddress(body);
      } else {
        await repo.updateAddress(editing.id, body);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _toast(
        context.tr(
          'addresses.saveFailed',
          namedArgs: {'error': localizeException(context, e)},
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(
                _editing
                    ? 'addresses.editAddressSheetTitle'
                    : 'addresses.addAddressSheetTitle',
              ),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('checkout.shippingHint'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            WTextField(
              controller: _label,
              label: context.tr('checkout.labelField'),
              hint: context.tr('checkout.labelHint'),
              textCapitalization: TextCapitalization.words,
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _locating ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location, size: 18),
                label: Text(
                  context.tr(
                    _locating
                        ? 'city.detectingLocation'
                        : 'city.useCurrentLocation',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isDefault,
              activeThumbColor: Palette.gold,
              onChanged: (value) => setState(() => _isDefault = value),
              title: Text(
                context.tr('addresses.setDefault'),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('checkout.saveAddress')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final addressesProvider = FutureProvider<AddressBook>((ref) {
  return ref.watch(accountRepositoryProvider).addresses();
});
