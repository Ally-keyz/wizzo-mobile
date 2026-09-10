import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/w_widgets.dart';
import '../../account/data/account_repository.dart';
import '../../account/models/profile.dart';
import '../../account/presentation/addresses_screen.dart';
import '../../cart/models/cart.dart';
import '../../cart/providers/cart_provider.dart';
import '../data/checkout_repository.dart';
import '../models/checkout.dart';
import 'widgets/checkout_payment_step.dart';
import 'widgets/checkout_shared.dart';
import 'widgets/checkout_shipping_step.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  List<String> _stepLabels(BuildContext context) => [
        context.tr('checkout.stepCart'),
        context.tr('checkout.stepShipping'),
        context.tr('checkout.stepPayment'),
      ];

  int _step = 0;
  bool _creating = false;
  bool _placing = false;
  bool _termsAccepted = false;
  String? _selectedAddressId;
  DeliveryKind _delivery = DeliveryKind.standard;
  final Map<String, PaymentKind> _methods = {};
  final Map<String, PaymentProof> _proofs = {};
  final Map<String, SellerPaymentInfo> _paymentAccounts = {};
  String _momoPhone = '';
  String? _googlePayToken;
  Set<String> _loadedAccountIds = const {};
  String? _error;
  final _couponController = TextEditingController();
  final _picker = ImagePicker();
  Coupon? _coupon;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  void _maybeLoadPaymentAccounts(CartData cart) {
    final ids = cart.groups
        .map((g) => g.sellerId)
        .where((id) => id.isNotEmpty)
        .toSet();
    if (_loadedAccountIds.length == ids.length &&
        _loadedAccountIds.containsAll(ids)) {
      return;
    }
    _loadedAccountIds = ids;
    ref
        .read(checkoutRepositoryProvider)
        .getSellersPaymentAccounts(ids.toList())
        .then((infos) {
      if (!mounted) return;
      final map = <String, SellerPaymentInfo>{};
      for (final info in infos) {
        map[info.sellerUserId] = info;
        if (info.sellerId != null && info.sellerId!.isNotEmpty) {
          map[info.sellerId!] = info;
        }
      }
      setState(() {
        _paymentAccounts
          ..clear()
          ..addAll(map);
      });
    }).catchError((_) {});
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;
    final cart = ref.read(cartProvider).value;
    final lines = [
      for (final g in cart?.groups ?? const <CartSellerGroup>[])
        for (final item in g.items)
          {
            'productId': item.product.id,
            'price': item.product.price,
            'quantity': item.quantity,
          },
    ];
    try {
      final coupon = await ref
          .read(checkoutRepositoryProvider)
          .validateCoupon(code, lines: lines);
      if (mounted) {
        setState(() => _coupon = coupon);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.tr('checkout.couponApplied',
                  namedArgs: {'code': coupon.code}))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _coupon = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.tr('checkout.invalidCoupon',
                  namedArgs: {'error': '$e'}))),
        );
      }
    }
  }

  Future<void> _createAddress(Address draft) async {
    setState(() => _creating = true);
    try {
      final id = await ref.read(accountRepositoryProvider).addAddress({
        'label': draft.label,
        'fullName': draft.fullName,
        'phone': draft.phone,
        'country': draft.country,
        'city': draft.city,
        'street': draft.street,
      });
      if (id.isEmpty) throw Exception('The server did not return an address id');
      ref.invalidate(addressesProvider);
      if (mounted) {
        setState(() {
          _selectedAddressId = id;
          _creating = false;
        });
        _goNext();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.tr('addresses.saveFailed',
                  namedArgs: {'error': '$e'}))),
        );
      }
    }
  }

  Future<void> _uploadProof(String sellerId) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(context.tr('common.gallery')),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(context.tr('common.takePhoto')),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final XFile? picked;
    try {
      picked = await _picker.pickImage(source: source, imageQuality: 80);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.tr('common.cameraFailed',
                  namedArgs: {'error': '$e'}))),
        );
      }
      return;
    }
    if (picked == null || !mounted) return;
    final file = picked;

    try {
      final url =
          await ref.read(checkoutRepositoryProvider).uploadImage(file.path);
      if (mounted) {
        final method = _methods[sellerId] ?? PaymentKind.momo;
        setState(() {
          _proofs[sellerId] = PaymentProof(
            method: method,
            proofUrl: url,
            proofName: file.name,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.tr('common.uploadFailed',
                  namedArgs: {'error': '$e'}))),
        );
      }
    }
  }

  void _goNext() {
    setState(() {
      _step = (_step + 1).clamp(0, _stepLabels(context).length - 1);
      _error = null;
    });
  }

  void _goBack() {
    setState(() {
      _step = (_step - 1).clamp(0, _stepLabels(context).length - 1);
      _error = null;
    });
  }

  bool _validate(CartData cart, AddressBook book) {
    switch (_step) {
      case 0:
        if (cart.groups.isEmpty) return false;
        return true;
      case 1:
        if (_creating) return false;
        final effective = _effectiveAddress(book);
        if (effective == null) {
          _showError(context.tr('checkout.selectAddress'));
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  String? _effectiveAddressId(AddressBook book) {
    if (_selectedAddressId != null) return _selectedAddressId;
    return book.addresses.isNotEmpty ? book.addresses.first.id : null;
  }

  Address? _effectiveAddress(AddressBook book) {
    final id = _effectiveAddressId(book);
    if (id == null) return null;
    return book.addresses
        .firstWhere((a) => a.id == id, orElse: () => book.addresses.first);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  num _discountFor(CartData cart) => _coupon?.applyTo(cart.subtotal) ?? 0;

  num _deliveryFee() =>
      DeliveryOption.all.firstWhere((o) => o.id == _delivery).price;

  Future<void> _placeOrder(CartData cart) async {
    final address = _effectiveAddress(
        ref.read(addressesProvider).value ?? AddressBook());
    if (address == null) {
      _showError(context.tr('checkout.selectAddressFirst'));
      return;
    }
    if (!_termsAccepted) {
      _showError(context.tr('checkout.acceptTerms'));
      return;
    }

    final firstMethod = _methods.values.firstOrNull ?? PaymentKind.momo;
    final isGooglePay = firstMethod == PaymentKind.googlePay;
    final isMomo = firstMethod == PaymentKind.momo;

    if (isGooglePay && _googlePayToken == null) {
      _showError('Tap the Google Pay button to authorize payment');
      return;
    }

    if (isMomo && _momoPhone.trim().length < 9) {
      _showError('Enter a valid MoMo phone number');
      return;
    }

    setState(() {
      _placing = true;
      _error = null;
    });
    try {
      final deliveryOption = _delivery.apiValue;
      final couponCode = _coupon?.code;

      final selection = [
        for (final g in cart.groups)
          {
            'sellerId': g.sellerId,
            'paymentMethod':
                (_methods[g.sellerId] ?? PaymentKind.momo).apiValue,
            if (_proofs[g.sellerId] != null)
              'proof': _proofs[g.sellerId]!.toApi(),
          },
      ];

      final onlineMethod = (isGooglePay || isMomo)
          ? firstMethod.apiValue
          : null;
      final Map<String, dynamic>? paymentDetails = isGooglePay
          ? {
              if (_googlePayToken != null) 'walletToken': _googlePayToken,
            }
          : (isMomo && _momoPhone.trim().isNotEmpty
              ? {'momoPhone': _momoPhone.trim()}
              : null);

      final summary = await ref.read(checkoutRepositoryProvider).placeOrder(
            sellerPayments: selection,
            couponCode: couponCode,
            deliveryOption: deliveryOption,
            deliveryAddressId:
                _delivery == DeliveryKind.pickup ? null : address.id,
            proofSubmittedSellerIds: _proofs.keys.toList(),
            paymentMethod: onlineMethod,
            paymentDetails: paymentDetails,
          );
      await ref.read(cartProvider.notifier).clear();
      ref.invalidate(cartProvider);
      if (!mounted) return;
      context.pushReplacement('/order-confirmation', extra: summary);
    } catch (e) {
      if (mounted) {
        setState(() {
          _placing = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('checkout.title'),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    final cartAsync = ref.watch(cartProvider);
    final addressesAsync = ref.watch(addressesProvider);

    return cartAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => WEmptyState(
        icon: Icons.cloud_off,
        title: context.tr('checkout.cartLoadFailed'),
        subtitle: '${e}',
        actionLabel: context.tr('common.retry'),
        onAction: () => ref.read(cartProvider.notifier).refresh(),
      ),
      data: (cart) {
        if (cart.groups.isEmpty) {
          return WEmptyState(
            icon: Icons.shopping_cart_outlined,
            title: context.tr('checkout.cartEmpty'),
            subtitle: context.tr('checkout.cartEmptyHint'),
          );
        }
        final book = addressesAsync.value ?? const AddressBook();
        final address = _effectiveAddress(book);
        final discount = _discountFor(cart);
        final deliveryFee = _deliveryFee();
        final total = cart.subtotal - discount + deliveryFee;
        _maybeLoadPaymentAccounts(cart);

        return Column(
          children: [
            CheckoutStepIndicator(
                current: _step, labels: _stepLabels(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_step == 0)
                    _cartStep(cart, book)
                  else if (_step == 1)
                    ShippingStep(
                      addresses: book.addresses,
                      selectedAddressId: address?.id,
                      creating: _creating,
                      delivery: _delivery,
                      onSelectAddress: (a) =>
                          setState(() => _selectedAddressId = a.id),
                      onCreateAddress: _createAddress,
                      onDeliveryChanged: (d) =>
                          setState(() => _delivery = d),
                    )
                  else
                    PaymentStep(
                      cart: cart,
                      methods: _methods,
                      proofs: _proofs,
                      paymentAccounts: _paymentAccounts,
                      momoPhone: _momoPhone,
                      totalAmount: total,
                      termsAccepted: _termsAccepted,
                      error: _placing ? null : _error,
                      placing: _placing,
                      onMethodSelected: (sellerId, kind) =>
                          setState(() => _methods[sellerId] = kind),
                      onUploadProof: _uploadProof,
                      onRemoveProof: (sellerId) =>
                          setState(() => _proofs.remove(sellerId)),
                      onMomoPhoneChanged: (phone) =>
                          setState(() => _momoPhone = phone),
                      onToggleTerms: () => setState(
                          () => _termsAccepted = !_termsAccepted),
                      onGooglePayResult: (result) {
                        final tokenData = result['tokenizationData'];
                        if (tokenData is Map &&
                            tokenData['token'] != null) {
                          setState(() => _googlePayToken =
                              tokenData['token'] as String);
                          _placeOrder(cart);
                        }
                      },
                      onPayNow: () => _placeOrder(cart),
                    ),
                  const SizedBox(height: 8),
                  _couponCard(theme),
                ],
              ),
            ),
            if (_step < 2)
              CheckoutBottomNav(
                step: _step,
                last: false,
                busy: false,
                label: context.tr('common.continue'),
                onBack: _step > 0 ? _goBack : null,
                onContinue: () {
                  if (_validate(cart, book)) _goNext();
                },
              ),
          ],
        );
      },
    );
  }

  Widget _cartStep(CartData cart, AddressBook book) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WPageTitle(
          context.tr('checkout.orderSummary'),
          subtitle: context.tr('checkout.itemCountFromSellers', namedArgs: {
            'itemCount': '${cart.itemCount}',
            'sellerCount': '${cart.groups.length}',
          }),
        ),
        const SizedBox(height: 14),
        for (final g in cart.groups) CheckoutGroupLine(group: g),
        SectionCard(
          child: Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('checkout.sellersPaidSeparately'),
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _couponCard(ThemeData theme) {
    final subtotal = ref.watch(cartProvider).value?.subtotal ?? 0;
    return SectionCard(
      title: context.tr('checkout.couponTitle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponController,
                  decoration: InputDecoration(
                      hintText: context.tr('checkout.enterCode'),
                      isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _applyCoupon,
                child: Text(context.tr('common.apply')),
              ),
            ],
          ),
          if (_coupon != null) ...[
            const SizedBox(height: 8),
            Text(
              context.tr('checkout.couponOff', namedArgs: {
                'code': _coupon!.code,
                'amount': formatMoney(_coupon!.applyTo(subtotal)),
              }),
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.appColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
