import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/w_async.dart';
import '../../catalog/models/product.dart';
import '../data/seller_repository.dart';
import '../models/coupon.dart';
import '../providers/seller_providers.dart';

class PromotionsScreen extends ConsumerStatefulWidget {
  const PromotionsScreen({super.key});

  @override
  ConsumerState<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends ConsumerState<PromotionsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final couponsAsync = ref.watch(couponsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('seller.promotionsTitle')),
        actions: [
          IconButton(
            tooltip: context.tr('seller.newCoupon'),
            onPressed: () => _openForm(context, null),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: WAsyncView(
        value: couponsAsync,
        onRetry: () => ref.invalidate(couponsProvider),
        builder: (context, coupons) {
          if (coupons.isEmpty) {
            return _EmptyCoupons(onCreate: () => _openForm(context, null));
          }
          final sorted = [...coupons]
            ..sort((a, b) => b.timesUsed.compareTo(a.timesUsed));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              Text(
                '${coupons.length} active coupon${coupons.length == 1 ? '' : 's'}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              for (final coupon in sorted)
                _CouponCard(
                  coupon: coupon,
                  onEdit: () => _openForm(context, coupon),
                  onToggle: () => _toggle(coupon),
                  onDelete: () => _delete(coupon),
                ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => _openForm(context, null),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.tr('seller.newCoupon')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openForm(BuildContext context, Coupon? coupon) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.92,
        child: _CouponFormSheet(
          coupon: coupon,
          onSaved: () {
            ref.invalidate(couponsProvider);
          },
        ),
      ),
    );
  }

  Future<void> _toggle(Coupon coupon) async {
    try {
      await ref.read(sellerRepositoryProvider).updateCoupon(coupon.id, {
        'isActive': !coupon.isActive,
      });
      ref.invalidate(couponsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _delete(Coupon coupon) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('seller.deleteCouponTitle')),
        content: Text(
          context.tr(
            'seller.deleteCouponBody',
            namedArgs: {'code': coupon.code},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(sellerRepositoryProvider).deleteCoupon(coupon.id);
      ref.invalidate(couponsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({
    required this.coupon,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final Coupon coupon;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final off = coupon.isExpired || coupon.usedUp || !coupon.isActive;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainerLow,
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
                  child: coupon.productImage != null
                      ? Image.network(
                          coupon.productImage!,
                          cacheWidth: 48,
                          cacheHeight: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _iconBox(scheme),
                        )
                      : _iconBox(scheme),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coupon.code,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      coupon.valueLabel(context),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        coupon.productName ?? context.tr('seller.allItems'),
                        context.tr(
                          'seller.couponUsed',
                          namedArgs: {
                            'used':
                                '${coupon.timesUsed}${coupon.maxUses != null ? '/${coupon.maxUses}' : ''}',
                          },
                        ),
                        if (coupon.isExpired)
                          context.tr('seller.couponExpired'),
                        if (coupon.usedUp) context.tr('seller.couponUsedUp'),
                      ].join(' · '),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: coupon.isActive
                    ? context.tr('seller.deactivate')
                    : context.tr('common.active'),
                onPressed: onToggle,
                icon: Icon(
                  coupon.isActive ? Icons.toggle_on : Icons.toggle_off,
                  size: 28,
                  color: coupon.isActive && !off
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                icon: Icon(
                  Icons.more_vert,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(context.tr('common.edit')),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(context.tr('common.delete')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBox(ColorScheme scheme) {
    return Container(
      color: scheme.secondaryContainer,
      child: Icon(Icons.local_offer_outlined, size: 20, color: scheme.primary),
    );
  }
}

class _EmptyCoupons extends StatelessWidget {
  const _EmptyCoupons({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 44,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              context.tr('seller.emptyCouponsTitle'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('seller.emptyCouponsBody'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: Text(context.tr('seller.createCouponCTA')),
            ),
          ],
        ),
      ),
    );
  }
}

class _CouponFormSheet extends ConsumerStatefulWidget {
  const _CouponFormSheet({required this.coupon, required this.onSaved});

  final Coupon? coupon;
  final VoidCallback onSaved;

  @override
  ConsumerState<_CouponFormSheet> createState() => _CouponFormSheetState();
}

class _CouponFormSheetState extends ConsumerState<_CouponFormSheet> {
  final _code = TextEditingController();
  final _discountValue = TextEditingController();
  final _maxUses = TextEditingController();
  final _description = TextEditingController();

  String? _productId;
  DiscountType _type = DiscountType.percent;
  DateTime? _startsAt;
  DateTime? _expiresAt;
  bool _isActive = true;
  bool _busy = false;
  String? _error;

  bool get isEdit => widget.coupon != null;

  @override
  void initState() {
    super.initState();
    final c = widget.coupon;
    if (c != null) {
      _code.text = c.code;
      _discountValue.text = c.discountValue.toString();
      _maxUses.text = c.maxUses?.toString() ?? '';
      _description.text = c.description ?? '';
      _productId = c.productId;
      _type = c.discountType;
      _startsAt = c.startsAt;
      _expiresAt = c.expiresAt;
      _isActive = c.isActive;
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _discountValue.dispose();
    _maxUses.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = int.tryParse(_discountValue.text.trim());
    if (_productId == null) {
      setState(() => _error = context.tr('seller.errorChooseProduct'));
      return;
    }
    if (value == null || value < 1 || value > 10000) {
      setState(() => _error = context.tr('seller.errorDiscountRange'));
      return;
    }
    if (_type == DiscountType.percent && value > 100) {
      setState(() => _error = context.tr('seller.errorPercentOver100'));
      return;
    }
    if (_code.text.trim().isEmpty) {
      setState(() => _error = context.tr('seller.errorCodeRequired'));
      return;
    }
    if (_expiresAt != null &&
        _startsAt != null &&
        _expiresAt!.isBefore(_startsAt!)) {
      setState(() => _error = context.tr('seller.errorExpiryBeforeStart'));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(sellerRepositoryProvider);
      if (isEdit) {
        await repo.updateCoupon(widget.coupon!.id, {
          'discountValue': value,
          'maxUses': int.tryParse(_maxUses.text.trim()),
          'startsAt': _startsAt?.toIso8601String(),
          'expiresAt': _expiresAt?.toIso8601String(),
          'isActive': _isActive,
          if (_description.text.trim().isNotEmpty)
            'description': _description.text.trim(),
        });
      } else {
        await repo.createCoupon(
          CouponInput(
            productId: _productId!,
            code: _code.text,
            discountType: _type,
            discountValue: value,
            maxUses: int.tryParse(_maxUses.text.trim()),
            startsAt: _startsAt,
            expiresAt: _expiresAt,
            isActive: _isActive,
            description: _description.text,
          ),
        );
      }
      if (mounted) {
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                isEdit ? 'seller.couponUpdated' : 'seller.couponCreated',
              ),
            ),
          ),
        );
        Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final productsAsync = ref.watch(myProductsProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr(
                      isEdit ? 'seller.editCoupon' : 'seller.newCoupon',
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                WAsyncView(
                  value: productsAsync,
                  onRetry: () => ref.invalidate(myProductsProvider),
                  builder: (context, products) {
                    final options = products
                        .where(
                          (p) => p.status == 'active' || p.id == _productId,
                        )
                        .toList();
                    if (options.isEmpty) {
                      return _noProducts(theme, scheme);
                    }
                    return InkWell(
                      onTap: () => _pickProduct(options),
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: context.tr('seller.couponProductLabel'),
                          prefixIcon: const Icon(Icons.inventory_2_outlined),
                          suffixIcon: const Icon(Icons.chevron_right),
                          border: const OutlineInputBorder(),
                        ),
                        child: Text(
                          _productName(options),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _code,
                  enabled: !isEdit,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: context.tr('seller.couponCodeLabel'),
                    hintText: context.tr('seller.couponCodeHint'),
                    prefixIcon: const Icon(Icons.tag),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final type in DiscountType.values)
                      ChoiceChip(
                        label: Text(type.label(context)),
                        selected: _type == type,
                        onSelected: (_) => setState(() => _type = type),
                        showCheckmark: false,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _discountValue,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _type == DiscountType.percent
                        ? context.tr('seller.discountPercentLabel')
                        : context.tr('seller.discountAmountLabel'),
                    hintText: _type == DiscountType.percent
                        ? context.tr('seller.discountPercentHint')
                        : context.tr('seller.discountAmountHint'),
                    prefixIcon: const Icon(Icons.percent),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _dateField(
                        scheme,
                        context.tr('seller.starts'),
                        _startsAt,
                        () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _startsAt ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365 * 2),
                            ),
                          );
                          if (picked != null) {
                            setState(() => _startsAt = picked);
                          }
                        },
                        clear: _startsAt == null
                            ? null
                            : () => setState(() => _startsAt = null),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dateField(
                        scheme,
                        context.tr('seller.expires'),
                        _expiresAt,
                        () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate:
                                _expiresAt ??
                                DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365 * 2),
                            ),
                          );
                          if (picked != null) {
                            setState(() => _expiresAt = picked);
                          }
                        },
                        clear: _expiresAt == null
                            ? null
                            : () => setState(() => _expiresAt = null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _maxUses,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.tr('seller.maxRedemptions'),
                    hintText: context.tr('seller.maxRedemptionsHint'),
                    prefixIcon: const Icon(Icons.all_inclusive_outlined),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _description,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: context.tr('seller.descriptionOptional'),
                    prefixIcon: const Icon(Icons.notes_outlined),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr('common.active')),
                  subtitle: Text(context.tr('seller.inactiveCouponHint')),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
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
                FilledButton(
                  onPressed: _busy ? null : _save,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          context.tr(
                            isEdit
                                ? 'common.saveChanges'
                                : 'seller.createCoupon',
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

  String _productName(List<Product> options) {
    final match = options.where((p) => p.id == _productId).firstOrNull;
    return match?.name ?? context.tr('seller.chooseProduct');
  }

  void _pickProduct(List<Product> options) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final product in options)
              ListTile(
                leading: Icon(
                  Icons.inventory_2_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(formatMoney(product.price)),
                selected: product.id == _productId,
                onTap: () {
                  setState(() => _productId = product.id);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _noProducts(ThemeData theme, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 34,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('seller.couponsNeedProduct'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/seller/product/new');
            },
            child: Text(context.tr('seller.addProduct')),
          ),
        ],
      ),
    );
  }

  Widget _dateField(
    ColorScheme scheme,
    String label,
    DateTime? value,
    VoidCallback onTap, {
    VoidCallback? clear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event_outlined, size: 18),
          suffixIcon: clear != null
              ? IconButton(
                  onPressed: clear,
                  icon: const Icon(Icons.close, size: 16),
                )
              : null,
          border: const OutlineInputBorder(),
        ),
        child: Text(
          value == null
              ? context.tr('seller.notSet')
              : context.tr(
                  'seller.untilDate',
                  namedArgs: {'date': formatDate(value)},
                ),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: value == null ? scheme.onSurfaceVariant : null,
          ),
        ),
      ),
    );
  }
}
