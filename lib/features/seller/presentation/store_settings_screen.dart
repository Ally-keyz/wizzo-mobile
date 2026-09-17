import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/i18n/localization_helpers.dart';
import '../../../core/widgets/w_async.dart';
import '../../../core/widgets/w_widgets.dart';
import '../data/seller_repository.dart';
import '../models/store.dart';
import '../models/store_payout.dart';
import '../providers/seller_providers.dart';

class StoreSettingsScreen extends ConsumerStatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  ConsumerState<StoreSettingsScreen> createState() =>
      _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends ConsumerState<StoreSettingsScreen> {
  final _storeName = TextEditingController();
  final _aboutStore = TextEditingController();
  final _country = TextEditingController();
  final _district = TextEditingController();
  final _city = TextEditingController();
  final _payoutProvider = TextEditingController();
  final _payoutAccountName = TextEditingController();
  final _payoutAccountNumber = TextEditingController();

  SellerPayoutMethod _payoutMethod = SellerPayoutMethod.mobileMoney;
  String? _logoUrl;
  bool _uploadingLogo = false;
  bool _dirty = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _storeName.dispose();
    _aboutStore.dispose();
    _country.dispose();
    _district.dispose();
    _city.dispose();
    _payoutProvider.dispose();
    _payoutAccountName.dispose();
    _payoutAccountNumber.dispose();
    super.dispose();
  }

  void _hydrate(MyStore store) {
    _storeName.text = store.storeName;
    _aboutStore.text = store.aboutStore ?? '';
    _country.text = store.country ?? '';
    _district.text = store.district ?? '';
    _city.text = store.city ?? '';
    _logoUrl = store.logoUrl;
    _payoutMethod = store.payout?.method ?? SellerPayoutMethod.mobileMoney;
    _payoutProvider.text = store.payout?.provider ?? '';
    _payoutAccountName.text = store.payout?.accountName ?? '';
    _payoutAccountNumber.text = store.payout?.accountNumber ?? '';
  }

  void _markDirty() => setState(() => _dirty = true);

  Future<void> _pickLogo() async {
    if (_uploadingLogo) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() {
      _uploadingLogo = true;
      _error = null;
    });
    try {
      final url = await ref
          .read(sellerRepositoryProvider)
          .uploadImage(picked.path, folder: 'wizzo/stores');
      if (mounted) {
        setState(() {
          _logoUrl = url;
          _dirty = true;
        });
      }
    } catch (e) {
      if (mounted) {
        final localized = localizeException(context, e);
        setState(() => _error = localized);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(localized)));
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _save(MyStore store) async {
    if (_saving) return;
    if (_storeName.text.trim().isEmpty) {
      setState(() => _error = context.tr('seller.storeNameRequired'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
final body = <String, dynamic>{
      'storeName': _storeName.text.trim(),
      if (_aboutStore.text.trim().isNotEmpty)
        'aboutStore': _aboutStore.text.trim(),
      if (_logoUrl != null) 'logoUrl': _logoUrl,
      if (_country.text.trim().isNotEmpty) 'country': _country.text.trim(),
      if (_district.text.trim().isNotEmpty) 'district': _district.text.trim(),
      if (_city.text.trim().isNotEmpty) 'city': _city.text.trim(),
    };
    final hasPayout =
        _payoutAccountName.text.trim().isNotEmpty &&
        _payoutAccountNumber.text.trim().isNotEmpty;
    if (hasPayout) {
      body['payout'] = {
        'method': _payoutMethod.apiValue,
        if (_payoutProvider.text.trim().isNotEmpty)
          'provider': _payoutProvider.text.trim(),
        'accountName': _payoutAccountName.text.trim(),
        'accountNumber': _payoutAccountNumber.text.trim(),
      };
    }
    await ref.read(sellerRepositoryProvider).updateStore(store.id, body);
      if (mounted) {
        ref.invalidate(myStoreProvider);
        setState(() {
          _dirty = false;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('seller.settingsSaved'))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final storeAsync = ref.watch(myStoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('seller.settingsTitle')),
        actions: [
          TextButton(
            onPressed: () {
              final store = storeAsync.value;
              if (store != null && _dirty) _save(store);
            },
            child: Text(
              _saving ? context.tr('seller.saving') : context.tr('common.save'),
            ),
          ),
        ],
      ),
      body: WAsyncView(
        value: storeAsync,
        onRetry: () {
          ref.invalidate(myStoreProvider);
          setState(() {});
        },
        builder: (context, store) {
          if (store == null) {
            return Center(
              child: Text(
                context.tr('seller.createStorePrompt'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            );
          }
          if (!_hydratedOnce) {
            _hydratedOnce = true;
            _hydrate(store);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              if (store.verificationStatus == 'pending')
                _banner(
                  scheme,
                  Icons.gavel_outlined,
                  context.tr('seller.reviewPendingBanner'),
                )
              else if (store.verificationStatus == 'rejected')
                _banner(
                  scheme,
                  Icons.gpp_bad_outlined,
                  context.tr('seller.reviewRejectedBanner'),
                ),
              const SizedBox(height: 8),
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: scheme.secondaryContainer,
                      backgroundImage: _logoUrl != null
                          ? NetworkImage(_logoUrl!)
                          : null,
                      child: _logoUrl == null
                          ? Icon(
                              Icons.storefront_outlined,
                              size: 32,
                              color: scheme.primary,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _pickLogo,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: _uploadingLogo
                              ? const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  Icons.camera_alt_outlined,
                                  size: 16,
                                  color: scheme.onPrimary,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _pickLogo,
                  child: Text(
                    _logoUrl != null
                        ? context.tr('seller.changeStoreLogo')
                        : context.tr('seller.addStoreLogo'),
                    style: TextStyle(color: scheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              WTextField(
                controller: _storeName,
                label: context.tr('seller.fieldStoreName'),
                prefixIcon: Icons.store_outlined,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => _markDirty(),
              ),
              const SizedBox(height: 16),
              WTextField(
                controller: _aboutStore,
                label: context.tr('seller.fieldAboutStore'),
                prefixIcon: Icons.notes_outlined,
                maxLines: 4,
                onChanged: (_) => _markDirty(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: WTextField(
                      controller: _country,
                      label: context.tr('seller.country'),
                      prefixIcon: Icons.public,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => _markDirty(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: WTextField(
                      controller: _district,
                      label: context.tr('seller.district'),
                      prefixIcon: Icons.place_outlined,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => _markDirty(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              WTextField(
                controller: _city,
                label: context.tr('seller.city'),
                prefixIcon: Icons.location_city,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => _markDirty(),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr('seller.payout.title'),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('seller.payout.settingsSubtitle'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _methodChip(
                            scheme,
                            SellerPayoutMethod.mobileMoney,
                            Icons.phone_android,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _methodChip(
                            scheme,
                            SellerPayoutMethod.card,
                            Icons.credit_card,
                          ),
                        ),
                      ],
                    ),
                    if (_payoutMethod == SellerPayoutMethod.mobileMoney) ...[
                      const SizedBox(height: 16),
                      WTextField(
                        controller: _payoutProvider,
                        label: context.tr('seller.payout.provider'),
                        hint: context.tr('seller.payout.providerHint'),
                        prefixIcon: Icons.verified_user_outlined,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => _markDirty(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    WTextField(
                      controller: _payoutAccountName,
                      label: context.tr('seller.payout.accountName'),
                      hint: context.tr('seller.payout.accountNameHint'),
                      prefixIcon: Icons.person_outline,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => _markDirty(),
                    ),
                    const SizedBox(height: 16),
                    WTextField(
                      controller: _payoutAccountNumber,
                      label: context.tr('seller.payout.accountNumber'),
                      hint: context.tr('seller.payout.accountNumberHint'),
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      onChanged: (_) => _markDirty(),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => context.push('/seller/funds'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
                icon: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                ),
                label: Text(context.tr('seller.paymentAccounts')),
              ),
              const SizedBox(height: 10),
              Text(
                context.tr(
                  'seller.storeSlug',
                  namedArgs: {'slug': store.storeSlug},
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _hydratedOnce = false;

  Widget _methodChip(
    ColorScheme scheme,
    SellerPayoutMethod method,
    IconData icon,
  ) {
    final selected = _payoutMethod == method;
    return InkWell(
      onTap: () => setState(() {
        _payoutMethod = method;
        _dirty = true;
      }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surface,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 6),
            Text(
              method.label(context),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _banner(ColorScheme scheme, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: scheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
