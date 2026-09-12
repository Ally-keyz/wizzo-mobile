import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/i18n/localization_helpers.dart';
import '../../../core/widgets/w_async.dart';
import '../../../core/widgets/w_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/seller_repository.dart';
import '../providers/seller_providers.dart';

/// Become-a-seller wizard for an existing buyer account: stores logo + details,
/// then creates the store and force-refreshes the token to the seller role.
class CreateStoreScreen extends ConsumerStatefulWidget {
  const CreateStoreScreen({super.key});

  @override
  ConsumerState<CreateStoreScreen> createState() => _CreateStoreScreenState();
}

class _CreateStoreScreenState extends ConsumerState<CreateStoreScreen> {
  static const _stepCount = 4;

  final _storeName = TextEditingController();
  final _aboutStore = TextEditingController();
  final _country = TextEditingController();
  final _district = TextEditingController();
  final _city = TextEditingController();

  int _step = 0;
  bool _busy = false;
  bool _uploading = false;
  String? _logoUploadedUrl;
  String? _error;

  @override
  void dispose() {
    _storeName.dispose();
    _aboutStore.dispose();
    _country.dispose();
    _district.dispose();
    _city.dispose();
    super.dispose();
  }

  String? _validateCurrentStep() {
    switch (_step) {
      case 0:
        if (_storeName.text.trim().isEmpty) {
          return context.tr('seller.storeNameRequired');
        }
        return null;
      case 1:
        if (_country.text.trim().isEmpty) {
          return context.tr(
            'common.errors.isRequired',
            namedArgs: {'label': context.tr('seller.country')},
          );
        }
        return null;
      case 2:
        if (_district.text.trim().isEmpty) {
          return context.tr(
            'common.errors.isRequired',
            namedArgs: {'label': context.tr('seller.district')},
          );
        }
        if (_city.text.trim().isEmpty) {
          return context.tr(
            'common.errors.isRequired',
            namedArgs: {'label': context.tr('seller.city')},
          );
        }
        return null;
      default:
        return null;
    }
  }

  Future<void> _pickLogo() async {
    if (_uploading || _busy) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final url = await ref
          .read(sellerRepositoryProvider)
          .uploadImage(picked.path, folder: 'wizzo/stores');
      if (mounted) setState(() => _logoUploadedUrl = url);
    } catch (e) {
      if (mounted) {
        final localized = localizeException(context, e);
        setState(() => _error = localized);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(localized)));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _createStore() async {
    if (_busy) return;
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .registerStore(
            storeName: _storeName.text,
            aboutStore: _aboutStore.text,
            logoUrl: _logoUploadedUrl,
            country: _country.text,
            district: _district.text,
            city: _city.text,
          );
      if (!mounted) return;
      ref.invalidate(myStoreProvider);
      context.go('/seller');
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = localizeException(context, e);
          _busy = false;
        });
      }
    }
  }

  void _next() {
    final error = _validateCurrentStep();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _error = null;
      _step += 1;
    });
  }

  void _back() {
    if (_step > 0) {
      setState(() => _error = null);
      setState(() => _step -= 1);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = ref.watch(authControllerProvider).user;
    final isLast = _step == _stepCount - 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('seller.openStoreTitle')),
        leading: IconButton(
          onPressed: _back,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: WAppMark(size: 40)),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('seller.sellOnWizzo'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(
                      'seller.sellingAs',
                      namedArgs: {
                        'name': user?.fullName?.isNotEmpty == true
                            ? user!.fullName!
                            : context.tr('seller.you'),
                        'email': user?.email ?? '',
                      },
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_step == 0) ...[
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: scheme.secondaryContainer,
                            backgroundImage: _logoUploadedUrl != null
                                ? NetworkImage(_logoUploadedUrl!)
                                : null,
                            child: _logoUploadedUrl == null
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
                                child: _uploading
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
                          _logoUploadedUrl != null
                              ? context.tr('seller.changeLogo')
                              : context.tr('seller.addStoreLogoShort'),
                          style: TextStyle(color: scheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    WTextField(
                      controller: _storeName,
                      label: context.tr('seller.fieldStoreName'),
                      hint: context.tr('seller.storeNameHint'),
                      prefixIcon: Icons.store_outlined,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                    ),
                  ] else if (_step == 1) ...[
                    WTextField(
                      controller: _aboutStore,
                      label: context.tr('seller.fieldAboutStore'),
                      hint: context.tr('seller.aboutStoreHint'),
                      prefixIcon: Icons.notes_outlined,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    WTextField(
                      controller: _country,
                      label: context.tr('seller.country'),
                      hint: context.tr('seller.countryHint'),
                      prefixIcon: Icons.public,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                    ),
                  ] else if (_step == 2) ...[
                    WTextField(
                      controller: _district,
                      label: context.tr('seller.district'),
                      hint: context.tr('seller.districtHint'),
                      prefixIcon: Icons.place_outlined,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    WTextField(
                      controller: _city,
                      label: context.tr('seller.city'),
                      hint: context.tr('seller.cityHint'),
                      prefixIcon: Icons.location_city,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                    ),
                  ] else ...[
                    _StoreSummary(
                      storeName: _storeName.text,
                      about: _aboutStore.text,
                      country: _country.text,
                      district: _district.text,
                      city: _city.text,
                    ),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 18,
                            color: scheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _busy
                          ? null
                          : isLast
                          ? _createStore
                          : _next,
                      child: _busy
                          ? const WInlineLoader()
                          : Text(
                              isLast
                                  ? context.tr('seller.createStore')
                                  : context.tr('common.continue'),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  WStepBars(count: _stepCount, index: _step),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreSummary extends StatelessWidget {
  const _StoreSummary({
    required this.storeName,
    required this.about,
    required this.country,
    required this.district,
    required this.city,
  });

  final String storeName;
  final String about;
  final String country;
  final String district;
  final String city;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('seller.reviewStore'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _summaryRow(
            theme,
            scheme,
            context.tr('seller.fieldStoreName'),
            storeName,
          ),
          if (about.trim().isNotEmpty)
            _summaryRow(
              theme,
              scheme,
              context.tr('seller.aboutSummary'),
              about,
            ),
          _summaryRow(theme, scheme, context.tr('seller.country'), country),
          _summaryRow(theme, scheme, context.tr('seller.district'), district),
          _summaryRow(theme, scheme, context.tr('seller.city'), city),
        ],
      ),
    );
  }

  Widget _summaryRow(
    ThemeData theme,
    ColorScheme scheme,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
