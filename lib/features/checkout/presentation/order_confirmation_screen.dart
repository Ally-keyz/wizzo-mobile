import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../data/checkout_repository.dart';
import '../models/checkout.dart';
import 'widgets/checkout_shared.dart';

/// Post-checkout screen (mirrors the web `OrderConfirmationScreen`): shows the
/// order reference, a success header, money totals, and one card per seller
/// with the pay-in details and an optional proof-submission flow.
class OrderConfirmationScreen extends ConsumerStatefulWidget {
  const OrderConfirmationScreen({super.key, this.summary});

  final PlacementSummary? summary;

  @override
  ConsumerState<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState
    extends ConsumerState<OrderConfirmationScreen> {
  final Map<String, SellerPaymentInfo> _paymentAccounts = {};
  final Set<String> _submittedAfterCheckout = {};

  PlacementSummary? get summary => widget.summary;

  @override
  void initState() {
    super.initState();
    _loadPaymentAccounts();
  }

  Future<void> _loadPaymentAccounts() async {
    final sellers = summary?.sellerOrders.map((o) => o.sellerUserId).toList();
    if (sellers == null || sellers.isEmpty) return;
    try {
      final infos = await ref
          .read(checkoutRepositoryProvider)
          .getSellersPaymentAccounts(sellers);
      if (!mounted) return;
      setState(() {
        for (final info in infos) {
          _paymentAccounts[info.sellerUserId] = info;
          if (info.sellerId != null && info.sellerId!.isNotEmpty) {
            _paymentAccounts[info.sellerId!] = info;
          }
        }
      });
    } catch (_) {
      // Cards fall back to a "no account listed" hint when offline.
    }
  }

  Future<void> _openProofSheet(SellerOrderReceipt order) async {
    final repo = ref.read(checkoutRepositoryProvider);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => _PaymentProofSheet(
        repo: repo,
        orderId: order.id,
        method: order.paymentMethod ?? PaymentKind.momo,
      ),
    );
    if (ok == true && mounted) {
      setState(() => _submittedAfterCheckout.add(order.sellerUserId));
    }
  }

  SellerPaymentAccount? _accountFor(SellerOrderReceipt order) {
    final info = _paymentAccounts[order.sellerUserId];
    if (info == null) return null;
    final method = order.paymentMethod ?? PaymentKind.momo;
    for (final account in info.paymentAccounts) {
      if (account.method == method) return account;
    }
    return null;
  }

  String? _storeNameFor(SellerOrderReceipt order) =>
      _paymentAccounts[order.sellerUserId]?.storeName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final s = summary;
    final orderId = s?.orderNumber ?? s?.orderId ?? '';

    final hasProofFor = s == null
        ? (String _) => false
        : (String sellerUserId) =>
              s.hasProofFor(sellerUserId) ||
              _submittedAfterCheckout.contains(sellerUserId);

    final itemsTotal = s == null
        ? null
        : (s.sellerOrders.isNotEmpty
              ? s.sellerOrders.fold<num>(0, (acc, o) => acc + o.subtotal)
              : s.total);
    final grandTotal = s?.grandTotal ?? s?.total;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('checkout.confirmationTitle'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (orderId.isNotEmpty)
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  orderId.toUpperCase().startsWith('WZ')
                      ? orderId.toUpperCase()
                      : 'WZ-${orderId.toUpperCase()}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.surface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Center(
              child: Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.successContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 52,
                  color: colors.success,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('checkout.orderPlaced'),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('checkout.orderPlacedHint'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            if (grandTotal != null) ...[
              const SizedBox(height: 12),
              Text(
                formatMoney(grandTotal),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Palette.gold,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (s?.deliveryAddress != null)
              Text(
                context.tr(
                  'checkout.deliveringTo',
                  namedArgs: {
                    'address': [
                      s!.deliveryAddress!.street,
                      s.deliveryAddress!.city,
                      s.deliveryAddress!.country,
                    ].where((e) => e != null && e.isNotEmpty).join(', '),
                  },
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 24),
            if (s != null && s.sellerOrders.isNotEmpty) ...[
              Row(
                children: [
                  Text(
                    context.tr('checkout.payments'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    context.tr(
                      'checkout.storeCount',
                      namedArgs: {'count': '${s.sellerOrders.length}'},
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final order in s.sellerOrders)
                _sellerCard(
                  context,
                  theme,
                  order,
                  hasProofFor(order.sellerUserId),
                ),
              const SizedBox(height: 16),
              SectionCard(
                title: context.tr('checkout.orderSummary'),
                child: Column(
                  children: [
                    if (itemsTotal != null)
                      CheckoutSummaryRow(
                        label: context.tr('checkout.itemsTotal'),
                        value: formatMoney(itemsTotal),
                      ),
                    CheckoutSummaryRow(
                      label: context.tr('checkout.orderTotalInclDelivery'),
                      value: formatMoney(grandTotal ?? itemsTotal ?? 0),
                      bold: true,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.go('/orders'),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: Text(context.tr('checkout.viewMyOrders')),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go('/home'),
                child: Text(context.tr('common.continueShopping')),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sellerCard(
    BuildContext context,
    ThemeData theme,
    SellerOrderReceipt order,
    bool hasProof,
  ) {
    final colors = context.appColors;
    final isCod = order.isCashOnDelivery;
    final method = order.paymentMethod ?? PaymentKind.momo;
    final methodLabel = PaymentOption.all
        .firstWhere(
          (o) => o.kind == method,
          orElse: () => PaymentOption.all.first,
        )
        .label;

    return SectionCard(
      title: _storeNameFor(order) ?? context.tr('common.seller'),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatMoney(order.subtotal),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Palette.gold,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            methodLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCod)
            PaymentInstructionsCard(
              method: PaymentKind.cashOnDelivery,
              amount: order.subtotal,
            )
          else if (method == PaymentKind.card)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.successContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_outlined, size: 18, color: colors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('checkout.cardPaid'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (hasProof)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.warningContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.hourglass_top, size: 18, color: colors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('checkout.proofPending'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            PaymentInstructionsCard(
              method: method,
              account: _accountFor(order),
              amount: order.subtotal,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openProofSheet(order),
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: Text(context.tr('checkout.submitProof')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottom sheet used to attach + submit payment proof for a SellerOrder —
/// mirrors the web `PaymentProofDialog`.
class _PaymentProofSheet extends StatefulWidget {
  const _PaymentProofSheet({
    required this.repo,
    required this.orderId,
    this.method = PaymentKind.momo,
  });

  final CheckoutRepository repo;
  final String orderId;
  final PaymentKind method;

  @override
  State<_PaymentProofSheet> createState() => _PaymentProofSheetState();
}

class _PaymentProofSheetState extends State<_PaymentProofSheet> {
  PaymentKind _method = PaymentKind.momo;
  final _referenceController = TextEditingController();
  final _picker = ImagePicker();
  XFile? _picked;
  String? _uploadedUrl;
  String? _uploadedName;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _method = widget.method;
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null || !mounted) return;
    setState(() {
      _picked = file;
      _uploadedUrl = null;
    });
  }

  Future<void> _submit() async {
    if (_picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('checkout.attachScreenshotFirst'))),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final url = _uploadedUrl ?? await widget.repo.uploadImage(_picked!.path);
      final name = _uploadedName ?? _picked!.name;
      await widget.repo.submitPaymentProof(
        orderId: widget.orderId,
        method: _method,
        transactionReference: _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
        proofUrl: url,
        proofName: name,
        proofType: 'image/jpeg',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'checkout.proofSubmitFailed',
              namedArgs: {'error': '$e'},
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined),
                const SizedBox(width: 8),
                Text(
                  context.tr('checkout.submitProofTitle'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('checkout.attachScreenshotHint'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('checkout.paymentMethod'),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final option in [PaymentKind.momo, PaymentKind.bank])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(
                          PaymentOption.all
                              .firstWhere((o) => o.kind == option)
                              .label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        selected: _method == option,
                        onSelected: (_) => setState(() => _method = option),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.tr('checkout.txReference'),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _referenceController,
              decoration: InputDecoration(
                hintText: context.tr('checkout.txReferenceHint'),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            if (_picked != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.image_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _picked!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      onPressed: _pickProof,
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: context.tr('common.pickAnotherFile'),
                    ),
                  ],
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _pickProof,
                icon: const Icon(Icons.attach_file_outlined, size: 18),
                label: Text(context.tr('checkout.attachScreenshot')),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('checkout.submitProofShort')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
