import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Address;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/currency/currency_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/w_widgets.dart';
import '../../account/data/account_repository.dart';
import '../../account/models/profile.dart';
import '../../account/presentation/addresses_screen.dart';
import '../../cart/models/cart.dart';
import '../../cart/providers/cart_provider.dart';
import '../../messages/providers/chat_providers.dart';
import '../data/checkout_repository.dart';
import '../models/checkout.dart';
import 'widgets/checkout_payment_step.dart';
import 'widgets/checkout_shared.dart';
import 'widgets/checkout_shipping_step.dart';
import 'widgets/checkout_wallet_sheet.dart';

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
  String? _selectedAddressId;
  DeliveryKind _delivery = DeliveryKind.standard;
  PaymentKind? _method;
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
      if (id.isEmpty)
        throw Exception('The server did not return an address id');
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
            content: Text(
              context.tr('addresses.saveFailed', namedArgs: {'error': '$e'}),
            ),
          ),
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
    return book.addresses.firstWhere(
      (a) => a.id == id,
      orElse: () => book.addresses.first,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  num _deliveryFee() =>
      DeliveryOption.all.firstWhere((o) => o.id == _delivery).price;

  /// Normalizes the MoMo phone entry into the 9-digit local number
  /// (without country code or leading 0): "0788 123 456" ? "788123456",
  /// "+250 788 123 456" ? "788123456".
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
      ref.read(addressesProvider).value ?? AddressBook(),
    );
    if (address == null) {
      _showError(context.tr('checkout.selectAddressFirst'));
      return;
    }
    final method = _method;
    if (method == null) {
      _showError(context.tr('checkout.selectPaymentMethod'));
      return;
    }
    final momoPhoneInvalid = context.tr('checkout.momoPhoneInvalid');

    // Every Stripe method has its own native flow: cards get the card
    // PaymentSheet, wallets get their own native sheet, PayPal gets a hosted
    // PayPal page. They must never fall through to one shared modal.
    switch (method) {
      case PaymentKind.card:
        await _payWithCard(cart);
        return;
      case PaymentKind.googlePay:
      case PaymentKind.applePay:
        await _payWithWallet(cart, method);
        return;
      case PaymentKind.paypal:
        await _payWithPaypal(cart);
        return;
      case PaymentKind.momo:
      case PaymentKind.bank:
      case PaymentKind.cashOnDelivery:
        break;
    }

    final isMomo = method == PaymentKind.momo;
    if (isMomo && _momoDigits().length != 9) {
      _showError(momoPhoneInvalid);
      return;
    }

    setState(() {
      _placing = true;
      _error = null;
    });
    try {
      final deliveryOption = _delivery.apiValue;

      // The buyer pays the platform once; we record the same method on every
      // seller order so each seller's share is scheduled for payout.
      final selection = [
        for (final g in cart.groups)
          {'sellerId': g.sellerId, 'paymentMethod': method.apiValue},
      ];

      final onlineMethod = isMomo ? method.apiValue : null;
      final momoDigits = _momoDigits();
      final Map<String, dynamic>? paymentDetails =
          isMomo && momoDigits.isNotEmpty
          ? {'momoPhone': '+250$momoDigits'}
          : null;

      final summary = await ref
          .read(checkoutRepositoryProvider)
          .placeOrder(
            sellerPayments: selection,
            deliveryOption: deliveryOption,
            deliveryAddressId: _delivery == DeliveryKind.pickup
                ? null
                : address.id,
            paymentMethod: onlineMethod,
            paymentDetails: paymentDetails,
          );
      await _completeOrder(summary);
    } catch (e) {
      _fail(e);
    }
  }

  /// Card entry only: the Stripe PaymentSheet is initialised without wallet
  /// config, so Apple Pay / Google Pay tiles inside the sheet are disabled.
  Future<void> _payWithCard(CartData cart) async {
    final address = _effectiveAddress(
      ref.read(addressesProvider).value ?? AddressBook(),
    );
    if (address == null) {
      _showError(context.tr('checkout.selectAddressFirst'));
      return;
    }

    setState(() {
      _placing = true;
      _error = null;
    });
    try {
      final intent = await ref
          .read(checkoutRepositoryProvider)
          .createStripePaymentIntent(
            sellerPayments: _sellerSelection(cart, PaymentKind.card),
            deliveryOption: _delivery.apiValue,
            deliveryAddressId: _delivery == DeliveryKind.pickup
                ? null
                : address.id,
            currency: currencyController.value.code.toLowerCase(),
            stripeMethod: 'card',
          );

      await _prepareStripe(intent.publishableKey);

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: AppConfig.appName,
          paymentIntentClientSecret: intent.clientSecret,
          style: ThemeMode.system,
          // No applePay / googlePay config: this sheet must show card entry
          // only. The wallets have dedicated tiles and native flows.
          allowsDelayedPaymentMethods: false,
        ),
      );
      try {
        await Stripe.instance.presentPaymentSheet();
      } on StripeException catch (e) {
        if (e.error.code == FailureCode.Canceled) {
          if (mounted) setState(() => _placing = false);
          return;
        }
        rethrow;
      }

      await _confirmStripeIntent(intent.intentId);
    } catch (e) {
      _fail(e);
    }
  }

  /// Apple Pay / Google Pay: opens a modal with Stripe's own wallet button. The
  /// button is rendered by the Stripe SDK, so the native wallet sheet and the
  /// card payment method both come from Stripe. When the device cannot present
  /// that wallet (or the merchant is not approved for it), the modal offers
  /// Stripe's hosted checkout page instead.
  Future<void> _payWithWallet(CartData cart, PaymentKind wallet) async {
    final address = _effectiveAddress(
      ref.read(addressesProvider).value ?? AddressBook(),
    );
    if (address == null) {
      _showError(context.tr('checkout.selectAddressFirst'));
      return;
    }

    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final isApplePay = wallet == PaymentKind.applePay;
    if (isApplePay ? !isIOS : !isAndroid) {
      _showError(
        context.tr(
          isApplePay
              ? 'checkout.payment.applePayUnavailable'
              : 'checkout.payment.googlePayUnavailable',
        ),
      );
      return;
    }

    setState(() {
      _placing = true;
      _error = null;
    });
    try {
      // RWF and several local currencies cannot be presented by the wallet
      // sheets, so charge the equivalent in USD (same rule as the web app).
      final currency = walletCheckoutCurrency(currencyController.value.code);
      final intent = await ref
          .read(checkoutRepositoryProvider)
          .createStripePaymentIntent(
            sellerPayments: _sellerSelection(cart, PaymentKind.card),
            deliveryOption: _delivery.apiValue,
            deliveryAddressId: _delivery == DeliveryKind.pickup
                ? null
                : address.id,
            currency: currency.toLowerCase(),
            stripeMethod: 'card',
          );

      final testEnv = _stripeTestMode(intent);
      bool supported = false;
      try {
        await _prepareStripe(intent.publishableKey, applePay: isApplePay);
        supported = isApplePay
            ? await Stripe.instance.isPlatformPaySupported()
            : await Stripe.instance.isPlatformPaySupported(
                googlePay: IsGooglePaySupportedParams(testEnv: testEnv),
              );
      } catch (_) {
        // A missing merchant id, entitlement or unsupported device must not
        // block the hosted Stripe fallback.
        supported = false;
      }

      if (!mounted) return;
      setState(() => _placing = false);

      final action = await showModalBottomSheet<WalletSheetAction>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        showDragHandle: false,
        builder: (_) => CheckoutWalletSheet(
          wallet: wallet,
          clientSecret: intent.clientSecret,
          currencyCode: intent.currency,
          amount: intent.chargeTotal ?? intent.grandTotal ?? 0,
          supported: supported,
          testMode: testEnv,
        ),
      );
      if (!mounted) return;

      switch (action) {
        case WalletSheetAction.paid:
          setState(() => _placing = true);
          await _confirmStripeIntent(intent.intentId);
        case WalletSheetAction.hostedCheckout:
          await _payWithHostedWallet(cart, address);
        case null:
          setState(() => _placing = false);
      }
    } catch (e) {
      _fail(e);
    }
  }

  /// Fallback for native wallets: Stripe's hosted Checkout still renders
  /// Google Pay / Apple Pay in the in-app browser when the device / merchant
  /// setup supports them, and works with a card everywhere else.
  Future<void> _payWithHostedWallet(CartData cart, Address address) async {
    final startFailed = context.tr('checkout.payment.stripeOpenFailed');

    setState(() {
      _placing = true;
      _error = null;
    });
    try {
      final currency = walletCheckoutCurrency(currencyController.value.code);
      final session = await ref
          .read(checkoutRepositoryProvider)
          .createStripeCheckout(
            sellerPayments: _sellerSelection(cart, PaymentKind.card),
            deliveryOption: _delivery.apiValue,
            deliveryAddressId: _delivery == DeliveryKind.pickup
                ? null
                : address.id,
            paymentMethodType: 'card',
            stripeMethod: 'card',
            currency: currency.toLowerCase(),
          );
      if (session.url.isEmpty) {
        throw Exception(startFailed);
      }
      final launched = await _openHostedCheckout(session.url);
      if (!launched) {
        throw Exception(startFailed);
      }
      if (!mounted) return;

      final summary = await showDialog<PlacementSummary?>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _HostedCheckoutWaitDialog(
          intentId: session.intentId,
          titleKey: 'checkout.payment.walletWaitingTitle',
          bodyKey: 'checkout.payment.walletWaitingBody',
        ),
      );
      if (!mounted) return;
      if (summary != null) {
        await _completeOrder(summary);
        return;
      }
      setState(() {
        _placing = false;
        _error = context.tr('checkout.payment.walletNotCompleted');
      });
    } catch (e) {
      _fail(e);
    }
  }

  /// Wallet fallbacks prefer an in-app browser (SFSafariViewController / Chrome
  /// Custom Tabs) because both support Apple Pay and Google Pay web checkout.
  /// PayPal keeps its existing external-browser flow, which its login page
  /// expects. Any in-app failure falls back to the external browser.
  Future<bool> _openHostedCheckout(String url, {bool inApp = true}) async {
    final uri = Uri.parse(url);
    if (inApp) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
          return true;
        }
      } catch (_) {
        // Fall through to the external browser.
      }
    }
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// PayPal: the mobile Stripe SDKs cannot present a PayPal sheet, so start a
  /// PayPal-only Stripe-hosted Checkout session (same integration as the web),
  /// open it in the browser and poll the order status until it is paid.
  Future<void> _payWithPaypal(CartData cart) async {
    final address = _effectiveAddress(
      ref.read(addressesProvider).value ?? AddressBook(),
    );
    if (address == null) {
      _showError(context.tr('checkout.selectAddressFirst'));
      return;
    }
    final startFailed = context.tr('checkout.payment.paypalStartFailed');

    setState(() {
      _placing = true;
      _error = null;
    });
    try {
      final session = await ref
          .read(checkoutRepositoryProvider)
          .createStripeCheckout(
            sellerPayments: _sellerSelection(cart, PaymentKind.card),
            deliveryOption: _delivery.apiValue,
            deliveryAddressId: _delivery == DeliveryKind.pickup
                ? null
                : address.id,
            paymentMethodType: 'paypal',
            stripeMethod: 'paypal',
            currency: currencyController.value.code,
          );
      if (session.url.isEmpty) {
        throw Exception(startFailed);
      }
      final launched = await _openHostedCheckout(session.url, inApp: false);
      if (!launched) {
        throw Exception(startFailed);
      }
      if (!mounted) return;

      final summary = await showDialog<PlacementSummary?>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _HostedCheckoutWaitDialog(
          intentId: session.intentId,
          titleKey: 'checkout.payment.paypalWaitingTitle',
          bodyKey: 'checkout.payment.paypalWaitingBody',
        ),
      );
      if (!mounted) return;
      if (summary != null) {
        await _completeOrder(summary);
        return;
      }
      setState(() {
        _placing = false;
        _error = context.tr('checkout.payment.paypalNotCompleted');
      });
    } catch (e) {
      _fail(e);
    }
  }

  /// Seller selection for a Stripe payment. Wallets and PayPal settle as a
  /// card charge on the server; only the intent's top-level method differs.
  List<Map<String, dynamic>> _sellerSelection(
    CartData cart,
    PaymentKind kind,
  ) => [
    for (final g in cart.groups)
      {'sellerId': g.sellerId, 'paymentMethod': kind.apiValue},
  ];

  /// Applies the publishable key (and Apple Pay merchant id when needed) to
  /// the Stripe SDK before presenting a native sheet.
  Future<void> _prepareStripe(String serverKey, {bool applePay = false}) async {
    Stripe.publishableKey = serverKey.isNotEmpty
        ? serverKey
        : AppConfig.stripePublishableKey;
    if (applePay) {
      final merchantId = AppConfig.applePayMerchantId;
      if (merchantId.isEmpty) {
        throw Exception(context.tr('checkout.payment.applePayNotConfigured'));
      }
      Stripe.merchantIdentifier = merchantId;
    }
    await Stripe.instance.applySettings();
  }

  bool _stripeTestMode(StripePaymentIntentResult intent) {
    final key = intent.publishableKey.isNotEmpty
        ? intent.publishableKey
        : AppConfig.stripePublishableKey;
    return key.startsWith('pk_test_');
  }

  /// Verifies the PaymentIntent server-side and places the order.
  Future<void> _confirmStripeIntent(String intentId) async {
    final result = await ref
        .read(checkoutRepositoryProvider)
        .confirmStripePaymentIntent(intentId);
    if (!mounted) return;
    if (result.status == 'paid' && result.summary != null) {
      await _completeOrder(result.summary!);
      return;
    }
    setState(() {
      _placing = false;
      _error = context.tr('checkout.payment.notCompleted');
    });
  }

  /// Clears the cart and shows the placed order. Shared by every Stripe flow.
  Future<void> _completeOrder(PlacementSummary summary) async {
    await ref.read(cartProvider.notifier).clear();
    ref.invalidate(cartProvider);
    if (!mounted) return;
    context.pushReplacement('/order-confirmation', extra: summary);
  }

  void _fail(Object error) {
    if (!mounted) return;
    setState(() {
      _placing = false;
      _error = error.toString();
    });
  }

  /// Lets the buyer pick a store from the cart and opens a chat with that
  /// seller � the single "Chat with sellers" affordance on the payment step.
  Future<void> _showSellerChatSheet(CartData cart) async {
    final selected = await showModalBottomSheet<CartSellerGroup>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _SellerChatSheet(groups: cart.groups),
    );
    if (selected == null || !mounted) return;
    try {
      final conversation = await ref
          .read(chatRepositoryProvider)
          .start(selected.sellerId);
      if (!mounted) return;
      if (conversation.id.isEmpty) {
        throw Exception(context.tr('orders.noSellerToChat'));
      }
      context.push('/conversation/${conversation.id}');
    } catch (e) {
      if (mounted) {
        _showError(context.tr('orders.chatFailed', namedArgs: {'error': '$e'}));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('checkout.title'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
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
            CheckoutStepIndicator(current: _step, labels: _stepLabels(context)),
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
                      onDeliveryChanged: (d) => setState(() => _delivery = d),
                    )
                  else
                    PaymentStep(
                      cart: cart,
                      method: _method,
                      momoPhone: _momoPhone,
                      totalAmount: total,
                      error: _placing ? null : _error,
                      placing: _placing,
                      onMethodSelected: (kind) =>
                          setState(() => _method = kind),
                      onMomoPhoneChanged: (phone) =>
                          setState(() => _momoPhone = phone),
                      onChatWithSellers: () => _showSellerChatSheet(cart),
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
          subtitle: context.tr(
            'checkout.itemCountFromSellers',
            namedArgs: {
              'itemCount': '${cart.itemCount}',
              'sellerCount': '${cart.groups.length}',
            },
          ),
        ),
        const SizedBox(height: 14),
        for (final g in cart.groups) CheckoutGroupLine(group: g),
        SectionCard(
          child: Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('checkout.sellersPaidSeparately'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet listing the stores in the cart so the buyer can pick who to
/// chat with. Pops with the selected [CartSellerGroup] (or null).
class _SellerChatSheet extends StatelessWidget {
  const _SellerChatSheet({required this.groups});

  final List<CartSellerGroup> groups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('checkout.chatSheetTitle'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('checkout.chatSheetHint'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: groups.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final group = groups[i];
                  final name = group.sellerName?.trim().isNotEmpty == true
                      ? group.sellerName!.trim()
                      : context.tr('common.seller');
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    tileColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    leading: CircleAvatar(
                      backgroundColor: Palette.gold,
                      foregroundColor: Colors.black,
                      child: Text(
                        name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    title: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      context.tr(
                        'checkout.storeItemCount',
                        namedArgs: {'count': '${group.items.length}'},
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(Icons.forum_outlined, size: 20),
                    onTap: () => Navigator.of(context).pop(group),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Waits for a Stripe-hosted session (PayPal or a wallet fallback) to be paid.
/// The buyer completes the payment in the browser; once the webhook places the
/// order this dialog closes with the placed-order summary.
class _HostedCheckoutWaitDialog extends ConsumerStatefulWidget {
  const _HostedCheckoutWaitDialog({
    required this.intentId,
    required this.titleKey,
    required this.bodyKey,
  });

  final String intentId;
  final String titleKey;
  final String bodyKey;

  @override
  ConsumerState<_HostedCheckoutWaitDialog> createState() =>
      _HostedCheckoutWaitDialogState();
}

class _HostedCheckoutWaitDialogState
    extends ConsumerState<_HostedCheckoutWaitDialog> {
  Timer? _timer;
  bool _checking = false;
  int _attempts = 0;

  /// ~10 minutes at 3 second intervals.
  static const int _maxAttempts = 200;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      final result = await ref
          .read(checkoutRepositoryProvider)
          .getStripeCheckoutStatus(widget.intentId);
      if (!mounted) return;
      if (result.isPaid && result.summary != null) {
        _timer?.cancel();
        Navigator.of(context).pop(result.summary);
        return;
      }
      if (result.isExpired) {
        _timer?.cancel();
        Navigator.of(context).pop();
        return;
      }
    } catch (_) {
      // A transient network error should not stop the poll loop.
    } finally {
      _checking = false;
    }

    _attempts++;
    if (_attempts >= _maxAttempts) {
      _timer?.cancel();
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _cancel() {
    _timer?.cancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr(widget.titleKey)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LinearProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            context.tr(widget.bodyKey),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : _check,
          child: Text(context.tr('checkout.payment.paypalCheckNow')),
        ),
        TextButton(
          onPressed: _cancel,
          child: Text(context.tr('common.cancel')),
        ),
      ],
    );
  }
}
