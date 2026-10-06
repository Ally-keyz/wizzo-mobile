import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../core/currency/currencies.dart';
import '../../../core/currency/currency_controller.dart';
import '../../../core/currency/currency_service.dart';
import '../../../core/i18n/localization_helpers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/flag_icon.dart';
import '../../../core/widgets/w_async.dart';
import '../../../core/widgets/w_widgets.dart';
import '../../catalog/models/product.dart';
import '../../catalog/models/seller.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../data/seller_repository.dart';
import '../providers/seller_providers.dart';

/// Create / edit listing form. For edits, pass the existing [Product] through
/// the route `extra`.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _discountPrice = TextEditingController();
  final _stock = TextEditingController();
  final _brand = TextEditingController();
  final _size = TextEditingController();
  final _description = TextEditingController();

  /// Live "this is what gets stored" preview under the price fields.
  final _pricePreview = ValueNotifier<String?>(null);

  String? _categoryId;
  String? _subcategoryId;
  String? _categoryName;
  String? _subcategoryName;
  String _condition = 'new';
  String _priceCurrency = kBaseCurrency;
  DateTime? _discountEndsAt;
  final List<String> _sizeOptions = [];
  final List<ColorPhotoDraft> _colorPhotos = [];
  bool _uploadingColor = false;
  final List<String> _images = [];
  String? _video;
  bool _busy = false;

  bool get isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      // Existing listings already hold a base-RWF price, so the amount shown
      // while editing is RWF — pre-selecting the app display currency here
      // would silently re-convert an already-converted number on save.
      _priceCurrency = kBaseCurrency;
      _name.text = p.name;
      _price.text = p.isOnSale
          ? p.originalPrice!.toString()
          : p.price.toString();
      if (p.isOnSale) _discountPrice.text = p.price.toString();
      _stock.text = (p.stock ?? 0).toString();
      _brand.text = p.brand ?? '';
      _description.text = p.description ?? '';
      _condition = p.condition;
      _discountEndsAt = p.discountEndsAt;
      _categoryId = p.category?.id;
      _subcategoryId = p.subcategory?.id;
      _categoryName = p.category?.name?.trim().isNotEmpty == true
          ? p.category!.name
          : null;
      _subcategoryName = p.subcategory?.name?.trim().isNotEmpty == true
          ? p.subcategory!.name
          : null;
      _images.addAll(p.images);
      _sizeOptions.addAll(p.sizeOptions);
      for (final v in p.colorVariants) {
        _colorPhotos.add(ColorPhotoDraft(name: v.name, image: v.image));
      }
      if (p.video != null && p.video!.isNotEmpty) _video = p.video;
    } else {
      // A brand new listing should default to the currency the seller already
      // browses prices in, so the amount they type needs no mental conversion.
      final display = currencyController.value.code;
      _priceCurrency = isSupportedCurrency(display) ? display : kBaseCurrency;
    }
    _price.addListener(_refreshPricePreview);
    _discountPrice.addListener(_refreshPricePreview);
    _refreshPricePreview();
  }

  @override
  void dispose() {
    _price.removeListener(_refreshPricePreview);
    _discountPrice.removeListener(_refreshPricePreview);
    _pricePreview.dispose();
    _name.dispose();
    _price.dispose();
    _discountPrice.dispose();
    _stock.dispose();
    _brand.dispose();
    _size.dispose();
    _description.dispose();
    for (final c in _colorPhotos) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = 6 - _images.length;
    if (remaining <= 0) return;
    final picked = await ImagePicker().pickMultiImage(
      limit: remaining,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    if (picked.isEmpty) return;
    setState(() => _busy = true);
    try {
      final uploaded = <String>[];
      for (final image in picked) {
        final url = await ref
            .read(sellerRepositoryProvider)
            .uploadImage(image.path, folder: 'wizzo/products');
        uploaded.add(url);
      }
      if (mounted) setState(() => _images.addAll(uploaded));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizeException(context, e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickColorPhoto(int index) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _uploadingColor = true);
    try {
      final url = await ref
          .read(sellerRepositoryProvider)
          .uploadImage(picked.path, folder: 'wizzo/products');
      if (mounted) setState(() => _colorPhotos[index].image = url);
    } catch (e) {
      if (mounted) _toast(localizeException(context, e));
    } finally {
      if (mounted) setState(() => _uploadingColor = false);
    }
  }

  void _addColorPhoto() {
    setState(() => _colorPhotos.add(ColorPhotoDraft()));
  }

  void _removeColorPhoto(int index) {
    final draft = _colorPhotos.removeAt(index);
    draft.dispose();
    setState(() {});
  }

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      final controller = VideoPlayerController.file(File(picked.path));
      await controller.initialize();
      final duration = controller.value.duration;
      await controller.dispose();
      if (duration > const Duration(seconds: 60)) {
        _toast(context.tr('seller.videoTooLong'));
        return;
      }
      final url = await ref
          .read(sellerRepositoryProvider)
          .uploadVideo(picked.path, folder: 'wizzo/products/videos');
      if (mounted) setState(() => _video = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizeException(context, e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _pickCategory() {
    showModalBottomSheet<({CategoryNode top, CategoryNode? sub})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const FractionallySizedBox(
        heightFactor: 0.8,
        child: _CategoryPickerShell(),
      ),
    ).then((selection) {
      if (selection != null) {
        _applyCategory(selection.top, selection.sub);
      }
    });
  }

  void _applyCategory(CategoryNode? category, CategoryNode? subcategory) {
    if (category == null) return;
    setState(() {
      _categoryId = category.id.isNotEmpty ? category.id : category.slug;
      _categoryName = category.name;
      _subcategoryId = subcategory == null
          ? null
          : subcategory.id.isNotEmpty
          ? subcategory.id
          : subcategory.slug;
      _subcategoryName = subcategory?.name;
    });
  }

  void _addSize() {
    final value = _size.text.trim().toUpperCase();
    if (value.isEmpty || _sizeOptions.contains(value)) return;
    setState(() {
      _sizeOptions.add(value);
      _size.clear();
    });
  }

  void _pickPriceCurrency() {
    showModalBottomSheet<CurrencyDef>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const FractionallySizedBox(
        heightFactor: 0.8,
        child: _CurrencyPickerShell(),
      ),
    ).then((def) {
      if (def != null) _setPriceCurrency(def.code);
    });
  }

  /// Switching currency must not change what the listing is worth, so any
  /// amount already typed is re-expressed in the new currency rather than
  /// reinterpreted.
  void _setPriceCurrency(String next) {
    if (next == _priceCurrency) return;
    final rates = currencyController.value.rates;
    setState(() {
      _rebaseAmount(_price, _priceCurrency, next, rates);
      _rebaseAmount(_discountPrice, _priceCurrency, next, rates);
      _priceCurrency = next;
    });
    _refreshPricePreview();
  }

  void _refreshPricePreview() {
    final base = _basePriceOf(_price);
    _pricePreview.value = base == null || base <= 0
        ? null
        : formatFromBase(base, kBaseCurrency, currencyController.value.rates);
  }

  void _rebaseAmount(
    TextEditingController controller,
    String from,
    String to,
    Map<String, double>? rates,
  ) {
    final current = num.tryParse(controller.text.trim());
    if (current == null) return;
    final inBase = convertToBase(current, from, rates);
    controller.text = _plainAmount(
      convertFromBase(inBase, to, rates),
      currencyDef(to).decimals,
    );
  }

  /// Base-RWF figure the API will store for whatever is currently typed.
  num? _basePriceOf(TextEditingController controller) {
    final typed = num.tryParse(controller.text.trim());
    if (typed == null) return null;
    return convertToBase(
      typed,
      _priceCurrency,
      currencyController.value.rates,
    ).round();
  }

  /// Trims a converted amount for the text field: `25000`, `24.5`, `$0.00`.
  String _plainAmount(double value, int decimals) {
    if (decimals == 0) return value.round().toString();
    var text = value.toStringAsFixed(decimals);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return text;
  }

  String _priceExample() {
    final def = currencyDef(_priceCurrency);
    return _plainAmount(convertFromBase(25000, def.code, currencyController.value.rates), def.decimals);
  }

  bool _validate() {
    if (Validators.required(
          _name.text,
          context.tr('seller.fieldProductName'),
        ) !=
        null) {
      _toast(context.tr('seller.errorProductNameRequired'));
      return false;
    }
    if (_categoryId == null) {
      _toast(context.tr('seller.errorChooseCategory'));
      return false;
    }
    final price = num.tryParse(_price.text.trim());
    if (price == null || price <= 0) {
      _toast(context.tr('seller.errorValidPrice'));
      return false;
    }
    final basePrice = _basePriceOf(_price);
    if (basePrice == null || basePrice <= 0) {
      _toast(context.tr('seller.errorValidPrice'));
      return false;
    }
    final stock = int.tryParse(_stock.text.trim());
    if (stock == null || stock < 0) {
      _toast(context.tr('seller.errorValidStock'));
      return false;
    }
    if (_images.isEmpty) {
      _toast(context.tr('seller.errorPhotoRequired'));
      return false;
    }
    return true;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save({required bool draft}) async {
    if (_busy || !_validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final discount = num.tryParse(_discountPrice.text.trim());
    final baseDiscount = discount == null ? null : _basePriceOf(_discountPrice);
    final photos = _colorPhotos
        .where((c) => c.name.text.trim().isNotEmpty)
        .toList();
    final input = ProductInput(
      name: _name.text,
      categoryId: _categoryId!,
      subcategoryId: _subcategoryId,
      description: _description.text,
      price: _basePriceOf(_price)!,
      discountPrice: baseDiscount,
      discountEndsAt: discount != null && baseDiscount != null && baseDiscount > 0
          ? _discountEndsAt
          : null,
      stock: int.parse(_stock.text.trim()),
      images: _images,
      brand: _brand.text,
      condition: _condition,
      sizeOptions: _sizeOptions,
      colorOptions: photos.map((c) => c.name.text.trim()).toList(),
      colorVariants: photos
          .where((c) => c.image.isNotEmpty)
          .map((c) => ColorPhotoInput(name: c.name.text.trim(), image: c.image))
          .toList(),
      deliveryOptions: const [],
      tags: const [],
      video: _video,
    );
    try {
      final repo = ref.read(sellerRepositoryProvider);
      String newId;
      if (isEdit) {
        await repo.updateProduct(widget.product!.id, input);
        newId = widget.product!.id;
      } else {
        final created = await repo.createProduct(input);
        newId = created.id;
      }
      if (draft) {
        try {
          await repo.updateProductStatus(newId, 'draft');
        } catch (_) {}
      }
      if (mounted) {
        ref.invalidate(myProductsProvider);
        ref.invalidate(sellerStatsProvider);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  String? _error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(isEdit ? 'seller.editItem' : 'seller.addProduct'),
        ),
        actions: [
          if (isEdit)
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(context.tr('seller.deleteItemTitle')),
                          content: Text(
                            context.tr(
                              'seller.deleteItemBody',
                              namedArgs: {'name': widget.product!.name},
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(context.tr('common.cancel')),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: scheme.error,
                              ),
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(context.tr('common.delete')),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        try {
                          await ref
                              .read(sellerRepositoryProvider)
                              .deleteProduct(widget.product!.id);
                          if (mounted) {
                            ref.invalidate(myProductsProvider);
                            context.pop();
                          }
                        } catch (e) {
                          if (mounted) _toast(e.toString());
                        }
                      }
                    },
              child: Text(context.tr('common.delete')),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              // Photos
              Text(
                context.tr('seller.photos'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < _images.length; i++)
                    SizedBox(
                      width: 92,
                      height: 92,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              _images[i],
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: scheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          if (_images.length > 1)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Material(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  onTap: () =>
                                      setState(() => _images.removeAt(i)),
                                  borderRadius: BorderRadius.circular(20),
                                  child: const Padding(
                                    padding: EdgeInsets.all(3),
                                    child: Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (_images.length < 6)
                    InkWell(
                      onTap: _busy ? null : _pickImages,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: _busy
                            ? const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 22,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    context.tr('common.add'),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _section(theme, scheme, context.tr('seller.shortVideoSection')),
              const SizedBox(height: 8),
              if (_video != null && _video!.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.video_library_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr('seller.videoAttached'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      IconButton(
                        tooltip: context.tr('seller.removeVideo'),
                        onPressed: _busy
                            ? null
                            : () => setState(() => _video = null),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                )
              else
                InkWell(
                  onTap: _busy ? null : _pickVideo,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_busy)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else ...[
                          Icon(
                            Icons.videocam_outlined,
                            size: 22,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.tr('seller.attachShort'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              _section(theme, scheme, context.tr('seller.listing')),
              WTextField(
                controller: _name,
                label: context.tr('seller.fieldProductName'),
                hint: context.tr('seller.productNameHint'),
                prefixIcon: Icons.sell_outlined,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickCategory,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: context.tr('seller.category'),
                    prefixIcon: const Icon(Icons.category_outlined),
                    suffixIcon: const Icon(Icons.chevron_right),
                    border: const OutlineInputBorder(),
                  ),
                  child: Text(
                    _subcategoryName?.trim().isNotEmpty == true
                        ? _subcategoryName!
                        : _categoryName?.trim().isNotEmpty == true
                        ? _categoryName!
                        : context.tr('seller.chooseCategory'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _conditionSelector(theme, scheme),
              const SizedBox(height: 16),
              WTextField(
                controller: _brand,
                label: context.tr('seller.brand'),
                hint: context.tr('seller.brandHint'),
                prefixIcon: Icons.tag_outlined,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),
              _section(theme, scheme, context.tr('seller.pricingStock')),
              _priceCurrencyField(theme, scheme),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: WTextField(
                      controller: _price,
                      label: context.tr(
                        'seller.priceIn',
                        namedArgs: {'currency': _priceCurrency},
                      ),
                      hint: context.tr(
                        'seller.priceHintIn',
                        namedArgs: {'amount': _priceExample()},
                      ),
                      prefixIcon: Icons.attach_money,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: WTextField(
                      controller: _discountPrice,
                      label: context.tr(
                        'seller.salePriceIn',
                        namedArgs: {'currency': _priceCurrency},
                      ),
                      hint: context.tr('common.optional'),
                      prefixIcon: Icons.percent,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                    ),
                  ),
                ],
              ),
              ValueListenableBuilder<String?>(
                valueListenable: _pricePreview,
                builder: (context, stored, _) {
                  if (stored == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      context.tr(
                        'seller.priceStoredAs',
                        namedArgs: {'amount': stored},
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: WTextField(
                      controller: _stock,
                      label: context.tr('seller.stockQuantity'),
                      hint: context.tr('seller.stockHint'),
                      prefixIcon: Icons.inventory_2_outlined,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _discountEndsAt == null
                          ? () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now().add(
                                  const Duration(days: 30),
                                ),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365 * 2),
                                ),
                              );
                              if (picked != null && mounted) {
                                setState(() => _discountEndsAt = picked);
                              }
                            }
                          : () => setState(() => _discountEndsAt = null),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(
                        _discountEndsAt == null
                            ? context.tr('seller.dealEnds')
                            : context.tr(
                                'seller.untilDate',
                                namedArgs: {
                                  'date': formatDate(_discountEndsAt),
                                },
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _section(theme, scheme, context.tr('seller.variants')),
              WTextField(
                controller: _size,
                label: context.tr('seller.addSize'),
                hint: context.tr('seller.sizeHint'),
                prefixIcon: Icons.straighten_outlined,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                suffix: IconButton(
                  onPressed: _addSize,
                  icon: const Icon(Icons.add),
                ),
              ),
              if (_sizeOptions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final size in _sizeOptions)
                      InputChip(
                        label: Text(size),
                        onDeleted: () =>
                            setState(() => _sizeOptions.remove(size)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              _section(theme, scheme, context.tr('seller.colorPhotos')),
              Text(
                context.tr('seller.colorPhotosHint'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _uploadingColor ? null : _addColorPhoto,
                icon: const Icon(Icons.palette_outlined, size: 18),
                label: Text(context.tr('seller.addColor')),
              ),
              if (_colorPhotos.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    context.tr('seller.colorPhotosEmpty'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (var i = 0; i < _colorPhotos.length; i++) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: _uploadingColor ? null : () => _pickColorPhoto(i),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 64,
                        height: 64,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: scheme.outlineVariant),
                          color: scheme.surfaceContainerHighest,
                        ),
                        child: _uploadingColor
                            ? Padding(
                                padding: const EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.primary,
                                ),
                              )
                            : _colorPhotos[i].image.isEmpty
                                ? Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 22,
                                    color: scheme.onSurfaceVariant,
                                  )
                                : Image.network(
                                    _colorPhotos[i].image,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Icon(
                                      Icons.broken_image_outlined,
                                      size: 22,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _colorPhotos[i].name,
                        decoration: InputDecoration(
                          labelText: context.tr('seller.colorName'),
                          hintText: context.tr('seller.colorNameHint'),
                          prefixIcon: const Icon(Icons.colorize_outlined),
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _removeColorPhoto(i),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              WTextField(
                controller: _description,
                label: context.tr('product.description'),
                hint: context.tr('seller.descriptionHint'),
                prefixIcon: Icons.notes_outlined,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
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
              FilledButton.icon(
                onPressed: _busy ? null : () => _save(draft: false),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  context.tr(
                    isEdit ? 'common.saveChanges' : 'seller.publishItem',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () {
                        if (isEdit) {
                          _savedAsDraft = true;
                        }
                        _save(draft: true);
                      },
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
                child: Text(
                  context.tr(
                    _savedAsDraft ? 'seller.keepAsDraft' : 'seller.saveAsDraft',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _savedAsDraft = false;

  Widget _section(ThemeData theme, ColorScheme scheme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _priceCurrencyField(ThemeData theme, ColorScheme scheme) {
    final def = currencyDef(_priceCurrency);
    return InkWell(
      onTap: _pickPriceCurrency,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: context.tr('seller.currency'),
          prefixIcon: const Icon(Icons.payments_outlined),
          suffixIcon: const Icon(Icons.chevron_right),
          border: const OutlineInputBorder(),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                def.name,
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${def.code} · ${def.symbol}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conditionSelector(ThemeData theme, ColorScheme scheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Text(
            context.tr('seller.condition'),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          for (final option in ['new', 'used', 'refurbished']) ...[
            ChoiceChip(
              label: Text(_conditionLabel(option)),
              selected: _condition == option,
              onSelected: (_) => setState(() => _condition = option),
              showCheckmark: false,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  String _conditionLabel(String option) {
    return switch (option) {
      'new' => context.tr('seller.conditionNew'),
      'used' => context.tr('seller.conditionUsed'),
      'refurbished' => context.tr('seller.conditionRefurbished'),
      _ => option[0].toUpperCase() + option.substring(1),
    };
  }
}

/// Bottom-sheet category picker (top-level then optional subcategory).
class _CategoryPickerShell extends ConsumerStatefulWidget {
  const _CategoryPickerShell();

  @override
  ConsumerState<_CategoryPickerShell> createState() =>
      _CategoryPickerShellState();
}

class _CategoryPickerShellState extends ConsumerState<_CategoryPickerShell> {
  CategoryNode? _selected;
  List<CategoryNode>? _subs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final categoriesAsync = ref.watch(categoriesProvider);
    return WAsyncView(
      value: categoriesAsync,
      onRetry: () => ref.invalidate(categoriesProvider),
      builder: (context, categories) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                _subs != null
                    ? context.tr(
                        'seller.subcategoryTitle',
                        namedArgs: {'category': _selected!.name},
                      )
                    : context.tr('seller.chooseCategory'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final category in _subs ?? categories)
                    ListTile(
                      leading: Icon(
                        category.icon ?? Icons.category_outlined,
                        color: scheme.primary,
                      ),
                      title: Text(category.name),
                      trailing: category.children.isNotEmpty && _subs != null
                          ? const Icon(Icons.chevron_right, size: 18)
                          : null,
                      onTap: () {
                        if (_subs == null && category.children.isNotEmpty) {
                          setState(() {
                            _selected = category;
                            _subs = category.children;
                          });
                          return;
                        }
                        final sub = _subs == null ? null : category;
                        Navigator.of(
                          context,
                        ).pop((top: _selected ?? category, sub: sub));
                      },
                    ),
                  if (_subs != null) ...[
                    const Divider(height: 28),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _subs = null),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: Text(context.tr('seller.backToCategories')),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Bottom-sheet currency picker used when composing a listing price.
/// Returns the chosen [CurrencyDef], or null when dismissed.
class _CurrencyPickerShell extends StatefulWidget {
  const _CurrencyPickerShell();

  @override
  State<_CurrencyPickerShell> createState() => _CurrencyPickerShellState();
}

class _CurrencyPickerShellState extends State<_CurrencyPickerShell> {
  String _query = '';

  List<CurrencyDef> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return kCurrencies;
    return kCurrencies
        .where(
          (c) =>
              c.code.toLowerCase().contains(q) ||
              c.name.toLowerCase().contains(q) ||
              c.symbol.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ValueListenableBuilder<CurrencyState>(
      valueListenable: currencyController,
      builder: (context, state, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              context.tr('currency.title'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: context.tr('currency.searchHint'),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                for (final def in _filtered)
                  ListTile(
                    selected: def.code == state.code,
                    selectedTileColor: scheme.primaryContainer,
                    leading: def.code == state.code
                        ? Icon(Icons.check_circle, color: scheme.primary)
                        : FlagIcon(countryCode: def.flagCode, width: 24),
                    title: Text(
                      def.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(def.symbol),
                    trailing: Text(
                      formatFromBase(25000, def.code, state.rates),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(def),
                  ),
                if (_filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        context.tr('currency.noResults'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Draft state for one seller color photo row (name + uploaded image URL).
class ColorPhotoDraft {
  ColorPhotoDraft({String name = '', this.image = ''})
      : name = TextEditingController(text: name);

  final TextEditingController name;
  String image;

  void dispose() => name.dispose();
}
