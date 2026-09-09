import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
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

  String? _categoryId;
  String? _subcategoryId;
  String? _categoryName;
  String? _subcategoryName;
  String _condition = 'new';
  DateTime? _discountEndsAt;
  final List<String> _sizeOptions = [];
  final List<String> _images = [];
  String? _video;
  bool _busy = false;

  bool get isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
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
      if (p.video != null && p.video!.isNotEmpty) _video = p.video;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _discountPrice.dispose();
    _stock.dispose();
    _brand.dispose();
    _size.dispose();
    _description.dispose();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
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
    final input = ProductInput(
      name: _name.text,
      categoryId: _categoryId!,
      subcategoryId: _subcategoryId,
      description: _description.text,
      price: num.parse(_price.text.trim()),
      discountPrice: discount,
      discountEndsAt: discount != null && discount > 0 ? _discountEndsAt : null,
      stock: int.parse(_stock.text.trim()),
      images: _images,
      brand: _brand.text,
      condition: _condition,
      sizeOptions: _sizeOptions,
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: WTextField(
                      controller: _price,
                      label: context.tr('seller.price'),
                      hint: context.tr('seller.priceHint'),
                      prefixIcon: Icons.currency_franc,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: WTextField(
                      controller: _discountPrice,
                      label: context.tr('seller.salePrice'),
                      hint: context.tr('common.optional'),
                      prefixIcon: Icons.percent,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                    ),
                  ),
                ],
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
