import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
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
  String _momoPhone = '';
  String? _error;

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

  num _deliveryFee() =>
      DeliveryOption.all.firstWhere((o) => o.id == _delivery).price;

  /// Normalizes the MoMo phone entry into the 9-digit local number
  /// (without country code or leading 0): "0788 123 456" → "788123456",
  /// "+250 788 123 456" → "788123456".
  String _momoDigits() {
    var digits = _momoPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('250') && digits.length > 9) {
      digits = digits.substring(3);
    }
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.length > 9) digits = digits.substring(0, 9);
    return digits;
  }

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
    final isMomo = firstMethod == PaymentKind.momo;
    final isCard = firstMethod == PaymentKind.card;

    if (isCard) {
      await _payWithCard(cart);
      return;
    }

    if (isMomo && _momoDigits().length != 9) {
      _showError('Enter a valid MoMo phone number');
      return;
    }

    setState(() {
      _placing = true;
      _error = null;
    });
    try {
      final deliveryOption = _delivery.apiValue;

      final selection = [
        for (final g in cart.groups)
          {
            'sellerId': g.sellerId,
            'paymentMethod':
                (_methods[g.sellerId] ?? PaymentKind.momo).apiValue,
          },
      ];

      final onlineMethod = isMomo ? firstMethod.apiValue : null;
      final momoDigits = _momoDigits();
      final Map<String, dynamic>? paymentDetails =
          isMomo && momoDigits.isNotEmpty
              ? {'momoPhone': '+250$momoDigits'}
              : null;

      final summary = await ref.read(checkoutRepositoryProvider).placeOrder(
            sellerPayments: selection,
            deliveryOption: deliveryOption,
            deliveryAddressId:
                _delivery == DeliveryKind.pickup ? null : address.id,
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

  /// Card payments go through Stripe's hosted Checkout page. The backend
  /// creates a session for the whole cart; the Stripe webhook places the
  /// order once the buyer pays. When they come back we poll the intent
  /// status, then clear the cart and open the confirmation page.
  Future<void> _payWithCard(CartData cart) async {
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

    setState(() {
      _placing = true;
      _error = null;
    });
    try {
      final deliveryOption = _delivery.apiValue;
      final selection = [
        for (final g in cart.groups)
          {
            'sellerId': g.sellerId,
            'paymentMethod':
                (_methods[g.sellerId] ?? PaymentKind.card).apiValue,
          },
      ];

      final session = await ref
          .read(checkoutRepositoryProvider)
          .createStripeCheckout(
            sellerPayments: selection,
            deliveryOption: deliveryOption,
            deliveryAddressId:
                _delivery == DeliveryKind.pickup ? null : address.id,
          );
      if (!mounted) return;

      final opened = await launchUrl(
        Uri.parse(session.url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw Exception(context.tr('checkout.stripeOpenFailed'));
      }

      final summary = await showModalBottomSheet<PlacementSummary>(
        context: context,
        isDismissible: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        showDragHandle: true,
        builder: (_) => _StripePaymentSheet(intentId: session.intentId),
      );

      if (!mounted) return;
      if (summary == null) {
        // Dismissed, expired or failed — the cart was never touched.
        setState(() => _placing = false);
        _showError(context.tr('checkout.stripeNotConfirmed'));
        return;
      }
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
        final deliveryFee = _deliveryFee();
        final total = cart.subtotal + deliveryFee;

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
                      momoPhone: _momoPhone,
                      totalAmount: total,
                      termsAccepted: _termsAccepted,
                      error: _placing ? null : _error,
                      placing: _placing,
                      onMethodSelected: (sellerId, kind) =>
                          setState(() => _methods[sellerId] = kind),
                      onMomoPhoneChanged: (phone) =>
                          setState(() => _momoPhone = phone),
                      onToggleTerms: () => setState(
                          () => _termsAccepted = !_termsAccepted),
                      onPayNow: () => _placeOrder(cart),
                    ),
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
}

/// Shown after the buyer is sent to Stripe's hosted Checkout page. Polls the
/// checkout intent until the webhook has placed the order (pops with the
/// [PlacementSummary]) or the session expires (pops with null).
class _StripePaymentSheet extends ConsumerStatefulWidget {
  const _StripePaymentSheet({required this.intentId});

  final String intentId;

  @override
  ConsumerState<_StripePaymentSheet> createState() => _StripePaymentSheetState();
}

class _StripePaymentSheetState extends ConsumerState<_StripePaymentSheet> {
  static const _interval = Duration(seconds: 3);
  static const _maxPolls = 60;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _poll(0);
  }

  Future<void> _poll(int attempt) async {
    if (_done) return;
    try {
      final result = await ref
          .read(checkoutRepositoryProvider)
          .getStripeCheckoutStatus(widget.intentId);
      if (!mounted || _done) return;
      if (result.isPaid && result.summary != null) {
        _done = true;
        Navigator.of(context).pop(result.summary);
        return;
      }
      if (result.isExpired) {
        _done = true;
        Navigator.of(context).pop(null);
        return;
      }
    } catch (_) {
      // Transient network error — keep polling.
    }
    if (attempt >= _maxPolls) return;
    await Future<void>.delayed(_interval);
    if (!mounted || _done) return;
    _poll(attempt + 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              context.tr('checkout.stripeWaitingTitle'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('checkout.stripeWaitingBody'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _done
                  ? null
                  : () {
                      _done = true;
                      Navigator.of(context).pop(null);
                    },
              icon: Icon(Icons.close, size: 16, color: colors.warning),
              label: Text(context.tr('common.close')),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
